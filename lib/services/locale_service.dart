import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LocaleService: ユーザーが選択したUI言語の永続化と即時反映を管理する。
///
/// [currentLocale] が null の間は「端末設定に従う」(MaterialApp.locale
/// を指定しない=デフォルトのシステムロケール解決に委ねる)。
/// VoikerchatApp はこの ValueNotifier を購読し、値が変わるたびに
/// MaterialApp.locale を差し替えて再起動なしでUI言語を切り替える。
class LocaleService {
  static const String _localeKey = 'app_locale';

  /// サポート言語コード。AppLocalizations.supportedLocales と一致させる。
  static const List<String> supportedCodes = ['ja', 'en', 'fil'];

  static final ValueNotifier<Locale?> currentLocale =
      ValueNotifier<Locale?>(null);

  /// 起動時に一度だけ呼ぶ(main() で runApp 前に await する)。
  Future<void> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey);
    currentLocale.value =
        (code != null && supportedCodes.contains(code)) ? Locale(code) : null;
  }

  /// [code] に null を渡すと「端末設定に従う」に戻す(保存値を削除)。
  Future<void> setLocale(String? code) async {
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      await prefs.remove(_localeKey);
    } else {
      await prefs.setString(_localeKey, code);
    }
    currentLocale.value = code != null ? Locale(code) : null;
  }
}
