# ASSPROM | Presença Digital

Sistema web para controle de presença escolar com:

- autenticação por matrícula (Supabase Auth);
- marcação por QR Code com expiração e link curto;
- validação geográfica por GPS (raio por turma);
- área do aluno e área do professor;
- integração com Google Sheets via OAuth 2.0 e Edge Function;
- PWA instalável com cache offline básico.

## Status Do Projeto

Projeto funcional em produção acadêmica, com base em HTML/CSS/JS puro e backend Supabase.

## Stack

- Frontend: HTML + CSS + JavaScript (vanilla)
- Backend: Supabase (Auth, Postgres, RLS, RPC)
- QR Code: qrcode.js (geração) e html5-qrcode (leitura)
- Integração externa: Google Sheets API via OAuth 2.0
- PWA: manifest.json + service worker

## Funcionalidades Implementadas

### Acesso e autenticação

- Login por matrícula + senha.
- Cadastro de usuário com perfil salvo em perfis.
- Regra de papel por domínio de e-mail:
  - @assprom.org.br => professor
  - demais domínios => aluno
- Guardas de rota por papel (aluno/professor).

### Área do aluno

- Dashboard com saudação, data e estatísticas (presenças, atrasos, faltas).
- Lista de aulas do dia via RPC turmas_do_aluno_hoje.
- Marcação de presença:
  - manual (durante horário da aula, com validação de localização);
  - por QR Code (escaneando câmera ou link curto).
- Validação de presença duplicada por aluno/turma/data.
- Histórico com filtros por disciplina, status e período.

### Área do professor

- Dashboard com indicadores e últimas presenças.
- CRUD de disciplinas.
- CRUD de turmas com:
  - dia da semana, horário, sala;
  - latitude/longitude;
  - raio em metros;
  - captura de GPS para preencher coordenadas.
- Gestão de alunos na turma (adicionar/remover por matrícula).
- Gerador de QR dinâmico com:
  - validade configurável (1 a 60 min);
  - renovação automática;
  - link curto para p.html?s=...
- Relatório de presenças com filtro, ordenação e exportação CSV.
- Gestão de usuários:
  - editar nome/matrícula de contas;
  - excluir usuários (exceto autoexclusão).
- Planilhas:
  - CRUD de cards de planilhas (links);
  - integração por turma com Google Sheets (OAuth);
  - sincronização em tempo real no registro de presença;
  - sincronização manual por data.

### Segurança e regras de negócio

- RLS ativa nas tabelas principais.
- Políticas por papel e escopo do professor.
- Presença exige vínculo aluno-turma.
- Auto-vínculo idempotente via RPC auto_vincular_aluno_turma.
- Token QR com validade curta + slug curto.
- Bloqueio de duplicidade com UNIQUE(aluno_id, turma_id, data).

### PWA

- Manifesto para instalação.
- Cache estático no service worker.
- Estratégia network-first com fallback em cache para assets locais.

## Estrutura De Pastas

```text
.
├─ index.html                     # login/cadastro
├─ presenca.html                  # confirmação de presença por token/slug
├─ p.html                         # redirecionador para presenca.html
├─ manifest.json
├─ sw.js
├─ aluno/
│  ├─ index.html                  # dashboard do aluno
│  └─ historico.html              # histórico com filtros
├─ professor/
│  └─ index.html                  # painel completo do professor
├─ js/
│  ├─ config.js                   # URL/chave Supabase + configs globais
│  ├─ auth.js                     # login/cadastro/guards
│  └─ utils.js                    # toasts, modal, tema, geolocalização, helpers
├─ css/
│  ├─ style.css
│  └─ logo-config.css
├─ database/
│  ├─ schema.sql
│  ├─ migration_planilhas.sql
│  ├─ migration_qr_slug_validade.sql
│  ├─ migration_qr_tokens_rls_fix.sql
│  ├─ migration_auto_vinculo_presenca.sql
│  ├─ migration_google_planilha_turma.sql
│  ├─ migration_google_oauth_tokens.sql
│  └─ migration_gerenciar_usuarios.sql
└─ supabase/
   └─ functions/
      └─ google-sheets-sync/
         ├─ index.ts
         └─ README.md
```

## Modelo De Dados

Principais tabelas:

- perfis
- disciplinas
- turmas
- turma_alunos
- qr_tokens
- presencas
- planilhas
- integracao_planilhas_turma
- google_oauth_tokens

Principais RPCs/funções:

- buscar_email_por_matricula
- turmas_do_aluno_hoje
- validar_qr_token
- resolver_token_por_slug
- auto_vincular_aluno_turma
- editar_perfil_usuario
- excluir_usuario

## Configuração Do Ambiente

### 1) Criar projeto Supabase

1. Crie um projeto no Supabase.
2. Copie Project URL e anon public key.

### 2) Configurar frontend

Edite js/config.js:

```javascript
const SUPABASE_URL = 'https://SEU-PROJETO.supabase.co';
const SUPABASE_ANON_KEY = 'SUA_ANON_KEY';
const PUBLIC_BASE_URL = 'https://seu-dominio-publico.com';
```

Observações:

