import 'package:flutter/material.dart';

/// マイク権限のOS標準プロンプトを出す「前」に表示する説明ダイアログ（pre-permission rationale）。
///
/// いきなりOSの許可ダイアログを出すのではなく、なぜマイクが必要かを先に伝えることで、
/// ユーザーが文脈を理解した上で許可でき、誤って拒否されるのを防ぐ。
///
/// 文言はすべて引数で受け取りハードコードしない（l10n対応）。
/// 呼び出し側は戻り値が true のときだけ speechService.initialize()/start() を呼ぶ想定。
///
/// 戻り値: 「続ける」で true / キャンセルまたは画面外タップで false。
Future<bool> showMicRationaleDialog(
  BuildContext context, {
  required String message,
  required String allowLabel,
  required String cancelLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.mic_none),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(allowLabel),
        ),
      ],
    ),
  );
  // barrierDismissible により外側タップ時は null が返るため、未許可(false)として扱う。
  return result ?? false;
}
