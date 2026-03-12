-- ============================================
-- TABELA: google_oauth_tokens
-- Armazena tokens OAuth do Google por professor
-- ============================================

CREATE TABLE IF NOT EXISTS google_oauth_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  professor_id UUID NOT NULL UNIQUE REFERENCES perfis(id) ON DELETE CASCADE,
  google_email VARCHAR(255),
  access_token TEXT NOT NULL,
  refresh_token TEXT,
  scope TEXT,
  token_type VARCHAR(50) DEFAULT 'Bearer',
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_google_oauth_tokens_professor ON google_oauth_tokens(professor_id);

ALTER TABLE google_oauth_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "GoogleOAuthTokens: professor leitura propria"
  ON google_oauth_tokens FOR SELECT
  TO authenticated
  USING (professor_id = auth.uid());

CREATE POLICY "GoogleOAuthTokens: professor inserir proprio"
  ON google_oauth_tokens FOR INSERT
  TO authenticated
  WITH CHECK (professor_id = auth.uid());

CREATE POLICY "GoogleOAuthTokens: professor atualizar proprio"
  ON google_oauth_tokens FOR UPDATE
  TO authenticated
  USING (professor_id = auth.uid())
  WITH CHECK (professor_id = auth.uid());

CREATE POLICY "GoogleOAuthTokens: professor deletar proprio"
  ON google_oauth_tokens FOR DELETE
  TO authenticated
  USING (professor_id = auth.uid());
