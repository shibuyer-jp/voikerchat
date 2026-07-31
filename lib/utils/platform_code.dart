import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// usage_logs.platform 用の識別子('ios'/'android'/'web')。
/// CHECK制約外の値はサーバー側(api/_validation.ts)で null 化されるため、
/// 対象外プラットフォーム(windows/macos/linux)は operatingSystem 文字列を
/// そのまま返す。
String currentPlatformCode() {
  if (kIsWeb) return 'web';
  if (Platform.isIOS) return 'ios';
  if (Platform.isAndroid) return 'android';
  return Platform.operatingSystem;
}
