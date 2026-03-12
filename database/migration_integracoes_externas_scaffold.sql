-- Scaffold para integrações externas futuras.

CREATE TABLE IF NOT EXISTS integracoes_externas (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  professor_id UUID NOT NULL REFERENCES perfis(id) ON DELETE CASCADE,
  provider VARCHAR(40) NOT NULL CHECK (provider IN ('google_classroom', 'microsoft_365', 'lms')),
  status VARCHAR(20) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'connected', 'error')),
  config JSONB NOT NULL DEFAULT '{}'::jsonb,
  last_sync_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (professor_id, provider)
);

ALTER TABLE integracoes_externas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "IntegracoesExternas: professor CRUD" ON integracoes_externas;
CREATE POLICY "IntegracoesExternas: professor CRUD"
  ON integracoes_externas FOR ALL
  TO authenticated
  USING (professor_id = auth.uid())
  WITH CHECK (professor_id = auth.uid());