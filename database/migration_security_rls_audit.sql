-- Endurecimento de policies apos auditoria de seguranca.

DROP POLICY IF EXISTS "Perfis: leitura autenticada" ON perfis;
CREATE POLICY "Perfis: leitura controlada"
  ON perfis FOR SELECT
  TO authenticated
  USING (
    auth.uid() = id
    OR EXISTS (
      SELECT 1 FROM perfis p
      WHERE p.id = auth.uid() AND p.role = 'professor'
    )
  );

DROP POLICY IF EXISTS "Disciplinas: leitura autenticada" ON disciplinas;
CREATE POLICY "Disciplinas: leitura controlada"
  ON disciplinas FOR SELECT
  TO authenticated
  USING (
    professor_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM turmas t
      JOIN turma_alunos ta ON ta.turma_id = t.id
      WHERE t.disciplina_id = disciplinas.id
        AND ta.aluno_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Turmas: leitura autenticada" ON turmas;
CREATE POLICY "Turmas: leitura controlada"
  ON turmas FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM disciplinas d
      WHERE d.id = turmas.disciplina_id
        AND d.professor_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1
      FROM turma_alunos ta
      WHERE ta.turma_id = turmas.id
        AND ta.aluno_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "TurmaAlunos: leitura autenticada" ON turma_alunos;
CREATE POLICY "TurmaAlunos: leitura controlada"
  ON turma_alunos FOR SELECT
  TO authenticated
  USING (
    aluno_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM turmas t
      JOIN disciplinas d ON d.id = t.disciplina_id
      WHERE t.id = turma_alunos.turma_id
        AND d.professor_id = auth.uid()
    )
  );