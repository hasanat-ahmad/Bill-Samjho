/** Validation of Gemini output (SDA §9.3). */

export const MIN_CONFIDENCE = 0.6;
export const MAX_UNITS = 5000;

export type ExtractError = "not_a_bill" | "unreadable";

export type ValidationResult =
  | { ok: true; bill: Record<string, unknown> }
  | { ok: false; error: ExtractError };

const NUMBER_FIELDS = [
  "energy_charges", "fixed_charges", "fpa", "qtr_adjustment", "gst", "income_tax",
  "electricity_duty", "tv_fee", "arrears", "late_surcharge",
] as const;
const STRING_FIELDS = ["disco", "reference_no", "bill_month", "tariff_category", "due_date"] as const;

function toNumber(v: unknown): number | null {
  if (typeof v === "number" && Number.isFinite(v)) return v;
  if (typeof v === "string") {
    const n = Number(v.replace(/,/g, "").trim());
    return v.trim() !== "" && Number.isFinite(n) ? n : null;
  }
  return null;
}

function toInt(v: unknown): number | null {
  const n = toNumber(v);
  return n === null ? null : Math.round(n);
}

function toStr(v: unknown): string | null {
  if (typeof v !== "string") return null;
  const s = v.trim();
  return s === "" ? null : s;
}

/**
 * Checks the model output and returns only the ExtractedBill fields,
 * so nothing the app shows can come from unvalidated AI text.
 */
export function validateExtraction(raw: unknown): ValidationResult {
  if (typeof raw !== "object" || raw === null) return { ok: false, error: "unreadable" };
  const r = raw as Record<string, unknown>;

  if (r.is_electricity_bill === false) return { ok: false, error: "not_a_bill" };

  const units = toInt(r.units);
  const totalDue = toNumber(r.total_due);
  if (units === null || totalDue === null) return { ok: false, error: "unreadable" };
  if (units < 0 || units > MAX_UNITS) return { ok: false, error: "unreadable" };

  let confidence = toNumber(r.confidence) ?? 0;
  if (confidence < MIN_CONFIDENCE) return { ok: false, error: "unreadable" };

  const previous = toInt(r.previous_reading);
  const present = toInt(r.present_reading);
  if (previous !== null && present !== null && present - previous !== units) {
    // K-Electric and some meters print a multiplying factor.
    const multiplier = toNumber(r.meter_multiplier);
    const matchesMultiplier =
      multiplier !== null && Math.abs((present - previous) * multiplier - units) <= 1;
    if (!matchesMultiplier) confidence = Math.min(confidence, MIN_CONFIDENCE);
  }

  const bill: Record<string, unknown> = {
    units,
    total_due: totalDue,
    previous_reading: previous,
    present_reading: present,
    confidence: Math.max(0, Math.min(1, confidence)),
  };
  for (const f of STRING_FIELDS) bill[f] = toStr(r[f]);
  for (const f of NUMBER_FIELDS) bill[f] = toNumber(r[f]);
  bill.bill_month ??= "";

  const history = Array.isArray(r.history) ? r.history : [];
  bill.history = history.flatMap((h) => {
    if (typeof h !== "object" || h === null) return [];
    const e = h as Record<string, unknown>;
    const month = toStr(e.month);
    const u = toInt(e.units);
    if (month === null || u === null || u < 0 || u > MAX_UNITS) return [];
    return [{ month, units: u, amount: toNumber(e.amount) }];
  });

  return { ok: true, bill };
}
