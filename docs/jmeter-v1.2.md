--8<-- "snippets/dt-enablement.md"

# Part 2 — Test Marking

## Use Case

Correlate load-test traffic in Dynatrace using the `x-dynatrace-test` request header. Every JMeter request is tagged with the load test name, scenario, virtual user, and run ID. In Dynatrace you can filter traces by test name and cleanly separate load-test traffic from real-user traffic at any time.

The header attached to every request:

```
x-dynatrace-test: LTN=<test-name>;LSN=<scenario>;TSN=<sampler>;VU=<thread>;RUN=<time>;RID=<run-id>
```

---

## Step 1 — Configure Dynatrace Request Attributes

Tell Dynatrace to capture the test header so you can filter traces by load test name.

!!! example "Step-by-step"

    1. In Dynatrace, navigate to **Settings → Server-side service monitoring** (or search for **Service Request attributes**)
    2. Click **Add new request attribute**, name it `Load.Test.Name`
    3. Set **New Data source** to `HTTP request header`, header name: `x-dynatrace-test`
    4. Add a **Pre-processing step** — extract substring: **Between** `LTN=` and `;`
    5. Click **Save** and wait ~1 minute for Dynatrace to apply

    ![Dynatrace Request Attribute config for v1.2](img/jmeter/v1.2-dt-config.png)

    6. Repeat for `Load.Script.Name` — extract **Between** `LSN=` and `;`
    7. Repeat for `Test.Step.Name` — extract **Between** `TSN=` and `;`

---

## Step 2 — Stop Any Running Test

Before starting a new test, stop any currently running JMeter job:

```bash
stopJmeterTest
```

---

## Step 3 — Run the v1.2 Test

```bash
runJmeterTest v1.2 paste-your-codespaces-url-generated-id-here-80.app.github.dev
```

---

## Step 4 — Verify the Job Started

```bash
kubectl -n jmeter get all
```

---

## Step 5 — Watch the JMeter Logs

```bash
kubectl logs -n jmeter -l app=jmeter-tester --follow
```

![JMeter v1.2 test run](img/jmeter/v1.2-jmeter.png)

---

## Step 6 — Understand What Is New in v1.2

JMeter now adds the standard `x-dynatrace-test` header to **every** request. The header encodes:

| Field | Meaning |
|---|---|
| `LTN` | Load test name |
| `LSN` | Scenario (load script) name |
| `TSN` | Sampler (transaction step) name |
| `VU` | Virtual user (thread) number |
| `RUN` | Run timestamp |
| `RID` | Unique run ID |

Dynatrace captures this header in each distributed trace automatically — so load-test traffic can be filtered and isolated from real-user traffic at any time.

---

## Step 7 — Validate in Dynatrace: Filter by Load Test

!!! example "Step-by-step"

    1. Navigate to **Applications & Microservices → Distributed Traces**
    2. Click **Add filter → Request attribute: Load.Test.Name**
    3. Enter the value `dTPay-Test-Case`
    4. You should now see only JMeter-generated traces, fully isolated from real-user traffic

    ![JMeter v1.2 DT traces](img/jmeter/v1.2-dt-traces.png)

---

## Step 8 — Import the Performance Dashboard

Compare load-test traffic vs. real-user traffic side by side:

!!! example "Step-by-step"

    1. Download the dashboard JSON: [JMeter Perf Test Report-v1.2](dashboard/Jmeter-Performance-Test-Report-v1.2.json){: download }
    2. In Dynatrace, navigate to **Dashboards → Upload** (arrow icon, top-right corner)
    3. Upload the JSON file
    4. Explore how the metrics tiles pull performance data and how load-test traffic is separated

    ![Dynatrace dashboard for v1.2](img/jmeter/v1.2-dt-dashboard.png)

---

## What You Observed

By adding a single request header, you gained the ability to:

- Filter distributed traces exclusively to load-test traffic
- Compare load-test performance against real-user baselines in the same dashboard
- Identify which test run, scenario, and virtual user generated each trace

---

## Knowledge Check

??? question "1. You filter Distributed Traces by `Load.Test.Name = dTPay-Test-Case` but get no results, even though JMeter v1.2 is running. What do you check?"
    Click to reveal the answer.

    **Answer:** Work through these in order:

    1. **Is the right version running?** v1.0 does not send the header. Run `kubectl logs -n jmeter -l app=jmeter-tester` and confirm you started `v1.2` (after `stopJmeterTest`).
    2. **Does the request attribute exist and is it saved?** Check `Settings → Service Request attributes` for `Load.Test.Name`, source `HTTP request header` = `x-dynatrace-test`.
    3. **Is the pre-processing correct?** It must extract **Between** `LTN=` and `;` and the value you filter on must match exactly (case-sensitive).
    4. **Timing:** request attributes only apply to traffic captured *after* the rule is saved (allow ~1 minute). Traces from before the rule do not get the attribute, so wait for new traffic.

??? question "2. In `LTN=<test-name>;LSN=<scenario>;TSN=<sampler>;VU=<thread>;RUN=<time>;RID=<run-id>`, which field tells you which individual virtual user generated a trace, and which one separates two executions of the same test?"
    Click to reveal the answer.

    **Answer:** `VU` identifies the virtual user (thread number). `RID` (unique run ID), together with `RUN` (timestamp), separates one execution from another, while `LTN` stays the same across runs of the same test.

---

## Hands-on Use Case

??? example "Hands-on: Isolate the slowest transaction step of the load test"
    **Scenario:** Users complain that payments feel slow. Using only load-test traffic, find which JMeter sampler (transaction step) is the slowest.

    Click to reveal the solution.

    **Solution:**

    1. Create the third request attribute if you have not yet: `Test.Step.Name`, header `x-dynatrace-test`, extract **Between** `TSN=` and `;`.
    2. Go to **Applications & Microservices → Distributed Traces** and add the filter **Request attribute: Load.Test.Name = dTPay-Test-Case** so real-user traffic is excluded.
    3. Group or split the results by **Test.Step.Name** and sort by **Response time** descending.
    4. Open the slowest trace and review the span breakdown to see whether the time is in nginx, Spring Boot, or a downstream call.

    **Expected result:** The `POST /api/payment` step should typically be slower than `GET /` because it executes backend logic. You now have the exact step name, its slowest trace, and the service responsible.

    **Troubleshooting:** If `Test.Step.Name` has no values, confirm the extraction uses `TSN=` (not `LTN=`) and remember the last field of a header may not end with `;`, so only fields followed by `;` can be extracted this way.

!!! tip "Ready for the next step?"
    In Part 3 you will publish Dynatrace Business Events at test start and end, enabling DQL queries to compare performance across runs.

<div class="grid cards" markdown>
- [Continue to Part 3 — BizEvents :octicons-arrow-right-24:](jmeter-v1.3.md)
</div>
