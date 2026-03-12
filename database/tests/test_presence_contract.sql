BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'presencas'
      AND column_name = 'google_synced'
      AND data_type = 'boolean'
  ) THEN
    RAISE EXCEPTION 'Coluna presencas.google_synced ausente';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE tablename = 'presencas'
      AND indexname = 'idx_presencas_google_synced'
  ) THEN
    RAISE EXCEPTION 'Índice idx_presencas_google_synced ausente';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_name = 'google_sync_logs'
  ) THEN
    RAISE EXCEPTION 'Tabela google_sync_logs ausente';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_name = 'rate_limit_events'
  ) THEN
    RAISE EXCEPTION 'Tabela rate_limit_events ausente';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE tablename = 'perfis'
      AND policyname = 'Perfis: leitura controlada'
  ) THEN
    RAISE EXCEPTION 'Policy de leitura controlada de perfis ausente';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE tablename = 'turmas'
      AND policyname = 'Turmas: leitura controlada'
  ) THEN
    RAISE EXCEPTION 'Policy de leitura controlada de turmas ausente';
  END IF;
END $$;

ROLLBACK;