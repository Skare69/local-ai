# local-ai

Scripts for building a CUDA-enabled, FastMTP-patched
[llama.cpp](https://github.com/ggml-org/llama.cpp) and serving the HauhauCS
Qwen3.8 27B Aggressive GGUF release.

- **Windows**: PowerShell 7.4+ scripts (`*.ps1`)
- **Linux / macOS**: bash scripts (`*.sh`); macOS has no CUDA support, so only
  CPU builds are possible there

Both sets do the same thing: clone llama.cpp beside this repository, pin it,
apply the patch, build `llama-server`, download model assets, and start the
server on `http://127.0.0.1:8080`.

## Prerequisites (all platforms)

- Git
- CMake (`cmake`) and CUDA compiler (`nvcc`) on `PATH`
- C++ build tools and an NVIDIA driver compatible with the target GPU

### Install build tools

**Windows** (winget; Scoop fallback for CMake):

```powershell
winget install --exact --id Kitware.CMake --source winget
winget install --exact --id Nvidia.CUDA --source winget
scoop install cmake   # if winget cannot install Kitware.CMake
```

CUDA Toolkit alternative:
[NVIDIA CUDA Downloads](https://developer.nvidia.com/cuda-downloads).

**Debian/Ubuntu:**

```bash
sudo apt install -y cmake nvidia-cuda-toolkit build-essential
```

**Fedora/RHEL:** use NVIDIA's CUDA repository from
[NVIDIA CUDA Downloads](https://developer.nvidia.com/cuda-downloads);
distribution packages often lag behind.

The display driver alone never includes `nvcc`. After installing, verify in a
new shell:

```bash
cmake --version
nvcc --version
```

## 1. Install llama.cpp

The scripts pin llama.cpp to `4df29be4f4c3673f428170fda944a5b19f743bb8`, apply
the [HauhauCS FastMTP patch](https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/resolve/main/HauhauCS-FastMTP-llama.cpp.patch)
(draft-vocab trim in `src/models/qwen35.cpp`), and build `llama-server`.
By default the checkout lands beside this repository; override per script flag
below. If draft loading reports `expected 5120, 248320, got 5120, 32768`,
the sidecar is fine but you ran an unpatched binary.

### Windows

```powershell
.\Install-LlamaCpp.ps1 -CudaArchitecture native          # or e.g. 89, "86;89"
# different workspace: -WorkspaceRoot D:\projects
```

### Linux / macOS

macOS: omit `-DGGML_CUDA=ON` below for a CPU-only build.

```bash
./install-llamacpp.sh -a native                          # or e.g. -a 89, -a "86;89"
# different workspace: -w /path/to/workspace
```

### CUDA architectures

`native` is simplest when compiling on the target GPU with CMake 3.24+;
otherwise pass explicit values from the
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

Blackwell `120` requires CUDA 12.8+. A wrong value fails at runtime with
`no kernel image is available for execution on the device`.

## 2. Install model and support assets

Model repository:
[HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF](https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF)

Choose one quantization:

| Quantization | File size |
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

Downloads the target model, fixed chat template, and FastMTP sidecar;
existing files are left untouched. Add vision with `-Vision` / `-v`.

### Windows

```powershell
.\Install-Qwen38Assets.ps1 -Quantization Q4_K_P [-Vision] [-Destination <llama.cpp-path>]
```

### Linux / macOS

```bash
./install-qwen38-assets.sh -q Q4_K_P [-v] [-d /path/to/llama.cpp]
```

- One FastMTP sidecar works with every target quant.
- Sidecar SHA-256:
  `115e618e1f73cb50817ed5856f0551c6bf9c3d94df96f440eaca78dc63b8968b`

## 3. Chat template

Source:
[froggeric/Qwen-Fixed-Chat-Templates](https://huggingface.co/froggeric/Qwen-Fixed-Chat-Templates).

The drop-in `chat_template.jinja` fixes Qwen 3.5/3.6/3.8 failures:
`enable_thinking=false`, empty-think poisoning, serialized tool arguments,
KV-cache invalidation. Used via:

```text
--jinja --chat-template-file chat_template.jinja --reasoning-format deepseek
```

## 4. Start the server

Pass the same quantization as installed plus a context size that fits VRAM
(valid range `1..262144`). Both launchers expect sidecar, template, and
projector in the checkout; endpoint `http://127.0.0.1:8080`, alias
`qwen3.8-27b`, official thinking sampler.

### Windows

```powershell
.\Start-Qwen38Server.ps1 -Quantization Q4_K_P -ContextSize 32768 [-WorkspaceRoot <workspace-root>]
```

### Linux / macOS

```bash
./start-qwen38-server.sh -q Q4_K_P -c 32768 [-w /path/to/workspace]
```

Disable thinking for all requests:
`--chat-template-kwargs '{"enable_thinking":false}'`.

## License

Scripts and documentation authored in this repository are available under the
[MIT License](LICENSE).

Downloaded and upstream components retain their own licenses:

- llama.cpp: MIT
- HauhauCS model and FastMTP patch: Apache-2.0
- froggeric Qwen chat template: Apache-2.0
