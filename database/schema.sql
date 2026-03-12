-- ============================================
-- SCHEMA DO BANCO DE DADOS — SUPABASE (PostgreSQL)
-- Sistema de Presença Digital
-- ============================================
-- INSTRUÇÕES:
-- 1. Acesse o painel do Supabase → SQL Editor
-- 2. Cole todo este SQL e execute
-- ============================================

-- Habilitar extensão UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- TABELA: perfis
-- ============================================
CREATE TABLE perfis (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nome VARCHAR(200) NOT NULL,
  matricula VARCHAR(50) UNIQUE NOT NULL,
  email VARCHAR(200) NOT NULL,
  role VARCHAR(20) NOT NULL DEFAULT 'aluno' CHECK (role IN ('aluno', 'professor')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX idx_perfis_matricula ON perfis(matricula);
CREATE INDEX idx_perfis_role ON perfis(role);

-- RLS
ALTER TABLE perfis ENABLE ROW LEVEL SECURITY;

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

-- Usuário pode atualizar apenas seu próprio perfil
CREATE POLICY "Perfis: atualizar próprio"
  ON perfis FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

-- Inserção durante cadastro (service role ou trigger)
CREATE POLICY "Perfis: inserir próprio"
  ON perfis FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);


-- ============================================
-- TABELA: disciplinas
-- ============================================
CREATE TABLE disciplinas (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nome VARCHAR(200) NOT NULL,
  professor_id UUID NOT NULL REFERENCES perfis(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_disciplinas_professor ON disciplinas(professor_id);

ALTER TABLE disciplinas ENABLE ROW LEVEL SECURITY;

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

CREATE POLICY "Disciplinas: professor CRUD"
  ON disciplinas FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM perfis WHERE id = auth.uid() AND role = 'professor')
    AND professor_id = auth.uid()
  );

CREATE POLICY "Disciplinas: professor atualizar"
  ON disciplinas FOR UPDATE
  TO authenticated
  USING (professor_id = auth.uid());

CREATE POLICY "Disciplinas: professor deletar"
  ON disciplinas FOR DELETE
  TO authenticated
  USING (professor_id = auth.uid());


-- ============================================
-- TABELA: turmas
-- ============================================
CREATE TABLE turmas (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  disciplina_id UUID NOT NULL REFERENCES disciplinas(id) ON DELETE CASCADE,
  nome_turma VARCHAR(100) NOT NULL,
  dia_semana SMALLINT NOT NULL CHECK (dia_semana BETWEEN 0 AND 6),
  hora_inicio TIME NOT NULL,
  hora_fim TIME NOT NULL,
  sala VARCHAR(100),
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  raio_metros INTEGER DEFAULT 50,
  ble_service_uuid VARCHAR(100),
  ble_device_name VARCHAR(120),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_turmas_disciplina ON turmas(disciplina_id);
CREATE INDEX idx_turmas_dia ON turmas(dia_semana);

ALTER TABLE turmas ENABLE ROW LEVEL SECURITY;

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

CREATE POLICY "Turmas: professor inserir"
  ON turmas FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM disciplinas d
      WHERE d.id = disciplina_id AND d.professor_id = auth.uid()
    )
  );

CREATE POLICY "Turmas: professor atualizar"
  ON turmas FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM disciplinas d
      WHERE d.id = disciplina_id AND d.professor_id = auth.uid()
    )
  );

CREATE POLICY "Turmas: professor deletar"
  ON turmas FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM disciplinas d
      WHERE d.id = disciplina_id AND d.professor_id = auth.uid()
    )
  );


-- ============================================
-- TABELA: turma_alunos (relação N:N)
-- ============================================
CREATE TABLE turma_alunos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  turma_id UUID NOT NULL REFERENCES turmas(id) ON DELETE CASCADE,
  aluno_id UUID NOT NULL REFERENCES perfis(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(turma_id, aluno_id)
);

CREATE INDEX idx_turma_alunos_turma ON turma_alunos(turma_id);
CREATE INDEX idx_turma_alunos_aluno ON turma_alunos(aluno_id);

ALTER TABLE turma_alunos ENABLE ROW LEVEL SECURITY;

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

CREATE POLICY "TurmaAlunos: professor inserir"
  ON turma_alunos FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM turmas t
      JOIN disciplinas d ON d.id = t.disciplina_id
      WHERE t.id = turma_id AND d.professor_id = auth.uid()
    )
  );

