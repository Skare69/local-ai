#Requires -Version 7.4
[CmdletBinding()]
param(
  [string]$WorkspaceRoot = (Split-Path -Parent $PSScriptRoot),
  [Parameter(Mandatory)]
  [string]$CudaArchitecture
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$pinnedCommit = (Get-Content (Join-Path $PSScriptRoot 'PINNED_LLAMA_COMMIT') -Raw).Trim()

$missingTools = @()

if (-not (Get-Command cmake -CommandType Application -ErrorAction SilentlyContinue)) {
  $missingTools += @'
CMake was not found on PATH.
Install with winget:
  winget install --exact --id Kitware.CMake --source winget
Or with Scoop:
  scoop install cmake
Then open a new PowerShell window and verify:
  cmake --version
'@
}

if (-not (Get-Command nvcc -CommandType Application -ErrorAction SilentlyContinue)) {
  $missingTools += @'
NVIDIA CUDA compiler (nvcc) was not found on PATH.
The display driver alone is not enough. Install the CUDA Toolkit with:
  winget install --exact --id Nvidia.CUDA --source winget
Or download it from NVIDIA:
  https://developer.nvidia.com/cuda-downloads
Then open a new PowerShell window and verify:
  nvcc --version
If CUDA is already installed, add its bin directory
(C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v<version>\bin) to PATH.
'@
}

if ($missingTools) {
  throw "Cannot install llama.cpp until build prerequisites are available:`n`n$($missingTools -join "`n`n")"
}

$llamaRoot = Join-Path $WorkspaceRoot 'llama.cpp'
$build = Join-Path $llamaRoot 'build'
$patch = Join-Path $llamaRoot 'HauhauCS-FastMTP-llama.cpp.patch'

New-Item -ItemType Directory -Force $WorkspaceRoot | Out-Null
git clone https://github.com/ggerganov/llama.cpp $llamaRoot
git -C $llamaRoot checkout $pinnedCommit

curl.exe -fL -o $patch `
  https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/resolve/main/HauhauCS-FastMTP-llama.cpp.patch
git -C $llamaRoot apply $patch

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
