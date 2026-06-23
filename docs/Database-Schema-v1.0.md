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
Daily API call tracking (implements T-15).

```sql
CREATE TABLE public.rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.user_profiles ON DELETE CASCADE,
  date DATE NOT NULL,
  api_calls_used INT DEFAULT 0,
  daily_limit INT DEFAULT 5,
  reset_at TIMESTAMPTZ,
  UNIQUE (user_id, date)
);

-- RLS Policy: Users can only view their own limits
CREATE POLICY "Users can view own rate limits" 
  ON public.rate_limits 
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "System can update rate limits" 
  ON public.rate_limits 
  FOR UPDATE USING (auth.uid() = user_id);
```

### 7. usage_logs
Audit trail for all API usage (analytics).

```sql
CREATE TABLE public.usage_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.user_profiles ON DELETE CASCADE,
  scene_id UUID,
  api_endpoint TEXT,
  tokens_consumed INT,
  cost DECIMAL(10, 4),
  status TEXT CHECK (status IN ('success', 'error')),
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS Policy: System insert only (no user SELECT)
CREATE POLICY "System can insert usage logs" 
  ON public.usage_logs 
  FOR INSERT WITH CHECK (true);
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
