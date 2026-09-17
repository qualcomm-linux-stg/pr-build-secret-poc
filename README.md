# pr-build-secret-poc

Minimal proof-of-concept for [qli-ci#39](https://github.com/qualcomm-linux/qli-ci/issues/39):
does a `pull_request` / `workflow_run` split actually keep a secret out of
reach of PR-controlled code when the PR comes from a fork?

This repo does not build any real packages. It stands in `POC_TOKEN` (a
throwaway repo secret, not a real credential) for `DEBUSINE_TOKEN` /
`DEB_PKG_BOT_CI_TOKEN`, and asks the same question three ways:

## Workflows

- **`poc-broken.yml`** — today's pattern in `qli-ci`'s `pkg-pr-hook.yml`: a
  plain `on: pull_request` trigger that references `${{ secrets.POC_TOKEN }}`
  directly. Expected on a fork PR: the secret is empty. This is the "before"
  evidence for [qli-ci#30](https://github.com/qualcomm-linux/qli-ci/issues/30).

- **`poc-hook.yml`** + **`poc-check.yml`** — the proposed fix, mirroring
  `debusine-pr-hook.yml` / `debusine-pr-check.yml`: the hook runs on
  `pull_request` with no secrets and just records a pending status; the check
  runs on `workflow_run` (trusted context, has `POC_TOKEN`), checks out the PR
  merge ref, and runs the PR's own script (if any) in a step that does **not**
  have the secret in its env, before a later step that does have the secret
  but only does a stand-in "upload". The PR branch used for testing plants an
  `attack.sh` that tries to read the secret directly and, separately, tries to
  hijack `PATH` so that the *later*, secret-bearing step's `curl` invocation
  gets intercepted instead — testing the same-job/same-container residual risk
  noted in the qli-ci#39 write-up, not just direct env access.

- **`poc-check-positive-control.yml`** — manual-only (`workflow_dispatch`)
  sanity check: deliberately puts `POC_TOKEN` in the "untrusted" step's env
  and runs the same capture logic against itself, to prove the
  capture/detection method actually would catch a real leak rather than being
  silently broken.

All "capture" steps write to local files uploaded as workflow artifacts
(`env-dump`, `curl-capture`) — nothing is sent to any external endpoint.
Findings are read back from those artifacts, not from anything the PR branch
could self-report.
