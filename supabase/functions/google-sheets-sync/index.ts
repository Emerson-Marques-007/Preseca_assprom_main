// @ts-nocheck

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-user-token',
};

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
const GOOGLE_OAUTH_CLIENT_ID = Deno.env.get('GOOGLE_OAUTH_CLIENT_ID') || '';
const GOOGLE_OAUTH_CLIENT_SECRET = Deno.env.get('GOOGLE_OAUTH_CLIENT_SECRET') || '';
const GOOGLE_OAUTH_REDIRECT_URI = Deno.env.get('GOOGLE_OAUTH_REDIRECT_URI') || '';
const GOOGLE_OAUTH_SCOPES = [
  'https://www.googleapis.com/auth/spreadsheets',
  'https://www.googleapis.com/auth/drive.file',
].join(' ');

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function logSyncAttempt(admin: any, payload: {
  turma_id: string;
  professor_id?: string | null;
  presence_id?: string | null;
  spreadsheet_id?: string | null;
  status: 'success' | 'skipped' | 'error';
  reason?: string | null;
}) {
  const { error } = await admin
    .from('google_sync_logs')
    .insert({
      turma_id: payload.turma_id,
      professor_id: payload.professor_id || null,
      presence_id: payload.presence_id || null,
      spreadsheet_id: payload.spreadsheet_id || null,
      status: payload.status,
      reason: payload.reason || null,
    });

  if (error) {
    console.error('Falha ao registrar log de sincronizacao:', error.message);
  }
}

function getUserToken(req: Request): string {
  const custom = req.headers.get('x-user-token') || '';
  if (custom) {
    return custom.trim();
  }

  const auth = req.headers.get('authorization') || '';
  if (!auth.toLowerCase().startsWith('bearer ')) {
    throw new Error('Token de usuario ausente.');
  }

  return auth.slice(7).trim();
}

async function getAuthenticatedProfessor(req: Request, admin: any) {
  const perfil = await getAuthenticatedProfile(req, admin);

  if (perfil.role !== 'professor') {
    throw new Error('Apenas professores podem usar esta funcionalidade.');
  }

  return perfil;
}

async function getAuthenticatedProfile(req: Request, admin: any) {
  const accessToken = getUserToken(req);

  if (!accessToken) {
    throw new Error('Sessao invalida. Faca login novamente.');
  }

  const { data: authData, error: authErr } = await admin.auth.getUser(accessToken);
  if (authErr || !authData?.user) {
    throw new Error('Sessao invalida. Faca login novamente.');
  }

  const userId = authData.user.id;
  const { data: perfil, error: perfilErr } = await admin
    .from('perfis')
    .select('id, role, nome')
    .eq('id', userId)
    .single();

  if (perfilErr || !perfil) {
    throw new Error('Perfil nao encontrado.');
  }

  return perfil;
}

async function exchangeCodeForTokens(code: string, redirectUri: string) {
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      code,
      client_id: GOOGLE_OAUTH_CLIENT_ID,
      client_secret: GOOGLE_OAUTH_CLIENT_SECRET,
      redirect_uri: redirectUri,
      grant_type: 'authorization_code',
    }).toString(),
  });

  const data = await response.json();
  if (!response.ok) {
    throw new Error(`Falha ao trocar code por token (${response.status}): ${data.error_description || data.error || 'erro desconhecido'}`);
  }

  return data;
}

async function refreshGoogleToken(refreshToken: string) {
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: GOOGLE_OAUTH_CLIENT_ID,
      client_secret: GOOGLE_OAUTH_CLIENT_SECRET,
      refresh_token: refreshToken,
      grant_type: 'refresh_token',
    }).toString(),
  });

  const data = await response.json();
  if (!response.ok) {
    throw new Error(`Falha ao renovar token Google (${response.status}): ${data.error_description || data.error || 'erro desconhecido'}`);
  }

  return data;
}