CREATE POLICY "TurmaAlunos: professor deletar"
  ON turma_alunos FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM turmas t
      JOIN disciplinas d ON d.id = t.disciplina_id
      WHERE t.id = turma_id AND d.professor_id = auth.uid()
    )
  );


-- ============================================
-- TABELA: qr_tokens
-- ============================================
CREATE TABLE qr_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  turma_id UUID NOT NULL REFERENCES turmas(id) ON DELETE CASCADE,
  token UUID NOT NULL UNIQUE DEFAULT uuid_generate_v4(),
  slug VARCHAR(20) UNIQUE,
  criado_em TIMESTAMPTZ DEFAULT NOW(),
  expira_em TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_qr_tokens_token ON qr_tokens(token);
CREATE INDEX idx_qr_tokens_slug ON qr_tokens(slug);
CREATE INDEX idx_qr_tokens_turma ON qr_tokens(turma_id);

ALTER TABLE qr_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "QRTokens: leitura autenticada"
  ON qr_tokens FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "QRTokens: professor inserir"
  ON qr_tokens FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM turmas t
      JOIN disciplinas d ON d.id = t.disciplina_id
      WHERE t.id = turma_id AND d.professor_id = auth.uid()
    )
  );

CREATE POLICY "QRTokens: professor deletar"
  ON qr_tokens FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM turmas t
      JOIN disciplinas d ON d.id = t.disciplina_id
      WHERE t.id = turma_id AND d.professor_id = auth.uid()
    )
  );


-- ============================================
-- TABELA: presencas
-- ============================================
CREATE TABLE presencas (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  aluno_id UUID NOT NULL REFERENCES perfis(id) ON DELETE CASCADE,
  turma_id UUID NOT NULL REFERENCES turmas(id) ON DELETE CASCADE,
  data DATE NOT NULL DEFAULT CURRENT_DATE,
  hora_registro TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status VARCHAR(20) NOT NULL DEFAULT 'presente' CHECK (status IN ('presente', 'atrasado', 'ausente')),
  minutos_atraso INTEGER DEFAULT 0,
  latitude_aluno DOUBLE PRECISION,
  longitude_aluno DOUBLE PRECISION,
  distancia_metros INTEGER,
  metodo VARCHAR(20) DEFAULT 'qrcode' CHECK (metodo IN ('qrcode', 'manual')),
  google_synced BOOLEAN NOT NULL DEFAULT false,
  risco_fraude_score INTEGER NOT NULL DEFAULT 0,
  risco_fraude_motivos JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(aluno_id, turma_id, data)
);

CREATE INDEX idx_presencas_aluno ON presencas(aluno_id);
CREATE INDEX idx_presencas_turma ON presencas(turma_id);
CREATE INDEX idx_presencas_data ON presencas(data);
CREATE INDEX idx_presencas_aluno_data ON presencas(aluno_id, data);
CREATE INDEX idx_presencas_google_synced ON presencas(google_synced);

ALTER TABLE presencas ENABLE ROW LEVEL SECURITY;

-- Aluno lê apenas suas presenças
CREATE POLICY "Presencas: aluno lê próprias"
  ON presencas FOR SELECT
  TO authenticated
  USING (
    aluno_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM turmas t
      JOIN disciplinas d ON d.id = t.disciplina_id
      WHERE t.id = turma_id AND d.professor_id = auth.uid()
    )
  );

-- Aluno pode inserir sua própria presença
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

-- Professor pode atualizar presenças de suas turmas (ex: marcar ausente)
CREATE POLICY "Presencas: professor atualizar"
  ON presencas FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM turmas t
      JOIN disciplinas d ON d.id = t.disciplina_id
      WHERE t.id = turma_id AND d.professor_id = auth.uid()
    )
  );


-- ============================================
-- TABELA: planilhas (cards com links)
-- ============================================
CREATE TABLE planilhas (
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

CREATE INDEX idx_planilhas_professor ON planilhas(professor_id);
CREATE INDEX idx_planilhas_disciplina ON planilhas(disciplina_id);
CREATE INDEX idx_planilhas_turma ON planilhas(turma_id);
CREATE INDEX idx_planilhas_created_at ON planilhas(created_at DESC);

ALTER TABLE planilhas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Planilhas: professor leitura compartilhada"
  ON planilhas FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM perfis p
      WHERE p.id = auth.uid() AND p.role = 'professor'
    )
  );

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

