import { createHmac } from "node:crypto";

import busboy from "busboy";
import { initializeApp } from "firebase-admin/app";
import { getAppCheck } from "firebase-admin/app-check";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { defineSecret } from "firebase-functions/params";
import { onRequest, type Request } from "firebase-functions/v2/https";
import { ApiError, GoogleGenAI } from "@google/genai";

import { BILL_SCHEMA, SYSTEM_PROMPT } from "./schema.js";
import { validateExtraction } from "./validate.js";

initializeApp();

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
/** Key for hashing client IPs, so raw IP addresses are never stored. */
const RATE_LIMIT_SECRET = defineSecret("RATE_LIMIT_SECRET");

const MAX_IMAGE_BYTES = 500 * 1024;
/** Image plus multipart overhead; larger requests are refused before parsing. */
const MAX_BODY_BYTES = MAX_IMAGE_BYTES + 16 * 1024;
const DAILY_LIMIT_PER_DEVICE = 30;
/** Generous because many Pakistani mobile users share one carrier IP (CGNAT). */
const DAILY_LIMIT_PER_IP = 300;
/** Total time for all model attempts; stays under the app's 20 s timeout. */
const GEMINI_BUDGET_MS = 18_000;
/** Errors worth retrying on the next model: overload, rate limit, server error. */
const RETRYABLE_STATUS = new Set([429, 500, 502, 503, 504]);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type Upload = { image?: Buffer; deviceId?: string; tooLarge: boolean };

/** Parses multipart form data in memory. The image is never written anywhere. */
function parseUpload(req: Request): Promise<Upload> {
  return new Promise((resolve, reject) => {
    const result: Upload = { tooLarge: false };
    const bb = busboy({
      headers: req.headers,
      limits: { files: 1, fields: 2, parts: 3, fieldSize: 64, fileSize: MAX_IMAGE_BYTES },
    });
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

/** JPEG files start with FF D8 FF. */
function isJpeg(data: Buffer): boolean {
  return data.length > 3 && data[0] === 0xff && data[1] === 0xd8 && data[2] === 0xff;
}

/**
 * Verifies the Firebase App Check token, proving the request comes from the
 * genuine app on a real device. Enforced unless REQUIRE_APP_CHECK=false
 * (only for the local emulator).
 */
async function appCheckPasses(req: Request): Promise<boolean> {
  if (process.env.REQUIRE_APP_CHECK === "false") return true;
  const token = req.header("X-Firebase-AppCheck");
  if (!token) return false;
  try {
    await getAppCheck().verifyToken(token);
    return true;
  } catch {
    return false;
  }
}

/**
 * Counts requests per device and per (hashed) IP per UTC day in one
 * transaction. Returns false when either is over its limit.
 */
async function allowRequest(deviceId: string, ip: string): Promise<boolean> {
  const day = new Date().toISOString().slice(0, 10);
  const ipHash = createHmac("sha256", RATE_LIMIT_SECRET.value()).update(ip).digest("hex").slice(0, 32);
  const db = getFirestore();
  const deviceRef = db.collection("rateLimits").doc(`d_${deviceId}_${day}`);
  const ipRef = db.collection("rateLimits").doc(`i_${ipHash}_${day}`);
  // Firestore TTL policy on `expiresAt` deletes old counters.
  const expiresAt = Timestamp.fromMillis(Date.now() + 2 * 24 * 60 * 60 * 1000);

  return db.runTransaction(async (tx) => {
    const [device, byIp] = await tx.getAll(deviceRef, ipRef);
    const deviceCount = (device.get("count") as number | undefined) ?? 0;
    const ipCount = (byIp.get("count") as number | undefined) ?? 0;
    if (deviceCount >= DAILY_LIMIT_PER_DEVICE || ipCount >= DAILY_LIMIT_PER_IP) return false;
    tx.set(deviceRef, { count: FieldValue.increment(1), expiresAt }, { merge: true });
    tx.set(ipRef, { count: FieldValue.increment(1), expiresAt }, { merge: true });
    return true;
  });
}

/**
 * Asks Gemini to read the bill, trying each model in turn while time remains.
 * Returns the JSON text, or undefined if every attempt failed.
 */
async function readBill(models: string[], image: Buffer): Promise<string | undefined> {
  const deadline = Date.now() + GEMINI_BUDGET_MS;
  const data = image.toString("base64");
  for (const model of models) {
    const remaining = deadline - Date.now();
    if (remaining < 2_000) break;
    try {
      const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY.value(), httpOptions: { timeout: remaining } });
      const response = await ai.models.generateContent({
        model,
        contents: [{
          role: "user",
          parts: [{ inlineData: { mimeType: "image/jpeg", data } }, { text: "Read this bill." }],
        }],
        config: {
          systemInstruction: SYSTEM_PROMPT,
          temperature: 0,
          responseMimeType: "application/json",
          responseSchema: BILL_SCHEMA,
        },
      });
      return response.text;
    } catch (e) {
      const status = e instanceof ApiError ? e.status : undefined;
      // Log only the model and status, never the image or the response.
      logger.warn("Gemini call failed", { model, status: status ?? "timeout_or_network" });
      if (status !== undefined && !RETRYABLE_STATUS.has(status)) return undefined;
    }
  }
  return undefined;
}

/** POST /extractBill: bill photo → validated ExtractedBill JSON (SDA §9). */
export const extractBill = onRequest(
  {
    region: "asia-south1",
    secrets: [GEMINI_API_KEY, RATE_LIMIT_SECRET],
    memory: "512MiB",
    timeoutSeconds: 30,
    maxInstances: 10,
    invoker: "public",
    cors: false,
  },
  async (req, res) => {
    res.set({ "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff" });
    const fail = (status: number, error: string) => { res.status(status).json({ error }); };

    if (req.method !== "POST") return fail(405, "method_not_allowed");
    if (!(req.header("content-type") ?? "").toLowerCase().startsWith("multipart/form-data")) {
      return fail(400, "unreadable");
    }
    const declaredLength = Number(req.header("content-length") ?? "0");
    if (declaredLength > MAX_BODY_BYTES || (req.rawBody?.length ?? 0) > MAX_BODY_BYTES) {
      return fail(413, "too_large");
    }
    if (!(await appCheckPasses(req))) return fail(401, "unauthorized");

    let upload: Upload;
    try {
      upload = await parseUpload(req);
    } catch {
      return fail(400, "unreadable");
    }
    if (upload.tooLarge) return fail(413, "too_large");
    if (!upload.deviceId || !UUID.test(upload.deviceId)) return fail(400, "unreadable");
    if (!upload.image || !isJpeg(upload.image)) return fail(400, "unreadable");

    if (!(await allowRequest(upload.deviceId, req.ip ?? "unknown"))) return fail(429, "rate_limited");

    // Comma-separated, best first; the next is tried when one is overloaded.
    const models = (process.env.GEMINI_MODEL ?? "").split(",").map((m) => m.trim()).filter(Boolean);
    if (models.length === 0) {
      logger.error("GEMINI_MODEL is not set");
      return fail(503, "ai_busy");
    }

    const text = await readBill(models, upload.image);
    if (text === undefined) return fail(503, "ai_busy");

    let parsed: unknown;
    try {
      parsed = JSON.parse(text ?? "");
    } catch {
      return fail(400, "unreadable");
    }

    const result = validateExtraction(parsed);
    if (!result.ok) return fail(400, result.error);
    res.status(200).json(result.bill);
  },
);
