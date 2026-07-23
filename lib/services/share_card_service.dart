import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_colors.dart';

/// ShareCardService: 「今日の言い直し」をシェア用画像カード(PNG)にして
/// OS標準の共有シートで共有する。
///
/// 【審査・申告への影響なし】SNS SDKは使わず share_plus(OS標準の
/// Share Sheet / Intent)経由のため、新規パーミッション不要・
/// プライバシー/データセーフティ申告の変更も不要。
///
/// 描画はWidgetツリーに依存しない純Canvas方式(ui.PictureRecorder +
/// TextPainter)で行い、単体テスト可能にしている。
class ShareCardService {
  final logger = Logger('ShareCardService');

  // 1080x可変(FB/IGで潰れない4:5前後を想定)。
  static const double _width = 1080;
  static const double _padding = 72;
  static const double _contentWidth = _width - _padding * 2;

  /// 言い直しリストからシェアカードPNGを生成する。
  ///
  /// [corrections] は `{original, improved, tip_en}` のリスト(最大3件)。
  /// [title] はカード見出し(ローカライズ済み文字列を渡す)。
  Future<Uint8List> buildRecapCardPng({
    required List<Map<String, dynamic>> corrections,
    required String title,
  }) async {
    final items = corrections.take(3).toList();

    // ---- 1パス目: 高さを測る ----
    final titlePainter = _painter(
      title,
      const TextStyle(
        fontSize: 56,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );

    double itemsHeight = 0;
    final measured = <_MeasuredCorrection>[];
    for (final c in items) {
      final original = _painter(
        (c['original'] as String? ?? ''),
        const TextStyle(
          fontSize: 38,
          color: Color(0xFF9E9E9E),
          decoration: TextDecoration.lineThrough,
        ),
      );
      final improved = _painter(
        (c['improved'] as String? ?? ''),
        const TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.bold,
          color: Color(0xFF212121),
        ),
        maxWidth: _contentWidth - 56, // 矢印分の字下げ
      );
      final tipText = c['tip_en'] as String? ?? '';
      final tip = tipText.isEmpty
          ? null
          : _painter(
              tipText,
              const TextStyle(fontSize: 30, color: Color(0xFF757575)),
            );
      final h = original.height +
          8 +
          improved.height +
          (tip == null ? 0 : 8 + tip.height) +
          48; // 項目間マージン
      measured.add(_MeasuredCorrection(original, improved, tip));
      itemsHeight += h;
    }

    const headerHeight = 200.0;
    const footerHeight = 140.0;
    final height =
        headerHeight + _padding + itemsHeight + footerHeight;

    // ---- 2パス目: 描画 ----
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 背景(白)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _width, height),
      Paint()..color = Colors.white,
    );

    // ヘッダー(ブランド赤)
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, _width, headerHeight),
      Paint()..color = AppColors.brand,
    );
    titlePainter.paint(
      canvas,
      Offset(_padding, (headerHeight - titlePainter.height) / 2),
    );

    // 本文
    double y = headerHeight + _padding;
    for (final m in measured) {
      m.original.paint(canvas, Offset(_padding, y));
      y += m.original.height + 8;

      // 矢印 + 改善文
      final arrow = _painter(
        '→',
        const TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.bold,
          color: AppColors.brand,
        ),
      );
      arrow.paint(canvas, Offset(_padding, y));
      m.improved.paint(canvas, Offset(_padding + 56, y));
      y += m.improved.height;

      if (m.tip != null) {
        y += 8;
        m.tip!.paint(canvas, Offset(_padding + 56, y));
        y += m.tip!.height;
      }
      y += 48;
    }

    // フッター(区切り線 + アプリ名)
    canvas.drawRect(
      Rect.fromLTWH(_padding, height - footerHeight, _contentWidth, 2),
      Paint()..color = const Color(0xFFEEEEEE),
    );
    final footer = _painter(
      'Voikerchat — Japanese conversation practice',
      const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: AppColors.brand,
      ),
    );
    footer.paint(
      canvas,
      Offset(_padding, height - footerHeight + 48),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(_width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// カードを生成して OS標準の共有シートを開く。
  /// 失敗しても例外は投げず false を返す(共有は補助機能のため会話体験を壊さない)。
  Future<bool> shareRecapCard({
    required List<Map<String, dynamic>> corrections,
    required String title,
  }) async {
    try {
      final png = await buildRecapCardPng(
        corrections: corrections,
        title: title,
      );
      final dir = await getTemporaryDirectory();
      final file = XFile.fromData(
        png,
        mimeType: 'image/png',
        name: 'voikerchat_recap.png',
      );
      // XFile.fromData はプラットフォームによって一時ファイル化が必要なため、
      // 明示的にtempへ書き出したパス版も用意する(iOS/Androidの互換安定策)。
      final path = '${dir.path}/voikerchat_recap.png';
      await file.saveTo(path);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path, mimeType: 'image/png')]),
      );
      return true;
    } catch (e) {
      logger.info('[ShareCardService] share failed: $e');
      return false;
    }
  }
}

class _MeasuredCorrection {
  final TextPainter original;
  final TextPainter improved;
  final TextPainter? tip;
  _MeasuredCorrection(this.original, this.improved, this.tip);
}

TextPainter _painter(
  String text,
  TextStyle style, {
  double maxWidth = ShareCardService._contentWidth,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 4,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);
  return painter;
}
