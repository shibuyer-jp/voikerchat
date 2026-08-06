# RLSポリシー欠如の横断チェック(2026-08-06)

`notification_history`にDELETEポリシーが1件も存在せず、RLSがDELETEを
デフォルト拒否していた不具合(DECISIONS.md 2026-08-06参照)を受けて、
同種の問題が他テーブルに潜んでいないか確認するSQL。
Supabaseダッシュボードの SQL Editor で実行する想定。

## チェッククエリ

RLSが有効な`public`スキーマの全テーブルについて、SELECT/INSERT/UPDATE/
DELETEの4コマンドそれぞれにポリシーが1件も無い組み合わせを一覧化する。
結果が0件なら「欠けているポリシーは無い」ことを意味する。

```sql
with rls_tables as (
  select c.relname as table_name
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind = 'r'
    and c.relrowsecurity = true
),
commands as (
  select unnest(array['SELECT','INSERT','UPDATE','DELETE']) as cmd
),
existing_policies as (
  select tablename, cmd
  from pg_policies
  where schemaname = 'public'
)
select
  t.table_name,
  c.cmd as missing_policy_for
from rls_tables t
cross join commands c
where not exists (
  select 1 from existing_policies ep
  where ep.tablename = t.table_name and ep.cmd = c.cmd
)
order by t.table_name, c.cmd;
```

## 見方

- 結果が0件(空)であれば、RLS有効テーブルで「あるコマンドに対応するポリシーが
  1件も無い」組み合わせは無いことが確認できる。
- 行が返った場合、`table_name`のテーブルで`missing_policy_for`のコマンドが
  RLSにより常に全拒否されている(SELECTなら常に空配列、DELETEなら常に0行、
  UPDATEなら常に0行、INSERTなら常にエラーになる)。
- **注意**: 「ポリシーが無い」ことは必ずしも不具合とは限らない。例えば
  `usage_logs`はapp-onlyのappend-only設計でUPDATE/DELETEを意図的に
  許可していない(RLS有効時のデフォルト拒否のままにする設計、
  `internal-docs/Database-Schema-v1.0.md`参照)。**行が返った場合は
  「意図した制限」か「notification_historyと同型の設定漏れ」かを
  1件ずつ判断すること。**
