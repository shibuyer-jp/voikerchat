import 'package:flutter/material.dart';

/// AppBar省略修正(2026-07-25): 割当幅に収まらない場合のみフォントを
/// 軽く自動縮小して1行に収めるText。短い文字列は元サイズのまま変わらない。
///
/// [minScale] を下回るほどの縮小が必要な場合は、それ以上は縮小せず
/// [TextOverflow.ellipsis] にフォールバックする。設計判断として、常時
/// 極小フォントになる体験より「たまに末尾省略」を選ぶため、デフォルトは
/// 軽い縮小(0.85 = 元サイズの85%)までに留める。
class ShrinkToFitText extends StatelessWidget {
  const ShrinkToFitText(
    this.text, {
    super.key,
    this.style,
    this.minScale = 0.85,
  });

  final String text;
  final TextStyle? style;
  final double minScale;

  @override
  Widget build(BuildContext context) {
    final baseStyle = DefaultTextStyle.of(context).style.merge(style);

    return LayoutBuilder(
      builder: (context, constraints) {
        var scale = 1.0;
        if (constraints.maxWidth.isFinite) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: baseStyle),
            textDirection: Directionality.of(context),
            maxLines: 1,
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();

          if (painter.width > constraints.maxWidth && painter.width > 0) {
            // 0.98: 測定と実描画の丸め誤差で境界ぎりぎりのケースが
            // ellipsisに落ちるのを防ぐための安全マージン。
            scale = (constraints.maxWidth / painter.width * 0.98)
                .clamp(minScale, 1.0);
          }
        }

        return Text(
          text,
          style: baseStyle.copyWith(
            fontSize: (baseStyle.fontSize ?? 14) * scale,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        );
      },
    );
  }
}