async function getValidGoogleAccessToken(admin: any, professorId: string) {
  const { data: tokenRow, error: tokenErr } = await admin
    .from('google_oauth_tokens')
    .select('id, google_email, access_token, refresh_token, expires_at')
    .eq('professor_id', professorId)
    .single();

  if (tokenErr || !tokenRow) {
    throw new Error('Conta Google nao conectada. Clique em "Conectar Google" primeiro.');
  }

  const now = Date.now();
  const expiresAtMs = tokenRow.expires_at ? new Date(tokenRow.expires_at).getTime() : 0;
  const hasValidAccessToken = tokenRow.access_token && expiresAtMs > now + 60_000;

  if (hasValidAccessToken) {
    return tokenRow.access_token;
  }

  if (!tokenRow.refresh_token) {
    throw new Error('Token Google expirado e sem refresh_token. Reconecte sua conta Google.');
  }

  const refreshed = await refreshGoogleToken(tokenRow.refresh_token);
  const newAccessToken = refreshed.access_token;
  const newExpiresAt = new Date(Date.now() + (Number(refreshed.expires_in || 3600) * 1000)).toISOString();

  const { error: updateErr } = await admin
    .from('google_oauth_tokens')
    .update({
      access_token: newAccessToken,
      expires_at: newExpiresAt,
      updated_at: new Date().toISOString(),
    })
    .eq('id', tokenRow.id);

  if (updateErr) {
    throw new Error(`Falha ao atualizar token renovado: ${updateErr.message}`);
  }

  return newAccessToken;
}

async function createGoogleSheetWithUserToken(accessToken: string, title: string) {
  const response = await fetch('https://sheets.googleapis.com/v4/spreadsheets', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      properties: { title },
      sheets: [{ properties: { title: 'Frequencia' } }],
    }),
  });

  const data = await response.json();
  if (!response.ok) {
    throw new Error(`Google Sheets create falhou (${response.status}): ${data?.error?.message || 'erro desconhecido'}`);
  }

  return {
    spreadsheet_id: data.spreadsheetId,
    spreadsheet_url: data.spreadsheetUrl,
  };
}

async function addHeadersToSheet(accessToken: string, spreadsheetId: string) {
  const response = await fetch(
    `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/Frequencia!A1:E1?valueInputOption=USER_ENTERED`,
    {
      method: 'PUT',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        values: [['Matricula', 'Nome', 'Frequencia', 'Atraso(min)', 'Horario']],
      }),
    },
  );

  if (!response.ok) {
    const errData = await response.json();
    throw new Error(`Falha ao criar cabecalho da planilha (${response.status}): ${errData?.error?.message || 'erro desconhecido'}`);
  }
}

