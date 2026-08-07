-- A. 機能別トークン集計(直近30日)
-- 読み取り専用。書き込み・更新は行わない。
SELECT
  COALESCE(metadata->>'feature', 'chat') AS feature,
  COUNT(*) AS call_count,
  ROUND(AVG(input_tokens)::numeric, 1)
    AS avg_input_tokens,
  ROUND(PERCENTILE_CONT(0.5)
    WITHIN GROUP (ORDER BY input_tokens)::numeric, 1)
    AS median_input_tokens,
  ROUND(PERCENTILE_CONT(0.9)
    WITHIN GROUP (ORDER BY input_tokens)::numeric, 1)
    AS p90_input_tokens,
  MAX(input_tokens) AS max_input_tokens,
  ROUND(AVG(output_tokens)::numeric, 1)
    AS avg_output_tokens,
  ROUND(PERCENTILE_CONT(0.5)
    WITHIN GROUP (ORDER BY output_tokens)::numeric, 1)
    AS median_output_tokens,
  ROUND(PERCENTILE_CONT(0.9)
    WITHIN GROUP (ORDER BY output_tokens)::numeric, 1)
    AS p90_output_tokens,
  MAX(output_tokens) AS max_output_tokens,
  ROUND(
    SUM(COALESCE(input_tokens, 0)) / 1e6 * 1.0
    + SUM(COALESCE(output_tokens, 0)) / 1e6 * 5.0,
    4
  ) AS total_cost_usd
FROM public.usage_logs
WHERE event = 'message_sent'
  AND created_at >= now() - interval '30 days'
GROUP BY COALESCE(metadata->>'feature', 'chat')
ORDER BY total_cost_usd DESC;
