#!/bin/bash
set -e
git init
git remote add origin https://github.com/accupara/los22.git
curl -sf https://raw.githubusercontent.com/ehfazo/crave_build_scripts/lineage-23.2/crave_build.sh | bash