async function applyPrettySheetLayout(accessToken: string, spreadsheetId: string, sheetName = 'Frequencia') {
  const metaResponse = await fetch(
    `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}?fields=sheets(properties(sheetId,title))`,
    {
      headers: { Authorization: `Bearer ${accessToken}` },
    },
  );

  if (!metaResponse.ok) {
    const errData = await metaResponse.json();
    throw new Error(`Falha ao obter metadados da planilha (${metaResponse.status}): ${errData?.error?.message || 'erro desconhecido'}`);
  }

  const metadata = await metaResponse.json();
  const sheet = metadata?.sheets?.find((item: any) => item?.properties?.title === sheetName);
  const sheetId = sheet?.properties?.sheetId;

  if (typeof sheetId !== 'number') {
    throw new Error(`Aba "${sheetName}" nao encontrada para aplicar layout.`);
  }

  const requests = [
    {
      updateSheetProperties: {
        properties: {
          sheetId,
          gridProperties: {
            frozenRowCount: 1,
          },
        },
        fields: 'gridProperties.frozenRowCount',
      },
    },
    {
      setBasicFilter: {
        filter: {
          range: {
            sheetId,
            startRowIndex: 0,
            startColumnIndex: 0,
            endColumnIndex: 5,
          },
        },
      },
    },
    {
      updateDimensionProperties: {
        range: {
          sheetId,
          dimension: 'COLUMNS',
          startIndex: 0,
          endIndex: 1,
        },
        properties: { pixelSize: 130 },
        fields: 'pixelSize',
      },
    },
    {
      updateDimensionProperties: {
        range: {
          sheetId,
          dimension: 'COLUMNS',
          startIndex: 1,
          endIndex: 2,
        },
        properties: { pixelSize: 260 },
        fields: 'pixelSize',
      },
    },
    {
      updateDimensionProperties: {
        range: {
          sheetId,
          dimension: 'COLUMNS',
          startIndex: 2,
          endIndex: 3,
        },
        properties: { pixelSize: 140 },
        fields: 'pixelSize',
      },
    },
    {
      updateDimensionProperties: {
        range: {
          sheetId,
          dimension: 'COLUMNS',
          startIndex: 3,
          endIndex: 4,
        },
        properties: { pixelSize: 120 },
        fields: 'pixelSize',
      },
    },
    {
      updateDimensionProperties: {
        range: {
          sheetId,
          dimension: 'COLUMNS',
          startIndex: 4,
          endIndex: 5,
        },
        properties: { pixelSize: 140 },
        fields: 'pixelSize',
      },
    },
    {
      repeatCell: {
        range: {
          sheetId,
          startRowIndex: 0,
          endRowIndex: 1,
          startColumnIndex: 0,
          endColumnIndex: 5,
        },
        cell: {
          userEnteredFormat: {
            backgroundColor: { red: 0.24, green: 0.35, blue: 0.6 },
            textFormat: {
              foregroundColor: { red: 1, green: 1, blue: 1 },
              bold: true,
              fontSize: 11,
            },
            horizontalAlignment: 'CENTER',
            verticalAlignment: 'MIDDLE',
          },
        },
        fields: 'userEnteredFormat(backgroundColor,textFormat,horizontalAlignment,verticalAlignment)',
      },
    },
    {
      repeatCell: {
        range: {
          sheetId,
          startRowIndex: 1,
          startColumnIndex: 0,
          endColumnIndex: 5,
        },
        cell: {
          userEnteredFormat: {
            textFormat: {
              foregroundColor: { red: 0.13, green: 0.16, blue: 0.22 },
              fontSize: 10,
            },
            verticalAlignment: 'MIDDLE',
            wrapStrategy: 'WRAP',
          },
        },
        fields: 'userEnteredFormat(textFormat,verticalAlignment,wrapStrategy)',
      },
    },
    {
      repeatCell: {
        range: {
          sheetId,
          startRowIndex: 1,
          startColumnIndex: 2,
          endColumnIndex: 5,
        },
        cell: {
          userEnteredFormat: {
            horizontalAlignment: 'CENTER',
          },
        },
        fields: 'userEnteredFormat.horizontalAlignment',
      },
    },
    {
      addBanding: {
        bandedRange: {
          range: {
            sheetId,
            startRowIndex: 0,
            startColumnIndex: 0,
            endColumnIndex: 5,
          },
          rowProperties: {
            headerColor: { red: 0.24, green: 0.35, blue: 0.6 },
            firstBandColor: { red: 0.97, green: 0.98, blue: 1 },
            secondBandColor: { red: 1, green: 1, blue: 1 },
          },
        },
      },
    },
    {
      addConditionalFormatRule: {
        index: 0,
        rule: {
          ranges: [
            {
              sheetId,
              startRowIndex: 1,
              startColumnIndex: 2,
              endColumnIndex: 3,
            },
          ],
          booleanRule: {
            condition: {
              type: 'TEXT_EQ',
              values: [{ userEnteredValue: 'P' }],
            },
            format: {
              backgroundColor: { red: 0.89, green: 0.97, blue: 0.91 },
              textFormat: {
                foregroundColor: { red: 0.1, green: 0.45, blue: 0.22 },
                bold: true,
              },
            },
          },
        },
      },
    },
    {
      addConditionalFormatRule: {
        index: 1,
        rule: {
          ranges: [
            {
              sheetId,
              startRowIndex: 1,
              startColumnIndex: 2,
              endColumnIndex: 3,
            },
          ],
          booleanRule: {
            condition: {
              type: 'TEXT_EQ',
              values: [{ userEnteredValue: 'F' }],
            },
            format: {
              backgroundColor: { red: 0.99, green: 0.9, blue: 0.9 },
              textFormat: {
                foregroundColor: { red: 0.72, green: 0.11, blue: 0.11 },
                bold: true,
              },
            },
          },
        },
      },
    },
    {
      addConditionalFormatRule: {
        index: 2,
        rule: {
          ranges: [
            {
              sheetId,
              startRowIndex: 1,
              startColumnIndex: 3,
              endColumnIndex: 4,
            },
          ],
          booleanRule: {
            condition: {
              type: 'NUMBER_GREATER',
              values: [{ userEnteredValue: '0' }],
            },
            format: {
              backgroundColor: { red: 1, green: 0.95, blue: 0.82 },
              textFormat: {
                foregroundColor: { red: 0.68, green: 0.33, blue: 0 },
                bold: true,
              },
            },
          },
        },
      },
    },
  ];

  const response = await fetch(
    `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}:batchUpdate`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ requests }),
    },
  );

  if (!response.ok) {
    const errData = await response.json();
    throw new Error(`Falha ao aplicar layout da planilha (${response.status}): ${errData?.error?.message || 'erro desconhecido'}`);
  }
}

