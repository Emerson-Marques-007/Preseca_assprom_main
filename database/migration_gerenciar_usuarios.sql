-- ============================================
-- MIGRAÇÃO: Gerenciamento de Usuários pelo Professor
-- Sistema de Presença Digital
-- ============================================
-- INSTRUÇÕES:
-- 1. Acesse o painel do Supabase → SQL Editor
-- 2. Cole todo este SQL e execute
-- ============================================

-- --------------------------------------------
-- REGRA DE PAPEL AUTOMÁTICO POR DOMÍNIO DE E-MAIL
-- Novos cadastros com @assprom.org.br viram professor,
-- todos os demais domínios viram aluno.
-- --------------------------------------------
CREATE OR REPLACE FUNCTION inferir_role_por_email(p_email TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN lower(split_part(trim(coalesce(p_email, '')), '@', 2)) = 'assprom.org.br' THEN 'professor'
    ELSE 'aluno'
  END;
$$;

CREATE OR REPLACE FUNCTION aplicar_role_por_email_em_perfis()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.role := inferir_role_por_email(NEW.email);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_perfis_role_por_email ON perfis;
CREATE TRIGGER trg_perfis_role_por_email
BEFORE INSERT ON perfis
FOR EACH ROW
EXECUTE FUNCTION aplicar_role_por_email_em_perfis();

-- Função antiga de troca manual de papel removida do fluxo
DROP FUNCTION IF EXISTS alterar_role_usuario(UUID, TEXT);

-- --------------------------------------------
-- FUNÇÃO: editar_perfil_usuario
-- Permite que um professor edite nome e matrícula
-- de qualquer outro usuário.
-- --------------------------------------------
CREATE OR REPLACE FUNCTION editar_perfil_usuario(
  p_usuario_id UUID,
  p_nome       TEXT,
  p_matricula  TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- 1. Apenas professores
  IF NOT EXISTS (
    SELECT 1 FROM perfis
    WHERE id = auth.uid() AND role = 'professor'
  ) THEN
    RAISE EXCEPTION 'Apenas professores podem editar perfis de outros usuários.';
  END IF;

  -- 2. Validar campos
  IF trim(p_nome) = '' THEN
    RAISE EXCEPTION 'O nome não pode ficar em branco.';
  END IF;

  IF trim(p_matricula) = '' THEN
    RAISE EXCEPTION 'A matrícula não pode ficar em branco.';
  END IF;

  -- 3. Verificar duplicidade de matrícula (exceto o próprio usuário)
  IF EXISTS (
    SELECT 1 FROM perfis
    WHERE matricula = trim(p_matricula) AND id <> p_usuario_id
  ) THEN
    RAISE EXCEPTION 'Esta matrícula já está em uso por outro usuário.';
  END IF;

  -- 4. Verificar se o usuário-alvo existe
  IF NOT EXISTS (SELECT 1 FROM perfis WHERE id = p_usuario_id) THEN
    RAISE EXCEPTION 'Usuário não encontrado.';
  END IF;

  -- 5. Atualizar
  UPDATE perfis
  SET nome      = trim(p_nome),
      matricula = trim(p_matricula)
  WHERE id = p_usuario_id;
END;
$$;

GRANT EXECUTE ON FUNCTION editar_perfil_usuario(UUID, TEXT, TEXT) TO authenticated;

-- --------------------------------------------
-- FUNÇÃO: excluir_usuario
-- Permite que um professor exclua qualquer outro
-- usuário. SECURITY DEFINER garante acesso ao
-- schema auth sem expor service_role key.
-- --------------------------------------------
CREATE OR REPLACE FUNCTION excluir_usuario(p_usuario_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- 1. Apenas professores
  IF NOT EXISTS (
    SELECT 1 FROM perfis
    WHERE id = auth.uid() AND role = 'professor'
  ) THEN
    RAISE EXCEPTION 'Apenas professores podem excluir usuários.';
  END IF;

  -- 2. Não permitir auto-exclusão
  IF p_usuario_id = auth.uid() THEN
    RAISE EXCEPTION 'Você não pode excluir sua própria conta.';
  END IF;

  -- 3. Verificar se o usuário existe
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_usuario_id) THEN
    RAISE EXCEPTION 'Usuário não encontrado.';
  END IF;

  -- 4. Excluir — cascateia para a tabela perfis automaticamente
  DELETE FROM auth.users WHERE id = p_usuario_id;
END;
$$;

GRANT EXECUTE ON FUNCTION excluir_usuario(UUID) TO authenticated;

-- --------------------------------------------
-- ÍNDICE EXTRA (se ainda não existir)
-- Acelera listagem de usuários por role
-- --------------------------------------------
CREATE INDEX IF NOT EXISTS idx_perfis_role_nome ON perfis(role, nome);
