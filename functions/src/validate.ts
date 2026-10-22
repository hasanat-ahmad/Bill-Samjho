/** Validation of Gemini output (SDA §9.3). */

export const MIN_CONFIDENCE = 0.6;
export const MAX_UNITS = 5000;
export const MAX_AMOUNT = 10_000_000;
export const MAX_HISTORY_ROWS = 24;

const MONTH = /^\d{4}-(0[1-9]|1[0-2])$/;
const DATE = /^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/;
/** Control and bidi-override characters that could disguise text. */
const UNSAFE_CHARS = /[\u0000-\u001F\u007F-\u009F\u200B-\u200F\u202A-\u202E\u2066-\u2069]/g;
const STRING_LIMITS: Record<string, number> = {
  disco: 24, reference_no: 40, bill_month: 7, tariff_category: 24, due_date: 10, reading_date: 10,
};

export type ExtractError = "not_a_bill" | "unreadable";

export type ValidationResult =
  | { ok: true; bill: Record<string, unknown> }
  | { ok: false; error: ExtractError };

const NUMBER_FIELDS = [
  "energy_charges", "fixed_charges", "fpa", "qtr_adjustment", "gst", "income_tax",
  "electricity_duty", "tv_fee", "arrears", "late_surcharge",
] as const;
const STRING_FIELDS = ["disco", "reference_no", "bill_month", "tariff_category", "due_date", "reading_date"] as const;

function toNumber(v: unknown): number | null {
  if (typeof v === "number") return Number.isFinite(v) ? v : null;
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

function toStr(v: unknown, maxLength = 64): string | null {
  if (typeof v !== "string") return null;
  const s = v.replace(UNSAFE_CHARS, "").trim();
  return s === "" ? null : [...s].slice(0, maxLength).join("");
}

function toAmount(v: unknown): number | null {
  const n = toNumber(v);
  return n !== null && Math.abs(n) <= MAX_AMOUNT ? n : null;
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
  // Negative = credit bill ("CR"), e.g. after overpayment or solar net metering.
  if (Math.abs(totalDue) > MAX_AMOUNT) return { ok: false, error: "unreadable" };
  const billMonth = toStr(r.bill_month);
  if (billMonth === null || !MONTH.test(billMonth)) return { ok: false, error: "unreadable" };

  let confidence = toNumber(r.confidence) ?? 0;
  if (confidence < MIN_CONFIDENCE) return { ok: false, error: "unreadable" };

  const reading = (v: unknown) => {
    const n = toInt(v);
    return n !== null && n >= 0 && n < 1_000_000_000 ? n : null;
  };
  const previous = reading(r.previous_reading);
  const present = reading(r.present_reading);
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
  for (const f of STRING_FIELDS) bill[f] = toStr(r[f], STRING_LIMITS[f]);
  for (const f of NUMBER_FIELDS) bill[f] = toAmount(r[f]);
  bill.bill_month = billMonth;
  bill.protected_consumer = typeof r.protected_consumer === "boolean" ? r.protected_consumer : null;
  if (typeof bill.due_date === "string" && !DATE.test(bill.due_date)) bill.due_date = null;
  if (typeof bill.reading_date === "string" && !DATE.test(bill.reading_date)) bill.reading_date = null;

  const history = Array.isArray(r.history) ? r.history : [];
  bill.history = history.flatMap((h) => {
    if (typeof h !== "object" || h === null) return [];
    const e = h as Record<string, unknown>;
    const month = toStr(e.month, 7);
    const u = toInt(e.units);
    if (month === null || !MONTH.test(month) || u === null || u < 0 || u > MAX_UNITS) return [];
    return [{ month, units: u, amount: toAmount(e.amount) }];
  }).slice(0, MAX_HISTORY_ROWS);

  return { ok: true, bill };
}
