-- ============================================
-- MIGRAÇÃO: integração Google Sheets por turma
-- Execute no Supabase SQL Editor
-- ============================================

CREATE TABLE IF NOT EXISTS integracao_planilhas_turma (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  turma_id UUID NOT NULL UNIQUE REFERENCES turmas(id) ON DELETE CASCADE,
  professor_id UUID NOT NULL REFERENCES perfis(id) ON DELETE CASCADE,
  spreadsheet_id VARCHAR(200) NOT NULL,
  spreadsheet_url TEXT NOT NULL,
  sheet_name VARCHAR(100) NOT NULL DEFAULT 'Frequencia',
  ativo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_integracao_planilha_turma ON integracao_planilhas_turma(turma_id);
CREATE INDEX IF NOT EXISTS idx_integracao_planilha_professor ON integracao_planilhas_turma(professor_id);

ALTER TABLE integracao_planilhas_turma ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "IntegracaoPlanilha: professor leitura própria" ON integracao_planilhas_turma;
CREATE POLICY "IntegracaoPlanilha: professor leitura própria"
  ON integracao_planilhas_turma FOR SELECT
  TO authenticated
  USING (
    professor_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM turmas t
      JOIN disciplinas d ON d.id = t.disciplina_id
      WHERE t.id = integracao_planilhas_turma.turma_id
        AND d.professor_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "IntegracaoPlanilha: professor inserir própria" ON integracao_planilhas_turma;
CREATE POLICY "IntegracaoPlanilha: professor inserir própria"
  ON integracao_planilhas_turma FOR INSERT
  TO authenticated
  WITH CHECK (
    professor_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM turmas t
      JOIN disciplinas d ON d.id = t.disciplina_id
      WHERE t.id = turma_id
        AND d.professor_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "IntegracaoPlanilha: professor atualizar própria" ON integracao_planilhas_turma;
CREATE POLICY "IntegracaoPlanilha: professor atualizar própria"
  ON integracao_planilhas_turma FOR UPDATE
  TO authenticated
  USING (professor_id = auth.uid())
  WITH CHECK (professor_id = auth.uid());

DROP POLICY IF EXISTS "IntegracaoPlanilha: professor deletar própria" ON integracao_planilhas_turma;
CREATE POLICY "IntegracaoPlanilha: professor deletar própria"
  ON integracao_planilhas_turma FOR DELETE
  TO authenticated
  USING (professor_id = auth.uid());
