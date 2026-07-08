# multi-tenancy-gitops

The GitOps **bootstrap / app-of-apps root** for the platform: point one Argo CD Application at this repo and the entire IBM Cloud Pak for Integration estate assembles itself — infrastructure, then services, then applications — in the correct order, entirely from Git.

> Part of the **IBM Client Engineering Cloud Pak for Integration production-deployment demo** — the four-repo GitOps split that stands up a governed CP4I environment on Red Hat OpenShift. This is the entry point; the other three repos hold the manifests it deploys.

> **Provenance:** Derived from [cloud-native-toolkit/multi-tenancy-gitops](https://github.com/cloud-native-toolkit/multi-tenancy-gitops) (Apache-2.0); modernized for CP4I 16.x / OpenShift 4.18+ (July 2026).

## What this is

This repo is the **source of truth and the ignition switch**. It contains the Argo CD [app-of-apps](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/#app-of-apps-pattern) that installs the whole platform in three layered stages: **`1-infra` → `2-services` → `3-apps`**. Every layer is an Argo CD `AppProject` + child `Application`s whose manifests live in the *other* three repos. You choose what to deploy by uncommenting lines in a `kustomization.yaml` and pushing — nothing is installed by hand.

## What's inside

- **`0-bootstrap/`** — the app-of-apps. `bootstrap.yaml` is the single Application you apply to the cluster; it points Argo CD at a profile:
  - **`single-cluster/`** — the primary profile. Its `kustomization.yaml` wires the three layers together and patches each layer's `repoURL` to the matching repo:
    - **`1-infra/`** — namespaces, service accounts, SCCs, and cluster-wide config (machinesets, storage, pull-secret). Sourced from `-gitops-infra`.
    - **`2-services/`** — CP4I operators + instances (Platform Navigator, MQ, App Connect, API Connect + DataPower, Event Streams). Sourced from `-gitops-services`. The active profile is a minimal CP4I validation set (Platform Navigator + MQ + foundations); the rest are ready to uncomment.
    - **`3-apps/`** — sample integrations and CI/CD pipelines that run *on* those products (ACE, MQ, APIC, ES flows across dev/stage/prod). Sourced from `-gitops-apps`.
  - **`others/`** — alternate topologies: `1-shared-cluster`, `2-isolated-cluster`, `3-multi-cluster`.
- **`setup/`** — installs the OpenShift GitOps operator and a custom Argo CD instance with CP4I health checks (`ocp4x/`).
- **`scripts/`** — automation, notably `set-git-source.sh` to repoint all four repo/branch references at your own Git org.
- **`doc/`** — per-product recipes (MQ, ACE, APIC, Process Mining, Instana, Sterling, and more) plus architecture diagrams.

## Why it's built this way

- **Separation of duties, enforced by structure.** Each layer is its own repo and its own `AppProject` (labeled `gitops.tier.layer`). An app developer PRs to `-apps` and *cannot* touch cluster RBAC, machinesets, or storage in `-infra`. Platform, DevOps, and app teams own their layer without stepping on each other.
- **Blast-radius containment + natural sync ordering.** Infra must exist before services, services before apps. The layered app-of-apps encodes that dependency as sync ordering, so a bad app change can't take down the cluster foundation.
- **Everything is a PR — promotion included.** Enabling a product, moving a change dev → stage → prod, or rolling back is a Git commit. That gives you a full audit trail and Argo CD self-heal/prune reconciliation instead of drift-prone manual `oc apply`.
- **A reusable factory, not a one-off.** `set-git-source.sh` clones the whole model into any Git org in minutes. The comment-driven `kustomization.yaml` files are the deployment menu — the same rails deliver a two-product demo or a full estate.
- **Current, not legacy.** The 2026 refresh trimmed the upstream Cloud Pak kitchen sink (CP4D / CP4S / CP4BA / service-mesh) down to the IBM Automation portfolio on modern CP4I 16.x / OpenShift 4.18+ CR shapes.

## How it fits the bigger picture

This is one of a **four-repo split**, each cross-referenced by the bootstrap's kustomize patches:

| Repo | Layer | Holds |
|------|-------|-------|
| **multi-tenancy-gitops** (this repo) | `0-bootstrap` | The app-of-apps root + profiles |
| multi-tenancy-gitops-infra | `1-infra` | Namespaces, RBAC, cluster config |
| multi-tenancy-gitops-services | `2-services` | CP4I operators + instances |
| multi-tenancy-gitops-apps | `3-apps` | Integration apps + pipelines |

The product factories in `-services` (e.g. the MQ and ACE operators/instances) provision the platform that the overlays in `-apps` deliver flows into — for example, the MQ `3-apps` Applications source from `mq/config/argocd/<env>` in the `-apps` repo. Start here, and the other three repos are pulled in automatically.

---

Maintained by IBM Client Engineering.
