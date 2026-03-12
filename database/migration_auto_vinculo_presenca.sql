-- ============================================
-- MIGRAÇÃO: Auto-vínculo do aluno + policy endurecida de presença
-- Execute no Supabase SQL Editor
-- ============================================

-- 1) Endurecer policy de INSERT em presencas
DROP POLICY IF EXISTS "Presencas: aluno inserir" ON presencas;

CREATE POLICY "Presencas: aluno inserir"
  ON presencas FOR INSERT
  TO authenticated
  WITH CHECK (
    aluno_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM turma_alunos ta
      WHERE ta.turma_id = presencas.turma_id
        AND ta.aluno_id = auth.uid()
    )
  );

-- 2) RPC de auto-vínculo idempotente
CREATE OR REPLACE FUNCTION auto_vincular_aluno_turma(p_turma_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_aluno_id UUID;
  v_eh_aluno BOOLEAN;
BEGIN
  v_aluno_id := auth.uid();

  IF v_aluno_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado.';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM perfis p
    WHERE p.id = v_aluno_id
      AND p.role = 'aluno'
  ) INTO v_eh_aluno;

  IF NOT v_eh_aluno THEN
    RAISE EXCEPTION 'Apenas alunos podem se vincular automaticamente.';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM turmas t WHERE t.id = p_turma_id) THEN
    RAISE EXCEPTION 'Turma não encontrada.';
  END IF;

  INSERT INTO turma_alunos (turma_id, aluno_id)
  VALUES (p_turma_id, v_aluno_id)
  ON CONFLICT (turma_id, aluno_id) DO NOTHING;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
