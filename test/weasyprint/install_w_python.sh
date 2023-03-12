#!/bin/bash

set -e

# Optional: Import test library
source dev-container-features-test-lib

# Definition specific tests
check "version" python  --version
check "pip is installed" pip --version
check "pip is installed" pip3 --version

# Check that tools can execute
check "weasyprint is installed" weasyprint --version

# Report result
reportResults
