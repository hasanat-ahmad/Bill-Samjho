/// Common household appliances with typical power and daily use, for the
/// "what does it cost to run?" calculator. Watts are typical figures, not a
/// specific model's; the user changes the hours (and the count).
class Appliance {
  const Appliance(this.key, this.watts, this.hours, {this.dutyCycle = 1.0});

  /// i18n key suffix: `appliance_<key>`.
  final String key;
  final int watts;

  /// Default hours a day it is on.
  final double hours;

  /// Share of the "on" time it actually draws power (a fridge's compressor
  /// runs about half the time).
  final double dutyCycle;

  /// Units (kWh) in [days] days for [count] of them used [hoursPerDay].
  double units({required int count, required double hoursPerDay, int days = 30}) =>
      watts * dutyCycle * hoursPerDay * days * count / 1000;

  static const all = [
    Appliance('fan', 80, 12),
    Appliance('led', 12, 6),
    Appliance('tube', 40, 6),
    Appliance('ac_inverter', 1100, 6),
    Appliance('ac', 1500, 6),
    Appliance('cooler', 200, 8),
    Appliance('fridge', 150, 24, dutyCycle: 0.5),
    Appliance('tv', 100, 5),
    Appliance('iron', 1000, 0.5),
    Appliance('washer', 500, 1),
    Appliance('motor', 750, 1),
    Appliance('heater', 1500, 3),
    Appliance('geyser', 2000, 1),
    Appliance('microwave', 1200, 0.25),
    Appliance('computer', 150, 4),
    Appliance('ups', 100, 8),
  ];
}

/// One appliance the user added: how many and how long.
class ApplianceUse {
  const ApplianceUse(this.appliance, {this.count = 1, required this.hoursPerDay});

  final Appliance appliance;
  final int count;
  final double hoursPerDay;

  int get monthlyUnits => appliance.units(count: count, hoursPerDay: hoursPerDay).round();

  ApplianceUse copyWith({int? count, double? hoursPerDay}) =>
      ApplianceUse(appliance, count: count ?? this.count, hoursPerDay: hoursPerDay ?? this.hoursPerDay);
}
