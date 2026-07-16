$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)
Write-Host "=== Contenedores ==="
docker compose ps
Write-Host "`n=== API pública ==="
try {
  Invoke-RestMethod http://localhost:8080/api/v1/public/health | ConvertTo-Json
} catch {
  Write-Warning "La API todavía no responde: $($_.Exception.Message)"
}
