import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/bill_repository.dart';
import '../../data/models/extracted_bill.dart';
import '../../data/pitc/pitc.dart';
import '../../data/pitc/pitc_bill_parser.dart';

/// Opens the user's bill on PITC's official duplicate-bill website inside the
/// app, then reads it once the user has opened it. The user taps Search on
/// the official page (and answers any CAPTCHA PITC shows); the app never
/// submits the form itself.
class LookupScreen extends StatefulWidget {
  const LookupScreen({super.key, required this.connectionId, this.openDirectly = false});

  final String connectionId;

  /// Skip the form when the meter already has a saved reference number.
  final bool openDirectly;

  @override
  State<LookupScreen> createState() => _LookupScreenState();
}

class _LookupScreenState extends State<LookupScreen> {
  final _reference = TextEditingController();
  Disco? _disco;
  bool _rural = false;
  String? _formError;

  WebViewController? _web;
  ReferenceNumber? _openedFor;
  bool _pageLoading = false;
  bool _billVisible = false;
  bool _reading = false;
  String? _pageError;

  @override
  void initState() {
    super.initState();
    final c = context.read<BillRepository>().connection(widget.connectionId);
    _disco = Disco.find(c?.disco);
    final saved = c?.referenceNo == null ? null : ReferenceNumber.parse(c!.referenceNo!);
    if (saved != null) {
      _reference.text = saved.display.substring(0, 16);
      _rural = saved.rural;
    }
    if (widget.openDirectly && saved != null && _disco != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _open());
    }
  }

  @override
  void dispose() {
    _reference.dispose();
    // Do not keep PITC session data on the phone.
    if (_web != null) {
      WebViewCookieManager().clearCookies();
      _web!.clearCache();
    }
    super.dispose();
  }

  void _open() {
    final s = context.read<AppStrings>();
    final ref = ReferenceNumber.parse(_reference.text, rural: _rural);
    if (_disco == null || ref == null) {
      setState(() => _formError = s.t('reference_invalid'));
      return;
    }
    FocusScope.of(context).unfocus();
    final controller = WebViewController()
      // PITC's page is an ASP.NET form and needs JavaScript.
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      // PITC's bill is laid out for a desktop screen: allow pinch-zoom.
      ..enableZoom(true)
      // The web view can still report after the user has left this screen.
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          return uri != null && PitcSite.isAllowed(uri) ? NavigationDecision.navigate : NavigationDecision.prevent;
        },
        onPageStarted: (_) {
          if (!mounted) return;
          setState(() {
            _pageLoading = true;
            _billVisible = false;
            _pageError = null;
          });
        },
        onPageFinished: (_) => _afterPageLoad(),
        onWebResourceError: (error) {
          if (mounted && (error.isForMainFrame ?? true)) {
            setState(() {
              _pageLoading = false;
              _pageError = s.t('page_error');
            });
          }
        },
      ))
      ..loadRequest(_disco!.billPage);
    setState(() {
      _formError = null;
      _web = controller;
      _openedFor = ref;
    });
  }

  /// Fills the reference number into PITC's search box (the user still taps
  /// Search) and checks whether a bill is now showing.
  Future<void> _afterPageLoad() async {
    final web = _web, ref = _openedFor;
    if (web == null || ref == null) return;
    try {
      // Digits only, so safe to place in the script.
      await web.runJavaScript(
        "(function(){var b=document.getElementById('searchTextBox');if(b&&!b.value){b.value='${ref.digits}';}"
        "var s=document.getElementById('ruCodeTextBox');if(s){s.value='${ref.rural ? 'R' : ''}';}})();",
      );
      final shown = await web.runJavaScriptReturningResult(
        "document.body ? /PAYABLE\\s+WITHIN\\s+DUE\\s+DATE|UNITS\\s+CONSUMED/i.test(document.body.innerText) : false",
      );
      final billVisible = shown == true || shown.toString() == 'true';
      if (billVisible) await _fitToWidth(web);
      if (mounted) {
        setState(() {
          _pageLoading = false;
          _billVisible = billVisible;
        });
      }
    } catch (e) {
      debugPrint('PITC page check failed: ${e.runtimeType}');
      if (mounted) setState(() => _pageLoading = false);
    }
  }

  /// Fits PITC's bill to the phone screen; the user can still pinch-zoom.
  /// Display only.
  ///
  /// PITC's 2026 page scales its 794 px bill itself, but never below 50% and
  /// from the box's centre, which on phones pushes the bill off the right
  /// edge. This applies the same scaling to the real screen width, anchored
  /// at the left, and again after PITC's own resize handler. Other layouts
  /// are zoomed so the widest element fits.
  static Future<void> _fitToWidth(WebViewController web) => web.runJavaScript(r"""
(function () {
  function fit() {
    var boxes = document.querySelectorAll('.bill-canvas-viewport');
    if (!boxes.length) return false;
    var w = 794, h = 1123;
    var shell = document.querySelector('.gbn-app-shell');
    if (shell) shell.style.maxWidth = '100%';
    boxes.forEach(function (b) {
      // Width actually available inside the bill's card (it has padding).
      var parent = b.parentElement, avail = window.innerWidth;
      if (parent) {
        var cs = getComputedStyle(parent);
        avail = Math.min(avail, parent.clientWidth - parseFloat(cs.paddingLeft) - parseFloat(cs.paddingRight));
      }
      var s = Math.min(1, (avail - 2) / w);
      b.style.width = w + 'px';
      b.style.transform = 'scale(' + s + ')';
      b.style.transformOrigin = 'top left';
      b.style.marginRight = (w * (s - 1)) + 'px';
      b.style.marginBottom = (h * (s - 1)) + 'px';
    });
    return true;
  }
  if (!window.__billSamjhoFit) {
    window.__billSamjhoFit = true;
    window.addEventListener('resize', fit);
  }
  if (fit()) return;
  var body = document.body;
  if (!body) return;
  body.style.zoom = '';
  var v = window.innerWidth, widest = document.documentElement.scrollWidth, all = body.getElementsByTagName('*');
  for (var i = 0; i < all.length; i++) { if (all[i].scrollWidth > widest) widest = all[i].scrollWidth; }
  if (widest > v + 4) body.style.zoom = String(Math.max(0.3, (v - 8) / widest));
})();
""");

  Future<void> _read() async {
    final web = _web;
    if (web == null || _reading) return;
    final s = context.read<AppStrings>();
    final repo = context.read<BillRepository>();
    setState(() => _reading = true);
    HapticFeedback.lightImpact();
    try {
      final script = await rootBundle.loadString('assets/pitc/read_bill.js');
      final page = PitcPage.fromJson(_decode(await web.runJavaScriptReturningResult(script)));
      ExtractedBill? bill = PitcBillParser.parse(page, disco: _disco!.code);
      // Unknown layout: let the AI backend read the page text instead.
      bill ??= await repo.extractText(page.text).then<ExtractedBill?>((b) => b, onError: (Object _) => null);
      if (!mounted) return;
      if (bill == null) {
        setState(() => _pageError = s.t('lookup_failed'));
        return;
      }
      await repo.saveReference(
        widget.connectionId,
        referenceNo: bill.referenceNo ?? _openedFor!.display,
        disco: _disco!.code,
      );
      if (mounted) context.pushReplacement('/confirm/${widget.connectionId}', extra: bill);
    } catch (e) {
      debugPrint('Reading PITC page failed: ${e.runtimeType}');
      if (mounted) setState(() => _pageError = s.t('lookup_failed'));
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  /// Android returns the script's string result JSON-encoded once more.
  static Map<String, dynamic> _decode(Object raw) {
    Object value = raw;
    if (value is String && value.startsWith('"')) value = jsonDecode(value);
    if (value is String) value = jsonDecode(value);
    return value as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) => _web == null ? _form(context) : _browser(context);

  Widget _form(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('lookup_title'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, bottomPadding(context)),
        children: [
          Text(s.t('lookup_intro'), style: theme.textTheme.bodyMedium),
          SectionTitle(s.t('company')),
          Wrap(spacing: Gap.sm, runSpacing: Gap.sm, children: [
            for (final d in Disco.all)
              ChoiceChip(
                showCheckmark: false,
                selected: _disco == d,
                side: BorderSide(color: _disco == d ? AppColors.primary : AppColors.borderStrong),
                label: Text(d.code, style: numberStyle(13.5, color: _disco == d ? AppColors.primaryDark : AppColors.ink)),
                tooltip: d.city,
                onSelected: (_) => setState(() => _disco = d),
              ),
          ]),
          SectionTitle(s.t('reference_label')),
          TextField(
            controller: _reference,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            maxLength: 18,
            style: numberStyle(19, letterSpacing: 0.5),
            inputFormatters: [_ReferenceFormatter()],
            decoration: InputDecoration(
              hintText: s.t('reference_hint'),
              hintStyle: numberStyle(19, weight: FontWeight.w400, color: AppColors.inkSubtle, letterSpacing: 0.5),
              counterText: '',
              errorText: _formError,
            ),
            onSubmitted: (_) => _open(),
          ),
          const SizedBox(height: Gap.md),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: false, label: Text(s.t('urban'))),
              ButtonSegment(value: true, label: Text(s.t('rural'))),
            ],
            selected: {_rural},
            onSelectionChanged: (v) => setState(() => _rural = v.first),
          ),
          const SizedBox(height: Gap.xl),
          PrimaryButton(label: s.t('open_bill'), onPressed: _open),
          const SizedBox(height: Gap.xl),
          NoteRow(icon: Icons.lock_outline_rounded, color: AppColors.green, text: s.t('lookup_privacy')),
          const SizedBox(height: Gap.md),
          NoteRow(icon: Icons.info_outline_rounded, text: s.t('kelectric_note')),
        ],
      ),
    );
  }

  Widget _browser(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_disco!.code),
        actions: [
          IconButton(
            tooltip: s.t('try_again'),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _web?.reload(),
          ),
        ],
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: Gap.page, vertical: Gap.sm + 2),
          child: Row(children: [
            const Icon(Icons.verified_user_outlined, color: AppColors.green, size: 18),
            const SizedBox(width: Gap.sm),
            Expanded(child: Text(s.t(_billVisible ? 'lookup_bill_open' : 'lookup_tap_search'), style: theme.textTheme.bodySmall)),
          ]),
        ),
        if (_pageLoading) const LinearProgressIndicator(minHeight: 3),
        Expanded(
          child: _pageError != null
              ? MessageView(
                  icon: Icons.cloud_off_rounded,
                  tone: Tone.check,
                  title: _pageError!,
                  actions: [
                    PrimaryButton(
                      label: s.t('try_again'),
                      icon: Icons.refresh_rounded,
                      onPressed: () {
                        setState(() => _pageError = null);
                        _web?.reload();
                      },
                    ),
                    SecondaryButton(
                      label: s.t('take_photo'),
                      icon: Icons.photo_camera_rounded,
                      onPressed: () => context.pushReplacement('/scan/${widget.connectionId}'),
                    ),
                  ],
                )
              : WebViewWidget(controller: _web!),
        ),
      ]),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.md),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (!_billVisible && _pageError == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.sm),
                  child: Text(s.t('lookup_waiting'), style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
                ),
              PrimaryButton(
                label: s.t('lookup_explain'),
                busy: _reading,
                onPressed: _billVisible && _pageError == null ? _read : null,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Digits only (Urdu digits converted), grouped as "07 11234 1234567".
class _ReferenceFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = StringBuffer();
    for (final r in newValue.text.runes) {
      if (r >= 0x30 && r <= 0x39) {
        digits.writeCharCode(r);
      } else if (r >= 0x6F0 && r <= 0x6F9) {
        digits.writeCharCode(r - 0x6F0 + 0x30);
      } else if (r >= 0x660 && r <= 0x669) {
        digits.writeCharCode(r - 0x660 + 0x30);
      }
    }
    final d = digits.toString();
    final trimmed = d.length > 14 ? d.substring(0, 14) : d;
    final grouped = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      if (i == 2 || i == 7) grouped.write(' ');
      grouped.write(trimmed[i]);
    }
    final text = grouped.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
