#Requires -Version 7.4
[CmdletBinding()]
param(
  [string]$Destination = (Join-Path (Split-Path -Parent $PSScriptRoot) 'llama.cpp'),
  [Parameter(Mandatory)]
  [ValidateSet('Q8_K_P', 'Q6_K_P', 'Q5_K_P', 'Q4_K_P', 'IQ4_XS', 'Q3_K_P', 'IQ3_M', 'IQ3_XS', 'Q2_K_P', 'IQ2_M')]
  [string]$Quantization,
  [switch]$Vision
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

New-Item -ItemType Directory -Force $Destination | Out-Null
$modelRepo = 'https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/resolve/main'

$modelName = "Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-$Quantization.gguf"
$model = Join-Path $Destination $modelName
if (-not (Test-Path $model)) {
  curl.exe -fL --remove-on-error -o $model "$modelRepo/$modelName"
}

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

Write-Host "OK: $Quantization model and assets in $Destination"
