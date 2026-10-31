# Component: Alerting

**Where:** `helm/values-kube-prometheus-stack.yaml` under `additionalPrometheusRulesMap`
**Engine:** Prometheus (rules) and Alertmanager (routing, not configured yet)

## Why rules live in the values file

Alert rules are Prometheus objects. Putting them in the Helm values means they are created in the same release as Prometheus, with no ordering problem against the CRDs. The rules are visible in Prometheus under **Alerts**.

## The starter rules

### GPU group

| Alert | Expression (summary) | For | Severity | Why |
|---|---|---|---|---|
| `GPUIdleWhileRunning` | GPU utilization equals 0 | 30 min | warning | A running GPU is billed even when idle. This is the top budget risk. |
| `GPUMemoryNearFull` | Framebuffer used above 95% | 10 min | warning | Predicts out-of-memory crashes. |
| `GPUXIDError` | XID errors increased in 10 min | 0 | critical | Hardware or driver fault. Drain the node. |

### Inference group

| Alert | Expression (summary) | For | Severity | Why |
|---|---|---|---|---|
| `InferenceP95LatencyHigh` | p95 end-to-end latency above 10 s | 10 min | warning | User-visible slowness. |
| `InferenceRequestsQueued` | More than 20 waiting requests | 5 min | warning | Demand is above capacity. |

### Cost group

| Alert | Expression (summary) | For | Severity | Why |
|---|---|---|---|---|
| `RunRateExceedsBudget` | Hourly cluster cost times 730 above 100 | 1 h | warning | Projects the monthly cost of the current rate. |
| `NodeCostWithoutWorkload` | Node billed with no pods scheduled | 30 min | warning | Found the idle node the autoscaler forgot. |

## Limits of the cost alerts

`RunRateExceedsBudget` uses the current hourly rate times 730 hours. It is a projection, not a bill. A one-hour spike projects the full month, so the alert fires early. Use it as a prompt to look, not as a record of spend. The real spend is in the Nebius billing console.

## Routing (not configured)

Alertmanager has no receivers yet. To receive alerts, add a receiver in the kube-prometheus-stack values (`alertmanager.config`) with an email or chat webhook. Keep the webhook URL in a Kubernetes Secret, not in the values file.

## Testing an alert

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
# In the UI, run the expression from the rule with the threshold lowered to see it fire.
```

Rules can also be tested by temporarily lowering `for:` to `1m`. Restore the value before you apply.

## References

- Prometheus alerting rules: https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/
- Alertmanager configuration: https://prometheus.io/docs/alerting/latest/configuration/
- Prometheus Operator PrometheusRule: https://prometheus-operator.dev/docs/developer/alerting/
