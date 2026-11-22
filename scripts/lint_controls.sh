#!/bin/sh
# lint_controls.sh - a Feature screen describes itself; src/UI draws it.
# Fails on a label, button, field, switch, slider, spinner or hand-rolled
# animation built in src/Features outside a canvas. Table: scripts/ui_ownership.txt.
exec sh "$(dirname "$0")/lint_ui_ownership.sh" controls "$@"
