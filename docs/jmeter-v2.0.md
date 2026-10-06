--8<-- "snippets/dt-enablement.md"

# Part 4 — Live Stats & Extended Scenarios

## Use Case

Stream incremental BizEvents **throughout** the test run — not just at the end. A background thread group publishes rolling stats every 30 seconds, enabling a real-time Dynatrace dashboard that updates while the test is running. This version also adds extended test scenarios covering more dtpay endpoints, producing a richer distributed trace topology.

**Events published in this version:**

| Event | When | Key Fields |
|---|---|---|
| `com.jmeter.test.start` | Before test (setUp group) | test name, target URL, thread count, duration |
| `com.jmeter.test.stats` | Every 30 s during test | rolling avg/min/max latency, error count, throughput |
| `com.jmeter.test.summary` | After test (tearDown group) | final avg/min/max latency, error %, throughput, total requests |

---

## Step 1 — Stop Any Running Test

```bash
stopJmeterTest
```

---

## Step 2 — Run the v2.0 Test

```bash
runJmeterTest v2.0 paste-your-codespaces-url-generated-id-here-80.app.github.dev
```

---

## Step 3 — Verify the Job Started

```bash
kubectl -n jmeter get all
```

---

## Step 4 — Watch the Live BizEvents in Logs

Follow the logs — you will see a BizEvent emitted every 30 seconds during the test:

```bash
kubectl logs -n jmeter -l app=jmeter-tester --follow
```

Watch for repeating log lines like `[stats] BizEvent sent — T+30s`, `[stats] BizEvent sent — T+60s` to confirm live stats are publishing.

![JMeter v2.0 test run](img/jmeter/v2.0-jmeter.png)

---

## Step 5 — Understand What Is New in v2.0

A third thread group — the **Stats Reporter** — runs in parallel with the main load threads. It wakes up every 30 seconds, collects rolling statistics from all active samplers, and POSTs a `com.jmeter.test.stats` BizEvent to Dynatrace.

The interval is configurable via `STATS_INTERVAL_SEC` (default: `30`).

The extended test plan also adds additional request scenarios (balance check, transaction history) to cover a broader set of dtpay endpoints, producing a richer service-map topology in Dynatrace.

---

## Step 6 — Query Live Stats in Dynatrace While the Test Runs

!!! example "Step-by-step"

    1. In Dynatrace, navigate to **Notebooks → New Notebook → Add DQL section**
    2. Run the following query **while the test is still running**:

    ```dql
    fetch bizevents
    | filter event.type == "com.jmeter.test.stats.live"
    | sort timestamp desc
    | limit 20
    ```

    3. Click **Run** every 30 seconds — you should see new rows appearing in real time as the test progresses

---

## Step 7 — Explore the Extended Service Map

JMeter v2.0 exercises additional dtpay endpoints, producing a richer service graph:

- Navigate to **Services → dtpay services → Service flow** to see the expanded topology compared to v1.x
- The extended test plan runs for **~10 minutes** with **50 concurrent users**

---

## Step 8 — Build a Real-Time Dashboard

!!! example "Step-by-step"

    1. Download: [JMeter Perf Test Report-v2.0](dashboard/JMeter-Performance-Test-Report-v2.0.json){: download }
    2. In Dynatrace, navigate to **Dashboards → Upload**
    3. Set **auto-refresh** to every **1 minute**
    4. Watch the dashboard update live as JMeter publishes rolling stats

    ![Dynatrace live dashboard for v2.0](img/jmeter/v2.0-dt-dashboard.png)

---

## Step 9 — Compare Multiple Test Runs

Use DQL to compare performance summaries across runs — useful for tracking regressions across releases or config changes:

```dql
fetch bizevents
| filter event.type == "com.jmeter.test.summary"
| sort timestamp desc
| fields timestamp, test.name, avg.latency.ms, error.rate.pct, throughput.rps
```

!!! example "Step-by-step"

    1. Download: [JMeter Perf Test Report-v2.1](dashboard/JMeter-Performance-Test-Report-v2.1.json){: download }
    2. Upload as a **New Dashboard** with 1-minute auto-refresh
    3. Run the test several times and observe how each run's summary appears as a new row

    ![Dynatrace cross-run comparison dashboard](img/jmeter/v2.0-dt-dashboard-compare.png)

---

## Reference — Configuration Variables

| Variable | Default | Description |
|---|---|---|
| `JVM_THREADS` | `50` | Concurrent virtual users |
| `JVM_LOOPS` | `-1` | Iterations per thread (`-1` = run for full duration) |
| `JVM_DURATION` | `600` | Test duration in seconds |
| `JVM_APP_URL` | `dtpay.127.0.0.1.sslip.io` | Target domain — bare hostname, no protocol or port |
| `JVM_DT_URL` | *(required)* | Dynatrace environment URL |
| `JVM_DT_TOKEN` | *(required)* | DT API token with `bizevents.ingest` scope |
| `STATS_INTERVAL_SEC` | `30` | How often v2.0 publishes a live stats BizEvent |

