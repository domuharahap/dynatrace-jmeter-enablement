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

---

## Knowledge Check

??? question "1. After starting the test, `kubectl -n jmeter get all` shows the pod in `ImagePullBackOff` or `Error`. How do you find out why?"
    Click to reveal the answer.

    **Answer:** Inspect the pod and its logs instead of guessing:

    ```bash
    kubectl -n jmeter get pods
    kubectl -n jmeter describe pod -l app=jmeter-tester   # Events section shows pull/scheduling errors
    kubectl logs -n jmeter -l app=jmeter-tester           # JMeter's own output
    ```

    Common causes: a typo in the version (valid values: `v1.0`, `v1.2`, `v1.3`, `v2.0`) or a target URL that includes `https://` or a port. If a previous job is still around, run `stopJmeterTest` and start again.

??? question "2. Why can Dynatrace show traces for JMeter traffic without any change to the test plan?"
    Click to reveal the answer.

    **Answer:** OneAgent instruments the dtpay services (nginx frontend and Spring Boot backend) and automatically captures every incoming request as a PurePath/distributed trace. JMeter is just an ordinary HTTP client. The downside is that load-test requests are **indistinguishable from real-user requests**, which is what Part 2 fixes.

---

## Hands-on Use Case

??? example "Hands-on: Build a tile that shows only failed payments"
    **Scenario:** The team wants to know whether `POST /api/payment` returns errors under 50 concurrent users. Add a dashboard tile that shows only non-2xx responses for that endpoint.

    Click to reveal the solution.

    **Solution:**

    1. Open your dashboard (`Dashboards → Create New Dashboard`) and add a **metric query** tile.
    2. Reuse the Step 6 filter, but narrow it to the payment endpoint and exclude successes:
        - **Filter:** `dt.smartscape.service.name = ":80" endpoint.name = "/api/payment" http.response.status_code != 200`
        - **Summarize:** `Count`, **Split by:** `http.response.status_code`
    3. Set the timeframe to the last 30 minutes while the test is running.

    **Expected result:** An empty tile (or a very small count) means the endpoint is healthy. If bars appear, click one and use **Traces** to open the failing requests and inspect their exception details.

    **Troubleshooting:** If the tile is empty even for the unfiltered query, the test is not running (check `kubectl logs`) or the `endpoint.name` values differ. Remove the endpoint filter and use **Split by** `endpoint.name` to see the real names.

!!! tip "Ready for the next step?"
    In Part 2 you will add the `x-dynatrace-test` header to cleanly tag and isolate load-test traffic from real-user traffic.

<div class="grid cards" markdown>
- [Continue to Part 2 — Test Marking :octicons-arrow-right-24:](jmeter-v1.2.md)
</div>
