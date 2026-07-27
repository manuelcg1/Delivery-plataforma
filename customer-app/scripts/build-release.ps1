param(
  [ValidateSet('staging','production')][string]$Environment = 'production',
  [string]$ApiBaseUrl = 'https://api.cerka.site',
  [string]$WsBaseUrl = 'wss://api.cerka.site',
  [switch]$AppBundle
)
$ErrorActionPreference='Stop'
if(-not $ApiBaseUrl.StartsWith('https://')){throw 'API_BASE_URL debe usar HTTPS en release.'}
if(-not $WsBaseUrl.StartsWith('wss://')){throw 'WS_BASE_URL debe usar WSS en release.'}
$properties=Join-Path $PSScriptRoot '..\android\key.properties'
$usingEnvironment=$env:DELIVERY_ANDROID_STORE_FILE -and $env:DELIVERY_ANDROID_STORE_PASSWORD -and $env:DELIVERY_ANDROID_KEY_ALIAS -and $env:DELIVERY_ANDROID_KEY_PASSWORD
if(-not (Test-Path -LiteralPath $properties) -and -not $usingEnvironment){throw 'Configura android/key.properties o las cuatro variables DELIVERY_ANDROID_*.'}
$arguments=@('build',$(if($AppBundle){'appbundle'}else{'apk'}),'--release',"--dart-define=ENVIRONMENT=$Environment","--dart-define=API_BASE_URL=$ApiBaseUrl","--dart-define=WS_BASE_URL=$WsBaseUrl")
& flutter @arguments
if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
