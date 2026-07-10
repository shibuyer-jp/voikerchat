import 'package:flutter_test/flutter_test.dart';
import 'package:voikerchat/services/voice/tts_text_cleaner.dart';

void main() {
  group('cleanForSpeech', () {
    test('太字の装飾記号を除去する', () {
      expect(cleanForSpeech('**太字**'), '太字');
    });
    test('見出し記号を除去する', () {
      expect(cleanForSpeech('# 見出し'), '見出し');
    });
    test('Score行を除去する', () {
      expect(cleanForSpeech('Score: 8/10\n本文'), '本文');
    });
    test('絵文字を除去する', () {
      expect(cleanForSpeech('こんにちは😀'), 'こんにちは');
    });
    test('連続改行を句点+空白に正規化しtrimする', () {
      expect(cleanForSpeech('  hello\n\nworld  '), 'hello. world');
    });
    test('リンクはテキストのみ残す', () {
      expect(cleanForSpeech('[リンク](https://example.com)'), 'リンク');
    });
    test('インラインコードの記号を外す', () {
      expect(cleanForSpeech('use `flutter` here'), 'use flutter here');
    });
  });
}