`JVM_DT_URL` and `JVM_DT_TOKEN` are read from the `dynatrace-creds` Kubernetes Secret in the `jmeter` namespace — created automatically by `runJmeterTest` from `DT_ENVIRONMENT` and `DT_BIZEVENT_TOKEN`.

---

## Reference — All DQL Queries

**Watch live stats in real time (run while test is active):**
```dql
fetch bizevents
| filter event.type == "com.jmeter.test.stats"
| sort timestamp desc
| limit 20
```

**Full event history for a single run:**
```dql
fetch bizevents
| filter event.type in ("com.jmeter.test.start", "com.jmeter.test.stats", "com.jmeter.test.summary")
| sort timestamp asc
```

**Compare test run summaries:**
```dql
fetch bizevents
| filter event.type == "com.jmeter.test.summary"
| sort timestamp desc
| fields timestamp, test.name, avg.latency.ms, error.rate.pct, throughput.rps
```

---

## Knowledge Check

??? question "1. While the v2.0 test is running, your DQL query for live stats returns no rows. What do you check?"
    Click to reveal the answer.

    **Answer:**

    1. **Event type.** The rolling events are `com.jmeter.test.stats`. A filter on a different name (for example `com.jmeter.test.stats.live`) matches nothing.
    2. **Is it really v2.0?** Logs should show `[stats] BizEvent sent — T+30s` lines. If not, you are running an older version (`stopJmeterTest`, then `runJmeterTest v2.0 <url>`).
    3. **Wait one interval.** The first stats event arrives after `STATS_INTERVAL_SEC` (default 30 s).
    4. **Token/ingest.** A 401/403 in the logs means `dynatrace-creds` has a token without the `bizevents.ingest` scope.
    5. **Timeframe.** Make sure the Notebook timeframe includes the last few minutes.

??? question "2. Why does the live stats event come from a separate thread group instead of the main load threads?"
    Click to reveal the answer.

    **Answer:** The Stats Reporter runs in parallel and sleeps for `STATS_INTERVAL_SEC`, so publishing to Dynatrace never sits inside a load thread's request loop. Posting from the load threads would add the BizEvent call to their timing and distort the very latency being measured, and it would send one event per user rather than one aggregated event per interval.

---

## Hands-on Use Cases

??? example "Hands-on 1: Change the live stats interval to 10 seconds"
    **Scenario:** A 30-second refresh is too coarse for a short demo. Make the dashboard update every 10 seconds.

    Click to reveal the solution.

    **Solution:**

    1. Stop the current job: `stopJmeterTest`.
    2. Start the test again with `runJmeterTest v2.0 <url>`, then set the variable on the job the same way `runJmeterTest` sets `JVM_APP_URL` (`kubectl set env`, see *Kubernetes Manifest* in the [JMeter reference](jmeter.md)):

        ```bash
        kubectl -n jmeter set env job/jmeter-tester STATS_INTERVAL_SEC=10
        ```

        (Check the actual job name with `kubectl -n jmeter get jobs`.) If the pod is already running, stop and start it again so it picks up the new value.
    3. Follow the logs.

    **Expected result:** Log lines `[stats] BizEvent sent — T+10s`, `T+20s`, ... and a new `com.jmeter.test.stats` row every 10 seconds. Verify with:

    ```dql
    fetch bizevents
    | filter event.type == "com.jmeter.test.stats"
    | sort timestamp desc
    | limit 10
    ```

    **Troubleshooting:** If events are still 30 s apart, the env var was not applied to the running pod. Confirm with `kubectl -n jmeter describe pod -l app=jmeter-tester` and look at the Environment section.

??? example "Hands-on 2: Reconstruct the timeline of one test run"
    **Scenario:** You need to show how latency evolved over a single run, from start to finish, to spot when degradation began.

    Click to reveal the solution.

    **Solution:**

    1. Let one full run complete (about 10 minutes).
    2. In a Notebook, fetch the full event history in time order:

        ```dql
        fetch bizevents
        | filter event.type in ("com.jmeter.test.start", "com.jmeter.test.stats", "com.jmeter.test.summary")
        | sort timestamp asc
        ```

    3. Scan the `avg.latency.ms` (or equivalent latency field) in each `stats` row. Switch the visualization to a line chart over `timestamp` to see the trend.
    4. Compare with the final `summary` row; the overall average should sit near the average of the stats rows.

    **Expected result:** One `start` row, about 20 `stats` rows (10 min / 30 s), and one `summary` row. A step up in latency at a specific `T+` tells you when to look at the service flow and traces for that window.

    **Troubleshooting:** Mixed events from several runs? Restrict the timeframe to the run, or filter on the run's test name or ID field.

## What You Accomplished

Across all four JMeter versions in this workshop you progressed from zero instrumentation to production-grade observability:

| Version | Capability Unlocked |
|---|---|
| v1.0 | Distributed traces in DT APM — no config required |
| v1.2 | Test traffic isolation via `x-dynatrace-test` header |
| v1.3 | BizEvent test summaries queryable in DQL |
| v2.0 | Real-time rolling stats + richer service topology |

<div class="grid cards" markdown>
- [Continue to Cleanup :octicons-arrow-right-24:](cleanup.md)
</div>
