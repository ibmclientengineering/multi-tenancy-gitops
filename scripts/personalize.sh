#!/usr/bin/env bash
# Point this GitOps repo set at YOUR GitHub org.
# Works from the ibmclientengineering-stamped state (set-git-source.sh placeholders
# are consumed once stamped — this script re-stamps idempotently).
#   GIT_ORG=<your-org> ./scripts/personalize.sh
set -euo pipefail
if [ -z "${GIT_ORG:-}" ]; then echo "Set GIT_ORG=<your-github-org> and re-run."; exit 1; fi
CURRENT_ORG=${CURRENT_ORG:-ibmclientengineering}
GIT_BASEURL=${GIT_BASEURL:-https://github.com}
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "Re-pointing manifests: ${GIT_BASEURL}/${CURRENT_ORG}/* -> ${GIT_BASEURL}/${GIT_ORG}/*"
find "${SCRIPTDIR}/../0-bootstrap" -name '*.yaml' -print0 | while IFS= read -r -d '' f; do
  sed -i.bak -e "s#${GIT_BASEURL}/${CURRENT_ORG}/#${GIT_BASEURL}/${GIT_ORG}/#g" "$f"
  rm -f "${f}.bak"
done
echo "Done. Review with 'git diff', then commit and push — Argo follows your repo from there."
