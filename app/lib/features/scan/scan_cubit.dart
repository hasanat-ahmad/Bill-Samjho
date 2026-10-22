import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/api_service.dart';
import '../../data/bill_repository.dart';
import '../../data/models/bill.dart';
import '../../data/models/extracted_bill.dart';
import '../../services/scan_service.dart';

sealed class ScanState {
  const ScanState();
}

/// Document scanner, camera or gallery is open.
class ScanOpening extends ScanState {
  const ScanOpening();
}

/// The user backed out of the scanner.
class ScanCancelled extends ScanState {
  const ScanCancelled();
}

enum ReadPhase { preparing, uploading, reading }

/// Where the photo comes from. [scanner] is the ML Kit document scanner with
/// auto-crop; [camera] is the plain system camera, used when the scanner is
/// unavailable on the phone.
enum PhotoSource { scanner, camera, gallery }

/// S4 progress (NFR-04): compressing, uploading with real progress, reading.
class ScanReading extends ScanState {
  const ScanReading(this.phase, {this.progress});
  final ReadPhase phase;

  /// Upload progress 0..1, null when not measurable.
  final double? progress;
}

class ScanFailed extends ScanState {
  const ScanFailed(this.error);
  final ApiError error;
}

/// S5: user checks units and total against the photo.
class ScanConfirm extends ScanState {
  const ScanConfirm(this.data, this.jpeg, {this.saving = false});
  final ExtractedBill data;
  final Uint8List jpeg;
  final bool saving;
}

class ScanDone extends ScanState {
  const ScanDone(this.bill);
  final Bill bill;
}

/// UC-1 steps 3–5: photo → upload → confirm → analyse and save.
class ScanCubit extends Cubit<ScanState> {
  ScanCubit({required BillRepository repo, required ScanService scanner, required this.connectionId})
      : _repo = repo,
        _scanner = scanner,
        super(const ScanOpening());

  final BillRepository _repo;
  final ScanService _scanner;
  final String connectionId;

  Uint8List? _jpeg;

  /// Incremented on cancel so a late upload result is ignored.
  int _attempt = 0;

  Future<void> start({PhotoSource source = PhotoSource.scanner}) async {
    _emit(const ScanOpening());
    final String? path;
    try {
      path = switch (source) {
        PhotoSource.scanner => await _scanner.scan(),
        PhotoSource.camera => await _scanner.takePhoto(),
        PhotoSource.gallery => await _scanner.pickFromGallery(),
      };
    } catch (_) {
      _emit(const ScanFailed(ApiError.unknown));
      return;
    }
    if (path == null) {
      _emit(const ScanCancelled());
      return;
    }

    _emit(const ScanReading(ReadPhase.preparing));
    try {
      _jpeg = await _scanner.compress(path);
    } catch (_) {
      _emit(const ScanFailed(ApiError.unreadable));
      return;
    } finally {
      await _scanner.discard(path);
    }
    await _upload();
  }

  /// Sends the same photo again (offline, timeout, server busy).
  Future<void> retry() => _jpeg == null ? start() : _upload();

  Future<void> _upload() async {
    final attempt = ++_attempt;
    _emit(const ScanReading(ReadPhase.uploading, progress: 0));
    try {
      final data = await _repo.extract(_jpeg!, onProgress: (p) {
        if (attempt != _attempt) return;
        _emit(p >= 1 ? const ScanReading(ReadPhase.reading) : ScanReading(ReadPhase.uploading, progress: p));
      });
      if (attempt == _attempt) _emit(ScanConfirm(data, _jpeg!));
    } on ApiException catch (e) {
      if (attempt == _attempt) _emit(ScanFailed(e.error));
    }
  }

  void cancel() => _attempt++;

  Future<void> confirm({required int units, required double totalDue}) async {
    final s = state;
    if (s is! ScanConfirm || s.saving) return;
    _emit(ScanConfirm(s.data, s.jpeg, saving: true));
    final bill = await _repo.analyseAndSave(
      connectionId: connectionId,
      data: s.data.copyWith(units: units, totalDue: totalDue),
      jpeg: s.jpeg,
    );
    _emit(ScanDone(bill));
  }

  void _emit(ScanState s) {
    if (!isClosed) emit(s);
  }
}
