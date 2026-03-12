# Edge Function: google-sheets-sync

Integra a aplicacao com Google Sheets usando OAuth 2.0 por usuario (professor).

## Visao geral

- Runtime: Supabase Edge Function (Deno)
- Arquivo principal: index.ts
- Estrategia de autenticacao:
  - token de sessao do Supabase enviado no header x-user-token
  - validacao do perfil no backend (role professor/aluno conforme acao)
- Escopos Google utilizados:
  - https://www.googleapis.com/auth/spreadsheets
  - https://www.googleapis.com/auth/drive.file

## Secrets necessarios

Configure em Supabase > Project Settings > Edge Functions > Secrets:

- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY
- GOOGLE_OAUTH_CLIENT_ID
- GOOGLE_OAUTH_CLIENT_SECRET
- GOOGLE_OAUTH_REDIRECT_URI

Observacoes:

- Esta versao nao usa service account para criar/sincronizar planilha.
- O redirect URI precisa ser exatamente o mesmo cadastrado no OAuth Client do Google Cloud.

## Deploy

```bash
supabase functions deploy google-sheets-sync --project-ref <PROJECT_REF>
```

## Formato de chamada

Endpoint:

```text
POST https://<PROJECT_REF>.supabase.co/functions/v1/google-sheets-sync
```

Headers recomendados (como no frontend atual):

```http
Content-Type: application/json
apikey: <SUPABASE_ANON_KEY>
Authorization: Bearer <SUPABASE_ANON_KEY>
x-user-token: <ACCESS_TOKEN_DO_USUARIO_LOGADO>
```

Tambem e aceito Authorization: Bearer <token_do_usuario>, mas o frontend do projeto usa x-user-token.

## Acoes suportadas

### 1) get_oauth_url

Gera URL para iniciar consentimento OAuth no Google.

Payload:

```json
{
  "action": "get_oauth_url",
  "redirect_uri": "https://seu-dominio/professor/index.html"
}
```

Resposta (sucesso):

```json
{
  "ok": true,
  "auth_url": "https://accounts.google.com/o/oauth2/v2/auth?..."
}
```

### 2) exchange_oauth_code

Troca o code retornado pelo Google por access_token/refresh_token e salva em google_oauth_tokens.

Payload:

```json
{
  "action": "exchange_oauth_code",
  "code": "4/0Ab...",
  "redirect_uri": "https://seu-dominio/professor/index.html"
}
```

Resposta (sucesso):

```json
{
  "ok": true,
  "connected": true,
  "google_email": "professor@dominio.com",
  "expires_at": "2026-03-12T12:00:00.000Z"
}
```

### 3) get_oauth_status

Consulta se o professor logado ja conectou conta Google.

Payload:

```json
{
  "action": "get_oauth_status"
}
```

Resposta (exemplo):

```json
{
  "ok": true,
  "connected": true,
  "google_email": "professor@dominio.com",
  "expires_at": "2026-03-12T12:00:00.000Z"
}
```

### 4) create_sheet

Cria planilha para uma turma e grava integracao em integracao_planilhas_turma.

Payload:

```json
{
  "action": "create_sheet",
  "turma_id": "UUID_DA_TURMA"
}
```

Resposta (sucesso):

```json
{
  "ok": true,
  "spreadsheet_id": "1abcDEF...",
  "spreadsheet_url": "https://docs.google.com/spreadsheets/d/1abcDEF..."
}
```

### 5) sync_presence

Insere linha de presenca na aba Frequencia da planilha vinculada a turma.

Payload:

```json
{
  "action": "sync_presence",
  "turma_id": "UUID_DA_TURMA",
  "matricula": "ALU001",
  "nome": "Nome do Aluno",
  "frequencia": "P",
  "atraso": 0,
  "horario": "08:05"
}
```

Resposta possivel:

- sucesso:

```json
{ "ok": true }
```

- sem integracao ativa (nao bloqueante):

```json
{
  "ok": false,
  "skipped": true,
  "reason": "Turma sem integracao ativa."
}
```

## Regras de autorizacao

- Acoes get_oauth_url, exchange_oauth_code, get_oauth_status e create_sheet: somente professor.
- sync_presence:
  - professor: apenas para turma cuja integracao pertence ao proprio professor;
  - aluno: permitido apenas se estiver vinculado a turma.

## Tabelas utilizadas

- perfis
- turmas
- disciplinas
- google_oauth_tokens
- integracao_planilhas_turma
- turma_alunos

## Erros comuns

### Sessao invalida

- Causa: token ausente/expirado.
- Acao: refazer login e reenviar chamada com x-user-token valido.

### Conta Google nao conectada

- Causa: professor ainda nao autorizou OAuth.
- Acao: executar get_oauth_url e depois exchange_oauth_code.

### Sem permissao para turma

- Causa: turma nao pertence ao professor ou aluno sem vinculo.
- Acao: revisar disciplina/turma e vinculo em turma_alunos.

### Falha ao criar/sincronizar no Google

- Causa: token expirado sem refresh_token, escopo insuficiente ou API desabilitada.
- Acao: reconectar Google e validar configuracao do projeto no Google Cloud.
