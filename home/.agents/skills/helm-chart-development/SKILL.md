---
name: helm-chart-development
description: Helm chart best practices - diffing against an upstream chart's defaults, values schema validation, template structure, and safe verification. Use when creating, editing, or reviewing a Helm chart (Chart.yaml, values.yaml, templates/, subcharts, an umbrella chart wrapping an upstream one).
---

# Helm Chart Development

## Diff against the upstream chart, don't restate it

Before touching `values.yaml` for a chart that wraps or depends on an upstream chart, get the upstream's actual defaults for the pinned version:

```
helm show values <chart> --version <version>
```

Never copy a default value from that output into your own `values.yaml` unchanged. A restated default is duplication: it silently drifts out of sync when the upstream chart bumps its default, and it hides which values you actually intend to control. Your `values.yaml` should contain only the overrides that differ from upstream - nothing else. If you're unsure whether a value still matches upstream after a chart version bump, re-run `helm show values` against the new version and diff it.

## Validate with a values schema, not template logic

Put validation in `values.schema.json` (JSON Schema), not in `{{ required }}`/`{{ fail }}` chains scattered through templates. Helm validates values against the schema automatically before rendering, in one place, before any template runs. Templates render resources; they don't gate input.

## Keep templates declarative, push logic to _helpers.tpl

A file under `templates/*.yaml` should read as "which resource, with which values plugged in" - not as a small program. Extract conditionals, defaulting, and computed names/labels into named templates in `_helpers.tpl` (`define`/`include`), and call them from the resource templates. If a template needs more than a line or two of `{{- if }}`/`{{- range }}` to express, that logic belongs in a helper.

## Verify with a filtered render

Check rendered output with `helm template`, scoped to the manifest(s) you actually changed, rather than reading the whole chart's output:

```
helm template <release> <chart> --show-only templates/deployment.yaml
```

Pass `--show-only` multiple times for more than one manifest. For a values change, render before and after against the same `--show-only` target and diff the two.

## Live-cluster verification

`helm install`/`upgrade` against a live cluster is the user's call, not yours. Unless the user says otherwise, don't run it yourself - hand them the chart  and let them roll it out. They'll tell you once it's deployed; verify against that live release from there (`kubectl get`/`describe`, `helm test`, logs, etc.) rather than deploying it to check.

If the user explicitly asks you to install into a live cluster, first check the rendered manifests for cluster-scoped resources - anything with no `namespace` (`ClusterRole`, `ClusterRoleBinding`, `CustomResourceDefinition`, `ClusterIssuer`, etc.). These are named globally, so confirm each one won't conflict with an existing instance already in the cluster (a different release of the same chart, another chart defining the same CRD) before applying. Where the chart supports it, install into a dedicated namespace for anything namespaced.
