#!/usr/bin/env bash
# Local history-scrub helper using git-filter-repo.
# WARNING: Run this locally after you have REVOKED the exposed token on GitHub.
# This script will:
#  - Ask for the exposed token (entered on your machine, not sent anywhere)
#  - Mirror-clone your repo
#  - Replace the token in history and force-push the cleaned mirror
# Prereqs: git-filter-repo (pip install git-filter-repo) OR see BFG alternative.
set -euo pipefail

REPO_URL="https://github.com/SwatDesignz/sinful-lust-shopify-theme.git"
TMP_DIR="$(mktemp -d)"
cd "$TMP_DIR"

echo "IMPORTANT: Confirm you have REVOKED the exposed PAT on GitHub (yes/no)?"
read -r CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Abort: revoke the token first, then run this script."
  exit 1
fi

if ! command -v git-filter-repo >/dev/null 2>&1; then
  echo "git-filter-repo not found. Install it first:"
  echo "  pip install git-filter-repo"
  echo "Or use the BFG instructions instead."
  exit 1
fi

echo "Enter the exact exposed token (it will NOT be stored by this script beyond local replacements file)."
read -r -s EXPOSED_TOKEN
if [ -z "$EXPOSED_TOKEN" ]; then
  echo "No token entered; aborting."
  exit 1
fi

echo "Mirror-cloning repository..."
git clone --mirror "$REPO_URL" repo.git
cd repo.git

# Prepare replacements file
printf '%s\n' "${EXPOSED_TOKEN}==>[REDACTED_TOKEN]" > replacements.txt

echo "Running git-filter-repo to remove the token from history. This may take a few moments..."
git-filter-repo --replace-text replacements.txt

echo "Expiring reflog and running gc..."
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo "Force-pushing cleaned history back to origin (mirror)..."
git push --force --mirror "$REPO_URL"

echo "Cleanup local temp files: $TMP_DIR"
# We do not remove TMP_DIR so you can inspect; remove if you want:
# rm -rf "$TMP_DIR"

echo "Done. Inform collaborators to reclone the repository."