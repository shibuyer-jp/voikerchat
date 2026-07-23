import 'package:flutter_test/flutter_test.dart';
import 'package:voikerchat/services/share_card_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShareCardService', () {
    test('buildRecapCardPng returns a valid PNG for typical corrections',
        () async {
      final service = ShareCardService();
      final png = await service.buildRecapCardPng(
        corrections: [
          {
            'original': 'わたし ばなな たべる',
            'improved': '私(わたし)はバナナを食(た)べます',
            'tip_en':
                'Tagalog has no particles, so は and を are easy to drop — but Japanese needs them here.',
          },
          {
            'original': 'おばさん げんき?',
            'improved': 'おばあさんは元気(げんき)ですか?',
            'tip_en': 'Long vowels change meaning: おばさん (aunt) vs おばあさん (grandma).',
          },
        ],
        title: '今日の言い直し',
      );

      expect(png, isNotEmpty);
      // PNGシグネチャ(89 50 4E 47)で始まること。
      expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });

    test('buildRecapCardPng handles a single correction without tip', () async {
      final service = ShareCardService();
      final png = await service.buildRecapCardPng(
        corrections: [
          {'original': 'いく です', 'improved': '行(い)きます', 'tip_en': ''},
        ],
        title: "Today's rephrasing",
      );
      expect(png, isNotEmpty);
      expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });
  });
}
