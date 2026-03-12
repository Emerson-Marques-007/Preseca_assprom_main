BEGIN;

DO $$
DECLARE
  v_def TEXT;
BEGIN
  SELECT pg_get_functiondef('auto_vincular_aluno_turma(uuid)'::regprocedure) INTO v_def;
  IF v_def IS NULL OR POSITION('ON CONFLICT (turma_id, aluno_id) DO NOTHING' IN v_def) = 0 THEN
    RAISE EXCEPTION 'auto_vincular_aluno_turma deve ser idempotente e usar ON CONFLICT DO NOTHING';
  END IF;

  SELECT pg_get_functiondef('resolver_token_por_slug(character varying)'::regprocedure) INTO v_def;
  IF v_def IS NULL OR POSITION('expira_em > NOW()' IN v_def) = 0 THEN
    RAISE EXCEPTION 'resolver_token_por_slug deve filtrar tokens expirados';
  END IF;

  SELECT pg_get_functiondef('validar_qr_token(uuid)'::regprocedure) INTO v_def;
  IF v_def IS NULL OR POSITION('token_valido' IN v_def) = 0 THEN
    RAISE EXCEPTION 'validar_qr_token deve expor token_valido';
  END IF;

  SELECT pg_get_functiondef('consumir_rate_limit(character varying,character varying,integer,integer)'::regprocedure) INTO v_def;
  IF v_def IS NULL OR POSITION('rate_limit_events' IN v_def) = 0 THEN
    RAISE EXCEPTION 'consumir_rate_limit deve operar sobre rate_limit_events';
  END IF;
END $$;

ROLLBACK;