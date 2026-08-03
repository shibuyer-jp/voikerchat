import 'package:flutter/material.dart';

/// マイク権限のOS標準プロンプトを出す「前」に表示する説明ダイアログ（pre-permission rationale）。
///
/// いきなりOSの許可ダイアログを出すのではなく、なぜマイクが必要かを先に伝えることで、
/// ユーザーが文脈を理解した上で許可でき、誤って拒否されるのを防ぐ。
///
/// App Store Guideline 5.1.1(iv)対応(2026-08-03リジェクト): このメッセージを
/// 表示した後は必ずOSの権限リクエストへ進まなければならず、途中で離脱できる
/// ボタンを置いてはならない。そのためボタンは1つのみとし、バリアタップ・
/// 端末の戻る操作のいずれでも閉じられないようにしている。
///
/// 文言はすべて引数で受け取りハードコードしない（l10n対応）。
/// 呼び出し側はこのダイアログが閉じたら必ず speechService.initialize() を呼ぶこと。
Future<void> showMicRationaleDialog(
  BuildContext context, {
  required String message,
  required String continueLabel,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: AlertDialog(
        icon: const Icon(Icons.mic_none),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(continueLabel),
          ),
        ],
      ),
    ),
  );
}
