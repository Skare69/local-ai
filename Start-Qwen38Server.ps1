#Requires -Version 7.4
[CmdletBinding()]
param(
  [string]$WorkspaceRoot = (Split-Path -Parent $PSScriptRoot),
  [Parameter(Mandatory)]
  [ValidateSet('Q8_K_P', 'Q6_K_P', 'Q5_K_P', 'Q4_K_P', 'IQ4_XS', 'Q3_K_P', 'IQ3_M', 'IQ3_XS', 'Q2_K_P', 'IQ2_M')]
  [string]$Quantization,
  [Parameter(Mandatory)]
  [ValidateRange(1, 262144)]
  [int]$ContextSize
)

$ErrorActionPreference = 'Stop'

$model = ".\Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-$Quantization.gguf"

Push-Location (Join-Path $WorkspaceRoot 'llama.cpp')
try {
  & .\build\bin\Release\llama-server.exe `
  --model $model `
  --spec-draft-model .\Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-FastMTP-32K.gguf `
  --spec-draft-ngl all `
  --spec-type draft-mtp `
  --spec-draft-n-max 3 `
  --spec-draft-p-min 0 `
  --mmproj .\mmproj-Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-BF16.gguf `
  --ctx-size $ContextSize `
  --flash-attn on `
  --cache-type-k q4_0 `
  --cache-type-v q4_0 `
  --cache-type-k-draft q8_0 `
  --cache-type-v-draft q8_0 `
  --n-gpu-layers all `
  --split-mode none `
  --batch-size 2048 `
  --ubatch-size 512 `
  --load-mode none `
  --temp 1.0 `
  --top-k 20 `
  --top-p 0.95 `
  --min-p 0 `
  --presence-penalty 0 `
  --repeat-penalty 1.0 `
  --jinja `
  --chat-template-file .\chat_template.jinja `
  --reasoning on `
  --reasoning-effort normal `
  --reasoning-preserve `
  --reasoning-format deepseek `
  --image-min-tokens 1024 `
  --parallel 1 `
  --host 127.0.0.1 `
  --port 8080 `
  --alias "qwen3.8-27b"
} finally {
  Pop-Location
}

#  --ctx-size 65536 `
