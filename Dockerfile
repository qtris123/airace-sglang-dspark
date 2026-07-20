# LFM2.5-1.2B DSpark speculative-decoding image for Viettel AI Race Round 2.
# Base = SGLang nightly with merged base DSpark (#30261); adds LFM2 DSpark
# support (PR #31041, pure-Python) and bakes the draft head so nothing is
# downloaded at grading time.
FROM lmsysorg/sglang:nightly-dev-cu12-20260713-b94ac87e

# LFM2/LFM2-MoE DSpark target support (unmerged PR #31041 branch), pure Python.
RUN pip install --no-deps --force-reinstall \
    "git+https://github.com/tugot17/sglang.git@piotr/lfm2-dspark-main#subdirectory=python"

# Bake the DSpark draft head (~0.3B) so no runtime HF download is needed.
RUN python3 -c "from huggingface_hub import snapshot_download; snapshot_download('tugot17/LFM2.5-1.2B-Instruct-DSpark-5L', local_dir='/draft-model')" \
 && rm -rf /root/.cache/huggingface

LABEL org.opencontainers.image.description="SGLang + DSpark spec-decode for LFM2.5-1.2B-Instruct (Viettel AI Race R2)"
