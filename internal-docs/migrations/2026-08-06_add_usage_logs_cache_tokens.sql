-- 2026-08-06: usage_logs に プロンプトキャッシュ関連トークン数と往復数(turn_number)を追加。
--
-- 本SQLは Supabase SQL Editor で人間が実行すること(Claude CodeはDBに
-- 直接アクセスできないため)。ベータ利用の少ない時間帯での実行を想定。
--
-- 【破壊的操作について】本SQLに DROP / 既存データの変更は含まれない。
-- ADD COLUMN のみで、既存の列・ポリシー・インデックスは一切変更・削除しない。
-- 既存行は全て新規3列とも NULL のままになる(バックフィルは行わない)。
--
-- 背景(採算判断タスク、2026-08-06):
--   本番実測(n=157, message_sent/chat)で avg_input=585 / p99_input=1145 /
--   max_input=1187 と判明。プロンプトキャッシュは未導入(cache_control未使用)
--   のため cache_read/cache_creation は現時点では 0 が入る見込みだが、将来
--   キャッシュ導入時の効果測定の比較基準線として先行して列を用意する。
--   turn_number は「往復数が増えるほど入力トークンが伸びる」傾きを見るための
--   補助列。usage_logs.session_id は現状クライアントから送信されておらず常に
--   NULL のため(internal-docs/Kaigotalk-Data-Queries.md参照)、SQL側で
--   セッション境界を復元するのではなく、api/chat.ts が Claude へ送信する
--   messages 配列の要素数をログ書き込み時にそのまま記録する方式にした。

ALTER TABLE public.usage_logs
  ADD COLUMN IF NOT EXISTS cache_read_input_tokens INTEGER CHECK (cache_read_input_tokens >= 0),
  ADD COLUMN IF NOT EXISTS cache_creation_input_tokens INTEGER CHECK (cache_creation_input_tokens >= 0),
  ADD COLUMN IF NOT EXISTS turn_number SMALLINT CHECK (turn_number >= 0);

-- cache_read/cache_creation_input_tokens は Claude を呼ぶ全エンドポイント
-- (api/chat.ts・api/define.ts・api/recap.ts・api/hint.ts・api/vocab-summary.ts)
-- が送信する。turn_number は api/chat.ts のみが送信する(会話ターンの往復数
-- という意味を持つのは chat.ts 経由の event='message_sent' のみのため)。
-- 他4エンドポイントは会話ターンではないため turn_number は常に NULL のまま。
