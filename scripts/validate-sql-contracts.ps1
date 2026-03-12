$ErrorActionPreference = 'Stop'

$checks = @(
  @{ Path = 'database/schema.sql'; Pattern = 'CREATE OR REPLACE FUNCTION consumir_rate_limit' },
  @{ Path = 'database/schema.sql'; Pattern = 'CREATE TABLE google_sync_logs' },
  @{ Path = 'database/schema.sql'; Pattern = 'risco_fraude_score INTEGER NOT NULL DEFAULT 0' },
  @{ Path = 'database/tests/test_rpc_contracts.sql'; Pattern = 'auto_vincular_aluno_turma' },
  @{ Path = 'database/tests/test_presence_contract.sql'; Pattern = 'google_sync_logs' }
)

foreach ($check in $checks) {
  if (-not (Test-Path $check.Path)) {
    throw "Arquivo ausente: $($check.Path)"
  }

  $match = Select-String -Path $check.Path -Pattern $check.Pattern -SimpleMatch
  if (-not $match) {
    throw "Padrão não encontrado em $($check.Path): $($check.Pattern)"
  }
}

Write-Host 'SQL contracts OK'