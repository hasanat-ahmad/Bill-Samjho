import assert from "node:assert/strict";
import { test } from "node:test";

import { validateExtraction } from "./validate.js";

const good = {
  is_electricity_bill: true,
  confidence: 0.9,
  bill_month: "2026-09",
  units: 186,
  total_due: 5867,
  previous_reading: 18420,
  present_reading: 18606,
  history: [{ month: "2026-08", units: 178, amount: 4520 }],
};

test("accepts a good bill and keeps only known fields", () => {
  const r = validateExtraction({ ...good, meter_multiplier: null, extra: "x" });
  assert.ok(r.ok);
  assert.equal(r.bill.units, 186);
  assert.equal(r.bill.confidence, 0.9);
  assert.equal("extra" in r.bill, false);
  assert.equal("is_electricity_bill" in r.bill, false);
});

test("not a bill", () => {
  assert.deepEqual(validateExtraction({ ...good, is_electricity_bill: false }), { ok: false, error: "not_a_bill" });
});

test("missing units or total is unreadable", () => {
  assert.deepEqual(validateExtraction({ ...good, units: null }), { ok: false, error: "unreadable" });
  assert.deepEqual(validateExtraction({ ...good, total_due: null }), { ok: false, error: "unreadable" });
  assert.deepEqual(validateExtraction("nope"), { ok: false, error: "unreadable" });
});

test("units out of range is unreadable", () => {
  assert.equal(validateExtraction({ ...good, units: -1 }).ok, false);
  assert.equal(validateExtraction({ ...good, units: 5001 }).ok, false);
});

test("low confidence is unreadable", () => {
  assert.deepEqual(validateExtraction({ ...good, confidence: 0.5 }), { ok: false, error: "unreadable" });
});

test("reading mismatch flags low confidence instead of rejecting", () => {
  const r = validateExtraction({ ...good, present_reading: 18700 });
  assert.ok(r.ok);
  assert.equal(r.bill.confidence, 0.6);
});

test("reading mismatch explained by multiplier is accepted", () => {
  const r = validateExtraction({ ...good, previous_reading: 1000, present_reading: 1093, units: 186, meter_multiplier: 2 });
  assert.ok(r.ok);
  assert.equal(r.bill.confidence, 0.9);
});

test("numbers as strings with commas are parsed; bad history rows dropped", () => {
  const r = validateExtraction({
    ...good,
    total_due: "5,867",
    history: [{ month: "2026-08", units: "178" }, { month: null, units: 1 }, "x"],
  });
  assert.ok(r.ok);
  assert.equal(r.bill.total_due, 5867);
  assert.deepEqual(r.bill.history, [{ month: "2026-08", units: 178, amount: null }]);
});

test("missing or malformed bill month is unreadable", () => {
  assert.deepEqual(validateExtraction({ ...good, bill_month: "Sept 2026" }), { ok: false, error: "unreadable" });
  assert.deepEqual(validateExtraction({ ...good, bill_month: null }), { ok: false, error: "unreadable" });
  assert.deepEqual(validateExtraction({ ...good, bill_month: "2026-13" }), { ok: false, error: "unreadable" });
});

test("credit bill (negative total) is accepted", () => {
  const r = validateExtraction({ ...good, total_due: -297 });
  assert.ok(r.ok);
  assert.equal(r.bill.total_due, -297);
});

test("total out of range is unreadable", () => {
  assert.equal(validateExtraction({ ...good, total_due: -1e9 }).ok, false);
  assert.equal(validateExtraction({ ...good, total_due: 1e9 }).ok, false);
  assert.equal(validateExtraction({ ...good, total_due: Number.NaN }).ok, false);
});

test("strings are capped and stripped of control and bidi characters", () => {
  const r = validateExtraction({
    ...good,
    reference_no: "12\u202E34\u0000 " + "9".repeat(100),
    disco: "LESCO\u200F",
  });
  assert.ok(r.ok);
  assert.equal(r.bill.disco, "LESCO");
  assert.equal((r.bill.reference_no as string).length, 40);
  assert.ok(!(r.bill.reference_no as string).includes("\u202E"));
});

test("bad due date dropped, absurd amounts dropped, history capped", () => {
  const r = validateExtraction({
    ...good,
    due_date: "15 Oct",
    arrears: 1e12,
    history: Array.from({ length: 40 }, (_, i) => ({ month: "2025-01", units: i })),
  });
  assert.ok(r.ok);
  assert.equal(r.bill.due_date, null);
  assert.equal(r.bill.arrears, null);
  assert.equal((r.bill.history as unknown[]).length, 24);
});

test("history rows with bad months are dropped", () => {
  const r = validateExtraction({ ...good, history: [{ month: "Aug", units: 5 }, { month: "2026-08", units: 5 }] });
  assert.ok(r.ok);
  assert.deepEqual(r.bill.history, [{ month: "2026-08", units: 5, amount: null }]);
});
