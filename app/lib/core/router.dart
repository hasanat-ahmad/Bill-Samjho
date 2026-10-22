import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../data/bill_chat.dart';
import '../data/bill_repository.dart';
import '../data/local_store.dart';
import '../data/models/extracted_bill.dart';
import '../domain/chat_prompt.dart';
import '../domain/forecaster.dart';
import '../features/chat/chat_cubit.dart';
import '../features/chat/chat_screen.dart';
import '../features/glossary/glossary_screen.dart';
import '../features/history/history_cubit.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/lookup/lookup_screen.dart';
import '../features/onboarding/intro_screen.dart';
import '../features/result/result_cubit.dart';
import '../features/result/result_screen.dart';
import '../features/scan/scan_cubit.dart';
import '../features/scan/scan_screen.dart';
import '../features/settings/settings_screen.dart';
import '../services/scan_service.dart';
import 'i18n.dart';

GoRouter buildRouter(LocalStore store) => GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        final done = store.setting<bool>(SettingKeys.onboardingDone) ?? false;
        if (!done && state.matchedLocation != '/intro') return '/intro';
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(path: '/intro', builder: (context, state) => const IntroScreen()),
        GoRoute(
          path: '/scan/:connectionId',
          builder: (context, state) => BlocProvider(
            create: (context) => ScanCubit(
              repo: context.read<BillRepository>(),
              scanner: context.read<ScanService>(),
              connectionId: state.pathParameters['connectionId']!,
            )..start(),
            child: const ScanScreen(),
          ),
        ),
        GoRoute(
          path: '/lookup/:connectionId',
          builder: (context, state) => LookupScreen(
            connectionId: state.pathParameters['connectionId']!,
            openDirectly: state.uri.queryParameters['latest'] == '1',
          ),
        ),
        // Confirm step for a bill read from PITC's website.
        GoRoute(
          path: '/confirm/:connectionId',
          redirect: (context, state) => state.extra is ExtractedBill ? null : '/',
          builder: (context, state) => BlocProvider(
            create: (context) => ScanCubit.withBill(
              repo: context.read<BillRepository>(),
              scanner: context.read<ScanService>(),
              connectionId: state.pathParameters['connectionId']!,
              bill: state.extra! as ExtractedBill,
            ),
            child: const ScanScreen(),
          ),
        ),
        GoRoute(
          path: '/result/:billId',
          builder: (context, state) => BlocProvider(
            create: (context) =>
                ResultCubit(context.read<BillRepository>())..load(state.pathParameters['billId']!),
            // Auto-play only right after a scan, not when opened from history.
            child: ResultScreen(autoPlay: state.uri.queryParameters['fresh'] == '1'),
          ),
        ),
        GoRoute(
          path: '/chat/:billId',
          builder: (context, state) {
            final repo = context.read<BillRepository>();
            final bill = repo.bill(state.pathParameters['billId']!);
            final chat = context.read<ChatAvailability>();
            if (bill == null || !chat.enabled) return const ChatUnavailableScreen();
            final past = repo.billsFor(bill.connectionId).where((b) => b.id != bill.id).toList();
            final prompt = buildChatPrompt(
              s: context.read<AppStrings>(),
              bill: bill,
              config: repo.tariffConfig,
              forecast: Forecaster(repo.tariffConfig).forecast(bill.data, past),
              nickname: repo.connection(bill.connectionId)?.nickname,
            );
            return BlocProvider(
              create: (_) => ChatCubit(chat.create!(prompt)),
              child: ChatScreen(billMonth: bill.data.billMonth),
            );
          },
        ),
        GoRoute(
          path: '/history/:connectionId',
          builder: (context, state) => BlocProvider(
            create: (context) =>
                HistoryCubit(context.read<BillRepository>(), state.pathParameters['connectionId']!),
            child: const HistoryScreen(),
          ),
        ),
        GoRoute(path: '/glossary', builder: (context, state) => const GlossaryScreen()),
        GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      ],
    );
