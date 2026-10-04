--8<-- "snippets/dt-enablement.md"

# Part 1 — Basic APM Traces

## Use Case

Establish a baseline load against **dtpay** with no instrumentation beyond standard Dynatrace OneAgent APM. JMeter drives `GET /` and `POST /api/payment` traffic. In Dynatrace, the backend Spring Boot service appears in distributed traces with response time and throughput data — no custom configuration required.

**Test scenarios:**

| Scenario | Request | Details |
|---|---|---|
| Home Page | `GET /` | Loads the React SPA |
| Payment | `POST /api/payment` | Randomized amount, method, name, and user ID |

---

## Step 1 — Run the JMeter Test

Open the **Terminal** panel in VS Code (`View → Open View → Terminal`) and run:

```bash
runJmeterTest v1.0 paste-your-codespaces-url-generated-id-here-80.app.github.dev
```

**Replace the URL with the Codespaces forwarded URL** you copied in [Getting Started](getting-started.md).

---

## Step 2 — Verify the Job Started

Check that the JMeter Kubernetes Job was created and the pod is running:

```bash
kubectl -n jmeter get all
```

---

## Step 3 — Watch the JMeter Logs

Follow the pod logs to confirm the test is running:

```bash
kubectl logs -n jmeter -l app=jmeter-tester --follow
```

![JMeter v1.0 test run](img/jmeter/v1.0-jmeter-run.png)

---

## Step 4 — Understand the JMeter Configuration

JMeter is configured to test two URLs with **50 concurrent users** for **~5 minutes**. The test plan runs both the home page (`GET /`) and the payment endpoint (`POST /api/payment`) in a loop.

![JMeter v1.0 configuration](img/jmeter/v1.0-jmeter.png)

---

## Step 5 — Validate in Dynatrace

Navigate to **Services** in Dynatrace:

- Search for and select a **JMeter** service
- Navigate to **Service flow → Maps**
- Click **Traces** to see all transactions performed by JMeter

![Dynatrace configuration for v1.0](img/jmeter/v1.0-dt-config.png)

**Distributed Traces:**

![Dynatrace traces for v1.0](img/jmeter/v1.0-dt-traces.png)

---

## Step 6 — Build a Dashboard

Create a dashboard in Dynatrace to visualize the JMeter test results (`Dashboards → Create New Dashboard`):

1. Add a metric query tile
2. **Filter:** `dt.smartscape.service.name = ":80" endpoint.name in (/, "/api/payment")`
3. **Summarize:** `Count`, **Split by:** `http.response.status_code`

![Dynatrace dashboard for v1.0](img/jmeter/v1.0-dt-dashboard.png)

---

## What You Observed

With zero configuration beyond OneAgent, Dynatrace automatically captures:

- Distributed traces for every JMeter request
- Response time and throughput metrics broken down by endpoint
- Full service topology — from the nginx frontend through the Spring Boot backend

!!! tip "Ready for the next step?"
    In Part 2 you will add the `x-dynatrace-test` header to cleanly tag and isolate load-test traffic from real-user traffic.

<div class="grid cards" markdown>
- [Continue to Part 2 — Test Marking :octicons-arrow-right-24:](jmeter-v1.2.md)
</div>
