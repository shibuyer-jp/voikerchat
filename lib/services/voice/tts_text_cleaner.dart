/// 読み上げ前のテキスト整形（Web版 speakText 準拠）。
///
/// Markdown（太字/斜体/見出し/箇条書き/リンク/コード）と絵文字を除去し、
/// 'Score: X/10' の採点行を取り除き、改行を句点/空白へ正規化する。
String cleanForSpeech(String raw) {
  var text = raw;

  // 採点行（例: 'Score: 8/10'）を除去。
  text = text.replaceAll(
    RegExp(r'Score:\s*\d+/10\n?', caseSensitive: false),
    '',
  );

  // 太字 **x** / 斜体 *x*
  text = text.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m[1]!);
  text = text.replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => m[1]!);

  // 見出し # / ## / ###
  text = text.replaceAll(RegExp(r'#{1,3}\s'), '');

  // 箇条書き記号
  text = text.replaceAll(RegExp(r'[-•]\s'), '');

  // リンク [text](url) -> text
  text = text.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m[1]!);

  // インラインコード `x` -> x
  text = text.replaceAllMapped(RegExp(r'`(.+?)`'), (m) => m[1]!);

  // 絵文字（主要レンジ）
  text = text.replaceAll(
    RegExp(r'[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}]', unicode: true),
    '',
  );

  // 連続改行→句点、単一改行→空白
  text = text.replaceAll(RegExp(r'\n{2,}'), '. ');
  text = text.replaceAll('\n', ' ');

  return text.trim();
}
