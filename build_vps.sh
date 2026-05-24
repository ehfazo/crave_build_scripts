#!/bin/bash
set -e
git init
if ! git remote get-url origin &>/dev/null; then
    git remote add origin https://github.com/accupara/los22.git
else
    git remote set-url origin https://github.com/accupara/los22.git
fi
curl -sf https://raw.githubusercontent.com/ehfazo/crave_build_scripts/lineage-23.2/crave_build.sh | bash
