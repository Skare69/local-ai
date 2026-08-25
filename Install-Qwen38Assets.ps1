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

function Get-ExpectedSha256 {
  param([string]$SumsContent, [string]$FileName)
  foreach ($line in ($SumsContent -split "`n")) {
    $parts = $line.Trim() -split '\s+', 2
    if ($parts.Count -eq 2 -and $parts[1].Trim('*') -eq $FileName) { return $parts[0].ToLower() }
  }
  return $null
}

function Assert-Sha256 {
  param([string]$FilePath, [string]$SumsContent)
  $fileName = Split-Path $FilePath -Leaf
  $expected = Get-ExpectedSha256 $SumsContent $fileName
  if (-not $expected) { throw "No checksum found for $fileName in SHA256SUMS" }
  $actual = (Get-FileHash -Algorithm SHA256 $FilePath).Hash.ToLower()
  if ($actual -ne $expected) {
    throw "Checksum mismatch for ${fileName}: expected $expected, got $actual"
  }
}

$modelName = "Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-$Quantization.gguf"
$targets = @(
  @{ Url = "$modelRepo/$modelName"; Path = Join-Path $Destination $modelName },
  @{ Url = 'https://huggingface.co/froggeric/Qwen-Fixed-Chat-Templates/resolve/main/chat_template.jinja'; Path = Join-Path $Destination 'chat_template.jinja' },
  @{ Url = "$modelRepo/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-FastMTP-32K.gguf"; Path = Join-Path $Destination 'Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-FastMTP-32K.gguf' }
)
if ($Vision) {
  $targets += @{ Url = "$modelRepo/mmproj-Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-BF16.gguf"; Path = Join-Path $Destination 'mmproj-Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-BF16.gguf' }
}

foreach ($target in $targets) {
  if (-not (Test-Path $target.Path)) {
    curl.exe -fL --remove-on-error -o $target.Path $target.Url
  }
}

# Verify every GGUF against the upstream SHA256SUMS manifest (template excluded:
# froggeric publishes no checksums).
$sumsFile = Join-Path ([IO.Path]::GetTempPath()) 'qwen38-aggressive-SHA256SUMS'
curl.exe -fsL -o $sumsFile "$modelRepo/SHA256SUMS"
$sums = Get-Content $sumsFile -Raw
foreach ($target in $targets | Where-Object { $_.Path -like '*.gguf' }) {
  Assert-Sha256 -FilePath $target.Path -SumsContent $sums
}

Write-Host "OK: $Quantization model and assets verified in $Destination"
