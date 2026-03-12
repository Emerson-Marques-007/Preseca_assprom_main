-- ============================================
-- FIX RLS: qr_tokens insert/delete para professor da turma
-- ============================================

DROP POLICY IF EXISTS "QRTokens: professor inserir" ON qr_tokens;
DROP POLICY IF EXISTS "QRTokens: professor deletar" ON qr_tokens;

CREATE POLICY "QRTokens: professor inserir"
  ON qr_tokens FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM turmas t
      JOIN disciplinas d ON d.id = t.disciplina_id
      WHERE t.id = qr_tokens.turma_id
        AND d.professor_id = auth.uid()
    )
  );

CREATE POLICY "QRTokens: professor deletar"
  ON qr_tokens FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM turmas t
      JOIN disciplinas d ON d.id = t.disciplina_id
      WHERE t.id = qr_tokens.turma_id
        AND d.professor_id = auth.uid()
    )
  );
