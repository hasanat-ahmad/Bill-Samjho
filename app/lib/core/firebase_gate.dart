/// Firebase starts in the background so it never delays the first screen
/// (its first launch can take many seconds on a slow network). Features that
/// need it wait on [ready] only when used.
class FirebaseGate {
  FirebaseGate(Future<bool> init) : ready = init.catchError((Object _) => false) {
    ready.then((ok) => _done = ok);
  }

  FirebaseGate.done(bool ok)
      : ready = Future.value(ok),
        _done = ok;

  final Future<bool> ready;
  bool? _done;

  /// False only once Firebase is known not to work.
  bool get mayWork => _done != false;
}
