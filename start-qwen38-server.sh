#!/usr/bin/env bash
# Start llama-server with the Qwen3.8 Aggressive model and FastMTP sidecar.
set -euo pipefail

usage() {
  echo "Usage: $0 -q <quantization> -c <context-size> [-n <gpu-layers>] [-w <workspace-root>] [-V]" >&2
  echo "Quantizations: Q8_K_P Q6_K_P Q5_K_P Q4_K_P IQ4_XS Q3_K_P IQ3_M IQ3_XS Q2_K_P IQ2_M" >&2
  echo "GPU layers: 'all' (default) or a positive integer" >&2
  exit 2
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workspace_root="$(dirname "$script_dir")"
quantization=""
context_size=""
vision=0
ngl="all"

while getopts "q:c:w:Vn:h" opt; do
  case "$opt" in
    q) quantization="$OPTARG" ;;
    c) context_size="$OPTARG" ;;
    w) workspace_root="$OPTARG" ;;
    V) vision=1 ;;
    n) ngl="$OPTARG" ;;
    *) usage ;;
  esac
done
[[ -n "$quantization" && -n "$context_size" ]] || usage

case "$quantization" in
  Q8_K_P|Q6_K_P|Q5_K_P|Q4_K_P|IQ4_XS|Q3_K_P|IQ3_M|IQ3_XS|Q2_K_P|IQ2_M) ;;
  *) echo "Invalid quantization: $quantization" >&2; usage ;;
esac

if ! [[ "$context_size" =~ ^[0-9]+$ ]] || (( context_size < 1 || context_size > 262144 )); then
  echo "Invalid context size: $context_size (must be 1..262144)" >&2
  exit 2
fi

if [[ "$ngl" != "all" ]] && ! [[ "$ngl" =~ ^[1-9][0-9]*$ ]]; then
  echo "Invalid GPU layer count: $ngl (must be 'all' or a positive integer)" >&2
  exit 2
fi

cd "$workspace_root/llama.cpp"

server_args=(
  --model "./Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-$quantization.gguf"
  --spec-draft-model ./Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-FastMTP-32K.gguf
  --spec-draft-ngl "$ngl"
  --spec-type draft-mtp
  --spec-draft-n-max 3
  --spec-draft-p-min 0
)
if [[ "$vision" -eq 1 ]]; then
  server_args+=(--mmproj ./mmproj-Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-BF16.gguf)
fi
server_args+=(
  --ctx-size "$context_size"
  --flash-attn on
  --cache-type-k q4_0
  --cache-type-v q4_0
  --cache-type-k-draft q8_0
  --cache-type-v-draft q8_0
  --n-gpu-layers "$ngl"
  --split-mode none
  --batch-size 2048
  --ubatch-size 512
  --load-mode none
  --temp 1.0
  --top-k 20
  --top-p 0.95
  --min-p 0
  --presence-penalty 0
  --repeat-penalty 1.0
  --jinja
  --chat-template-file ./chat_template.jinja
  --reasoning on
  --reasoning-effort normal
  --reasoning-preserve
  --reasoning-format deepseek
  --image-min-tokens 1024
  --parallel 1
  --host 127.0.0.1
  --port 8080
  --alias "qwen3.8-27b"
)

exec ./build/bin/llama-server "${server_args[@]}"
