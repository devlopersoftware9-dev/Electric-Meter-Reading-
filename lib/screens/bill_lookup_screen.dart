import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/bill_service.dart';
import '../theme.dart';

/// Opens the official PITC bill page inside the app.
///
/// The PITC site now asks for a picture code (captcha) before showing a bill,
/// so the app cannot fetch the bill on its own. This screen fills in the
/// reference number, the user types the code and taps Search, and as soon as
/// the bill page loads the app reads the readings from it and closes.
///
/// Returns a [BillData] (pop result) or null if the user backs out.
class BillLookupScreen extends StatefulWidget {
  const BillLookupScreen({super.key, required this.ref, this.suffix, this.company});

  /// 14 digits, no spaces.
  final String ref;

  /// 'U' or 'R' if known.
  final String? suffix;
  final String? company;

  @override
  State<BillLookupScreen> createState() => _BillLookupScreenState();
}

class _BillLookupScreenState extends State<BillLookupScreen> {
  late String _company;
  late final WebViewController _web;
  bool _loading = true;
  bool _done = false;
  String _status = 'Bill website khul rahi hai…';

  @override
  void initState() {
    super.initState();
    _company = widget.company ?? BillService.guessCompany(widget.ref) ?? 'lesco';
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: _onPageFinished,
      ));
    _load();
  }

  void _load() {
    _web.loadRequest(Uri.parse('https://bill.pitc.com.pk/${_company}bill'));
  }

  Future<String> _html() async {
    final raw = await _web.runJavaScriptReturningResult('document.documentElement.outerHTML');
    if (raw is String) {
      // Android returns the string JSON-encoded ("...").
      if (raw.startsWith('"')) {
        try {
          return jsonDecode(raw) as String;
        } catch (_) {}
      }
      return raw;
    }
    return raw.toString();
  }

  Future<void> _onPageFinished(String url) async {
    if (!mounted || _done) return;
    setState(() => _loading = false);
    String html;
    try {
      html = await _html();
    } catch (_) {
      return;
    }

    final bill = BillService.parseBill(html, _company);
    if (bill != null) {
      _done = true;
      if (mounted) Navigator.pop(context, bill);
      return;
    }

    if (html.contains('searchTextBox')) {
      final ru = widget.suffix == 'R' ? 'R' : '';
      await _web.runJavaScript('''
        (function(){
          var t = document.getElementById('searchTextBox');
          if (t) { t.value = '${widget.ref}'; }
          var ru = document.getElementById('ruCodeTextBox');
          if (ru) { ru.value = '$ru'; }
          var c = document.getElementById('captchaInput');
          if (c) { c.scrollIntoView({block: 'center'}); c.focus(); }
        })();
      ''');
      final notFound = RegExp(r'not\s*found|invalid|incorrect|wrong', caseSensitive: false)
          .hasMatch(html.replaceAll(RegExp(r'<[^>]+>'), ' '));
      setState(() => _status = notFound
          ? 'Bill nahi mila ya code galat tha. Code dobara likhein, ya upar se company badal kar dekhein.'
          : 'Reference number bhar diya hai. Tasveer wala code likh kar "Search" dabayein.');
    } else {
      setState(() => _status = 'Bill parha nahi ja saka. Agar bill nazar aa raha hai to upar se company check karein.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bill dhoondein', style: titleStyle(20)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DropdownButton<String>(
              value: _company,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(12),
              items: [
                for (final e in BillService.companies.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w600))),
              ],
              onChanged: (v) {
                if (v == null || v == _company) return;
                setState(() {
                  _company = v;
                  _status = 'Bill website khul rahi hai…';
                });
                _load();
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(gradient: AppColors.headerWash),
            child: Row(children: [
              const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_status,
                    style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.ink, fontWeight: FontWeight.w500)),
              ),
            ]),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 3),
          Expanded(child: WebViewWidget(controller: _web)),
        ],
      ),
    );
  }
}