async function appendPresenceToSheet(accessToken: string, spreadsheetId: string, payload: any) {
  const response = await fetch(
    `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/Frequencia!A:E:append?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        values: [[payload.matricula, payload.nome, payload.frequencia, payload.atraso ?? 0, payload.horario]],
      }),
    },
  );

  if (!response.ok) {
    const errData = await response.json();
    throw new Error(`Falha ao sincronizar presenca (${response.status}): ${errData?.error?.message || 'erro desconhecido'}`);
  }

  const appendData = await response.json();
  const updatedRange = appendData?.updates?.updatedRange || '';
  const rowMatch = String(updatedRange).match(/![A-Z]+(\d+):[A-Z]+\d+/i);
  const rowNumber = rowMatch ? Number(rowMatch[1]) : NaN;

  if (!Number.isFinite(rowNumber) || rowNumber < 2) {
    return;
  }

  const metaResponse = await fetch(
    `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}?fields=sheets(properties(sheetId,title))`,
    {
      headers: { Authorization: `Bearer ${accessToken}` },
    },
  );

  if (!metaResponse.ok) {
    return;
  }

  const metadata = await metaResponse.json();
  const sheet = metadata?.sheets?.find((item: any) => item?.properties?.title === 'Frequencia');
  const sheetId = sheet?.properties?.sheetId;

  if (typeof sheetId !== 'number') {
    return;
  }

  await fetch(
    `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}:batchUpdate`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        requests: [
          {
            repeatCell: {
              range: {
                sheetId,
                startRowIndex: rowNumber - 1,
                endRowIndex: rowNumber,
                startColumnIndex: 0,
                endColumnIndex: 5,
              },
              cell: {
                userEnteredFormat: {
                  textFormat: {
                    foregroundColor: { red: 0.13, green: 0.16, blue: 0.22 },
                    fontSize: 10,
                  },
                  verticalAlignment: 'MIDDLE',
                  wrapStrategy: 'WRAP',
                },
              },
              fields: 'userEnteredFormat(textFormat,verticalAlignment,wrapStrategy)',
            },
          },
        ],
      }),
    },
  );
}

async function getPresenceForSync(admin: any, presenceId: string) {
  const { data, error } = await admin
    .from('presencas')
    .select('id, aluno_id, turma_id, status, minutos_atraso, hora_registro, google_synced, perfis!presencas_aluno_id_fkey(nome, matricula)')
    .eq('id', presenceId)
    .single();

  if (error || !data) {
    throw new Error('Presenca nao encontrada para sincronizacao.');
  }

  return data;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  try {
    const body = await req.json();
    const action = body?.action;

    if (!action) {
      return jsonResponse({ error: 'action obrigatoria' }, 400);
    }

    if (action === 'get_oauth_url') {
      const perfil = await getAuthenticatedProfessor(req, admin);
      const redirectUri = body?.redirect_uri || GOOGLE_OAUTH_REDIRECT_URI;

      if (!GOOGLE_OAUTH_CLIENT_ID || !GOOGLE_OAUTH_CLIENT_SECRET || !redirectUri) {
        return jsonResponse({ error: 'Secrets OAuth ausentes: GOOGLE_OAUTH_CLIENT_ID, GOOGLE_OAUTH_CLIENT_SECRET, GOOGLE_OAUTH_REDIRECT_URI' }, 500);
      }

      const statePayload = btoa(JSON.stringify({
        professor_id: perfil.id,
        ts: Date.now(),
      }));

      const authUrl = 'https://accounts.google.com/o/oauth2/v2/auth?' + new URLSearchParams({
        client_id: GOOGLE_OAUTH_CLIENT_ID,
        redirect_uri: redirectUri,
        response_type: 'code',
        access_type: 'offline',
        prompt: 'consent',
        include_granted_scopes: 'true',
        scope: GOOGLE_OAUTH_SCOPES,
        state: statePayload,
      }).toString();

      return jsonResponse({ ok: true, auth_url: authUrl });
    }

    if (action === 'exchange_oauth_code') {
      const perfil = await getAuthenticatedProfessor(req, admin);
      const code = body?.code;
      const redirectUri = body?.redirect_uri || GOOGLE_OAUTH_REDIRECT_URI;

      if (!code) {
        return jsonResponse({ error: 'code obrigatorio para exchange_oauth_code' }, 400);
      }

      const tokens = await exchangeCodeForTokens(code, redirectUri);
      const expiresAt = new Date(Date.now() + (Number(tokens.expires_in || 3600) * 1000)).toISOString();

      const oldToken = await admin
        .from('google_oauth_tokens')
        .select('refresh_token')
        .eq('professor_id', perfil.id)
        .maybeSingle();

      const refreshToken = tokens.refresh_token || oldToken?.data?.refresh_token || null;

      const googleUserResp = await fetch('https://www.googleapis.com/oauth2/v2/userinfo', {
        headers: { Authorization: `Bearer ${tokens.access_token}` },
      });
      const googleUserData = await googleUserResp.json();

      const { error: upsertErr } = await admin
        .from('google_oauth_tokens')
        .upsert({
          professor_id: perfil.id,
          google_email: googleUserData?.email || null,
          access_token: tokens.access_token,
          refresh_token: refreshToken,
          scope: tokens.scope || GOOGLE_OAUTH_SCOPES,
          token_type: tokens.token_type || 'Bearer',
          expires_at: expiresAt,
          updated_at: new Date().toISOString(),
        }, { onConflict: 'professor_id' });

      if (upsertErr) {
        throw new Error(`Erro ao salvar token OAuth: ${upsertErr.message}`);
      }

      return jsonResponse({ ok: true, connected: true, google_email: googleUserData?.email || null, expires_at: expiresAt });
    }

    if (action === 'get_oauth_status') {
      const perfil = await getAuthenticatedProfessor(req, admin);
      const { data, error } = await admin
        .from('google_oauth_tokens')
        .select('google_email, expires_at, updated_at')
        .eq('professor_id', perfil.id)
        .maybeSingle();

      if (error) {
        throw new Error(`Erro ao consultar status OAuth: ${error.message}`);
      }

      return jsonResponse({
        ok: true,
        connected: !!data,
        google_email: data?.google_email || null,
        expires_at: data?.expires_at || null,
      });
    }

    if (action === 'create_sheet') {
      const perfil = await getAuthenticatedProfessor(req, admin);
      const turmaId = body?.turma_id;

      if (!turmaId) {
        return jsonResponse({ error: 'turma_id e obrigatorio' }, 400);
      }

      const { data: turma, error: turmaErr } = await admin
        .from('turmas')
        .select('id, nome_turma, disciplinas(professor_id)')
        .eq('id', turmaId)
        .single();

      if (turmaErr || !turma) {
        return jsonResponse({ error: 'Turma nao encontrada.' }, 404);
      }

      if (turma.disciplinas?.professor_id !== perfil.id) {
        return jsonResponse({ error: 'Voce nao tem permissao para criar planilha desta turma.' }, 403);
      }

      const googleAccessToken = await getValidGoogleAccessToken(admin, perfil.id);
      const title = `Frequencia - ${turma.nome_turma}`;
      const { spreadsheet_id, spreadsheet_url } = await createGoogleSheetWithUserToken(googleAccessToken, title);
      await addHeadersToSheet(googleAccessToken, spreadsheet_id);
      await applyPrettySheetLayout(googleAccessToken, spreadsheet_id, 'Frequencia');

      const { error: upsertErr } = await admin
        .from('integracao_planilhas_turma')
        .upsert({
          turma_id: turmaId,
          professor_id: perfil.id,
          spreadsheet_id,
          spreadsheet_url,
          sheet_name: 'Frequencia',
          ativo: true,
          updated_at: new Date().toISOString(),
        }, { onConflict: 'turma_id' });

      if (upsertErr) {
        throw new Error(`Erro ao salvar integracao: ${upsertErr.message}`);
      }

      return jsonResponse({ ok: true, spreadsheet_id, spreadsheet_url });
    }

    if (action === 'sync_presence') {
      const perfil = await getAuthenticatedProfile(req, admin);
      const turmaId = body?.turma_id;
      const presenceId = body?.presence_id;

      if (!turmaId || !presenceId) {
        return jsonResponse({ error: 'Dados incompletos para sincronizacao.' }, 400);
      }

      const presence = await getPresenceForSync(admin, presenceId);

      if (presence.turma_id !== turmaId) {
        return jsonResponse({ error: 'Presenca nao pertence a turma informada.' }, 400);
      }

      if (presence.google_synced) {
        await logSyncAttempt(admin, {
          turma_id: turmaId,
          presence_id: presenceId,
          status: 'skipped',
          reason: 'Presenca ja sincronizada.',
        });
        return jsonResponse({ ok: true, skipped: true, reason: 'Presenca ja sincronizada.' });
      }

      const { data: integ, error: integErr } = await admin
        .from('integracao_planilhas_turma')
        .select('spreadsheet_id, professor_id, ativo')
        .eq('turma_id', turmaId)
        .eq('ativo', true)
        .single();

      if (integErr || !integ) {
        await logSyncAttempt(admin, {
          turma_id: turmaId,
          presence_id: presenceId,
          status: 'skipped',
          reason: 'Turma sem integracao ativa.',
        });
        return jsonResponse({ ok: false, skipped: true, reason: 'Turma sem integracao ativa.' });
      }

      if (perfil.role === 'professor') {
        if (integ.professor_id !== perfil.id) {
          await logSyncAttempt(admin, {
            turma_id: turmaId,
            professor_id: integ.professor_id,
            presence_id: presenceId,
            spreadsheet_id: integ.spreadsheet_id,
            status: 'error',
            reason: 'Sem permissao para sincronizar esta turma.',
          });
          return jsonResponse({ error: 'Sem permissao para sincronizar esta turma.' }, 403);
        }
      } else if (perfil.role === 'aluno') {
        if (presence.aluno_id !== perfil.id) {
          await logSyncAttempt(admin, {
            turma_id: turmaId,
            professor_id: integ.professor_id,
            presence_id: presenceId,
            spreadsheet_id: integ.spreadsheet_id,
            status: 'error',
            reason: 'Aluno sem permissao para sincronizar esta presenca.',
          });
          return jsonResponse({ error: 'Aluno sem permissao para sincronizar esta presenca.' }, 403);
        }
      } else {
        await logSyncAttempt(admin, {
          turma_id: turmaId,
          professor_id: integ.professor_id,
          presence_id: presenceId,
          spreadsheet_id: integ.spreadsheet_id,
          status: 'error',
          reason: 'Perfil sem permissao para sincronizar.',
        });
        return jsonResponse({ error: 'Perfil sem permissao para sincronizar.' }, 403);
      }

      try {
        const googleAccessToken = await getValidGoogleAccessToken(admin, integ.professor_id);
        await appendPresenceToSheet(googleAccessToken, integ.spreadsheet_id, {
          matricula: presence.perfis?.matricula || '',
          nome: presence.perfis?.nome || '',
          frequencia: presence.status === 'ausente' ? 'F' : 'P',
          atraso: presence.minutos_atraso || 0,
          horario: presence.hora_registro
            ? new Date(presence.hora_registro).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
            : '--:--',
        });

        const { error: updateErr } = await admin
          .from('presencas')
          .update({ google_synced: true })
          .eq('id', presenceId)
          .eq('google_synced', false);

        if (updateErr) {
          throw new Error(`Falha ao marcar presenca como sincronizada: ${updateErr.message}`);
        }

        await logSyncAttempt(admin, {
          turma_id: turmaId,
          professor_id: integ.professor_id,
          presence_id: presenceId,
          spreadsheet_id: integ.spreadsheet_id,
          status: 'success',
          reason: 'Presenca sincronizada com sucesso.',
        });

        return jsonResponse({ ok: true });
      } catch (syncError) {
        await logSyncAttempt(admin, {
          turma_id: turmaId,
          professor_id: integ.professor_id,
          presence_id: presenceId,
          spreadsheet_id: integ.spreadsheet_id,
          status: 'error',
          reason: (syncError as Error).message || 'Erro ao sincronizar presenca.',
        });

        throw syncError;
      }
    }

    return jsonResponse({ error: `Acao invalida: ${action}` }, 400);
  } catch (error) {
    return jsonResponse({
      error: (error as Error).message || 'Erro interno',
      type: 'server_error',
    }, 500);
  }
});
