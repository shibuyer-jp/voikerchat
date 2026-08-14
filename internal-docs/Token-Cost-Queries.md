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
- **cloud_tts のコストは `metadata.chars`(読み上げ文字数)から算出する。**
  `input_tokens`/`output_tokens` は null のままで正しい。gpt-4o-mini-tts は
  トークン課金体系が chat 系と異なる($0.60/1M入力トークン + $12/1M音声
  トークン ≒ $0.015/分)ため、無理にトークン列へ入れず別集計とする方針。
- 2026-08-14の再測定(下記「機能別原価の測定(2026-08-14)」節)で、
  無料枠5→10への引き上げ後も採算は悪化していないことを確認済み。

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

## cloud_tts のコスト集計クエリ(2026-08-14追加)

```sql
select
  case when created_at < '2026-08-06' then 'A_無料枠5' else 'B_無料枠10' end as period,
  count(*) as n,
  round(avg((metadata->>'chars')::numeric), 1) as avg_chars,
  percentile_cont(0.9) within group (order by (metadata->>'chars')::numeric) as p90_chars,
  max((metadata->>'chars')::numeric) as max_chars,
  sum((metadata->>'chars')::numeric) as total_chars,
  count(*) filter (where is_premium) as by_premium,
  count(*) filter (where not is_premium) as by_ad_reward
from usage_logs
where event = 'message_sent'
  and metadata->>'feature' = 'cloud_tts'
  and created_at >= '2026-07-30'
group by 1
order by 1;
```

## 機能別・期間別の利用量クエリ(2026-08-14追加)

```sql
select
  case when created_at < '2026-08-06' then 'A_無料枠5' else 'B_無料枠10' end as period,
  coalesce(metadata->>'feature', 'chat') as feature,
  count(*) as n,
  round(avg(input_tokens)) as avg_input,
  round(avg(output_tokens)) as avg_output
from usage_logs
where event = 'message_sent'
  and created_at >= '2026-07-30'
group by 1, 2
order by 1, 2;
```

## 1人1日あたりメッセージ数の期間比較クエリ(2026-08-14追加)

```sql
with daily as (
  select user_id, date_trunc('day', created_at)::date as day, count(*) as messages
  from usage_logs
  where event = 'message_sent'
    and metadata->>'feature' is null
    and created_at >= '2026-07-30'
  group by 1, 2
)
select
  case when day < '2026-08-06' then 'A_無料枠5' else 'B_無料枠10' end as period,
  count(*) as user_days,
  round(avg(messages), 2) as avg_msg,
  percentile_cont(0.5) within group (order by messages) as median,
  percentile_cont(0.9) within group (order by messages) as p90,
  max(messages) as max_msg,
  count(*) filter (where messages >= 5) as days_ge5,
  count(*) filter (where messages >= 10) as days_ge10
from daily
group by 1
order by 1;
```

## 機能別原価の測定(2026-08-14)

無料枠を5→10へ引き上げた前後(境界 2026-08-06)での比較。
**すべてテスター利用のデータであり、n が極小。結論ではなくシグナルとして扱う。**

### 利用量の実測値

| period | user_days | avg_msg/day | median | p90 | max | days>=5 | days>=10 |
|---|---|---|---|---|---|---|---|
| A_無料枠5 | 19 | 3.11 | 3 | 5 | 6 | 7 | 0 |
| B_無料枠10 | 4 | 4.75 | 4 | 8.2 | 10 | 1 | 1 |

| period | feature | n | avg_input | avg_output |
|---|---|---|---|---|
| A | chat | 59 | 785 | 63 |
| A | define | 11 | 644 | 152 |
| A | hint | 28 | 280 | 39 |
| A | cloud_tts | 24 | (null) | (null) |
| B | chat | 19 | 858 | 73 |
| B | define | 27 | 758 | 159 |
| B | hint | 20 | 219 | 39 |
| B | cloud_tts | 14 | (null) | (null) |

cloud_tts の文字数: A = 24件 / 平均67.0字 / 合計1,609字(Premium 2・広告22)、
B = 14件 / 平均66.4字 / 合計930字(Premium 4・広告10)。

### 算出した原価(B期間、1人1日あたり)

| 機能 | 1回あたり原価 | 回数/人日 | 原価/人日 | 構成比 |
|---|---|---|---|---|
| define | $0.00155 | 6.75 | $0.0105 | 36% |
| cloud_tts | — | 3.50 | $0.0100 | 34% |
| chat | $0.00122 | 4.75 | $0.0058 | 20% |
| hint | $0.00041 | 5.00 | $0.0021 | 7% |
| **合計** | | | **$0.0284** | 100% |

**損益分岐課金率: 約2.6%(TTS込み)**。従来値1.86%(2026-08-06、TTS未計上・
無料枠5時点)から悪化して見えるが、主因は無料枠倍増ではなく **辞書(define)の
利用急増とTTSの計上** である。プレミアム$12.99に対し十分安全な水準。

### 算出に用いた仮定(いずれも未検証)

- Claude Haiku 4.5 の料金を入力$1/1M・出力$5/1Mトークンとして計算
- cloud_tts は日本語の読み上げ速度を350字/分と仮定し `総文字数÷350×$0.015`
  で概算。**OpenAIの請求実績との突合は未実施**(影響額が$0.11程度と小さく、
  現時点では確認の価値が低いと判断)
- ストア手数料15%、Premiumユーザーは無料ユーザーの2倍利用、月10日アクティブ

### 重要な発見

1. **無料枠5→10の倍増による採算悪化は起きていない。** 利用実態が
   3.11→4.75回/日にしか増えず、上限10到達は4 user_days中1件のみ。
   ユーザーは上限まで使っていない
2. **最大のコスト要因は chat ではなく define(辞書)** になった。出力トークンが
   159と chat(73)の倍以上あり、かつ利用回数がA期間比で約11倍に急増した。
   PR #49の辞書サーバー化とオンボーディング拡充により機能が発見されやすく
   なった結果と推測される【未検証】
3. **無料枠の上限設計に非対称がある。** `FREE_DAILY_DEFINE_HINT_LIMIT = 30` は
   chat側の上限20より緩いのに単価が高い。全員が上限まで使う最悪ケースでは
   無料ユーザー1人あたり月$2.50、損益分岐は約25%まで跳ね上がる。現実の
   利用率から起きる確率は低いが、構造としては辞書側が野放しになっている
4. cloud_tts はPremium/広告視聴済みユーザーのみが使える機能のため、
   無料ユーザーのコストとしては過大に見積もっている可能性がある
