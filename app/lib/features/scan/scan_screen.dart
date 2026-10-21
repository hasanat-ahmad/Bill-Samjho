import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api_service.dart';
import '../../data/models/urdu_strings.dart';
import 'confirm_view.dart';
import 'scan_cubit.dart';

/// S4 scanning/loading, error states, and S5 confirm.
class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ScanCubit, ScanState>(
      listener: (context, state) {
        // Replace so Back from the result goes to Home, not the scanner.
        if (state is ScanDone) context.pushReplacement('/result/${state.bill.id}?fresh=1');
      },
      builder: (context, state) => switch (state) {
        ScanOpening() || ScanDone() => const Scaffold(body: Center(child: CircularProgressIndicator())),
        ScanReading() => const _ReadingView(),
        ScanCancelled() => const _CancelledView(),
        ScanFailed(:final error) => _ErrorView(error),
        ScanConfirm(:final data, :final saving) => ConfirmView(data: data, saving: saving),
      },
    );
  }
}

class _ReadingView extends StatelessWidget {
  const _ReadingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            const _PulsingIcon(),
            const SizedBox(height: 24),
            Text(Labels.readingBill, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(Labels.readingBillWait, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.close),
                label: const Text(Labels.cancel),
                onPressed: () {
                  context.read<ScanCubit>().cancel();
                  context.pop();
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon();

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: Tween(begin: 0.85, end: 1.1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
        child: const Icon(Icons.receipt_long, size: 120, color: AppColors.primary),
      );
}

class _CancelledView extends StatelessWidget {
  const _CancelledView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ScanCubit>();
    return Scaffold(
      appBar: AppBar(),
      body: MessageView(
        icon: Icons.photo_camera,
        message: Labels.takePhoto,
        actions: [
          FilledButton.icon(icon: const Icon(Icons.camera_alt), label: const Text(Labels.takePhoto), onPressed: cubit.start),
          OutlinedButton.icon(
            icon: const Icon(Icons.photo_library),
            label: const Text(Labels.fromGallery),
            onPressed: () => cubit.start(fromGallery: true),
          ),
          TextButton(onPressed: () => context.pop(), child: const Text(Labels.goBack)),
        ],
      ),
    );
  }
}

/// FR-06 and SDA §12 step 9: friendly Urdu message with a retry action.
class _ErrorView extends StatelessWidget {
  const _ErrorView(this.error);

  final ApiError error;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ScanCubit>();
    final message = context.read<UrduStrings>().error(error.code);
    return Scaffold(
      appBar: AppBar(),
      body: MessageView(
        icon: error == ApiError.offline ? Icons.wifi_off : Icons.error_outline,
        iconColor: AppColors.amber,
        message: message,
        actions: [
          if (error.needsNewPhoto) ...[
            FilledButton.icon(icon: const Icon(Icons.camera_alt), label: const Text(Labels.retake), onPressed: cubit.start),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text(Labels.fromGallery),
              onPressed: () => cubit.start(fromGallery: true),
            ),
          ] else if (error != ApiError.rateLimited)
            FilledButton.icon(icon: const Icon(Icons.refresh), label: const Text(Labels.tryAgain), onPressed: cubit.retry),
          TextButton(onPressed: () => context.pop(), child: const Text(Labels.goBack)),
        ],
      ),
    );
  }
}
