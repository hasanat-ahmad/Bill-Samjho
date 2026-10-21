import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/bill_repository.dart';
import '../../data/local_store.dart';
import '../../services/tts_service.dart';

class AppSettings {
  const AppSettings({required this.slowVoice, required this.largeText});

  final bool slowVoice;
  final bool largeText;
}

/// App-wide preferences (FR-17) and one-time flags.
class SettingsCubit extends Cubit<AppSettings> {
  SettingsCubit(this._store, this._repo, this._tts)
      : super(AppSettings(
          slowVoice: _store.setting<bool>(SettingKeys.slowVoice) ?? false,
          largeText: _store.setting<bool>(SettingKeys.largeText) ?? false,
        ));

  final LocalStore _store;
  final BillRepository _repo;
  final TtsService _tts;

  Future<void> setSlowVoice(bool slow) async {
    emit(AppSettings(slowVoice: slow, largeText: state.largeText));
    await _store.setSetting(SettingKeys.slowVoice, slow);
    await _tts.setSlow(slow);
  }

  Future<void> setLargeText(bool large) async {
    emit(AppSettings(slowVoice: state.slowVoice, largeText: large));
    await _store.setSetting(SettingKeys.largeText, large);
  }

  bool get onboardingDone => _store.setting<bool>(SettingKeys.onboardingDone) ?? false;

  Future<void> completeOnboarding() => _store.setSetting(SettingKeys.onboardingDone, true);

  bool get ttsTipShown => _store.setting<bool>(SettingKeys.ttsTipShown) ?? false;

  Future<void> markTtsTipShown() => _store.setSetting(SettingKeys.ttsTipShown, true);

  Future<void> clearAllData() => _repo.clearAll();
}
