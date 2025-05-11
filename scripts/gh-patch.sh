#!/usr/bin/env bash

# 1) find latest semver tag (sorted by version)
latest=$(git tag --list --sort=-v:refname | head -n1)

if [[ -z "$latest" ]]; then
    echo "No existing tags found; defaulting to 0.0.1"
    major=0
    minor=0
    patch=1
else
    # 2) split into MAJOR.MINOR.PATCH
    IFS='.' read -r major minor patch <<<"$latest"
    # 3) bump patch
    patch=$((patch + 1))
fi

new="$major.$minor.$patch"
echo "Creating release $new …"

# 4) create GitHub release at main
gh release create "$new" \
    --title "v$new" \
    --notes "Release v$new" \
    --target main

# pull new tag
git fetch --tags
