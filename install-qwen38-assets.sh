#!/usr/bin/env bash
# Download a Qwen3.8 target quant plus chat template, FastMTP sidecar, and
# optional vision projector. Existing files are left untouched but verified.
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

model_name="Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-$quantization.gguf"
targets=(
  "$model_repo/$model_name|$destination/$model_name"
  "https://huggingface.co/froggeric/Qwen-Fixed-Chat-Templates/resolve/main/chat_template.jinja|$destination/chat_template.jinja"
  "$model_repo/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-FastMTP-32K.gguf|$destination/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-FastMTP-32K.gguf"
)
if [[ "$vision" -eq 1 ]]; then
  targets+=("$model_repo/mmproj-Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-BF16.gguf|$destination/mmproj-Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-BF16.gguf")
fi

for target in "${targets[@]}"; do
  url="${target%%|*}"
  out="${target#*|}"
  [[ -e "$out" ]] || curl -fL --remove-on-error -o "$out" "$url"
done

# Verify every GGUF against the upstream SHA256SUMS manifest (template excluded:
# froggeric publishes no checksums).
sums_file="$(mktemp)"
trap 'rm -f "$sums_file"' EXIT
curl -fsL -o "$sums_file" "$model_repo/SHA256SUMS"

for target in "${targets[@]}"; do
  out="${target#*|}"
  case "$out" in
    *.gguf) ;;
    *) continue ;;
  esac
  file_name="$(basename "$out")"
  expected="$(awk -v name="$file_name" '{ if ($2 == name || $2 == "*" name) print $1 }' "$sums_file")"
  if [[ -z "$expected" ]]; then
    echo "No checksum found for $file_name in SHA256SUMS" >&2
    exit 1
  fi
  actual="$(sha256sum "$out" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    echo "Checksum mismatch for ${file_name}: expected $expected, got $actual" >&2
    exit 1
  fi
done

echo "OK: $quantization model and assets verified in $destination"
