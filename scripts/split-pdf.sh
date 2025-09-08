#!/bin/bash

splitpdf() { FILE="$1" nix-shell -p poppler_utils --run 'base=${FILE%.*}; pdfseparate "$FILE" "${base}-%03d.pdf"'; }

splitpdf "$1"
