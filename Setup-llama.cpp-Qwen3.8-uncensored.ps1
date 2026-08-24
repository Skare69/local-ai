#Requires -Version 7.4
[CmdletBinding()]
param(
  [string]$Destination = (Join-Path (Split-Path -Parent $PSScriptRoot) 'llama.cpp'),
  [switch]$Vision
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

New-Item -ItemType Directory -Force $Destination | Out-Null
$modelRepo = 'https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/resolve/main'

$template = Join-Path $Destination 'chat_template.jinja'
if (-not (Test-Path $template)) {
  curl.exe -fL --remove-on-error -o $template `
    https://huggingface.co/froggeric/Qwen-Fixed-Chat-Templates/resolve/main/chat_template.jinja
}

$fastMtp = Join-Path $Destination 'Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-FastMTP-32K.gguf'
if (-not (Test-Path $fastMtp)) {
  curl.exe -fL --remove-on-error -o $fastMtp "$modelRepo/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-FastMTP-32K.gguf"
}

$projector = Join-Path $Destination 'mmproj-Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-BF16.gguf'
if ($Vision -and -not (Test-Path $projector)) {
  curl.exe -fL --remove-on-error -o $projector "$modelRepo/mmproj-Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-BF16.gguf"
}

Write-Host "OK: assets in $Destination"
