-- Migração: Adiciona campo google_synced à tabela presencas para idempotência de sincronização Google Sheets

ALTER TABLE presencas
ADD COLUMN IF NOT EXISTS google_synced BOOLEAN NOT NULL DEFAULT false;

-- Opcional: índice para consultas rápidas
CREATE INDEX IF NOT EXISTS idx_presencas_google_synced ON presencas(google_synced);