import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/i18n.dart';
import '../data/bill_repository.dart';
import '../data/local_store.dart';
import '../domain/reminders.dart';

/// Bill reminders as local notifications: nothing leaves the phone. Every
/// change to the saved bills re-plans them all, so a deleted meter's
/// reminders go with it. Tapping one opens [ReminderService.tapped]'s route.
class ReminderService {
  ReminderService({required LocalStore store, required BillRepository repo, required AppStrings Function() strings})
      : _store = store,
        _repo = repo,
        _strings = strings;

  final LocalStore _store;
  final BillRepository _repo;
  final AppStrings Function() _strings;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  StreamSubscription<void>? _sub;

  /// The route of the reminder the user tapped (also when it launched the app).
  final ValueNotifier<String?> tapped = ValueNotifier(null);

  static const _channel = 'bill_reminders';

  bool get enabled => _store.setting<bool>(SettingKeys.reminders) ?? true;

  Future<void> init() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: (r) => tapped.value = r.payload,
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) tapped.value = launch!.notificationResponse?.payload;
      _ready = true;
    } catch (e) {
      debugPrint('Reminders unavailable: ${e.runtimeType}');
      return;
    }
    _sub = _repo.changes.listen((_) => sync());
    await sync();
  }

  Future<void> setEnabled(bool on) async {
    await _store.setSetting(SettingKeys.reminders, on);
    if (on) await _askPermission(force: true);
    await sync();
  }

  /// Cancels every reminder and schedules the current plan.
  Future<void> sync() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      if (!enabled) return;
      final s = _strings();
      final plan = const ReminderPlanner().plan(
        connections: _repo.connections(),
        latestBill: _repo.latestBill,
        s: s,
        now: DateTime.now(),
      );
      if (plan.isEmpty) return;
      await _askPermission();
      final details = NotificationDetails(
        android: AndroidNotificationDetails(_channel, s.t('notif_channel'),
            channelDescription: s.t('reminders_body'), importance: Importance.defaultImportance),
      );
      for (final r in plan) {
        await _plugin.zonedSchedule(
          id: r.id,
          // The instant itself is what matters; UTC needs no time zone data.
          scheduledDate: tz.TZDateTime.from(r.at, tz.UTC),
          notificationDetails: details,
          // Inexact: no "alarms & reminders" permission needed.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: r.title,
          body: r.body,
          payload: r.route,
        );
      }
    } catch (e) {
      debugPrint('Scheduling reminders failed: ${e.runtimeType}');
    }
  }

  /// Android 13+ asks once; later the user changes it in the phone settings.
  Future<void> _askPermission({bool force = false}) async {
    if (!force && (_store.setting<bool>(SettingKeys.notificationsAsked) ?? false)) return;
    await _store.setSetting(SettingKeys.notificationsAsked, true);
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  void dispose() {
    _sub?.cancel();
    tapped.dispose();
  }
}
