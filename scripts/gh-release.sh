#!/usr/bin/env bash

bump_type="${1:-patch}" # Default to patch if no argument

# Validate bump_type input
if [[ "$bump_type" != "major" && "$bump_type" != "minor" && "$bump_type" != "patch" ]]; then
    echo "Invalid bump type: '$bump_type'. Use 'major', 'minor', or 'patch'."
    exit 1
fi

# 1) find latest semver tag (sorted by version)
latest_raw_tag=$(git tag --list --sort=-v:refname | head -n1)

if [[ -z "$latest_raw_tag" ]]; then
    echo "No existing tags found."
    # Determine initial version based on bump type if no tags exist
    case "$bump_type" in
    major)
        major=1
        minor=0
        patch=0
        echo "Defaulting to 1.0.0 for new major version."
        ;;
    minor)
        major=0
        minor=1
        patch=0
        echo "Defaulting to 0.1.0 for new minor version."
        ;;
    patch)
        major=0
        minor=0
        patch=1
        echo "Defaulting to 0.0.1 for new patch version."
        ;;
    esac
else
    echo "Latest tag found: $latest_raw_tag"
    # Remove 'v' prefix if present for parsing
    version_string="${latest_raw_tag#v}"

    # 2) split into MAJOR.MINOR.PATCH components
    IFS='.' read -r major minor patch <<<"$version_string"

    # Validate that major, minor, patch are integers
    if ! [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ && "$patch" =~ ^[0-9]+$ ]]; then
        echo "Error: Could not parse version components from tag '$latest_raw_tag' (parsed as '$major.$minor.$patch')."
        echo "Ensure the latest tag is in semver format (e.g., v1.2.3 or 1.2.3)."
        exit 1
    fi

    # 3) bump version based on bump_type
    case "$bump_type" in
    major)
        major=$((major + 1))
        minor=0
        patch=0
        ;;
    minor)
        minor=$((minor + 1))
        patch=0
        ;;
    patch)
        patch=$((patch + 1))
        ;;
    esac
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
