#!/bin/sh
# lint_pages.sh - every rows screen in src/Features names its page kind (R1).
# Queue: scripts/pages_queue.txt, shrink only. See scripts/lint_pages.py.
exec python3 "$(dirname "$0")/lint_pages.py" "$@"
