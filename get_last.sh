find spec -mindepth 1 \( -type f -and -not -name '*.swp' \) -print0 | xargs -0 ls -t | head -1
