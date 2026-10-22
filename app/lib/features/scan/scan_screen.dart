import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api_service.dart';
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
        ScanReading() => _ReadingView(state),
        ScanCancelled() => const _CancelledView(),
        ScanFailed(:final error) => _ErrorView(error),
        ScanConfirm() => ConfirmView(data: state.data, jpeg: state.jpeg, saving: state.saving),
      },
    );
  }
}

class _ReadingView extends StatelessWidget {
  const _ReadingView(this.state);

  final ScanReading state;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final title = switch (state.phase) {
      ReadPhase.preparing => s.t('phase_preparing'),
      ReadPhase.uploading => s.t('phase_uploading'),
      ReadPhase.reading => s.t('phase_reading'),
    };
    return PopScope(
      onPopInvokedWithResult: (didPop, _) => context.read<ScanCubit>().cancel(),
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Gap.page),
            child: Column(children: [
              const Spacer(),
              const _ScanAnimation(),
              const SizedBox(height: Gap.xxl),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(title, key: ValueKey(title), style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
              ),
              const SizedBox(height: Gap.sm),
              Text(s.t('reading_hint'), style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: Gap.xl),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: state.phase == ReadPhase.uploading ? state.progress : null,
                ),
              ),
              const Spacer(),
              SecondaryButton(
                label: s.t('cancel'),
                icon: Icons.close_rounded,
                onPressed: () => context.pop(),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A bill with a scan line moving over it.
class _ScanAnimation extends StatefulWidget {
  const _ScanAnimation();

  @override
  State<_ScanAnimation> createState() => _ScanAnimationState();
}

class _ScanAnimationState extends State<_ScanAnimation> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const width = 150.0, height = 190.0;
    return Container(
      width: 220,
      height: 220,
      decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Radii.md),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.bolt_rounded, color: AppColors.amber, size: 26),
              const SizedBox(height: Gap.sm),
              for (final w in [100.0, 80.0, 110.0, 60.0, 90.0])
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  width: w,
                  height: 8,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
                ),
            ]),
          ),
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Positioned(
              top: 8 + (height - 24) * Curves.easeInOut.transform(_c.value),
              left: 8,
              right: 8,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 12)],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _CancelledView extends StatelessWidget {
  const _CancelledView();

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final cubit = context.read<ScanCubit>();
    return Scaffold(
      appBar: AppBar(),
      body: MessageView(
        icon: Icons.document_scanner_rounded,
        title: s.t('take_photo'),
        body: s.t('take_photo_body'),
        actions: [
          PrimaryButton(
            label: s.t('open_camera'),
            icon: Icons.photo_camera_rounded,
            onPressed: () => cubit.start(source: PhotoSource.camera),
          ),
          SecondaryButton(
            label: s.t('from_gallery'),
            icon: Icons.photo_library_rounded,
            onPressed: () => cubit.start(source: PhotoSource.gallery),
          ),
          TextButton(onPressed: () => context.pop(), child: Text(s.t('go_back'))),
        ],
      ),
    );
  }
}

/// FR-06 and SDA §12 step 9: friendly message with the right next step.
class _ErrorView extends StatelessWidget {
  const _ErrorView(this.error);

  final ApiError error;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final cubit = context.read<ScanCubit>();
    final icon = switch (error) {
      ApiError.offline => Icons.wifi_off_rounded,
      ApiError.timeout => Icons.hourglass_bottom_rounded,
      ApiError.notABill => Icons.receipt_long_rounded,
      ApiError.unreadable || ApiError.tooLarge => Icons.photo_camera_back_rounded,
      ApiError.rateLimited => Icons.event_busy_rounded,
      _ => Icons.cloud_off_rounded,
    };
    return Scaffold(
      appBar: AppBar(),
      body: MessageView(
        icon: icon,
        tone: Tone.check,
        title: s.error(error.code),
        actions: [
          if (error.needsNewPhoto) ...[
            PrimaryButton(label: s.t('retake'), icon: Icons.photo_camera_rounded, onPressed: cubit.start),
            SecondaryButton(
              label: s.t('from_gallery'),
              icon: Icons.photo_library_rounded,
              onPressed: () => cubit.start(source: PhotoSource.gallery),
            ),
          ] else if (error.canRetry)
            PrimaryButton(label: s.t('try_again'), icon: Icons.refresh_rounded, onPressed: cubit.retry),
          TextButton(onPressed: () => context.pop(), child: Text(s.t('go_back'))),
        ],
      ),
    );
  }
}
