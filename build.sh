#!/usr/bin/env bash
# Build the SGLang+DSpark image without a Docker daemon:
# real pip-install + draft download inside the SGLang base, then crane-append the
# delta layer onto the base and push to Docker Hub. Arg $1 = Docker Hub token.
set -euo pipefail
TOKEN="$1"
BASE="lmsysorg/sglang:nightly-dev-cu12-20260713-b94ac87e"
DEST="docker.io/trivo2312/sglang-lfm2-dspark:latest"

echo "== 1. install DSpark branch (pure python) =="
pip install --no-deps --force-reinstall \
  'git+https://github.com/tugot17/sglang.git@piotr/lfm2-dspark-main#subdirectory=python'

echo "== 2. download draft head =="
python3 -c 'from huggingface_hub import snapshot_download; snapshot_download("tugot17/LFM2.5-1.2B-Instruct-DSpark-5L", local_dir="/tmp/draft-model")'

echo "== 3. locate active sglang + verify branch =="
SG=$(python3 -c 'import sglang,os;print(os.path.dirname(sglang.__file__))')
echo "SGLANG_DIR=$SG"
test -f "$SG/srt/models/lfm2_dspark.py"   # fail if branch not active

echo "== 4. build delta layer (branch sglang at its abs path + /draft-model) =="
tar -czf /tmp/layer.tgz -C / "${SG#/}" -C /tmp draft-model
ls -la /tmp/layer.tgz

echo "== 5. fetch crane =="
python3 -c 'import urllib.request,tarfile; urllib.request.urlretrieve("https://github.com/google/go-containerregistry/releases/download/v0.20.2/go-containerregistry_Linux_x86_64.tar.gz","/tmp/gcr.tgz"); tarfile.open("/tmp/gcr.tgz").extract("crane","/tmp")'
chmod +x /tmp/crane

echo "== 6. login + append base + push =="
/tmp/crane auth login docker.io -u trivo2312 -p "$TOKEN"
AMD=$(/tmp/crane digest --platform linux/amd64 "$BASE")
echo "BASE_DIGEST=$AMD"
/tmp/crane append -b "lmsysorg/sglang@$AMD" -f /tmp/layer.tgz -t "$DEST"
echo "BUILD_PUSH_DONE $DEST"
