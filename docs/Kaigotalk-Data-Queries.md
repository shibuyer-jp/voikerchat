# Kaigotalk 向け集計クエリ(T-34)

介護(id 14)・医療(id 15)シーンの需要仮説検証のため、既存 `usage_logs` の範囲内(スキーマ変更なし)で
月次確認する際の SQL 例。Supabase ダッシュボードの SQL Editor で実行する想定。

## 前提・制約

- `usage_logs.scene_id` は smallint(1〜13の CHECK 制約)のため未使用(常に NULL)。
  文字列シーンID(`"14"`〜`"18"`含む)は従来通り `metadata->>'scene'` に格納される(既存規約)。
- `usage_logs.session_id` は現状クライアントから送信されておらず、常に NULL。
  そのため「完走率」「平均ターン数」はセッション単位の直接集計ではなく、
  **同一ユーザー×同一シーン×同一日の `message_sent` 件数**で近似する。
  より正確な計測が必要になった場合は、クライアントから `session_id`(UUID)を
  `api/chat.ts` の request body に追加送信し、`logUsage` へ引き渡す変更が別途必要。

## 1. シーン選択率(介護/医療 vs 他プレミアムシーン)

```sql
select
  metadata->>'scene' as scene_id,
  count(*) filter (where event = 'message_sent') as messages,
  count(distinct user_id) filter (where event = 'message_sent') as unique_users
from usage_logs
where created_at >= now() - interval '30 days'
  and metadata->>'scene' in ('9','10','11','12','13','14','15','16','17','18')
group by metadata->>'scene'
order by messages desc;
```

## 2. 介護/医療シーンの日次利用ユーザー数

```sql
select
  date_trunc('day', created_at) as day,
  metadata->>'scene' as scene_id,
  count(distinct user_id) as unique_users,
  count(*) as messages
from usage_logs
where event = 'message_sent'
  and metadata->>'scene' in ('14', '15')
  and created_at >= now() - interval '30 days'
group by 1, 2
order by 1, 2;
```

## 3. 平均ターン数(近似: ユーザー×シーン×日 の message_sent 件数平均)

```sql
with per_session as (
  select
    user_id,
    metadata->>'scene' as scene_id,
    date_trunc('day', created_at) as day,
    count(*) as turns
  from usage_logs
  where event = 'message_sent'
    and metadata->>'scene' in ('14', '15')
  group by 1, 2, 3
)
select scene_id, avg(turns) as avg_turns_per_day, count(*) as day_sessions
from per_session
group by scene_id;
```

## 4. リピート率(介護/医療シーンを複数日にわたって利用したユーザーの割合)

```sql
with days_used as (
  select
    user_id,
    metadata->>'scene' as scene_id,
    count(distinct date_trunc('day', created_at)) as active_days
  from usage_logs
  where event = 'message_sent'
    and metadata->>'scene' in ('14', '15')
    and created_at >= now() - interval '30 days'
  group by 1, 2
)
select
  scene_id,
  count(*) as total_users,
  count(*) filter (where active_days >= 2) as repeat_users,
  round(
    100.0 * count(*) filter (where active_days >= 2) / nullif(count(*), 0),
    1
  ) as repeat_rate_pct
from days_used
group by scene_id;
```

## プライバシー

会話本文は保存しない現行方針を維持(usage_logs は event/metadata のみで会話生文は含まない)。
集計目的の利用がプライバシーポリシーの記載範囲内かは Master Plan Phase B で確認する
(人間の作業。T-35 のクラウドTTS・T-31 の辞書API送信と合わせて棚卸し予定)。
