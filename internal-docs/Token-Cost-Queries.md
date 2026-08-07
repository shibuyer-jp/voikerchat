# トークンコスト集計クエリ(採算判断用、2026-08-06)

一般公開前の採算判断のため、`usage_logs`の実測トークン数を集計するSQL例。
Supabaseダッシュボードの SQL Editor で実行する想定。

## 前提・制約

- `metadata->>'feature' is null` で絞り込むことで、辞書検索(`define`)/ヒント(`hint`)/
  単語まとめ(`vocab_summary`)を除外し、**メインの会話ターン(`api/chat.ts`経由)のみ**を対象にする
  (既存の`Kaigotalk-Data-Queries.md`と同じ規約)。
- `turn_number`は`api/chat.ts`が Claude へ送信した`messages`配列の要素数
  (`sanitizeMessages(messages).length`)をログ書き込み時点でそのまま記録したもの。
  `usage_logs.session_id`は現状クライアントから送信されておらず常にNULLのため、
  SQL側でセッション境界を復元するのではなくこの方式を採用している。
- `cache_read_input_tokens` / `cache_creation_input_tokens`は2026-08-06時点で
  プロンプトキャッシュ未導入のため、実測値は0またはNULLになる見込み。将来
  キャッシュを導入した際の効果測定の比較基準線として先行して記録している。
- 2026-08-06の初回実測(n=157, chat): avg_input=585 / avg_output=69 /
  median_input=625 / p90_input=895 / p99_input=1145 / max_input=1187。
  1日あたりメッセージ数は中央値2〜3、最大25(外れ値1件)。月間 avg=4.0msg/user、p90=7.4。

## 1. 全体の平均入力/出力トークン

```sql
select
  avg(input_tokens) as avg_input_tokens,
  avg(output_tokens) as avg_output_tokens,
  avg(cache_read_input_tokens) as avg_cache_read_tokens,
  avg(cache_creation_input_tokens) as avg_cache_creation_tokens,
  count(*) as n
from usage_logs
where event = 'message_sent'
  and metadata->>'feature' is null
  and input_tokens is not null;
```

## 1b. input_tokens の中央値・上位10%・上位1%(平均だけでは見えないヘビーユーザーの裾を確認)

```sql
select
  percentile_cont(0.5)  within group (order by input_tokens) as median_input_tokens,
  percentile_cont(0.9)  within group (order by input_tokens) as p90_input_tokens,
  percentile_cont(0.99) within group (order by input_tokens) as p99_input_tokens,
  max(input_tokens) as max_input_tokens,
  count(*) as n
from usage_logs
where event = 'message_sent'
  and metadata->>'feature' is null
  and input_tokens is not null;
```

## 2. 会話の往復数(turn_number)別の平均入力トークン

履歴が伸びるほど入力が増えるはずのため、その傾きを確認する。

```sql
select turn_number, avg(input_tokens) as avg_input_tokens, count(*) as n
from usage_logs
where event = 'message_sent'
  and metadata->>'feature' is null
  and turn_number is not null
group by turn_number
order by turn_number;
```

## 3. ユーザー別・1日あたりメッセージ数の分布

```sql
with daily as (
  select user_id, date_trunc('day', created_at) as day, count(*) as messages
  from usage_logs
  where event = 'message_sent'
    and metadata->>'feature' is null
  group by 1, 2
)
select messages as messages_per_day, count(*) as user_days
from daily
group by messages_per_day
order by messages_per_day;
```

## 3b. ユーザーあたり月間メッセージ数の上位10%

```sql
with monthly as (
  select user_id, date_trunc('month', created_at) as month, count(*) as messages
  from usage_logs
  where event = 'message_sent'
    and metadata->>'feature' is null
  group by 1, 2
)
select
  percentile_cont(0.9) within group (order by messages) as p90_monthly_messages_per_user,
  avg(messages) as avg_monthly_messages_per_user,
  max(messages) as max_monthly_messages_per_user,
  count(*) as user_months
from monthly;
```

## プライバシー

会話本文は保存しない現行方針を維持(`usage_logs`はevent/metadata/トークン数のみで会話生文は含まない)。
