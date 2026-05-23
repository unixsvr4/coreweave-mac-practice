# CoreWeave Technical Screen — Interview Strategy

## What the 90-minute screen looks like

Based on JD + Glassdoor/Taro research:

- **~30 min:** Live Kubernetes debugging (shared terminal or CoderPad-like env)
- **~20 min:** Linux system administration debugging
- **~15 min:** Networking / DNS / storage troubleshooting
- **~10 min:** Observability — reading Grafana, writing PromQL
- **~10 min:** HPC/GPU concepts + CoreWeave platform questions
- **~5 min:** Behavioral — customer escalation scenario

The whole thing is **practical, not theoretical.** No LeetCode. They will give you a broken cluster or a broken pod and watch how you debug it.

---

## How to think out loud (this is critical)

CoreWeave is a support role. They want to hear your reasoning. Do this:

```
1. Repeat what you observe: "I see the pod is in CrashLoopBackOff state."
2. State your hypothesis: "That usually means the container is starting and immediately dying."
3. Say what you'll check: "Let me look at the logs with kubectl logs."
4. Act: run the command
5. Interpret: "I see 'Error opening config file: no such file or directory' — the config mount is missing."
6. Fix: "I'll check the volumes/volumeMounts section."
7. Confirm: "After fixing it, I'll watch the pod come up with kubectl get pod -w."
```

Never go silent. If you don't know, say: "I'd normally check X next, and if that doesn't reveal it, I'd escalate to the node logs."

---

## Debugging framework to memorize

### For ANY broken pod — the 5-step mental model:

```
kubectl get pod <name> -o wide       # State, node, IP, age
kubectl describe pod <name>          # Events section is gold
kubectl logs <name> [--previous]     # Container output
kubectl get events --sort-by=.lastTimestamp  # Cluster-wide timeline
kubectl debug pod/<name> -it --image=busybox  # Interactive probe
```

### For node issues:

```
kubectl get nodes -o wide            # Status, roles, version
kubectl describe node <name>         # Conditions, allocatable, events
kubectl get pods --field-selector spec.nodeName=<name> -A  # What's on it
kubectl debug node/<name> -it --image=busybox  # Exec into node namespace
```

### For service/networking:

```
kubectl get svc,endpoints -n <ns>    # Check endpoints != <none>
kubectl run debug --image=busybox --rm -it -- nslookup <svc>.<ns>
kubectl run debug --image=busybox --rm -it -- wget -O- <svc>:<port>
```

---

## What to say when stuck

- "Let me check the events — they usually give the fastest signal on what Kubernetes is complaining about."
- "I want to look at the kubelet logs on the node — sometimes the pod-level logs don't tell the full story."
- "On a real CoreWeave cluster I'd also check the GPU device plugin logs if this is a GPU workload."
- "In production I'd open a P1 bridge call with the customer while investigating."

---

## CoreWeave-specific things to mention proactively

1. **NVIDIA GPU Operator** — they use this to manage GPU drivers/device plugins on nodes
2. **InfiniBand/RDMA** — their HPC interconnect; mention when discussing networking between training nodes
3. **Priority classes** — HPC jobs need `priorityClassName: high-priority` to preempt lower jobs
4. **WEKA filesystem** — CoreWeave's high-performance storage (mention for AI training dataset I/O)
5. **Multi-tenant isolation** — namespace quotas, LimitRanges, OPA/Gatekeeper policies
6. **kubectl debug node** — CoreWeave engineers use this heavily; mention it before they ask
7. **Shift work / 24x7** — you're comfortable with on-call; reference your runbook creation experience

---

## The customer communication piece

They will likely ask: "Walk me through how you'd communicate this issue to a customer."

Template:
```
Initial response (< 5 min):
"We've identified an issue affecting [workload]. Our engineering team is 
actively investigating. Current impact: [X]. We'll update you every 30 min."

Root cause found:
"Root cause: [specific thing]. We're applying [fix] now. ETA to resolution: [X]."

Post-resolution:
"Issue resolved at [time]. Root cause was [X]. To prevent recurrence: [Y]. 
I'll send a full incident report within 24 hours."
```

---

## 4-Day Study Plan

| Day | Focus | Scenarios |
|-----|-------|-----------|
| 1 | K8s debugging fundamentals | s01, s02, s04, s05, s12 |
| 2 | Networking + storage + DNS | s06, s07, s08, s09 |
| 3 | GPU/HPC + observability | s10, s11, observability stack |
| 4 | Full mock run + cheatsheets | All scenarios timed, read all cheatsheets |

Run each scenario **without looking at the solution first.** Time yourself. Aim for < 8 minutes per scenario.
