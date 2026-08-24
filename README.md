# local-ai

Everything needed to rebuild my local llama.cpp setup (RTX 3090) from scratch.

## 1. Build llama.cpp

```powershell
.\Make-llama.cpp-3090.ps1
```

Clones llama.cpp pinned to `4df29be4f4c3673f428170fda944a5b19f743bb8`, applies the
[HauhauCS FastMTP patch](https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/resolve/main/HauhauCS-FastMTP-llama.cpp.patch)
(draft-vocab trim in `src/models/qwen35.cpp`), builds `llama-server` with CUDA for arch 86 (3090).

If draft loading reports `expected 5120, 248320, got 5120, 32768`: sidecar is fine, you're running an unpatched binary — use `build\bin\Release\llama-server.exe` from this checkout.

### CMAKE_CUDA_ARCHITECTURES for other hardware

The script hardcodes `-DCMAKE_CUDA_ARCHITECTURES=86`. Change it to match the target GPU
([full list](https://developer.nvidia.com/cuda-gpus)):

| Value | Architecture | Cards |
|---|---|---|
| 61 | Pascal | GTX 10xx |
| 75 | Turing | RTX 20xx, GTX 16xx |
| 80 | Ampere (datacenter) | A100 |
| 86 | Ampere (consumer) | RTX 30xx, RTX A-series workstation |
| 89 | Ada Lovelace | RTX 40xx, RTX 2000–5000 Ada laptop/workstation |
| 90 | Hopper | H100/H200 |
| 100 | Blackwell (datacenter) | B100/B200/GB200 |
| 120 | Blackwell (consumer) | RTX 50xx, RTX PRO Blackwell (needs CUDA 12.8+) |

- Work laptop RTX 3500 Ada → `89`.
- Multiple targets in one binary: semicolon list, e.g. `-DCMAKE_CUDA_ARCHITECTURES="86;89"` (PowerShell: quote it).
- Wrong value fails at runtime with `no kernel image is available for execution on the device`.

## 2. Model: Qwen3.8-27B Uncensored (HauhauCS Aggressive MTP)

https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF

Files in use (into `C:\workspace\llama.cpp\`):

```powershell
$repo = "https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/resolve/main"
curl.exe -L -O "$repo/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-Q4_K_P.gguf"          # target, 17.9 GB
curl.exe -L -O "$repo/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-FastMTP-32K.gguf"     # FastMTP draft sidecar, 903 MB
curl.exe -L -O "$repo/mmproj-Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-BF16.gguf"     # vision projector, only for image/video input
```

- One FastMTP sidecar works with every text quant; requires the patch from step 1.
- Sidecar SHA-256: `115e618e1f73cb50817ed5856f0551c6bf9c3d94df96f440eaca78dc63b8968b`
- Sampler (thinking mode, official): `temp 1.0, top-p 0.95, top-k 20, min-p 0, presence 0, repeat 1.0`

## 3. Chat template: froggeric fixed Qwen template

https://huggingface.co/froggeric/Qwen-Fixed-Chat-Templates

Drop-in `chat_template.jinja` replacing the official Qwen 3.5/3.6/3.8 template. Fixes
`enable_thinking=false` crash, empty-think poisoning, JSON-string tool-arg crashes,
KV-cache invalidation; defaults reasoning effort to `medium` instead of `xhigh`.

```powershell
curl.exe -L -O https://huggingface.co/froggeric/Qwen-Fixed-Chat-Templates/resolve/main/chat_template.jinja
```

Use with `--jinja --chat-template-file chat_template.jinja --reasoning-format deepseek`
(deepseek format moves `<think>` into `reasoning_content` so agents don't choke on raw thinking tokens).

## 4. Serve

```powershell
cd C:\workspace\llama.cpp
.\build\bin\Release\llama-server.exe `
  --model Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-Q4_K_P.gguf `
  --spec-draft-model Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-FastMTP-32K.gguf `
  --spec-draft-ngl all --spec-type draft-mtp --spec-draft-n-max 3 --spec-draft-p-min 0 `
  --ctx-size 32768 `
  --n-gpu-layers all --flash-attn on --no-mmap `
  --temp 1.0 --top-k 20 --top-p 0.95 --min-p 0 --repeat-penalty 1.0 `
  --jinja --chat-template-file chat_template.jinja `
  --reasoning on --reasoning-preserve --reasoning-format deepseek `
  --host 127.0.0.1 --port 8080
```

Notes:
- `--ctx-size`: native max is 262144, but Q4_K_P (17.9 GB) + KV must fit 24 GB on the 3090 — tune down as needed.
- Vision: add `--mmproj mmproj-Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-BF16.gguf`.
- Thinking off for all requests: `--chat-template-kwargs '{"enable_thinking":false}'` (works thanks to the froggeric template; official template crashes).
