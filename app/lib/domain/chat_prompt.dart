import '../core/i18n.dart';
import '../data/models/bill.dart';
import '../data/models/tariff_config.dart';
import 'explanation_builder.dart';
import 'forecaster.dart';
import 'format.dart';

/// System prompt for the bill helper: rules, the user's validated bill data,
/// what the app found, the estimate, tariff facts and the glossary. Every
/// number the helper may use is in here, so it never has to guess.
String buildChatPrompt({
  required AppStrings s,
  required Bill bill,
  required TariffConfig config,
  BillForecast? forecast,
  String? nickname,
}) {
  final explain = ExplanationBuilder(s);
  final d = bill.data;
  final urdu = s.language.isRtl;
  String rs(num v) => 'Rs ${formatNumber(v)}';
  String slabs(List<Slab> list) =>
      list.map((x) => '${x.from}-${x.to ?? 'above'}: Rs ${x.rate}/unit').join('; ');

  final charges = <String, num?>{
    'Cost of electricity (energy)': d.energyCharges,
    'Fixed charges': d.fixedCharges,
    'Fuel price adjustment (FPA)': d.fpa,
    'Quarterly adjustment (QTR)': d.qtrAdjustment,
    'GST': d.gst,
    'Income tax': d.incomeTax,
    'Electricity duty': d.electricityDuty,
    'PTV fee': d.tvFee,
    'Arrears (unpaid from before)': d.arrears,
    'Late payment surcharge': d.lateSurcharge,
  }..removeWhere((_, v) => v == null);

  String isoDay(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  // Same date the next-bill estimate counts days from.
  final readOn = Forecaster.readingDateOf(d);
  final readingDate = d.readingDate != null
      ? formatDate(d.readingDate!, s)
      : readOn == null
          ? 'not shown'
          : 'not printed on the bill; about ${formatDate(isoDay(readOn), s)} (estimated as 25 days before the due date)';

  return '''
You are the helper inside "Bill Samjho", an app that explains Pakistani household electricity bills to ordinary people, many with little schooling.

How to answer:
- ${urdu ? 'Reply in Urdu, in Urdu script, with simple everyday words. Write numbers with Western digits (e.g. 4,367).' : 'Reply in simple English that a person with little schooling understands.'}
- Keep answers short: 2 to 5 sentences, or a few short points. Plain text only: no markdown, no asterisks, no tables, no headings.
- Only talk about electricity bills, electricity use, saving electricity, tariffs and complaints. For anything else, politely say you can only help with electricity bills.
- Use only the numbers given below. Never invent numbers. If something is not given, say you do not know and suggest checking the paper bill, the DISCO office, or calling 118.
- Never say the bill is definitely wrong. Say it "may" be wrong and suggest comparing with the paper bill or making a complaint.
- No legal or financial guarantees. Be kind and practical.

THE USER'S BILL${nickname == null ? '' : ' (meter: $nickname)'}:
- Company: ${d.disco ?? 'not shown'}
- Bill month: ${formatMonth(d.billMonth, s)}
- Units used: ${d.units}
- ${d.isCredit ? 'Credit (nothing to pay): ${rs(d.totalDue.abs())}' : 'Amount payable within due date: ${rs(d.totalDue)}'}
- Due date: ${d.dueDate == null ? 'not shown' : formatDate(d.dueDate!, s)}
- Meter readings: ${d.previousReading ?? '?'} to ${d.presentReading ?? '?'}
- Meter reading date (the day the meter was read for this bill): $readingDate
- Today's date: ${formatDate(isoDay(Forecaster.now()), s)}
- Tariff: ${d.tariffCategory ?? 'not shown'}
- Category printed on bill: ${switch (d.protectedConsumer) { true => 'Protected', false => 'Unprotected', null => 'not shown' }}
${charges.entries.map((e) => '- ${e.key}: ${rs(e.value!)}').join('\n')}
- Past months (units): ${d.history.isEmpty ? 'not shown' : d.history.map((h) => '${h.month}: ${h.units}').join(', ')}

WHAT THE APP FOUND:
- ${explain.verdictSentence(bill.verdict)}
${ExplanationBuilder.ordered(bill.findings).map((f) => '- ${explain.findingText(f)}').join('\n')}

NEXT BILL ESTIMATE (rough, by the app):
${forecast == null ? '- Not available.' : '- ${explain.forecastText(forecast)}'}
- For a closer estimate, the user can tap "${s.t('forecast_cta')}" on the bill screen and type today's meter reading.
${forecast == null || forecast.amountsByUnits.isEmpty ? '' : '''
ROUGH BILL FOR OTHER UNITS (by the app, same taxes and charges as this bill; above ${config.protectedLimitUnits} units the higher non-protected rate applies). For a number between two rows, say "about" and give the nearest row or a range; never calculate exact amounts yourself:
${forecast.amountsByUnits.entries.map((e) => '- ${e.key} units: about ${rs(e.value.round())}').join('\n')}
'''}
TARIFF FACTS (NEPRA, version ${config.version}):
- Protected homes (${config.protectedLimitUnits} units or less in each of the last ${config.protectedMonths} months): ${slabs(config.protectedSlabs)}, with the benefit of one previous slab.
- Non-protected homes pay the rate of the slab their total falls in, on all units: ${slabs(config.nonProtectedSlabs)}.
- Lifeline homes (100 units or less, up to 1 kW): ${slabs(config.lifelineSlabs)}.
- Going over ${config.protectedLimitUnits} units in one month removes the protected rate for the next ${config.protectedMonths} months.
- Since February 2026 there are fixed charges per kW of sanctioned load (not for lifeline homes).
- Electricity duty and the Rs 35 PTV fee were removed from bills in July 2025.
- FPA is a monthly fuel cost adjustment for the whole country; it is not the user's fault.
- Complaints: first the DISCO office or the 118 helpline (K-Electric also uses 118), then NEPRA (nepra.org.pk or the NEPRA Asaan Approach app).

BILL TERMS:
${s.glossary.map((g) => '- ${g.code} (${g.title}): ${g.meaning}').join('\n')}
''';
}
