import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/i18n.dart';
import '../../data/bill_repository.dart';
import '../../data/local_store.dart';
import '../../services/tts_service.dart';

class AppSettings {
  const AppSettings({required this.language, required this.slowVoice, required this.largeText});

  final AppLanguage language;
  final bool slowVoice;
  final bool largeText;

  AppSettings copyWith({AppLanguage? language, bool? slowVoice, bool? largeText}) => AppSettings(
        language: language ?? this.language,
        slowVoice: slowVoice ?? this.slowVoice,
        largeText: largeText ?? this.largeText,
      );
}

/// App-wide preferences (FR-17), language, and one-time flags.
class SettingsCubit extends Cubit<AppSettings> {
  SettingsCubit(this._store, this._repo, this._tts)
      : super(AppSettings(
          language: AppLanguage.fromCode(_store.setting<String>(SettingKeys.language)),
          slowVoice: _store.setting<bool>(SettingKeys.slowVoice) ?? false,
          largeText: _store.setting<bool>(SettingKeys.largeText) ?? false,
        ));

  final LocalStore _store;
  final BillRepository _repo;
  final TtsService _tts;

  Future<void> setLanguage(AppLanguage language) async {
    if (language == state.language) return;
    emit(state.copyWith(language: language));
    await _store.setSetting(SettingKeys.language, language.name);
    await _tts.setLanguage(language);
  }

  Future<void> setSlowVoice(bool slow) async {
    emit(state.copyWith(slowVoice: slow));
    await _store.setSetting(SettingKeys.slowVoice, slow);
    await _tts.setSlow(slow);
  }

  Future<void> setLargeText(bool large) async {
    emit(state.copyWith(largeText: large));
    await _store.setSetting(SettingKeys.largeText, large);
  }

  bool get onboardingDone => _store.setting<bool>(SettingKeys.onboardingDone) ?? false;

  Future<void> completeOnboarding() => _store.setSetting(SettingKeys.onboardingDone, true);

  bool get ttsTipShown => _store.setting<bool>(SettingKeys.ttsTipShown) ?? false;

  Future<void> markTtsTipShown() => _store.setSetting(SettingKeys.ttsTipShown, true);

  Future<void> clearAllData() => _repo.clearAll();
}
