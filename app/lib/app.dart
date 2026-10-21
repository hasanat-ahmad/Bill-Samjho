import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/constants.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'data/bill_repository.dart';
import 'data/local_store.dart';
import 'data/models/urdu_strings.dart';
import 'domain/explanation_builder.dart';
import 'features/home/home_cubit.dart';
import 'features/settings/settings_cubit.dart';
import 'services/scan_service.dart';
import 'services/tts_service.dart';

class BillSamjhoApp extends StatefulWidget {
  const BillSamjhoApp({
    super.key,
    required this.store,
    required this.repo,
    required this.strings,
    required this.tts,
    required this.scanner,
  });

  final LocalStore store;
  final BillRepository repo;
  final UrduStrings strings;
  final TtsService tts;
  final ScanService scanner;

  @override
  State<BillSamjhoApp> createState() => _BillSamjhoAppState();
}

class _BillSamjhoAppState extends State<BillSamjhoApp> {
  late final GoRouter _router = buildRouter(widget.store);

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: widget.repo),
        RepositoryProvider.value(value: widget.strings),
        RepositoryProvider.value(value: widget.tts),
        RepositoryProvider.value(value: widget.scanner),
        RepositoryProvider(create: (_) => ExplanationBuilder(widget.strings)),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => SettingsCubit(widget.store, widget.repo, widget.tts)),
          BlocProvider(create: (_) => HomeCubit(widget.repo)),
        ],
        child: BlocBuilder<SettingsCubit, AppSettings>(
          builder: (context, settings) => MaterialApp.router(
            title: Labels.appName,
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            routerConfig: _router,
            // Urdu locale makes the whole app right-to-left (NFR-02).
            locale: const Locale('ur', 'PK'),
            supportedLocales: const [Locale('ur', 'PK')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              final scale = mq.textScaler.scale(1) * (settings.largeText ? 1.25 : 1.0);
              return MediaQuery(
                data: mq.copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              );
            },
          ),
        ),
      ),
    );
  }
}
