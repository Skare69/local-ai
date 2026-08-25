#!/usr/bin/env bash
# Download a Qwen3.8 target quant plus chat template, FastMTP sidecar, and
# optional vision projector. Existing files are left untouched.
set -euo pipefail

usage() {
  echo "Usage: $0 -q <quantization> [-d <llama.cpp-dir>] [-v]" >&2
  echo "Quantizations: Q8_K_P Q6_K_P Q5_K_P Q4_K_P IQ4_XS Q3_K_P IQ3_M IQ3_XS Q2_K_P IQ2_M" >&2
  exit 2
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
destination="$(dirname "$script_dir")/llama.cpp"
quantization=""
vision=0

while getopts "q:d:v" opt; do
  case "$opt" in
    q) quantization="$OPTARG" ;;
    d) destination="$OPTARG" ;;
    v) vision=1 ;;
    *) usage ;;
  esac
done
[[ -n "$quantization" ]] || usage

case "$quantization" in
  Q8_K_P|Q6_K_P|Q5_K_P|Q4_K_P|IQ4_XS|Q3_K_P|IQ3_M|IQ3_XS|Q2_K_P|IQ2_M) ;;
  *) echo "Invalid quantization: $quantization" >&2; usage ;;
esac

mkdir -p "$destination"
model_repo="https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/resolve/main"

download() {
  local url="$1" out="$2"
  [[ -e "$out" ]] && return 0
  curl -fL --remove-on-error -o "$out" "$url"
}

model_name="Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-$quantization.gguf"
download "$model_repo/$model_name" "$destination/$model_name"

download "https://huggingface.co/froggeric/Qwen-Fixed-Chat-Templates/resolve/main/chat_template.jinja" \
  "$destination/chat_template.jinja"

download "$model_repo/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-FastMTP-32K.gguf" \
  "$destination/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-FastMTP-32K.gguf"

if [[ "$vision" -eq 1 ]]; then
  download "$model_repo/mmproj-Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-BF16.gguf" \
    "$destination/mmproj-Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-BF16.gguf"
fi

echo "OK: $quantization model and assets in $destination"
