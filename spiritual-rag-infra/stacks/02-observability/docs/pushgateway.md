# Component: Prometheus Pushgateway

**Terraform:** `helm_release.pushgateway` in `main.tf`
**Values:** `helm/values-pushgateway.yaml`
**Project:** https://github.com/prometheus/pushgateway

## What it is

A service that accepts metrics pushed by short-lived jobs and holds them for Prometheus to scrape.

## Why it is here

Prometheus pulls metrics from running targets on a schedule. A training job runs for hours and then exits, so it may not exist when Prometheus scrapes it. The job pushes its loss, step count, and throughput to the Pushgateway instead, and Prometheus scrapes the Pushgateway.

## How training uses it

`apps/train/train.py` sets these gauges and pushes them at every logging step and checkpoint:

| Metric | Meaning |
|---|---|
| `srag_train_loss` | Training loss |
| `srag_train_step` | Current optimizer step |
| `srag_train_tokens_per_second` | Throughput (samples per second in the code; rename if you prefer tokens) |
| `srag_train_last_checkpoint_timestamp` | Unix time of the last checkpoint |

The job name is the run name (`RUN_NAME`), so each run is a separate series.

## Cleaning up old runs

The Pushgateway keeps the last value forever. An old run's metrics stay on the dashboard until you delete them:

```bash
kubectl -n monitoring port-forward svc/prometheus-pushgateway 9091:9091 &
curl -X DELETE http://localhost:9091/metrics/job/lora-run-01
```

Do this after each run, or the "seconds since last checkpoint" panel will show a growing number for finished jobs.

## Settings in this repo

| Setting | Value | Reason |
|---|---|---|
| `persistentVolume.enabled` | `false` | Metrics are short-lived. Losing them on restart is acceptable. |
| `serviceMonitor.enabled` | `true` | Prometheus scrapes the gateway. |
| `serviceMonitor.additionalLabels.release` | `kube-prometheus-stack` | Lets the Prometheus Operator select the monitor. |

## Known limits

- The Pushgateway is not a time-series store. Use it for batch jobs only, not for long-running services.
- Honor-labels behaviour matters: check that the `job` label is not overwritten by Prometheus. The default scrape config handles this for the gateway.

## References

- Pushgateway documentation and when to use it: https://prometheus.io/docs/practices/pushing/
- Prometheus Pushgateway project: https://github.com/prometheus/pushgateway
