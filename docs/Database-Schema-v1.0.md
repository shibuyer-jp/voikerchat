# Voikerchat Database Schema v1.0

## Overview
**Location:** Supabase PostgreSQL (voikerchat project)  
**Auth:** Supabase Auth (email/password + magic link)  
**RLS:** Row-level security enabled on all tables

---

## Tables

### 1. users (auto-managed by Supabase Auth)
```sql
-- Supabase Auth creates this automatically
-- id (UUID, PK) = auth.users.id
```

### 2. user_profiles
Store additional user metadata beyond auth.users.

```sql
CREATE TABLE public.user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  username TEXT UNIQUE NOT NULL,
  avatar_url TEXT,
  current_level INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- RLS Policy: Users can read/update only their own profile
CREATE POLICY "Users can view own profile" 
  ON public.user_profiles 
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" 
  ON public.user_profiles 
  FOR UPDATE USING (auth.uid() = id);
```

### 3. scenes
Predefined conversation scenes (Japanese learning scenarios).

```sql
CREATE TABLE public.scenes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  level INT NOT NULL,
  category TEXT,
  personas JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS Policy: All authenticated users can read scenes
CREATE POLICY "Authenticated users can read scenes" 
  ON public.scenes 
  FOR SELECT USING (auth.role() = 'authenticated');
```

### 4. messages
Chat message history per user per scene.

```sql
CREATE TABLE public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.user_profiles ON DELETE CASCADE,
  scene_id UUID NOT NULL REFERENCES public.scenes ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
  content TEXT NOT NULL,
  tokens_used INT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes for performance
CREATE INDEX idx_messages_user_id ON public.messages(user_id);
CREATE INDEX idx_messages_scene_id ON public.messages(scene_id);
CREATE INDEX idx_messages_created_at ON public.messages(created_at);

-- RLS Policy: Users can only see their own messages
CREATE POLICY "Users can view own messages" 
  ON public.messages 
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own messages" 
  ON public.messages 
  FOR INSERT WITH CHECK (auth.uid() = user_id);
```

### 5. conversation_sessions
Track conversation state and usage per user per scene.

```sql
CREATE TABLE public.conversation_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.user_profiles ON DELETE CASCADE,
  scene_id UUID NOT NULL REFERENCES public.scenes ON DELETE CASCADE,
  total_messages INT DEFAULT 0,
  total_tokens_used INT DEFAULT 0,
  last_message_at TIMESTAMPTZ,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'abandoned')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- RLS Policy: Users can only manage their own sessions
CREATE POLICY "Users can view own sessions" 
  ON public.conversation_sessions 
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own sessions" 
  ON public.conversation_sessions 
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can create sessions" 
  ON public.conversation_sessions 
  FOR INSERT WITH CHECK (auth.uid() = user_id);
```

### 6. rate_limits
Daily API call tracking + Premium status (T-17 & T-18).

```sql
CREATE TABLE public.rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES public.user_profiles ON DELETE CASCADE,
  is_premium BOOLEAN DEFAULT false,
  used_today INT DEFAULT 0,
  daily_limit INT DEFAULT 5,
  last_reset_utc TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- RLS Policy: Users can only view their own limits
CREATE POLICY "Users can view own rate limits" 
  ON public.rate_limits 
  FOR SELECT USING (auth.uid() = user_id);

-- Server-side only updates (API endpoint)
CREATE POLICY "System can update rate limits" 
  ON public.rate_limits 
  FOR UPDATE USING (auth.uid() = user_id);
```

**Premium Status Flow:**
- `is_premium = false` → Rate limited (5 calls/day free, +5 with ad-watch)
- `is_premium = true` → Unlimited calls
- Updated via RevenueCat webhook when subscription succeeds


### 7. usage_logs
Audit trail for all API usage (analytics).

```sql
-- 実テーブル定義（本番 rfwbwwhqclabhnbsrygw / 2026-07-02 時点）。
-- append-only の分析イベントログ。クォータ強制は rate_limits が担当し、
-- usage_logs は非同期の記録専用（書込み失敗は握り潰す）。
CREATE TABLE public.usage_logs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  event         TEXT NOT NULL CHECK (event IN (
                  'session_start','message_sent','ad_reward','quota_reached',
                  'upsell_shown','upsell_clicked','upsell_converted')),
  scene_id      SMALLINT CHECK (scene_id >= 1 AND scene_id <= 13),
  session_id    UUID,
  model         TEXT,
  platform      TEXT CHECK (platform IN ('ios','android','web')),
  locale        TEXT CHECK (locale IN ('ja','en','fil')),
  is_premium    BOOLEAN NOT NULL DEFAULT false,
  input_tokens  INTEGER CHECK (input_tokens >= 0),
  output_tokens INTEGER CHECK (output_tokens >= 0),
  metadata      JSONB NOT NULL DEFAULT '{}'::jsonb
);

-- RLS: owner-scoped（insert / select は自分の行のみ。update/delete 不可＝append-only）。
-- Index: (user_id, created_at) と (event, created_at)。
-- 注意: scene_id は smallint(1..13)。アプリのシーンは文字列IDのため、API 側は
--       scene_id を NULL とし、文字列シーン名を metadata.scene に格納している。
```

---

## Deployment Instructions

1. **Create Supabase project** (if not exists): https://supabase.com/dashboard
2. **Go to SQL Editor** → run all CREATE TABLE statements above
3. **Enable RLS** on each table:
   - Toggle "Enable RLS" in Table settings
   - Verify policies are created
4. **Test with Flutter app**:
   - User signup → triggers user_profiles insert
   - Load scenes → SELECT from scenes table
   - Send message → INSERT into messages + UPDATE conversation_sessions

---

## Notes

- `gen_random_uuid()` requires `uuid-ossp` extension (usually enabled by default)
- RLS policies assume Supabase Auth JWT contains `auth.uid()` 
- Rate limit reset happens at 00:00 JST (UTC+9)
