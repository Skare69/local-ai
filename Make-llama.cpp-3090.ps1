cd C:\workspace\
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
git checkout 4df29be4f4c3673f428170fda944a5b19f743bb8

curl.exe -L -o HauhauCS-FastMTP-llama.cpp.patch `
  https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/resolve/main/HauhauCS-FastMTP-llama.cpp.patch
git apply --check HauhauCS-FastMTP-llama.cpp.patch
git apply HauhauCS-FastMTP-llama.cpp.patch

# Just for re-building remove previous build first
# Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue

cmake -B build `
  -DCMAKE_BUILD_TYPE=Release `
  -DGGML_CUDA=ON `
  -DGGML_CUDA_FA_ALL_QUANTS=ON `
  -DCMAKE_CUDA_ARCHITECTURES=86 `
  -DLLAMA_BUILD_EXAMPLES=OFF `
  -DLLAMA_BUILD_TESTS=OFF

cmake --build build --config Release --target llama-server --parallel
