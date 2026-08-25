# local-ai

PowerShell 7 scripts (Windows host) for building a CUDA-enabled,
FastMTP-patched [llama.cpp](https://github.com/ggml-org/llama.cpp) and serving
the HauhauCS Qwen3.8 27B Aggressive GGUF release. Linux and macOS users can
run the same steps with the shell equivalents in each section.

## Requirements

- Windows host for the checked-in PowerShell scripts
- Git, CMake (`cmake`), and CUDA compiler (`nvcc`) available on `PATH`
- C++ build tools: MSVC on Windows; `build-essential` (apt), Development Tools
  (dnf), or Xcode Command Line Tools (macOS)
- NVIDIA driver compatible with the target GPU; CUDA Toolkit provides `nvcc`

Linux and macOS equivalents use bash; run them from this repository's parent
directory so `<workspace>/local-ai` and `<workspace>/llama.cpp` are siblings.

### Install CMake and CUDA Toolkit

Windows: install with winget:

```powershell
winget install --exact --id Kitware.CMake --source winget
winget install --exact --id Nvidia.CUDA --source winget
```

Alternatively, download the CUDA Toolkit from
[NVIDIA CUDA Downloads](https://developer.nvidia.com/cuda-downloads).

If CMake is unavailable through winget, use Scoop:

```powershell
scoop install cmake
```

The NVIDIA display driver does not include `nvcc`; the CUDA Toolkit is required.
After installation, open a new PowerShell window and verify:

```powershell
cmake --version
nvcc --version
```

Linux (Debian/Ubuntu):

```bash
sudo apt install -y cmake nvidia-cuda-toolkit build-essential
```

Fedora/RHEL:

```bash
sudo dnf install -y cuda-gcc cmake && sudo dnf module install -y nvidia-driver
```

NVIDIA's official repositories provide current CUDA packages for both distros;
follow [NVIDIA CUDA Downloads](https://developer.nvidia.com/cuda-downloads) if
distribution packages lag behind.

macOS has no CUDA support; NVIDIA GPUs stopped being supported there after
High Sierra. Skip this repository's CUDA path on Apple hardware.


## 1. Install llama.cpp

```powershell
.\Install-LlamaCpp.ps1 -CudaArchitecture native
```

By default, `llama.cpp` is cloned beside this repository. Pass
`-WorkspaceRoot <workspace-root>` when both repositories should live elsewhere.

The script pins llama.cpp to `4df29be4f4c3673f428170fda944a5b19f743bb8`,
applies the
[HauhauCS FastMTP patch](https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/resolve/main/HauhauCS-FastMTP-llama.cpp.patch),
and builds `llama-server`.

If draft loading reports `expected 5120, 248320, got 5120, 32768`, the sidecar
is correct but the server binary is unpatched. Use the binary produced by this
checkout.

Linux and macOS equivalent:

```bash
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
git checkout 4df29be4f4c3673f428170fda944a5b19f743bb8
curl -fL -o HauhauCS-FastMTP-llama.cpp.patch \
  https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/resolve/main/HauhauCS-FastMTP-llama.cpp.patch
git apply HauhauCS-FastMTP-llama.cpp.patch
cmake -S . -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_CUDA=ON \
  -DGGML_CUDA_FA_ALL_QUANTS=ON \
  -DCMAKE_CUDA_ARCHITECTURES=native \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_TESTS=OFF
cmake --build build --config Release --target llama-server --parallel
```

### CUDA architectures

`native` is simplest when compiling on the target GPU with CMake 3.24+.
For cross-compilation or a multi-GPU binary, pass an explicit value from the
[NVIDIA compute-capability list](https://developer.nvidia.com/cuda-gpus):

| Value | Architecture | Example GPUs |
|---:|---|---|
| 61 | Pascal | GTX 10 series |
| 70 | Volta | V100 |
| 75 | Turing | RTX 20 and GTX 16 series |
| 80 | Ampere datacenter | A100 |
| 86 | Ampere consumer/workstation | RTX 30 and RTX A series |
| 89 | Ada Lovelace | RTX 40 and RTX Ada workstation series |
| 90 | Hopper | H100/H200 |
| 100 | Blackwell datacenter | B100/B200/GB200 |
| 120 | Blackwell consumer/workstation | RTX 50 and RTX PRO Blackwell series |

Examples:

```powershell
.\Install-LlamaCpp.ps1 -CudaArchitecture 89
.\Install-LlamaCpp.ps1 -CudaArchitecture "86;89"
```

Blackwell `120` requires CUDA 12.8+. A wrong value can fail at runtime with
`no kernel image is available for execution on the device`.

## 2. Install model and support assets

Model repository:
[HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF](https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF)

Choose one quantization:

| `-Quantization` | File size |
|---|---:|
| `IQ2_M` | 10.32 GB |
| `Q2_K_P` | 10.68 GB |
| `IQ3_XS` | 12.18 GB |
| `IQ3_M` | 12.79 GB |
| `Q3_K_P` | 13.44 GB |
| `IQ4_XS` | 15.71 GB |
| `Q4_K_P` | 17.92 GB |
| `Q5_K_P` | 20.22 GB |
| `Q6_K_P` | 25.92 GB |
| `Q8_K_P` | 31.46 GB |

The installer downloads the selected target model, fixed chat template, and
FastMTP sidecar. Existing files are left untouched:

```powershell
.\Install-Qwen38Assets.ps1 -Quantization Q4_K_P
```

Add the optional vision projector:

```powershell
.\Install-Qwen38Assets.ps1 -Quantization Q4_K_P -Vision
```

Linux and macOS equivalent:

```bash
curl -fL --remove-on-error -O \
  "https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/resolve/main/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-Q4_K_P.gguf"
curl -fL --remove-on-error -o chat_template.jinja \
  https://huggingface.co/froggeric/Qwen-Fixed-Chat-Templates/resolve/main/chat_template.jinja
curl -fL --remove-on-error -O \
  "https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/resolve/main/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-FastMTP-32K.gguf"
# Optional vision projector:
curl -fL --remove-on-error -O \
  "https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/resolve/main/mmproj-Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-BF16.gguf"
```

The default destination is the sibling `llama.cpp` checkout. Pass
`-Destination <llama.cpp-path>` to use another checkout.

- One FastMTP sidecar works with every target quant.
- FastMTP sidecar SHA-256:
  `115e618e1f73cb50817ed5856f0551c6bf9c3d94df96f440eaca78dc63b8968b`
- The vision projector is needed only for image or video input.

## 3. Chat template

Source:
[froggeric/Qwen-Fixed-Chat-Templates](https://huggingface.co/froggeric/Qwen-Fixed-Chat-Templates)

The drop-in `chat_template.jinja` fixes Qwen 3.5/3.6/3.8 template failures,
including `enable_thinking=false`, empty-think poisoning, serialized tool
arguments, and KV-cache invalidation.

Use it with:

```text
--jinja --chat-template-file chat_template.jinja --reasoning-format deepseek
```

The DeepSeek reasoning format places `<think>` output in `reasoning_content`
instead of mixing it into answer text.

## 4. Start the server

Pass the same quantization selected during installation and a context size that
fits available VRAM. Valid context range is `1..262144`:

```powershell
.\Start-Qwen38Server.ps1 -Quantization Q4_K_P -ContextSize 32768
```

Linux and macOS equivalent (same flags; binary lives in `build/bin/`):

```bash
./build/bin/llama-server \
  --model ./Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-Q4_K_P.gguf \
  --spec-draft-model ./Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-FastMTP-32K.gguf \
  --spec-draft-ngl all --spec-type draft-mtp --spec-draft-n-max 3 --spec-draft-p-min 0 \
  --mmproj ./mmproj-Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-BF16.gguf \
  --ctx-size 32768 \
  --flash-attn on --cache-type-k q4_0 --cache-type-v q4_0 \
  --cache-type-k-draft q8_0 --cache-type-v-draft q8_0 \
  --n-gpu-layers all --split-mode none --batch-size 2048 --ubatch-size 512 \
  --temp 1.0 --top-k 20 --top-p 0.95 --min-p 0 --presence-penalty 0 --repeat-penalty 1.0 \
  --jinja --chat-template-file ./chat_template.jinja \
  --reasoning on --reasoning-effort normal --reasoning-preserve --reasoning-format deepseek \
  --image-min-tokens 1024 --parallel 1 --host 127.0.0.1 --port 8080 \
  --alias "qwen3.8-27b"
```

The launcher also expects the FastMTP sidecar, chat template, and vision
projector.

Pass `-WorkspaceRoot <workspace-root>` when `llama.cpp` is not beside this
repository.

Server defaults:

- OpenAI-compatible endpoint: `http://127.0.0.1:8080`
- Model alias: `qwen3.8-27b`
- Official thinking sampler: temperature `1.0`, top-k `20`, top-p `0.95`,
  min-p `0`, presence penalty `0`, repeat penalty `1.0`
- Context and KV-cache memory grow with `-ContextSize`; use the smallest value
  the workload needs
- Disable thinking with
  `--chat-template-kwargs '{"enable_thinking":false}'`

## License

Scripts and documentation authored in this repository are available under the
[MIT License](LICENSE).

Downloaded and upstream components retain their own licenses:

- llama.cpp: MIT
- HauhauCS model and FastMTP patch: Apache-2.0
- froggeric Qwen chat template: Apache-2.0
