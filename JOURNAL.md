# Building a Distributed Multi-VM Inference Mesh

This is a deep dive into how I built a distributed, secure inference mesh on AWS
for the Alchemyst DevOps assignment. It wasn't just about deploying code; it was
about designing a network that actually makes sense for production AI.

---

## 🎯 The Mission
The objective was to take a monolithic AI quickstart and split it across
multiple EC2 instances. I wanted a setup where the gateway is public, but the
heavy-lifting (inference) happens in total isolation.

The goal:
- **Security:** Private subnets only for workers.
- **Interoperability:** TS/Bun talking to Python 3.14 via RPC.
- **Reproducibility:** 100% Terraform + user-data scripts.

---

## 🛠️ The Setup
- **Cloud:** Amazon Web Services (VPC, EC2).
- **Network:** Isolated VPC with Public/Private subnets and a NAT Gateway.
- **Mesh Engine:** `iii` (RPC Hub + SDKs).
- **Runtimes:** Bun (Gateway) and Python 3.14 + uv (Inference).

---

## 🏗️ Phases of Construction

### Phase 1: The Networking Headache
The spec was clear: workers must be in a private subnet. But here's the
catch—the inference worker needs to download model weights and `uv` dependencies
on boot.

- **The Problem:** An EC2 instance in a private subnet with no public IP is
  basically a brick when it comes to the internet.
- **The Solution:** I provisioned an **AWS NAT Gateway** in the public subnet.
  This allows the Inference EC2 to reach out to GitHub and HuggingFace for what
  it needs, while remaining completely invisible to the public internet.

### Phase 2: Runtimes & The "Nix Surprise"
I started local dev using the provided Nix flake. I expected `iii` to be
pre-bundled, but `nix develop` actually dropped me into a **Linux FHS environment**.
- **The realization:** The flake isn't meant to package `iii` itself; it's
  designed to provide the perfect environment for the official installer. I ran
  `curl -fsSL https://install.iii.dev/iii/main/install.sh | sh` inside the shell
  and it worked like a charm.

### Phase 3: Bridging the Mesh (Bun + Python)
Getting two different languages to talk over RPC was where the "aha!" moments
happened.

- **Gateway:** I chose **Bun** for the gateway because I wanted that
  sub-millisecond startup and execution speed. I had to tweak the systemd units
  and user-data scripts to install Bun manually.
- **The Character Splitting Bug:** This was the most annoying part of the build.
  The API was returning `["H", "e", "l", "l", "o"]` instead of "Hello".
- **The Fix:** I realized the Python worker was returning a raw string, which
  the TS SDK was then iterating over. I wrapped the response in a dictionary
  `{"response": result}` in `main.py`, and the communication became seamless.

---

## 🚦 Orchestration & Verification
I didn't want to manually start scripts after every reboot, so I wrapped
everything in **systemd units**.

1. `iii-engine`: The Hub (listening on `0.0.0.0` to allow cross-VM traffic).
2. `caller-worker`: The TS Gateway.
3. `inference-worker`: The Python Model.

### The Final Test
Once Terraform finished, I hit the public IP of the gateway:

```bash
curl -X POST http://<GATEWAY_IP>:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "Explain quantum entanglement in 10 words."}]}'
```

The request hit the Gateway EC2, hopped over the private network to the Inference
EC2, and came back with a valid result in seconds.

---

## 💡 Lessons Learned
- **Least Privilege:** Using AWS Security Groups to restrict traffic to specific
  ports and sourcing from the VPC CIDR made the setup feel robust.
- **Scale:** If I had to do this with a 100x larger model, I'd swap the
  T3 nodes for G5 instances with NVIDIA GPUs and implement Tensor Parallelism.
## Final Check: Is it Reproducible?
To ensure someone else can pick this up and run it:
1. **The variables:** I exposed `my_ip` and `repo_url` so the stack isn't hardcoded to my environment.
2. **The Automation:** Everything from the VPC creation to the `uv` environment sync is handled by Terraform and User-Data. 
3. **The Proof:** A fresh `terraform apply` on a clean AWS account should yield a working endpoint in ~5 minutes.

This project was a great exercise in "Network Hygiene"—it’s one thing to run code locally, and another entirely to wire it together across isolated VMs in a cloud environment.
