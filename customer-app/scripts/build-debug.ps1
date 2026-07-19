param(
    [string]$ApiBaseUrl = "http://10.0.2.2:8080",
    [string]$WsBaseUrl = "ws://10.0.2.2:8080"
)

$ErrorActionPreference = "Stop"

if (-not ($ApiBaseUrl.StartsWith("http://") -or $ApiBaseUrl.StartsWith("https://"))) {
    throw "ApiBaseUrl debe comenzar con http:// o https://"
}

if (-not ($WsBaseUrl.StartsWith("ws://") -or $WsBaseUrl.StartsWith("wss://"))) {
    throw "WsBaseUrl debe comenzar con ws:// o wss://"
}

flutter build apk --debug `
    --dart-define=ENVIRONMENT=development `
    --dart-define=API_BASE_URL=$ApiBaseUrl `
    --dart-define=WS_BASE_URL=$WsBaseUrl

