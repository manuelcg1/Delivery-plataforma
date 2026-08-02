$ErrorActionPreference = 'Stop'
$credential = 'C:\Users\Manuel\clave-cerka-notificacion\cerka-delivery-firebase-adminsdk-fbsvc-57980fd929.json'
if (-not (Test-Path -LiteralPath $credential -PathType Leaf)) {
    throw "No se encontró la credencial Firebase: $credential"
}
$env:FIREBASE_ENABLED = 'true'
$env:FIREBASE_PROJECT_ID = 'cerka-delivery'
$env:GOOGLE_APPLICATION_CREDENTIALS = $credential
Push-Location (Join-Path $PSScriptRoot '..\backend')
try {
    mvn spring-boot:run
} finally {
    Pop-Location
}
