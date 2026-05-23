# CoreWeave Platform — What Makes Them Unique

## CoreWeave at a Glance

- **Founded**: 2017 (started as Ethereum mining → pivoted to GPU cloud)
- **IPO**: March 2025 (Nasdaq: CRWV)
- **Tagline**: "The Essential Cloud for AI™"
- **Model**: Hyperscaler-grade GPU infrastructure, rented to AI labs, enterprises, startups
- **Key customers**: Microsoft Azure (strategic partner), OpenAI, Stability AI, Cohere
- **HQ**: Livingston, NJ + Sunnyvale, CA + NY + Bellevue, WA (this role)
- **Culture**: 24/7 operations, fast-paced, engineering-heavy support team

## CoreWeave's Tech Stack

### GPU Fleet
- **NVIDIA H100 SXM5** (80GB, 3.35 TFLOPS BF16) — current flagship
- **NVIDIA H200** (141GB HBM3e) — latest, 1.4× H100 memory bandwidth
- **NVIDIA A100 SXM4** (40GB/80GB) — still widely deployed
- **NVIDIA GB200 NVL72** (coming) — Blackwell architecture
- OrbStack/minikube only has ARM64/AMD64 — no actual GPUs in practice

### Interconnect
- **InfiniBand NDR/HDR** (200Gb/400Gb) — between GPU nodes within a rack/cluster
- **GPUDirect RDMA** — GPU memory-to-memory communication over IB, no CPU hop
- **NVLink** — GPU-to-GPU within same node (NVLink 4.0 on H100)
- **NCCL** — NVIDIA's collective communication library (AllReduce, AllGather)

### Storage
- **WEKA** — high-performance parallel filesystem; RWX; used for training data
- **Vast Data** — alternative high-performance storage in some clusters
- **Pure Storage / local NVMe** — node-local high-speed scratch space
- **Object Storage** (S3-compatible) — for large model artifacts / checkpoints

### Kubernetes Platform
- **Kubernetes** — their entire cloud is K8s-native (they don't use VMs like AWS)
- **NVIDIA GPU Operator** — manages GPU drivers, device plugin, DCGM on every node
- **NVIDIA Network Operator** — manages InfiniBand/RDMA kernel drivers
- **OPA/Gatekeeper** — policy enforcement (resource quotas, security constraints)
- **ArgoCD** — GitOps for internal platform management
- **Prometheus + Grafana** — observability stack for customers and ops
- **DCGM Exporter** — GPU metrics (utilization, memory, temp, power, NVLink)

### Networking
- **Calico or Cilium** CNI (speculated based on public blog posts)
- **BGP** for internal routing between racks
- **1G/10G/25G/100G Ethernet** for non-RDMA traffic
- **InfiniBand** for RDMA/training traffic (separate network fabric)

## What Customers Actually Do on CoreWeave

### AI Training
- Large Language Model (LLM) training: GPT, Llama, Claude variants
- Distributed training: 100-1000+ GPUs, NCCL AllReduce over InfiniBand
- Data processing pipelines leading into training
- Checkpoint storage: multi-TB checkpoints on WEKA

### AI Inference
- Serving endpoints for LLMs and diffusion models
- Triton Inference Server, vLLM, TGI (Text Generation Inference)
- Autoscaling GPU pods based on request rate

### Scientific Computing / HPC
- Drug discovery (molecular dynamics — GROMACS, AMBER)
- Climate modeling, CFD, FEA simulations
- Seismic processing

## Common Customer Issues (Support Scenarios)

| Issue | Root Cause | Your Role |
|-------|-----------|-----------|
| Training job hung | NCCL timeout (IB link failure or pod died) | Check IB state, inspect dead pod logs |
| Job stuck Pending | GPU quota exceeded, wrong nodeSelector | Check quota, check GPU availability |
| CUDA OOM | Batch size too large, model too big | Guide to reduce batch size or use MIG |
| Slow training throughput | CPU data loading bottleneck, network bottleneck | Profile with Nsight, check IB bandwidth |
| Pod evicted mid-training | Node disk pressure, node memory pressure | Check node conditions, guide checkpoint recovery |
| Storage I/O slow | WEKA overloaded or misconfigured | Check WEKA status, escalate to platform team |
| "My bill is too high" | GPU idle (utilization < 20%) | Show DCGM dashboard, guide optimization |
| LoadBalancer service stuck Pending | No cloud LB provisioner | Explain CoreWeave's LB setup vs AWS ELB |

## The CX Team Structure (Customer Experience)

Based on JD context:
- **Tier 1**: Basic support (you won't be here — they escalate to you)
- **Tier 2**: You (Senior Cloud Support Engineer) — direct customer debug, escalation handling
- **Tier 3**: Platform / Infrastructure engineers — kernel-level, hardware, firmware
- **Account teams**: TAMs (Technical Account Managers) for strategic accounts
- **On-call**: 24/7/365 — you'll have shift work + rotation

## Why CoreWeave vs AWS/GCP/Azure

Practice articulating this:
- **GPU availability**: CoreWeave has more H100/H200 capacity than hyperscalers right now
- **Network**: InfiniBand NDR from day one — hyperscalers still lag on RDMA fabric for most customers
- **Latency**: On-demand access without hyperscaler queue times for GPU capacity
- **Price**: More competitive on pure GPU compute (no "cloud tax")
- **Support quality**: You're supporting the AI revolution at the infrastructure level

## Questions to Ask the Interviewer

1. "What does a typical P1 escalation look like? How do you triage between a customer-side issue vs. a CoreWeave infrastructure issue?"
2. "How does the support team interact with the platform engineering team during incidents?"
3. "What monitoring stack does the support team have access to — is there a single-pane-of-glass view across customer clusters?"
4. "How do you handle training job failures that span multiple nodes and require cross-team investigation?"
5. "What's the on-call rotation structure — how many engineers per shift, what's the escalation path?"
