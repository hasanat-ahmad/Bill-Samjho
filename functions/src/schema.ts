import { Schema, Type } from "@google/genai";

/** System prompt (SDA §9.2). */
export const SYSTEM_PROMPT = `You read photos of Pakistani electricity bills (WAPDA DISCOs and K-Electric).
Extract only values printed on the bill. Never guess or calculate.
If a field is not visible, return null.
Units = units consumed this month as printed.
total_due = amount payable within due date.
history = the month-wise units/amount table printed on the bill, if present.
If the image is not an electricity bill, set is_electricity_bill=false.
Set confidence between 0 and 1 for how clearly you could read units and total_due.
Write months as YYYY-MM and dates as YYYY-MM-DD. Write amounts as plain numbers without commas.

Hints for Pakistani bills (text may be in English and Urdu):
- Common labels: "Units Consumed", "Bill Month" (e.g. "SEP 26" means 2026-09), "Due Date" (e.g. "15 OCT 26" means 2026-10-15),
  "Payable Within Due Date", "Payable After Due Date", "Cost of Electricity", "Fixed Charges", "F.P.A" or "Fuel Price Adjustment",
  "QTR Tariff Adj", "GST", "Arrears", "Previous" and "Present" readings, "Reference No".
- energy_charges is only the "Cost of Electricity" line, not the total. "F.C. Surcharge" (financing cost) is NOT the fuel price adjustment.
  "Total Electricity Charges" on newer bills is also not energy_charges.
- Some newer bills print only the total and a QR code. Then return null for charge lines that are not printed; do not compute them.
- late_surcharge = the "L.P. Surcharge" (late payment) amount if printed; otherwise null.
- If the payable amount is marked "CR" or "Credit Bill", it is a credit: return total_due as a negative number (e.g. "297 CR" means -297).
- The reference number is usually 14 digits, sometimes followed by a letter such as U or R; copy it as printed.`;

const num = (description?: string): Schema => ({ type: Type.NUMBER, nullable: true, description });
const int = (description?: string): Schema => ({ type: Type.INTEGER, nullable: true, description });
const str = (description?: string): Schema => ({ type: Type.STRING, nullable: true, description });

/** Gemini structured-output schema matching ExtractedBill (snake_case). */
export const BILL_SCHEMA: Schema = {
  type: Type.OBJECT,
  properties: {
    is_electricity_bill: { type: Type.BOOLEAN },
    confidence: { type: Type.NUMBER, description: "0..1, how clearly units and total_due were read" },
    disco: str("Company short name, e.g. LESCO, IESCO, K-Electric"),
    reference_no: str("Reference / account number as printed"),
    bill_month: str("Billing month, YYYY-MM"),
    previous_reading: int(),
    present_reading: int(),
    meter_multiplier: num("Meter multiplying factor (MF) if printed, else null"),
    units: int("Units consumed this month as printed"),
    tariff_category: str("Tariff as printed, e.g. A-1a(01)"),
    protected_consumer: { type: Type.BOOLEAN, nullable: true, description: "true if the bill's category says Protected, false if Unprotected or Non-Protected, null if not printed" },
    energy_charges: num("Cost of electricity / energy charges"),
    fixed_charges: num(),
    fpa: num("Fuel price adjustment"),
    qtr_adjustment: num("Quarterly tariff adjustment"),
    gst: num(),
    income_tax: num(),
    electricity_duty: num(),
    tv_fee: num(),
    arrears: num(),
    total_due: num("Amount payable within due date"),
    late_surcharge: num("Extra amount if paid after due date"),
    due_date: str("YYYY-MM-DD"),
    reading_date: str("Date the meter was read for this bill, YYYY-MM-DD"),
    history: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          month: { type: Type.STRING, description: "YYYY-MM" },
          units: { type: Type.INTEGER },
          amount: num(),
        },
        required: ["month", "units"],
      },
    },
  },
  required: ["is_electricity_bill", "confidence", "units", "total_due", "history"],
};
