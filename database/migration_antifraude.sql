-- Score antifraude para presencas.

ALTER TABLE presencas
  ADD COLUMN IF NOT EXISTS risco_fraude_score INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS risco_fraude_motivos JSONB NOT NULL DEFAULT '[]'::jsonb;