CREATE POLICY "Planilhas: professor atualizar própria"
  ON planilhas FOR UPDATE
  TO authenticated
  USING (professor_id = auth.uid())
  WITH CHECK (professor_id = auth.uid());

CREATE POLICY "Planilhas: professor deletar própria"
  ON planilhas FOR DELETE
  TO authenticated
  USING (professor_id = auth.uid());


-- ============================================
-- TABELA: integracao_planilhas_turma (Google Sheets)
-- ============================================
CREATE TABLE integracao_planilhas_turma (
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

CREATE INDEX idx_integracao_planilha_turma ON integracao_planilhas_turma(turma_id);
CREATE INDEX idx_integracao_planilha_professor ON integracao_planilhas_turma(professor_id);


-- ============================================
-- TABELA: google_sync_logs
-- ============================================
CREATE TABLE google_sync_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  turma_id UUID NOT NULL REFERENCES turmas(id) ON DELETE CASCADE,
  professor_id UUID REFERENCES perfis(id) ON DELETE CASCADE,
  presence_id UUID REFERENCES presencas(id) ON DELETE SET NULL,
  spreadsheet_id VARCHAR(200),
  status VARCHAR(20) NOT NULL CHECK (status IN ('success', 'skipped', 'error')),
  reason TEXT,
  attempted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_google_sync_logs_professor ON google_sync_logs(professor_id, attempted_at DESC);
CREATE INDEX idx_google_sync_logs_turma ON google_sync_logs(turma_id, attempted_at DESC);
CREATE INDEX idx_google_sync_logs_presence ON google_sync_logs(presence_id);

ALTER TABLE google_sync_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "GoogleSyncLogs: professor leitura"
  ON google_sync_logs FOR SELECT
  TO authenticated
  USING (professor_id = auth.uid());


-- ============================================
-- TABELA: rate_limit_events
-- ============================================
CREATE TABLE rate_limit_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES perfis(id) ON DELETE CASCADE,
  action_key VARCHAR(60) NOT NULL,
  scope_key VARCHAR(120) NOT NULL DEFAULT 'global',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_rate_limit_events_lookup ON rate_limit_events(user_id, action_key, scope_key, created_at DESC);

ALTER TABLE rate_limit_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "RateLimitEvents: proprio select"
  ON rate_limit_events FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());


-- ============================================
-- FUNÇÃO: rate limiting por usuário/ação/escopo
-- ============================================
CREATE OR REPLACE FUNCTION consumir_rate_limit(
  p_action_key VARCHAR,
  p_scope_key VARCHAR DEFAULT 'global',
  p_limit INTEGER DEFAULT 10,
  p_window_seconds INTEGER DEFAULT 300
)
RETURNS TABLE (
  allowed BOOLEAN,
  remaining INTEGER,
  retry_after_seconds INTEGER
) AS $$
DECLARE
  v_user_id UUID;
  v_scope_key VARCHAR(120);
  v_count INTEGER;
  v_oldest TIMESTAMPTZ;
BEGIN
  v_user_id := auth.uid();
  v_scope_key := COALESCE(NULLIF(TRIM(p_scope_key), ''), 'global');

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado.';
  END IF;

  DELETE FROM rate_limit_events
  WHERE user_id = v_user_id
    AND action_key = p_action_key
    AND scope_key = v_scope_key
    AND created_at < NOW() - make_interval(secs => p_window_seconds);

  SELECT COUNT(*), MIN(created_at)
  INTO v_count, v_oldest
  FROM rate_limit_events
  WHERE user_id = v_user_id
    AND action_key = p_action_key
    AND scope_key = v_scope_key;

  IF v_count >= p_limit THEN
    RETURN QUERY SELECT
      FALSE,
      0,
      GREATEST(1, CEIL(EXTRACT(EPOCH FROM ((v_oldest + make_interval(secs => p_window_seconds)) - NOW())))::INTEGER);
    RETURN;
  END IF;

  INSERT INTO rate_limit_events (user_id, action_key, scope_key)
  VALUES (v_user_id, p_action_key, v_scope_key);

  RETURN QUERY SELECT TRUE, GREATEST(0, p_limit - (v_count + 1)), 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION consumir_rate_limit(VARCHAR, VARCHAR, INTEGER, INTEGER) TO authenticated;

ALTER TABLE integracao_planilhas_turma ENABLE ROW LEVEL SECURITY;

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

