-- Scaffold para multiinstituicao.

CREATE TABLE IF NOT EXISTS instituicoes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nome VARCHAR(200) NOT NULL,
  slug VARCHAR(100) NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS unidades (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  instituicao_id UUID NOT NULL REFERENCES instituicoes(id) ON DELETE CASCADE,
  nome VARCHAR(200) NOT NULL,
  slug VARCHAR(100) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (instituicao_id, slug)
);

ALTER TABLE perfis ADD COLUMN IF NOT EXISTS instituicao_id UUID REFERENCES instituicoes(id) ON DELETE SET NULL;
ALTER TABLE perfis ADD COLUMN IF NOT EXISTS unidade_id UUID REFERENCES unidades(id) ON DELETE SET NULL;
ALTER TABLE disciplinas ADD COLUMN IF NOT EXISTS instituicao_id UUID REFERENCES instituicoes(id) ON DELETE SET NULL;
ALTER TABLE turmas ADD COLUMN IF NOT EXISTS instituicao_id UUID REFERENCES instituicoes(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_perfis_instituicao ON perfis(instituicao_id);
CREATE INDEX IF NOT EXISTS idx_turmas_instituicao ON turmas(instituicao_id);