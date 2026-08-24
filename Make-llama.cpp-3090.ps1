#Requires -Version 7.4
[CmdletBinding()]
param(
  [string]$WorkspaceRoot = (Split-Path -Parent $PSScriptRoot),
  [string]$CudaArchitecture = '86'
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$llamaRoot = Join-Path $WorkspaceRoot 'llama.cpp'
$build = Join-Path $llamaRoot 'build'
$patch = Join-Path $llamaRoot 'HauhauCS-FastMTP-llama.cpp.patch'

New-Item -ItemType Directory -Force $WorkspaceRoot | Out-Null
git clone https://github.com/ggerganov/llama.cpp $llamaRoot
git -C $llamaRoot checkout 4df29be4f4c3673f428170fda944a5b19f743bb8

curl.exe -fL -o $patch `
  https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/resolve/main/HauhauCS-FastMTP-llama.cpp.patch
git -C $llamaRoot apply $patch

# Just for re-building remove previous build first
# Remove-Item -Recurse -Force $build -ErrorAction SilentlyContinue

cmake -S $llamaRoot -B $build `
  -DCMAKE_BUILD_TYPE=Release `
  -DGGML_CUDA=ON `
  -DGGML_CUDA_FA_ALL_QUANTS=ON `
  "-DCMAKE_CUDA_ARCHITECTURES=$CudaArchitecture" `
  -DLLAMA_BUILD_EXAMPLES=OFF `
  -DLLAMA_BUILD_TESTS=OFF

cmake --build $build --config Release --target llama-server --parallel
Write-Host "OK: $(Resolve-Path (Join-Path $build 'bin\Release\llama-server.exe'))"
