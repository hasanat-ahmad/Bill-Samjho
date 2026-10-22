import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/constants.dart';
import 'core/i18n.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'data/bill_repository.dart';
import 'data/local_store.dart';
import 'features/home/home_cubit.dart';
import 'features/settings/settings_cubit.dart';
import 'services/scan_service.dart';
import 'services/tts_service.dart';

class BillSamjhoApp extends StatefulWidget {
  const BillSamjhoApp({
    super.key,
    required this.store,
    required this.repo,
    required this.translations,
    required this.tts,
    required this.scanner,
    this.appVersion = '',
  });

  final LocalStore store;
  final BillRepository repo;
  final Map<AppLanguage, AppStrings> translations;
  final TtsService tts;
  final ScanService scanner;
  final String appVersion;

  @override
  State<BillSamjhoApp> createState() => _BillSamjhoAppState();
}

class _BillSamjhoAppState extends State<BillSamjhoApp> {
  late final GoRouter _router = buildRouter(widget.store);
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late AppStrings _strings;

  @override
  void initState() {
    super.initState();
    widget.tts.failures.addListener(_onVoiceFailure);
  }

  @override
  void dispose() {
    widget.tts.failures.removeListener(_onVoiceFailure);
    super.dispose();
  }

  /// No voice on the phone could speak: say so instead of staying silent.
  void _onVoiceFailure() {
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(_strings.t('voice_failed')),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: _strings.t('install'),
          onPressed: () => launchUrl(
            Uri.parse(AppConstants.googleTtsPlayStoreUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: widget.repo),
        RepositoryProvider.value(value: widget.tts),
        RepositoryProvider.value(value: widget.scanner),
        RepositoryProvider<AppVersion>.value(value: AppVersion(widget.appVersion)),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => SettingsCubit(widget.store, widget.repo, widget.tts)),
          BlocProvider(create: (_) => HomeCubit(widget.repo)),
        ],
        child: BlocBuilder<SettingsCubit, AppSettings>(
          builder: (context, settings) {
            final strings = _strings = widget.translations[settings.language]!;
            return RepositoryProvider<AppStrings>.value(
              value: strings,
              child: MaterialApp.router(
                title: strings.t('app_name'),
                debugShowCheckedModeBanner: false,
                scaffoldMessengerKey: _messenger,
                theme: buildTheme(settings.language),
                routerConfig: _router,
                // The locale also sets text direction: English LTR, Urdu RTL.
                locale: settings.language.locale,
                supportedLocales: [for (final l in AppLanguage.values) l.locale],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                builder: (context, child) {
                  final mq = MediaQuery.of(context);
                  // Respect the phone's text size, capped so layouts stay usable.
                  final system = mq.textScaler.scale(1).clamp(1.0, 1.3);
                  final scale = system * (settings.largeText ? 1.2 : 1.0);
                  return MediaQuery(data: mq.copyWith(textScaler: TextScaler.linear(scale)), child: child!);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// App version for the About section.
class AppVersion {
  const AppVersion(this.value);
  final String value;
}
