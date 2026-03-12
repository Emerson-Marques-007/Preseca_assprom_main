-- ============================================
-- MIGRAÇÃO: TABELA PLANILHAS (Cards de links)
-- Execute este script no Supabase SQL Editor
-- ============================================

CREATE TABLE IF NOT EXISTS planilhas (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nome VARCHAR(200) NOT NULL,
  url TEXT NOT NULL CHECK (url ~* '^https://'),
  imagem_url TEXT CHECK (imagem_url IS NULL OR imagem_url ~* '^https://'),
  disciplina_id UUID REFERENCES disciplinas(id) ON DELETE SET NULL,
  turma_id UUID REFERENCES turmas(id) ON DELETE SET NULL,
  professor_id UUID NOT NULL REFERENCES perfis(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_planilhas_professor ON planilhas(professor_id);
CREATE INDEX IF NOT EXISTS idx_planilhas_disciplina ON planilhas(disciplina_id);
CREATE INDEX IF NOT EXISTS idx_planilhas_turma ON planilhas(turma_id);
CREATE INDEX IF NOT EXISTS idx_planilhas_created_at ON planilhas(created_at DESC);

ALTER TABLE planilhas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Planilhas: professor leitura compartilhada" ON planilhas;
CREATE POLICY "Planilhas: professor leitura compartilhada"
  ON planilhas FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM perfis p
      WHERE p.id = auth.uid() AND p.role = 'professor'
    )
  );

DROP POLICY IF EXISTS "Planilhas: professor inserir própria" ON planilhas;
CREATE POLICY "Planilhas: professor inserir própria"
  ON planilhas FOR INSERT
  TO authenticated
  WITH CHECK (
    professor_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM perfis p
      WHERE p.id = auth.uid() AND p.role = 'professor'
    )
  );

DROP POLICY IF EXISTS "Planilhas: professor atualizar própria" ON planilhas;
CREATE POLICY "Planilhas: professor atualizar própria"
  ON planilhas FOR UPDATE
  TO authenticated
  USING (professor_id = auth.uid())
  WITH CHECK (professor_id = auth.uid());

DROP POLICY IF EXISTS "Planilhas: professor deletar própria" ON planilhas;
CREATE POLICY "Planilhas: professor deletar própria"
  ON planilhas FOR DELETE
  TO authenticated
  USING (professor_id = auth.uid());
