--8<-- "snippets/dt-enablement.md"

# Getting Started

## Prerequisites

Before launching the Codespace, ensure you have everything in place.

!!! warning "Requirements"
    - A **Dynatrace Platform** environment (SaaS) — [free trial available](https://www.dynatrace.com/signup/)
    - **GitHub Codespaces** access (or a local Dev Container)
    - All **Codespace secrets** populated (see table below)

### Required Secrets

| Secret | Description |
|---|---|
| `DT_ENVIRONMENT` | Your Dynatrace platform URL, e.g. `https://abc123.apps.dynatrace.com` |
| `DT_OPERATOR_TOKEN` | Operator token from the DT UI (auto-created when adding a cluster) |
| `DT_INGEST_TOKEN` | Ingest token for logs, metrics, and traces |

---

## Part 1 — Launch the Codespace

!!! example "Step-by-step"

    1. Open this repository on GitHub and click **Code > Codespaces > Create codespace on main**
    2. GitHub will prompt you to confirm secrets — verify all three are populated:

        | Secret | Status |
        |---|---|
        | `DT_ENVIRONMENT` | :material-check-circle:{ .green } required |
        | `DT_OPERATOR_TOKEN` | :material-check-circle:{ .green } required |
        | `DT_INGEST_TOKEN` | :material-check-circle:{ .green } required |

    3. Wait for the Codespace to finish initializing — the post-create script installs the Kubernetes cluster, and deploys the Dynatrace Operator (dtpay is deployed manually in Part 2)
    4. Open the **Terminal** panel in VS Code (`View → Open View → Terminal`)
    5. Verify the cluster and Dynatrace Operator are running:

    ```bash
    kubectl get nodes
    kubectl get pods -n dynatrace
    ```

!!! tip "What the post-create script does"
    The `post-create.sh` script automatically:

    - Creates a K3d Kubernetes cluster
    - Deploys the Dynatrace Operator via Helm and applies your credentials as a Dynakube

---

## Part 2 — Deploy the dtpay Application

The **dtpay** application is not deployed automatically. Deploy it manually from the terminal once the Codespace has finished initializing.

!!! example "Step-by-step"

    1. Open the **Terminal** panel in VS Code (`View → Open View → Terminal`)
    2. Run the following command:

    ```bash
    deployDtpay
    ```

    3. Wait for the command to finish — it creates the `dtusecase` namespace, applies all manifests, waits for the pods, and registers the frontend with the ingress
    4. Verify the pods are running:

    ```bash
    kubectl get pods -n dtusecase
    ```

## Part 3 — Make Port 80 Public

JMeter runs **inside the cluster** as a Kubernetes Job, so it reaches dtpay via the internal service without going through the Codespaces forwarded URL. However, to verify the dtpay portal is accessible (or to test from Postman), set port 80 to **Public** first.

!!! example "Step-by-step"

    1. Open the **Ports** panel in VS Code (`View → Open View → Ports`)
    2. Find port **80** — labeled `Ingress (Applications)`
    3. Right-click → **Port Visibility → Public**
    4. Click the forwarded URL to confirm the dtpay payment portal loads in your browser
    5. Copy the URL — it looks like `https://<codespace-name>-80.app.github.dev`

    ![Port 80 public visibility](img/jmeter/v1.0-codespace-config.png)

!!! warning "Revert when done"
    Set port 80 back to **Private** at the end of the workshop to avoid leaving the ingress publicly exposed.

---

!!! tip ""
    `deployDtpay` creates the `dtusecase` namespace, applies all manifests, waits for pods, and registers the frontend with the ingress — accessible via port 80.

<div class="grid cards" markdown>
- [Continue to dtpay Architecture :octicons-arrow-right-24:](dtpay.md)
</div>
