#!/bin/bash

set -e

# // Script to gather unique repository names from GitHub commit search results

# (async function collectRepositories() {
#   // Set to store unique repository names
#   const repositories = new Set();

#   // Function to extract repo names from the current page
#   function extractRepoNames() {
#     // Find all repo links in search results
#     const repoLinks = document.querySelectorAll('.search-title a[href*="/commit/"]');

#     // Extract repository names from the paths
#     repoLinks.forEach(link => {
#       const href = link.href;
#       const matches = href.match(/github\.com\/([^\/]+\/[^\/]+)\/commit/);
#       if (matches && matches[1]) {
#         repositories.add(matches[1]);
#       }
#     });

#     // Alternative selector if the above doesn't work
#     const repoHeadings = document.querySelectorAll('h3 .ksQFlo a');
#     repoHeadings.forEach(heading => {
#       if (heading.textContent) {
#         repositories.add(heading.textContent.trim());
#       }
#     });

#     console.log(`Found ${repositories.size} unique repositories so far`);
#   }

#   // Function to click the Next button and wait for page load
#   async function goToNextPage() {
#     const nextButton = document.querySelector('a.prc-Pagination-Page-yoEQf[rel="next"]');
#     if (!nextButton || nextButton.getAttribute('aria-disabled') === 'true') {
#       return false; // No more pages
#     }

#     // Remember current page URL to detect when navigation completes
#     const currentUrl = window.location.href;

#     // Click the next button
#     nextButton.click();

#     // Wait for page to change
#     return new Promise(resolve => {
#       const checkPageChanged = setInterval(() => {
#         if (window.location.href !== currentUrl) {
#           // Wait a bit more for content to load
#           setTimeout(() => {
#             clearInterval(checkPageChanged);
#             resolve(true);
#           }, 2000);
#         }
#       }, 500);

#       // Safety timeout if something goes wrong
#       setTimeout(() => {
#         clearInterval(checkPageChanged);
#         resolve(false);
#       }, 15000);
#     });
#   }

#   // Main process
#   try {
#     let hasMorePages = true;
#     let pageCount = 1;

#     while (hasMorePages) {
#       console.log(`Processing page ${pageCount}...`);
#       extractRepoNames();

#       // Try to go to the next page
#       hasMorePages = await goToNextPage();
#       if (hasMorePages) {
#         pageCount++;
#       }
#     }

#     // Print final results
#     console.log('===== COLLECTION COMPLETE =====');
#     console.log(`Found ${repositories.size} unique repositories:`);
#     console.log(Array.from(repositories).join('\n'));
#   } catch (error) {
#     console.error('Error occurred during collection:', error);
#   }
# })();

export FILTER_BRANCH_SQUELCH_WARNING=1

# Check if required parameters are provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <file-with-repo-list> <email-to-replace>"
    echo "The file should contain repository names in the format 'username/repo', one per line"
    echo "The email-to-replace parameter specifies which commits to update (only those with this author email)"
    exit 1
fi

REPO_LIST=$1
EMAIL_TO_REPLACE=$2

# Get user details from ~/.gitconfig
GIT_NAME=$(git config --get user.name)
GIT_EMAIL=$(git config --get user.email)

if [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; then
    echo "Error: Could not find user.name or user.email in ~/.gitconfig"
    exit 1
fi

# Prepare the environment file for rewriting commits
cat >/tmp/author-rewrite.env <<EOF
if [ "\$GIT_AUTHOR_EMAIL" = "$EMAIL_TO_REPLACE" ]; then
    GIT_AUTHOR_NAME="$GIT_NAME"
    GIT_AUTHOR_EMAIL="$GIT_EMAIL"
    GIT_COMMITTER_NAME="$GIT_NAME"
    GIT_COMMITTER_EMAIL="$GIT_EMAIL"
fi
EOF

# Process each repository
echo "$REPO_LIST" | while IFS= read -r REPO_PATH || [ -n "$REPO_PATH" ]; do
    # Skip empty lines
    if [ -z "$REPO_PATH" ]; then
        continue
    fi

    echo "Processing repository: $REPO_PATH"

    # skip if already processed:
    if grep -q "$REPO_PATH" /tmp/.repo.done; then
        echo "Repository already processed, skipping..."
        continue
    fi

    echo "$REPO_PATH" >>/tmp/.repo.done

    # Construct GitHub URL
    REPO_URL="git@github.com:${REPO_PATH}.git"
    REPO_NAME=$(basename "$REPO_PATH")
    TEMP_DIR="/tmp/$REPO_NAME"

    # Remove existing temporary directory if it exists
    if [ -d "$TEMP_DIR" ]; then
        echo "Removing existing temporary directory..."
        rm -rf "$TEMP_DIR"
    fi

    # Clone the repository with all branches
    echo "Cloning repository..."
    git clone "$REPO_URL" "$TEMP_DIR"
    cd "$TEMP_DIR" || {
        echo "Failed to cd into $TEMP_DIR"
        continue
    }

    # Fetch all branches and tags
    git fetch --all
    git fetch --tags

    # Get all remote branches
    BRANCHES=$(git branch -r | grep -v '\->' | sed 's/origin\///')

    # Process each branch individually
    for BRANCH in $BRANCHES; do
        echo "Checking out branch: $BRANCH"
        git checkout "$BRANCH"

        # Rewrite commit history for this branch
        echo "Rewriting commit history for $BRANCH..."
        git filter-branch --force --env-filter 'source /tmp/author-rewrite.env' --tag-name-filter cat -- HEAD

        # Force push the branch
        echo "Force pushing $BRANCH..."
        git push --force origin "$BRANCH" || echo "Failed to push $BRANCH, probably permission error."
    done

    # Process tags
    echo "Processing tags..."
    TAGS=$(git tag)
    if [ -n "$TAGS" ]; then
        # Force push all tags
        echo "Force pushing all tags..."
        git push --force --tags origin || echo "Failed to push tags, probably permission error."
    fi

    # Clean up this repository
    cd /tmp || exit
    rm -rf "$TEMP_DIR"

    echo "Completed processing $REPO_PATH"
    echo "-----------------------------------"
done

# Final cleanup
rm -f /tmp/author-rewrite.env

echo "All done! Author information has been replaced in all repositories for commits with email: $EMAIL_TO_REPLACE"
