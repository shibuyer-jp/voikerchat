import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voikerchat/widgets/shrink_to_fit_text.dart';

void main() {
  Widget harness(Widget child, {double width = 200}) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(width: width, child: child),
      ),
    );
  }

  testWidgets('短い文字列は元のフォントサイズのまま変わらない', (tester) async {
    const style = TextStyle(fontSize: 20);
    await tester.pumpWidget(harness(
      const ShrinkToFitText('友達', style: style),
      width: 300,
    ));

    final rendered = tester.widget<Text>(find.byType(Text));
    expect(rendered.style?.fontSize, 20);
  });

  testWidgets('幅に収まらない文字列はデフォルトminScale(0.85)まで軽く縮小する',
      (tester) async {
    const style = TextStyle(fontSize: 20);
    // 非常に長い文字列 + 極端に狭い幅なので、デフォルトのfloor(0.85)に
    // クランプされ、それでも収まらずellipsisにフォールバックするはず。
    await tester.pumpWidget(harness(
      const ShrinkToFitText('Pagkakaibigan at Teamwork', style: style),
      width: 100,
    ));

    final rendered = tester.widget<Text>(find.byType(Text));
    expect(rendered.style!.fontSize, 20 * 0.85);
    expect(rendered.overflow, TextOverflow.ellipsis);
  });

  testWidgets('minScaleを下回る縮小は行わずellipsisにフォールバックする',
      (tester) async {
    const style = TextStyle(fontSize: 20);
    await tester.pumpWidget(harness(
      const ShrinkToFitText(
        'Pagkakaibigan at Teamwork',
        style: style,
        minScale: 0.75,
      ),
      width: 30, // 0.75まで縮小しても収まらない極端な幅
    ));

    final rendered = tester.widget<Text>(find.byType(Text));
    expect(rendered.style!.fontSize, 20 * 0.75);
    expect(rendered.overflow, TextOverflow.ellipsis);

    final paragraph = tester.renderObject<RenderParagraph>(find.byType(Text));
    expect(paragraph.didExceedMaxLines, isTrue);
  });

  testWidgets('1行に収まる範囲では省略(ellipsis)されない', (tester) async {
    const style = TextStyle(fontSize: 20);
    await tester.pumpWidget(harness(
      const ShrinkToFitText('Mga Kaibigan', style: style, minScale: 0.75),
      width: 220, // fontSize20の自然幅240pxに対しscale=0.92程度で余裕を持って収まる幅
    ));

    final paragraph = tester.renderObject<RenderParagraph>(find.byType(Text));
    expect(paragraph.didExceedMaxLines, isFalse);
  });
}
