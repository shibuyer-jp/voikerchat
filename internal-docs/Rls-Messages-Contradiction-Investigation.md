# messages テーブルのRLS矛盾調査(2026-08-06)

## 確定した事実(2026-08-06時点)

- `messages`へのアクセスはコード上100%クライアント側(`message_service.dart`、
  publishable key + 匿名認証JWT)。サーバー側/service role経由の経路は無い
- `public.messages`: `relkind=r`(通常テーブル)、`relrowsecurity=true`、
  `relforcerowsecurity=false`、`owner=postgres`
- `pg_policies`ではポリシー0件
- `anon`/`authenticated`ロールの`rolbypassrls`はいずれも`false`
  (`service_role`/`postgres`のみ`true`)

**注意(オーナーバイパスの正しい理解)**: PostgreSQLのオーナーバイパスは
「テーブルのオーナーが`postgres`である」ことではなく、「**クエリを実行して
いるロール自身が**オーナーと一致する、またはスーパーユーザーである」ことで
発動する。`authenticated`ロールは`postgres`とは別ロールなので、`owner=postgres`
という事実**単体**では`authenticated`のクエリはバイパスされないはず。
ただし`authenticated`が`postgres`のメンバーシップを持っている等、別経路で
オーナー相当の権限を継承している可能性は残るため、以下で直接検証する。

## 1(優先・最も決定的). クライアントの実権限をSQL Editor内で直接シミュレートする

理屈をこねるより、実際に`authenticated`ロールとして`messages`を読んで
みるのが最も確実。トランザクション内で`SET LOCAL ROLE`を使い、
ロールバックすれば元の権限に影響を残さない。

```sql
begin;
set local role authenticated;
select current_user, session_user;
select count(*) from public.messages;
rollback;
```

**見方**:
- `count`が**0**(または権限エラー)になれば、`authenticated`は実際には
  `messages`を読めておらず、RLSは正しく機能している。この場合、実機で
  会話履歴が読めていた事実は**別の経路**(例: 想定と違うロールでの接続、
  またはこのテーブル自体が実際にはアプリから使われていない等)で説明する
  必要があり、追加調査が必要
- `count`が**実際の行数と一致**すれば、`authenticated`ロールが実際に
  RLSをバイパスして全件読めていることが直接証明される。この場合は
  下記2・3で「なぜバイパスされるか」を特定する

## 2. ロールの継承関係を確認(authenticatedがpostgres等のメンバーになっていないか)

```sql
select
  member_role.rolname as role,
  granted_role.rolname as inherits_from,
  member_role.rolinherit as role_has_inherit_flag
from pg_auth_members m
join pg_roles member_role on member_role.oid = m.member
join pg_roles granted_role on granted_role.oid = m.roleid
where member_role.rolname in ('anon', 'authenticated', 'authenticator', 'service_role')
order by member_role.rolname;
```

**見方**: `authenticated`(または`authenticator`)の行に`inherits_from = postgres`
のような行が出れば、メンバーシップ経由でオーナー権限を継承している可能性が
高い。何も出なければ、通常の継承関係にオーナーバイパスの原因は無い。

## 3. pg_policy を直接確認(pg_policiesビューの表示漏れの可能性を排除)

```sql
select
  pol.polname,
  pol.polcmd,
  pol.polpermissive,
  pol.polroles,
  pol.polqual,
  pol.polwithcheck
from pg_policy pol
join pg_class c on c.oid = pol.polrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname = 'messages';
```

`pg_policies`はこのカタログテーブルを表示用に整形した標準システムビューの
ため通常は表示漏れが起きないが、念のため生カタログを直接確認する。
0件であれば、ポリシーが本当に存在しないことが最終確定する。

## 総合判断

- 1の`count`が0 → RLSは機能している。実機で読めた理由を別途調査(接続方式の
  再確認、実際に使われているキー種別の再確認等)
- 1の`count`が全件 → RLSバイパスが実証される。2・3の結果と合わせて原因
  (ロール継承 / その他)を特定し、修正方針(不要な継承の解除、または
  ポリシーの追加)を提示する
