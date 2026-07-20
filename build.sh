#!/usr/bin/env bash
# Build SGLang+DSpark image (no Docker daemon) via crane.
# Adds a vllm.entrypoints.openai.api_server SHIM because the Viettel portal forces
# `python3 -m vllm.entrypoints.openai.api_server <flags>` — the shim re-execs sglang.
set -euo pipefail
TOKEN="$1"
BASE="lmsysorg/sglang:nightly-dev-cu12-20260713-b94ac87e"
DEST="docker.io/trivo2312/sglang-lfm2-dspark:latest"

echo "== 1. install DSpark branch =="
pip install --no-deps --force-reinstall \
  'git+https://github.com/tugot17/sglang.git@piotr/lfm2-dspark-main#subdirectory=python'

echo "== 2. download draft head =="
python3 -c 'from huggingface_hub import snapshot_download; snapshot_download("tugot17/LFM2.5-1.2B-Instruct-DSpark-5L", local_dir="/tmp/draft-model")'

echo "== 3. locate sglang + verify branch =="
SG=$(python3 -c 'import sglang,os;print(os.path.dirname(sglang.__file__))')
SP=$(dirname "$SG")
echo "SGLANG_DIR=$SG  SITE_PACKAGES=$SP"
test -f "$SG/srt/models/lfm2_dspark.py"

echo "== 4. create vllm entrypoint shim -> sglang =="
mkdir -p "$SP/vllm/entrypoints/openai"
: > "$SP/vllm/__init__.py"
: > "$SP/vllm/entrypoints/__init__.py"
: > "$SP/vllm/entrypoints/openai/__init__.py"
cat > "$SP/vllm/entrypoints/openai/api_server.py" <<'PYEOF'
# Shim: the Viettel portal forces `python3 -m vllm.entrypoints.openai.api_server`.
# Re-exec SGLang's server with the same flags so DSpark speculative decoding runs.
import sys, os
if __name__ == "__main__":
    os.execvp("python3", ["python3", "-m", "sglang.launch_server"] + sys.argv[1:])
PYEOF
python3 -c 'import vllm.entrypoints.openai.api_server as m; print("shim import ok:", m.__file__)'

echo "== 5. build delta layer (sglang + vllm shim + /draft-model) =="
tar -czf /tmp/layer.tgz -C / "${SG#/}" -C / "${SP#/}/vllm" -C /tmp draft-model
ls -la /tmp/layer.tgz

echo "== 6. fetch crane + push =="
python3 -c 'import urllib.request,tarfile; urllib.request.urlretrieve("https://github.com/google/go-containerregistry/releases/download/v0.20.2/go-containerregistry_Linux_x86_64.tar.gz","/tmp/gcr.tgz"); tarfile.open("/tmp/gcr.tgz").extract("crane","/tmp")'
chmod +x /tmp/crane
/tmp/crane auth login docker.io -u trivo2312 -p "$TOKEN"
AMD=$(/tmp/crane digest --platform linux/amd64 "$BASE")
echo "BASE_DIGEST=$AMD"
/tmp/crane append -b "lmsysorg/sglang@$AMD" -f /tmp/layer.tgz -t "$DEST"
echo "BUILD_PUSH_DONE $DEST"
