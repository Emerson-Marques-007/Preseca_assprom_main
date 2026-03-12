-- Suporte opcional a validacao de presenca por BLE/beacon.

ALTER TABLE turmas
  ADD COLUMN IF NOT EXISTS ble_service_uuid VARCHAR(100),
  ADD COLUMN IF NOT EXISTS ble_device_name VARCHAR(120);

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