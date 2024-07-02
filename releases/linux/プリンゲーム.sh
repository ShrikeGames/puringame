#!/bin/sh
echo -ne '\033c\033]0;プリンゲーム\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/プリンゲーム.x86_64" "$@"
