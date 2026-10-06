--8<-- "snippets/dt-enablement.md"

# Part 3 — BizEvents: Start & End

## Use Case

Publish Dynatrace **Business Events** at the start and end of every test run. The `com.jmeter.test.summary` event captures avg/min/max latency, error rate, and throughput — all queryable in DQL. Use this to compare performance across releases or configuration changes without needing a separate reporting tool.

**Events published in this version:**

| Event | When | Key Fields |
|---|---|---|
| `com.jmeter.test.start` | Before test (setUp group) | test name, target URL, thread count, duration |
| `com.jmeter.test.summary` | After test (tearDown group) | avg/min/max latency, error %, throughput, total requests |

---

## Step 1 — Stop Any Running Test

```bash
stopJmeterTest
```

---

## Step 2 — Run the v1.3 Test

```bash
runJmeterTest v1.3 paste-your-codespaces-url-generated-id-here-80.app.github.dev
```

---

## Step 3 — Verify the Job Started

```bash
kubectl -n jmeter get all
```

---

## Step 4 — Watch the JMeter Logs

Follow the logs and look for the BizEvent sent at test start, then wait for the summary event when the test finishes:

```bash
kubectl logs -n jmeter -l app=jmeter-tester --follow
```

You should see log lines confirming `com.jmeter.test.start` was published at the beginning and `com.jmeter.test.summary` at the end.

![JMeter v1.3 test run](img/jmeter/v1.3-jmeter.png)

---

## Step 5 — Understand What Is New in v1.3

Two **Groovy scripts** are added to the JMeter plan:

- **setUp Thread Group** — executes before any load begins; builds a JSON payload and POSTs a `com.jmeter.test.start` event to the Dynatrace BizEvents ingest API
- **tearDown Thread Group** — executes after all threads finish; collects computed statistics from all samplers and POSTs a `com.jmeter.test.summary` event

Both scripts read `DT_URL` and `DT_TOKEN` from the `dynatrace-creds` Kubernetes secret created automatically by the framework.

---

## Step 6 — Query BizEvents in Dynatrace Notebooks

!!! example "Step-by-step"

    1. In Dynatrace, navigate to **Notebooks → New Notebook → Add DQL section**
    2. Run the following query to see the test start and summary events:

    ```dql
    fetch bizevents
    | filter event.type == "com.jmeter.test.start" or event.type == "com.jmeter.test.summary"
    | sort timestamp desc
    | limit 20
    ```

    3. You should see one `start` event and one `summary` event per completed test run

---

## Step 7 — Import the BizEvents Dashboard

!!! example "Step-by-step"

    1. Download: [JMeter Perf Test Report-v1.3](dashboard/Jmeter-Performance-Test-Report-v1.3.json){: download }
    2. In Dynatrace, navigate to **Dashboards → Upload**
    3. Upload the JSON file to visualize the `start` and `summary` events

    ![Dynatrace dashboard for v1.3](img/jmeter/v1.3-dt-dashboard.png)

---

## What You Observed

With BizEvents at test boundaries you can now:

- Query test summaries in DQL at any time — hours or days after the test ran
- Compare `avg.latency.ms` and `error.rate.pct` across multiple test runs
- Correlate test start/end with deployment events or config changes in the same timeline

!!! tip "DQL — compare test run summaries"
    ```dql
    fetch bizevents
    | filter event.type == "com.jmeter.test.summary"
    | sort timestamp desc
    | fields timestamp, test.name, avg.latency.ms, error.rate.pct, throughput.rps
    ```

---

## Knowledge Check

??? question "1. The test ran to completion, but your DQL query shows a `com.jmeter.test.start` event and no `com.jmeter.test.summary`. What are the likely causes?"
    Click to reveal the answer.

    **Answer:**

    - **The test was stopped early.** If you ran `stopJmeterTest` (or the pod was killed) mid-run, the tearDown group never executes, so no summary is sent. Let the test finish.
    - **Still running.** The summary is only sent after all threads finish; wait until the job completes.
    - **Ingest failure in tearDown.** Check the end of the logs (`kubectl logs -n jmeter -l app=jmeter-tester`) for an HTTP 401/403 from the BizEvents API. The `DT_TOKEN` in the `dynatrace-creds` secret needs the `bizevents.ingest` scope.
    - **Time range.** Widen the Notebook timeframe.

??? question "2. Where do the Groovy scripts get the Dynatrace URL and token from, and why is that better than hard-coding them in the test plan?"
    Click to reveal the answer.

    **Answer:** From `DT_URL` and `DT_TOKEN` in the `dynatrace-creds` Kubernetes secret in the `jmeter` namespace, which the framework creates from `DT_ENVIRONMENT` and `DT_BIZEVENT_TOKEN`. Secrets are kept out of the image and the test plan (so they are not committed or leaked) and can be rotated without rebuilding the JMeter image.

---

## Hands-on Use Case

??? example "Hands-on: Detect a performance regression between two runs"
    **Scenario:** After a config change you ran the test twice. Decide whether the second run is a regression: error rate above 1% or average latency more than 20% worse than the previous run.

    Click to reveal the solution.

    **Solution:**

    1. Run the test twice (`stopJmeterTest`, then `runJmeterTest v1.3 <url>`), letting each finish.
    2. In a Notebook, run:

        ```dql
        fetch bizevents
        | filter event.type == "com.jmeter.test.summary"
        | sort timestamp desc
        | fields timestamp, test.name, avg.latency.ms, error.rate.pct, throughput.rps
        | limit 2
        ```

    3. Compare the two rows: the newest is first. Regression if `error.rate.pct > 1` or `avg.latency.ms` is more than 1.2x the older row's value.
    4. Optional: use `makeTimeseries` or add a `fieldsAdd` to compute the delta, and correlate the timestamps with the deployment or config change.

    **Expected result:** Two rows (one per completed run). With identical settings the numbers should be close; a clear jump in latency or error rate is your regression signal.

    **Troubleshooting:** Only one row? The other run did not complete or published no summary (see Knowledge Check 1). Fields empty? Click a row and verify the actual field names in the event.

!!! tip "Ready for the next step?"
    In Part 4 you will stream incremental stats **every 30 seconds** during the test — enabling a live Dynatrace dashboard that updates in real time.

<div class="grid cards" markdown>
- [Continue to Part 4 — Live Stats :octicons-arrow-right-24:](jmeter-v2.0.md)
</div>
