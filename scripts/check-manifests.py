#!/usr/bin/env python3
"""Platform guardrails: kustomize build の出力に対して「事故りやすい設定」を検出する。

使い方: kustomize build kubernetes/overlays/dev | python3 scripts/check-manifests.py
CI (ci.yml) の manifests ジョブで全 overlay に対して実行される。
"""
import sys

import yaml

docs = [d for d in yaml.safe_load_all(sys.stdin) if d]
errors, warnings = [], []
hpa_targets = {d["spec"]["scaleTargetRef"]["name"] for d in docs if d["kind"] == "HorizontalPodAutoscaler"}

for d in docs:
    kind, name = d["kind"], d["metadata"]["name"]
    if kind != "Deployment":
        continue
    if name in hpa_targets and "replicas" in d["spec"]:
        errors.append(f"Deployment/{name}: HPA があるのに spec.replicas が設定されています（Argo CD と HPA が綱引きします）")
    for c in d["spec"]["template"]["spec"]["containers"]:
        img = c.get("image", "")
        if img.endswith(":latest") or ":" not in img.split("/")[-1]:
            errors.append(f"Deployment/{name}: image '{img}' にタグがないか latest です")
        res = c.get("resources", {})
        if "requests" not in res or "limits" not in res:
            errors.append(f"Deployment/{name}/{c['name']}: resources.requests / limits が必要です")
        if "readinessProbe" not in c:
            warnings.append(f"Deployment/{name}/{c['name']}: readinessProbe がありません")

for w in warnings:
    print(f"::warning::{w}")
for e in errors:
    print(f"::error::{e}")
print(f"checked {len(docs)} resources: {len(errors)} error(s), {len(warnings)} warning(s)")
sys.exit(1 if errors else 0)
