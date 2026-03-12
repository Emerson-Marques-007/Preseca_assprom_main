-- Logs de sincronizacao com Google Sheets e rate limiting de acoes sensiveis.

CREATE TABLE IF NOT EXISTS google_sync_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  turma_id UUID NOT NULL REFERENCES turmas(id) ON DELETE CASCADE,
  professor_id UUID REFERENCES perfis(id) ON DELETE CASCADE,
  presence_id UUID REFERENCES presencas(id) ON DELETE SET NULL,
  spreadsheet_id VARCHAR(200),
  status VARCHAR(20) NOT NULL CHECK (status IN ('success', 'skipped', 'error')),
  reason TEXT,
  attempted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_google_sync_logs_professor ON google_sync_logs(professor_id, attempted_at DESC);
CREATE INDEX IF NOT EXISTS idx_google_sync_logs_turma ON google_sync_logs(turma_id, attempted_at DESC);
CREATE INDEX IF NOT EXISTS idx_google_sync_logs_presence ON google_sync_logs(presence_id);

ALTER TABLE google_sync_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "GoogleSyncLogs: professor leitura" ON google_sync_logs;
CREATE POLICY "GoogleSyncLogs: professor leitura"
  ON google_sync_logs FOR SELECT
  TO authenticated
  USING (professor_id = auth.uid());

CREATE TABLE IF NOT EXISTS rate_limit_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES perfis(id) ON DELETE CASCADE,
  action_key VARCHAR(60) NOT NULL,
  scope_key VARCHAR(120) NOT NULL DEFAULT 'global',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rate_limit_events_lookup
  ON rate_limit_events(user_id, action_key, scope_key, created_at DESC);

ALTER TABLE rate_limit_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "RateLimitEvents: proprio select" ON rate_limit_events;
CREATE POLICY "RateLimitEvents: proprio select"
  ON rate_limit_events FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP FUNCTION IF EXISTS consumir_rate_limit(VARCHAR, VARCHAR, INTEGER, INTEGER);
CREATE OR REPLACE FUNCTION consumir_rate_limit(
  p_action_key VARCHAR,
  p_scope_key VARCHAR DEFAULT 'global',
  p_limit INTEGER DEFAULT 10,
  p_window_seconds INTEGER DEFAULT 300
)
RETURNS TABLE (
  allowed BOOLEAN,
  remaining INTEGER,
  retry_after_seconds INTEGER
) AS $$
DECLARE
  v_user_id UUID;
  v_scope_key VARCHAR(120);
  v_count INTEGER;
  v_oldest TIMESTAMPTZ;
BEGIN
  v_user_id := auth.uid();
  v_scope_key := COALESCE(NULLIF(TRIM(p_scope_key), ''), 'global');

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado.';
  END IF;

  DELETE FROM rate_limit_events
  WHERE user_id = v_user_id
    AND action_key = p_action_key
    AND scope_key = v_scope_key
    AND created_at < NOW() - make_interval(secs => p_window_seconds);

  SELECT COUNT(*), MIN(created_at)
  INTO v_count, v_oldest
  FROM rate_limit_events
  WHERE user_id = v_user_id
    AND action_key = p_action_key
    AND scope_key = v_scope_key;

  IF v_count >= p_limit THEN
    RETURN QUERY SELECT
      FALSE,
      0,
      GREATEST(1, CEIL(EXTRACT(EPOCH FROM ((v_oldest + make_interval(secs => p_window_seconds)) - NOW())))::INTEGER);
    RETURN;
  END IF;

  INSERT INTO rate_limit_events (user_id, action_key, scope_key)
  VALUES (v_user_id, p_action_key, v_scope_key);

  RETURN QUERY SELECT TRUE, GREATEST(0, p_limit - (v_count + 1)), 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION consumir_rate_limit(VARCHAR, VARCHAR, INTEGER, INTEGER) TO authenticated;