#!/usr/bin/env bash
# Install (clone, patch, build) the FastMTP-patched llama.cpp.
# CUDA on Linux/Windows; Metal (automatic) on Apple Silicon.
set -euo pipefail

usage() {
  echo "Usage: $0 -a <cuda-architectures> [-w <workspace-root>]" >&2
  echo "-a is required on CUDA platforms, ignored on macOS (Metal is used instead)." >&2
  exit 2
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pinned_commit="$(tr -d '[:space:]' < "$script_dir/PINNED_LLAMA_COMMIT")"

workspace_root="$(dirname "$script_dir")"
arch=""

while getopts "a:w:h" opt; do
  case "$opt" in
    a) arch="$OPTARG" ;;
    w) workspace_root="$OPTARG" ;;
    *) usage ;;
  esac
done

os="$(uname)"

missing_tools=""
if [[ "$os" == "Darwin" ]]; then
  command -v cmake >/dev/null 2>&1 || missing_tools+="
CMake was not found on PATH.
Install it with:
  brew install cmake
"
else
  [[ -n "$arch" ]] || usage
  command -v cmake >/dev/null 2>&1 || missing_tools+="
CMake was not found on PATH.
Install it with your package manager, e.g.:
  sudo apt install cmake        # Debian/Ubuntu
  sudo dnf install cmake        # Fedora/RHEL
"
  command -v nvcc >/dev/null 2>&1 || missing_tools+="
NVIDIA CUDA compiler (nvcc) was not found on PATH.
The display driver alone is not enough. Install the CUDA Toolkit:
  https://developer.nvidia.com/cuda-downloads
Then verify:
  nvcc --version
If CUDA is already installed, add its bin directory
(/usr/local/cuda/bin) to PATH.
"
fi

if [[ -n "$missing_tools" ]]; then
  echo "Cannot install llama.cpp until build prerequisites are available:" >&2
  echo "$missing_tools" >&2
  exit 1
fi

llama_root="$workspace_root/llama.cpp"
build_dir="$llama_root/build"
patch_file="$llama_root/HauhauCS-FastMTP-llama.cpp.patch"
patch_url="https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/resolve/main/HauhauCS-FastMTP-llama.cpp.patch"

mkdir -p "$workspace_root"
git clone https://github.com/ggerganov/llama.cpp "$llama_root"
git -C "$llama_root" checkout "$pinned_commit"

curl -fL -o "$patch_file" "$patch_url"
git -C "$llama_root" apply "$patch_file"

# Just for re-building remove previous build first
# rm -rf "$build_dir"

cmake_args=(
  -S "$llama_root"
  -B "$build_dir"
  -DCMAKE_BUILD_TYPE=Release
  -DLLAMA_BUILD_EXAMPLES=OFF
  -DLLAMA_BUILD_TESTS=OFF
)
if [[ "$os" != "Darwin" ]]; then
  cmake_args+=(
    -DGGML_CUDA=ON
    -DGGML_CUDA_FA_ALL_QUANTS=ON
    "-DCMAKE_CUDA_ARCHITECTURES=$arch"
  )
fi
# macOS: GGML_METAL defaults to ON; nothing extra required.

cmake "${cmake_args[@]}"

cmake --build "$build_dir" --config Release --target llama-server --parallel

echo "OK: $(readlink -f "$build_dir/bin/llama-server")"
