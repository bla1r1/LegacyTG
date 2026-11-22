#!/bin/sh
# lint_presentation.sh - one way to open each kind of thing, owned by src/UI.
# Fails on a modal, navigation controller, bar button, system alert or sheet
# built in src/Features, canvases included. Table: scripts/ui_ownership.txt.
exec sh "$(dirname "$0")/lint_ui_ownership.sh" presents "$@"