- PUBLIC_BASE_URL deve apontar para a URL pública real (não localhost) para o QR funcionar em celular externo.
- Se ficar vazio, usa window.location.origin.

### 3) Criar banco

Projeto novo:

1. Execute database/schema.sql inteiro no SQL Editor.

Projeto já existente (atualização incremental):

1. Execute os arquivos abaixo na ordem:
   1. database/migration_planilhas.sql
   2. database/migration_qr_slug_validade.sql
   3. database/migration_qr_tokens_rls_fix.sql
   4. database/migration_auto_vinculo_presenca.sql
   5. database/migration_google_planilha_turma.sql
   6. database/migration_google_oauth_tokens.sql
   7. database/migration_gerenciar_usuarios.sql

### 4) Edge Function (Google Sheets)

No Supabase, configure os secrets da função google-sheets-sync:

- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY
- GOOGLE_OAUTH_CLIENT_ID
- GOOGLE_OAUTH_CLIENT_SECRET
- GOOGLE_OAUTH_REDIRECT_URI

Depois, faça deploy:

```bash
supabase functions deploy google-sheets-sync --project-ref <PROJECT_REF>
```

Notas importantes:

- O fluxo atual usa OAuth de usuário (professor), não service account.
- O redirect URI deve bater exatamente com a URL configurada no Google Cloud OAuth Client.

### 5) Configuração Google Cloud

1. Ative Google Sheets API.
2. Crie OAuth Client (Web Application).
3. Defina Authorized redirect URIs com a URL do painel do professor.
4. Copie client id/client secret para os secrets no Supabase.

## Como Executar Localmente

Como é um projeto estático, rode com um servidor local (não abrir por file://):

```bash
npx serve .
```

ou

```bash
python -m http.server 5500
```

Requisitos práticos:

- Câmera e geolocalização normalmente exigem HTTPS (ou localhost).
- Para teste em celular real na mesma rede, use túnel HTTPS ou deploy temporário.

## Fluxos Principais

### Fluxo QR

1. Professor escolhe turma e gera QR.
2. Sistema cria qr_tokens com expiração e slug curto.
3. Aluno acessa presenca.html via token/slug.
4. Sistema valida token, vínculo, duplicidade e localização.
5. Presença é registrada.
6. Se houver integração ativa da turma, tenta sincronizar no Google Sheets.

### Fluxo manual

1. Aluno abre aula em andamento no dashboard.
2. Sistema obtém GPS e valida raio da turma.
3. Registra presença com método manual.
4. Tenta sincronização Google em best effort.

## Troubleshooting

### QR não abre no celular

- Verifique PUBLIC_BASE_URL em js/config.js.
- Evite localhost na geração de QR para uso externo.

### Erro de OAuth Google

- Confira GOOGLE_OAUTH_CLIENT_ID, GOOGLE_OAUTH_CLIENT_SECRET e GOOGLE_OAUTH_REDIRECT_URI.
- Verifique se redirect URI do Google Cloud é idêntico ao usado pela aplicação.
- Confirme sessão válida do professor no Supabase.

### Presença falha por permissão

- Verifique se as políticas RLS foram aplicadas.
- Em banco legado, confirme execução das migrações listadas.
- Confira se o aluno está vinculado à turma (ou se auto_vincular_aluno_turma está disponível).

### Sincronização não acontece

- Verifique se a turma possui integração ativa em integracao_planilhas_turma.
- Confirme OAuth conectado para o professor dono da integração.
- Consulte logs da Edge Function google-sheets-sync.

## Melhorias E Novas Funcionalidades (Roadmap)

### Prioridade alta (curto prazo)

1. Idempotência de sincronização no Google Sheets.
2. Testes automatizados de RPCs críticas e fluxos de presença.
3. Auditoria de segurança: revisar permissões permissivas (ex.: leitura ampla de perfis/turmas).
4. Painel de saúde da integração (último sync, erros por turma, tentativas).
5. Rate limiting para geração de QR e tentativas de marcação.

### Prioridade média

1. Notificações push/web para início de aula e confirmação de presença.
2. Registro de presença por beacon/BLE como alternativa ao GPS indoor.
3. Controle de justificativa de falta com anexo e aprovação do professor.
4. Exportação avançada (XLSX/PDF) com filtros salvos.
5. Paginação e virtualização na tabela de presenças para grande volume.

### Prioridade estratégica

1. Multiinstituição (tenant por escola/unidade).
2. App mobile nativo/híbrido com melhor captura de localização em segundo plano.
3. Motor antifraude com score de risco (distância, horário, padrão de dispositivo).
4. Dashboard executivo com métricas de frequência por período, disciplina e turma.
5. Integrações adicionais (Google Classroom, Microsoft 365, LMS).

## Boas Práticas Recomendadas

- Mover chaves e URLs sensíveis para variáveis de ambiente no build/deploy.
- Versionar SQL com ferramenta de migrations (Supabase CLI/DbMate/Flyway).
- Implantar pipeline CI para lint/test/build e validação de SQL.
- Criar ambiente de homologação separado do ambiente de produção.

## Licença

Uso educacional.
