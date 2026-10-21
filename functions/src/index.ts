import busboy from "busboy";
import { initializeApp } from "firebase-admin/app";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { defineSecret } from "firebase-functions/params";
import { onRequest, type Request } from "firebase-functions/v2/https";
import { ApiError, GoogleGenAI } from "@google/genai";

import { BILL_SCHEMA, SYSTEM_PROMPT } from "./schema.js";
import { validateExtraction } from "./validate.js";

initializeApp();

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

const MAX_IMAGE_BYTES = 500 * 1024;
const DAILY_LIMIT_PER_DEVICE = 30;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type Upload = { image?: Buffer; deviceId?: string; tooLarge: boolean };

/** Parses multipart form data in memory. The image is never written anywhere. */
function parseUpload(req: Request): Promise<Upload> {
  return new Promise((resolve, reject) => {
    const result: Upload = { tooLarge: false };
    const bb = busboy({ headers: req.headers, limits: { files: 1, fields: 5, fileSize: MAX_IMAGE_BYTES } });
    bb.on("file", (name, stream) => {
      const chunks: Buffer[] = [];
      stream.on("data", (c: Buffer) => chunks.push(c));
      stream.on("limit", () => { result.tooLarge = true; });
      stream.on("end", () => { if (name === "image") result.image = Buffer.concat(chunks); });
    });
    bb.on("field", (name, value) => { if (name === "deviceId") result.deviceId = value; });
    bb.on("close", () => resolve(result));
    bb.on("error", reject);
    bb.end(req.rawBody);
  });
}

/** Counts requests per device per UTC day. Returns false when over the limit. */
async function allowRequest(deviceId: string): Promise<boolean> {
  const day = new Date().toISOString().slice(0, 10);
  const ref = getFirestore().collection("rateLimits").doc(`${deviceId}_${day}`);
  return getFirestore().runTransaction(async (tx) => {
    const count = ((await tx.get(ref)).get("count") as number | undefined) ?? 0;
    if (count >= DAILY_LIMIT_PER_DEVICE) return false;
    tx.set(ref, {
      count: FieldValue.increment(1),
      // Firestore TTL policy on `expiresAt` deletes old counters.
      expiresAt: Timestamp.fromMillis(Date.now() + 2 * 24 * 60 * 60 * 1000),
    }, { merge: true });
    return true;
  });
}

/** POST /extractBill: bill photo → ExtractedBill JSON (SDA §9). */
export const extractBill = onRequest(
  {
    region: "asia-south1",
    secrets: [GEMINI_API_KEY],
    memory: "512MiB",
    timeoutSeconds: 30,
    maxInstances: 10,
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "method_not_allowed" });
      return;
    }

    let upload: Upload;
    try {
      upload = await parseUpload(req);
    } catch {
      res.status(400).json({ error: "unreadable" });
      return;
    }
    if (upload.tooLarge) {
      res.status(413).json({ error: "too_large" });
      return;
    }
    if (!upload.image || upload.image.length === 0 || !upload.deviceId || !UUID.test(upload.deviceId)) {
      res.status(400).json({ error: "unreadable" });
      return;
    }

    if (!(await allowRequest(upload.deviceId))) {
      res.status(429).json({ error: "rate_limited" });
      return;
    }

    const model = process.env.GEMINI_MODEL;
    if (!model) {
      logger.error("GEMINI_MODEL is not set");
      res.status(503).json({ error: "ai_busy" });
      return;
    }

    let text: string | undefined;
    try {
      const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY.value() });
      const response = await ai.models.generateContent({
        model,
        contents: [{
          role: "user",
          parts: [
            { inlineData: { mimeType: "image/jpeg", data: upload.image.toString("base64") } },
            { text: "Read this bill." },
          ],
        }],
        config: {
          systemInstruction: SYSTEM_PROMPT,
          temperature: 0,
          responseMimeType: "application/json",
          responseSchema: BILL_SCHEMA,
        },
      });
      text = response.text;
    } catch (e) {
      // Log only the status, never the image or response.
      logger.warn("Gemini call failed", { status: e instanceof ApiError ? e.status : "unknown" });
      res.status(503).json({ error: "ai_busy" });
      return;
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(text ?? "");
    } catch {
      res.status(400).json({ error: "unreadable" });
      return;
    }

    const result = validateExtraction(parsed);
    if (!result.ok) {
      res.status(400).json({ error: result.error });
      return;
    }
    res.status(200).json(result.bill);
  },
);
