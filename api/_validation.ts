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
