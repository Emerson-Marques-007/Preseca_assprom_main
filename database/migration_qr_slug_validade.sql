-- ============================================
-- MIGRAÇÃO: QR com slug curto (link para PC)
-- Execute no Supabase SQL Editor
-- ============================================

ALTER TABLE qr_tokens
  ADD COLUMN IF NOT EXISTS slug VARCHAR(20);

CREATE UNIQUE INDEX IF NOT EXISTS idx_qr_tokens_slug ON qr_tokens(slug);

-- Função para resolver slug curto em token válido
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
