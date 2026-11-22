# Crea la clave de firma de producción de la app y android/key.properties.
# La contraseña se pide aquí y no se muestra. Nunca sobrescribe una clave existente.
param(
  [string]$StoreFile = 'C:\secure\delivery-customer-upload.jks',
  [string]$Alias = 'delivery-customer-upload'
)
$ErrorActionPreference = 'Stop'
$keytool = 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe'
if (-not (Test-Path -LiteralPath $keytool)) { $keytool = 'keytool' }
$properties = Join-Path $PSScriptRoot '..\android\key.properties'

if (Test-Path -LiteralPath $StoreFile) { throw "Ya existe $StoreFile. No se sobrescribe: usa esa clave o elige otra ruta." }
if (Test-Path -LiteralPath $properties) { throw "Ya existe android\key.properties. Revísalo antes de continuar." }
New-Item -ItemType Directory -Force (Split-Path -Parent $StoreFile) | Out-Null

function Read-Secret([string]$prompt) {
  $secure = Read-Host $prompt -AsSecureString
  $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}

Write-Host 'Usa al menos 8 caracteres, sin tildes ni la letra ñ.'
$password = Read-Secret 'Contraseña de la clave de firma'
$repeat = Read-Secret 'Repite la contraseña'
if ($password -ne $repeat) { throw 'Las contraseñas no coinciden.' }
if ($password.Length -lt 8) { throw 'La contraseña debe tener al menos 8 caracteres.' }
if ($password -match '[^\x20-\x7E]') { throw 'Usa solo letras sin tildes, números y símbolos comunes.' }

$env:CERKA_SIGNING_PASSWORD = $password
try {
  & $keytool -genkeypair -noprompt -keystore $StoreFile -alias $Alias -keyalg RSA -keysize 2048 -validity 10000 `
    -dname 'CN=Cerka, O=Cerka, C=PE' -storepass:env CERKA_SIGNING_PASSWORD -keypass:env CERKA_SIGNING_PASSWORD
  if ($LASTEXITCODE -ne 0) { throw 'keytool no pudo crear la clave.' }
} finally {
  Remove-Item Env:CERKA_SIGNING_PASSWORD -ErrorAction SilentlyContinue
}

$store = $StoreFile -replace '\\', '/'
Set-Content -LiteralPath $properties -Encoding ASCII -Value @(
  '# Generado por scripts/create-signing-key.ps1. No versionar.',
  "storeFile=$store",
  "storePassword=$password",
  "keyAlias=$Alias",
  "keyPassword=$password"
)
Write-Host ''
Write-Host "Clave creada: $StoreFile"
Write-Host 'Configuración creada: customer-app\android\key.properties'
Write-Host 'IMPORTANTE: respalda el archivo .jks y la contraseña fuera de este equipo.'
Write-Host 'Si se pierden, la app no podrá actualizarse en los celulares.'
