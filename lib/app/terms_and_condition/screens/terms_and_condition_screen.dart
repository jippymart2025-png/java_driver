import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/themes/app_them_data.dart';
import 'package:jippydriver_driver/utils/common.dart';
import 'package:jippydriver_driver/utils/preferences.dart';

class TermsAndConditionScreen extends StatefulWidget {
  final String? type;

  const TermsAndConditionScreen({super.key, this.type});

  @override
  State<TermsAndConditionScreen> createState() => _TermsAndConditionScreenState();
}

class _TermsAndConditionScreenState extends State<TermsAndConditionScreen> {
  String _content = '';
  bool _loading = true;

  bool get _isPrivacy => widget.type == "privacy";

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  String _sanitizeHtml(String input) {
    // Remove control characters and invalid surrogate code units that can break parsers
    return input.replaceAll(RegExp(r'[\u0000-\u001F\uD800-\uDFFF]'), '');
  }

  /// Extracts renderable HTML from the backend [content] field.
  /// The backend returns content in a few shapes depending on the policy type:
  ///  * `{"termsAndConditions": "<p>..."}` (JSON string wrapper)
  ///  * `{"privacyPolicy": "<p>..."}` (same wrapper, different key)
  ///  * `"<p>..."` (plain HTML, possibly entity-escaped)
  String _extractHtml(String input) {
    final content = input.trim();
    if (content.isEmpty) return '';
    String? html;

    try {
      final inner = json.decode(content);
      if (inner is Map) {
        html = _firstStringValue(Map<String, dynamic>.from(inner));
      }
    } catch (_) {
      // Not JSON -> the whole content is HTML.
    }

    if (html == null || html.trim().isEmpty) {
      html = content;
    }

    return _decodeEntities(html.trim());
  }

  /// Returns the first non-empty string value of [map], preferring the
  /// HTML-bearing keys returned by the backend.
  String? _firstStringValue(Map<String, dynamic> map) {
    const knownKeys = [
      'termsAndConditions',
      'terms_and_conditions',
      'privacyPolicy',
      'privacy_policy',
      'content',
      'html',
      'value',
      'text',
    ];
    for (final key in knownKeys) {
      final v = map[key];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    for (final v in map.values) {
      if (v is String && v.trim().isNotEmpty) return v;
    }
    return null;
  }

  /// Decodes common HTML entities so escaped markup becomes real markup.
  String _decodeEntities(String input) {
    const namedEntities = <String, String>{
      '&nbsp;': '\u00a0',
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&apos;': "'",
      '&#39;': "'",
      '&ldquo;': '\u201c',
      '&rdquo;': '\u201d',
      '&lsquo;': '\u2018',
      '&rsquo;': '\u2019',
      '&trade;': '\u2122',
      '&copy;': '\u00a9',
      '&reg;': '\u00ae',
      '&bull;': '\u2022',
      '&ndash;': '\u2013',
      '&mdash;': '\u2014',
      '&hellip;': '\u2026',
      '&times;': '\u00d7',
      '&divide;': '\u00f7',
      '&middot;': '\u00b7',
      '&deg;': '\u00b0',
      '&plusmn;': '\u00b1',
      '&sect;': '\u00a7',
      '&para;': '\u00b6',
      '&euro;': '\u20ac',
      '&pound;': '\u00a3',
      '&cent;': '\u00a2',
      '&yen;': '\u00a5',
      '&eacute;': '\u00e9',
      '&egrave;': '\u00e8',
      '&Eacute;': '\u00c9',
      '&agrave;': '\u00e0',
      '&Agrave;': '\u00c0',
      '&ccedil;': '\u00e7',
      '&Ccedil;': '\u00c7',
      '&oacute;': '\u00f3',
      '&Oacute;': '\u00d3',
      '&iacute;': '\u00ed',
      '&Iacute;': '\u00cd',
      '&uacute;': '\u00fa',
      '&Uacute;': '\u00da',
      '&ntilde;': '\u00f1',
      '&Ntilde;': '\u00d1',
      '&auml;': '\u00e4',
      '&ouml;': '\u00f6',
      '&uuml;': '\u00fc',
      '&szlig;': '\u00df',
      '&rarr;': '\u2192',
      '&larr;': '\u2190',
    };

    return input.replaceAllMapped(
      RegExp(r'&(#\d+|#x[0-9a-fA-F]+|[a-zA-Z]+);'),
      (match) {
        final whole = match.group(0)!;
        final code = match.group(1)!;
        if (code.startsWith('#')) {
          final numString = code.startsWith('#x')
              ? code.substring(2)
              : code.substring(1);
          final radix = code.startsWith('#x') ? 16 : 10;
          final value = int.tryParse(numString, radix: radix);
          if (value != null && value > 0 && value <= 0x10FFFF) {
            return String.fromCharCode(value);
          }
          return whole;
        }
        return namedEntities[whole] ?? whole;
      },
    );
  }

  Future<void> _loadContent() async {
    // Use in-memory Constant first (set by FireStoreUtils.getSettings at login/home)
    String content =
        _isPrivacy ? Constant.privacyPolicy : Constant.termsAndConditions;

    // If empty, fall back to cached SharedPreferences values
    if (content.isEmpty) {
      final cached = _isPrivacy
          ? Preferences.getString(Preferences.cachedPrivacyPolicy)
          : Preferences.getString(Preferences.cachedTermsAndConditions);
      content = cached;
    }

    // If still empty, fetch directly from the FM endpoint
    if (content.isEmpty) {
      try {
        final appPolicyType = _isPrivacy ? 'PRIVACYPOLICY' : 'TERMSANDCONDITIONS';
        final uri = Uri.parse(
          '${Constant.baseUrl}fm/terms-and-conditions/'
          'getTermsAndConditionsForAppType?appType=${Constant.userRoleDriver}&appPolicyType=$appPolicyType',
        );
        final response = await http.get(
          uri,
          headers: await getHeaders()
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          // Clean invalid chars and surrogate pairs before decoding
          final cleaned = String.fromCharCodes(
            response.body.runes.where(
              (int rune) =>
                  rune == 0x9 || // tab
                  rune == 0xA || // LF
                  rune == 0xD || // CR
                  (rune >= 0x20 &&
                      rune <= 0x10FFFF &&
                      (rune < 0xD800 || rune > 0xDFFF)),
            ),
          );

          final decoded = json.decode(cleaned);
          if (decoded is Map) {
            final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);
            dynamic body = map['data'];
            if (body is! Map) body = map;
            if (body is Map<String, dynamic>) {
              final html = _extractHtml(body['content']?.toString() ?? '');
              if (html.isNotEmpty) {
                content = html;
                // Also update global constants & cache for next time
                if (_isPrivacy) {
                  Constant.privacyPolicy = html;
                  await Preferences.setString(
                      Preferences.cachedPrivacyPolicy, html);
                } else {
                  Constant.termsAndConditions = html;
                  await Preferences.setString(
                      Preferences.cachedTermsAndConditions, html);
                }
              }
            }
          }
        }
      } catch (_) {
        // Swallow network/parse errors in production; we'll just show whatever we have
      }
    }

    if (mounted) {
      final sanitized = _sanitizeHtml(content);
      setState(() {
        _content = sanitized;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeData.grey50,
      appBar: AppBar(
        backgroundColor: AppThemeData.grey50,
        elevation: 0,
        title: Text(
          _isPrivacy ? 'Privacy Policy' : 'Terms & Conditions',
          style: const TextStyle(color: Colors.black87),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Html(
                  shrinkWrap: true,
                  data: _content,
                ),
              ),
      ),
    );
  }
}
