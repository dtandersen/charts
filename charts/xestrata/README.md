# xestrata

Helm chart for deploying [XeStrata](https://github.com/MistVVK/XeStrata) with
its OpenAI-compatible API. It is built on the TrueCharts
[`common`](https://truecharts.org/common/) library chart.

XeStrata runs Qwen3.8-Flash-Next (125B MoE) on a single Intel Arc, AMD
Radeon, or NVIDIA GPU by keeping hot experts in VRAM and the full expert set
in host RAM. The chart is modeled on the `llama-intel` chart: one replica,
`Recreate` strategy, pinned to the B70 node, with node-local model storage.

## Image

Upstream publishes `.deb`/`.rpm` packages only — there is **no upstream
container image**. The image lives in the dockerfiles repo at
`xestrata/` (`Dockerfile` + `entrypoint.sh`) and is built from source on
slim Debian by the `build-xestrata` workflow (300 min timeout for the
intel/llvm + engine compile) on pushes touching that directory:

```text
ghcr.io/dtandersen/xestrata:xe0.1.43.1
```

Free (free-software-only), Intel-only build: intel/llvm DPC++ built from
source, XeStrata's own XMX kernels for the dense products (no oneMKL, no
CUDA, no ROCm). The image ships a pre-warmed source tree — engine already
compiled and `BUILD.json` stamped — so the pod's first start only downloads
the model (60–110 GB) and writes its config instead of recompiling.
Intel Level Zero userspace is pinned to the 26 series (lists Battlemage).
Text-only: the image encoders are not built, so `xestrata.vision` must stay
`"no"`. Keep the workflow `TAG`, `image.tag` here, and `appVersion` in
`Chart.yaml` in lockstep; the workflow passes `TAG` as `XESTRATA_REF`.

## Values

The model is configured under `xestrata`:

```yaml
xestrata:
  family: ""      # "" (original), coder, swift, unsloth, ornith, llmjp
  model: IQ2_XS   # IQ2_XS fits ~48 GB RAM; IQ3_S needs ~64 GB
  contextSize: 32768
  vision: "no"
  port: 8095
  apiKey: ""      # optional; stored in a Secret when set
```

The server exposes port `80` targeting container port `8095` (`/v1` is the
OpenAI-compatible base URL, `/health` is the probe endpoint). Model files live
in the `data` volume (`/data`, default hostPath `/var/cache/xestrata/data`)
and settings in the `config` volume (`/config`). The first start downloads
60-110 GB, so the startup probe allows ~2 hours before failing.

GPU, memory, and placement defaults target the B70 on `kube-2`:

```yaml
resources:
  requests:
    cpu: 2
    memory: 32Gi
    gpu.intel.com/xe: 1
  limits:
    cpu: 8
    memory: 60Gi
    gpu.intel.com/xe: 1

podOptions:
  nodeSelector:
    kubernetes.io/hostname: kube-2
```

Do not schedule alongside `vllm-qwen38` or `llama-intel` — all three want the
same single B70. All other values are supplied by the TrueCharts common chart
(see its [documentation](https://truecharts.org/common/) for `persistence`,
`service`, `ingress`, `certificate`, `extraTpl`, and security contexts).

## Helmfile

The chart is intended to be configured through Helmfile values, following the
`llama-intel` pattern (TLS certificate, ReferenceGrant, and HTTPRoute in the
release values, disabled sibling release while testing):

```yaml
releases:
  - name: xestrata
    chart: ../charts/charts/xestrata
    namespace: vllm
    values:
      - releases/xestrata/values.yaml
```

## Upstream

- XeStrata: <https://github.com/MistVVK/XeStrata>
- Upstream Strata: <https://github.com/Niko1221/Strata>
- Model quants: <https://huggingface.co/ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF>
- TrueCharts common: <https://truecharts.org/common/>