CREATE POLICY "IntegracaoPlanilha: professor atualizar própria"
  ON integracao_planilhas_turma FOR UPDATE
  TO authenticated
  USING (professor_id = auth.uid())
  WITH CHECK (professor_id = auth.uid());

CREATE POLICY "IntegracaoPlanilha: professor deletar própria"
  ON integracao_planilhas_turma FOR DELETE
  TO authenticated
  USING (professor_id = auth.uid());


-- ============================================
-- VIEWS AUXILIARES
-- ============================================

-- View: presenças com dados completos (para listagem)
CREATE OR REPLACE VIEW presencas_completas AS
SELECT
  p.id,
  p.data,
  p.hora_registro,
  p.status,
  p.minutos_atraso,
  p.distancia_metros,
  p.metodo,
  a.nome AS aluno_nome,
  a.matricula AS aluno_matricula,
  t.nome_turma,
  t.hora_inicio,
  t.sala,
  d.nome AS disciplina_nome
FROM presencas p
JOIN perfis a ON a.id = p.aluno_id
JOIN turmas t ON t.id = p.turma_id
JOIN disciplinas d ON d.id = t.disciplina_id;


-- ============================================
-- FUNÇÕES AUXILIARES
-- ============================================

-- Função: buscar turmas do aluno para hoje
CREATE OR REPLACE FUNCTION turmas_do_aluno_hoje(p_aluno_id UUID)
RETURNS TABLE (
  turma_id UUID,
  nome_turma VARCHAR,
  disciplina_nome VARCHAR,
  hora_inicio TIME,
  hora_fim TIME,
  sala VARCHAR,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  raio_metros INTEGER,
  ja_marcou BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    t.id AS turma_id,
    t.nome_turma,
    d.nome AS disciplina_nome,
    t.hora_inicio,
    t.hora_fim,
    t.sala,
    t.latitude,
    t.longitude,
    t.raio_metros,
    EXISTS (
      SELECT 1 FROM presencas pr
      WHERE pr.aluno_id = p_aluno_id
        AND pr.turma_id = t.id
        AND pr.data = CURRENT_DATE
    ) AS ja_marcou
  FROM turma_alunos ta
  JOIN turmas t ON t.id = ta.turma_id
  JOIN disciplinas d ON d.id = t.disciplina_id
  WHERE ta.aluno_id = p_aluno_id
    AND t.dia_semana = EXTRACT(DOW FROM CURRENT_DATE)::SMALLINT
  ORDER BY t.hora_inicio;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Função: validar token QR e retornar dados da turma
CREATE OR REPLACE FUNCTION validar_qr_token(p_token UUID)
RETURNS TABLE (
  turma_id UUID,
  nome_turma VARCHAR,
  disciplina_nome VARCHAR,
  hora_inicio TIME,
  hora_fim TIME,
  sala VARCHAR,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  raio_metros INTEGER,
  ble_service_uuid VARCHAR,
  ble_device_name VARCHAR,
  token_valido BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    t.id AS turma_id,
    t.nome_turma,
    d.nome AS disciplina_nome,
    t.hora_inicio,
    t.hora_fim,
    t.sala,
    t.latitude,
    t.longitude,
    t.raio_metros,
    t.ble_service_uuid,
    t.ble_device_name,
    (qt.expira_em > NOW()) AS token_valido
  FROM qr_tokens qt
  JOIN turmas t ON t.id = qt.turma_id
  JOIN disciplinas d ON d.id = t.disciplina_id
  WHERE qt.token = p_token;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Função: auto-vincular aluno autenticado em uma turma (idempotente)
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


-- Função: resolver token por slug curto (somente token ainda válido)
CREATE OR REPLACE FUNCTION resolver_token_por_slug(p_slug VARCHAR)
RETURNS TABLE(token UUID) AS $$
BEGIN
  RETURN QUERY
  SELECT qt.token
  FROM qr_tokens qt
  WHERE qt.slug = p_slug
    AND qt.expira_em > NOW()
  ORDER BY qt.criado_em DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================
-- FUNÇÃO: buscar email pela matrícula (acessível por anon para login)
-- ============================================
CREATE OR REPLACE FUNCTION buscar_email_por_matricula(p_matricula VARCHAR)
RETURNS TABLE(email VARCHAR) AS $$
BEGIN
  RETURN QUERY
  SELECT p.email FROM perfis p WHERE p.matricula = p_matricula;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
