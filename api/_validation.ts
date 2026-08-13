/**
 * usage_logs の locale / platform は CHECK 制約付き(internal-docs/Database-Schema-v1.0.md 参照)。
 * 許容値以外を渡すと insert 自体が失敗するため、書込み前に必ずここでサニタイズする。
 */

const ALLOWED_LOCALES = ['ja', 'en', 'fil'] as const;
const ALLOWED_PLATFORMS = ['ios', 'android', 'web'] as const;

export function sanitizeLocale(value: unknown): string | null {
  return typeof value === 'string' && (ALLOWED_LOCALES as readonly string[]).includes(value)
    ? value
    : null;
}

export function sanitizePlatform(value: unknown): string | null {
  return typeof value === 'string' && (ALLOWED_PLATFORMS as readonly string[]).includes(value)
    ? value
    : null;
}

// usage_logs.session_id は uuid 型。conversation_sessions.id
// (lib/services/message_service.dart で Uuid().v4() 生成)を想定するが、
// クライアントからの入力は信用せず、不正な形式は null に落として
// insert 自体は失敗させない(リクエストをブロックしない)。
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function sanitizeSessionId(value: unknown): string | null {
  return typeof value === 'string' && UUID_PATTERN.test(value) ? value : null;
}
