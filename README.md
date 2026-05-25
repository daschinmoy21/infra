# Alchemyst DevOps Internship Assignment

Deploy the
[Alchemyst `quickstart`](https://github.com/Alchemyst-ai/hiring/tree/main/may-2026/devops/quickstart)
inference mesh across isolated VMs in a private subnet, then expose it behind a
JSON HTTP API.

## Architecture

```mermaid
graph TD
    subgraph Public ["Public Internet"]
        User((User))
    end

    subgraph VPC ["GCP VPC: red-vpc"]
        subgraph Subnet ["Private Subnet: 10.0.1.0/24"]
            
            subgraph GatewayVM ["Caller-Gateway VM (Public IP)"]
                direction TB
                API["HTTP API (:8000)"]
                TS["Caller-Worker (TS)"]
                Hub["iii-engine (RPC Hub)"]
                
                API --> TS
                TS -- "Local RPC" --> Hub
            end

            subgraph InferenceVM ["Inference-Worker VM (Private IP Only)"]
                direction TB
                Py["Inference-Worker (Python)"]
                Model["Gemma-3-270m (LLM)"]
                
                Py --- Model
            end

            Hub -- "Private RPC (49134)" --> Py
        end

        NAT["Cloud NAT"]
        Subnet -. "Outbound Only" .-> NAT
    end

    User -- "JSON Request" --> API
    NAT -. "SNAT" .-> Public
```

### Prerequisites

#### Using Nix (recommended)

Install [Nix](https://nixos.org/download) with flakes enabled, then run:

```bash
nix develop
```

This drops you into a shell with all dependencies available:
- Google Cloud SDK (`gcloud`)
- Terraform + Terraform LS
- Python 3.14 + uv
- Node.js 24, TypeScript, Bun
- curl, jq

#### Manual installation

<details>
<summary>Click to expand manual steps</summary>

1. **Google Cloud SDK** — Install the [`gcloud` CLI](https://cloud.google.com/sdk/docs/install), then authenticate:
   ```bash
   gcloud auth application-default login
   ```

2. **Terraform** — Install [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.5:
   ```bash
   terraform --version
   ```

3. **Python 3.14** + **uv** — Install [uv](https://docs.astral.sh/uv/):
   ```bash
   curl -LsSf https://astral.sh/uv/install.sh | sh
   uv python install 3.14
   ```

4. **Node.js 23+**, **TypeScript**, **Bun** — Install via your package manager or [nvm](https://github.com/nvm-sh/nvm):
   ```bash
   nvm install 23
   npm install -g typescript
   curl -fsSL https://bun.sh/install | bash
   ```

5. **curl**, **jq** — Install via your system package manager:
   ```bash
   # Debian/Ubuntu
   sudo apt install curl jq
   # macOS
   brew install curl jq
   ```

</details>
