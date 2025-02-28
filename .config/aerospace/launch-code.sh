#!/bin/bash

if ! [ "$(aerospace list-workspaces --focused)" == "C" ]; then
    aerospace workspace C
    if [ "$(aerospace list-windows --workspace C | wc -l)" -gt "0" ]; then
        exit 0
    fi
fi

open -a "Visual Studio Code"
