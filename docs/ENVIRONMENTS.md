# Ambientes

## Produção

- Injete `window.__APP_CONFIG__` antes de carregar `js/config.js`.
- Use projeto Supabase dedicado.
- Use domínio público real em `PUBLIC_BASE_URL`.

## Homologação

- Mantenha projeto Supabase separado de produção.
- Use OAuth Google com redirect URI próprio de homologação.
- Execute primeiro os testes SQL em `database/tests/`.
- Aponte `PUBLIC_BASE_URL` para a URL de preview/staging.

## Arquivo de exemplo

- Use `js/config.runtime.example.js` como base.
- No deploy, publique uma cópia como `js/config.runtime.js` ou injete via template HTML/CDN.