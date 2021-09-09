#!/bin/bash
platform="$(uname -s)"
case "${platform}" in
    Linux*)     ./priv/stormdrain-x86_64-unknown-linux-musl -a 0.0.0.0:6986 serve;;
    Darwin*)    ./priv/stormdrain-x86_64-apple-darwin -a 0.0.0.0:6986 serve;;
    *)          echo "platform not supported"
esac