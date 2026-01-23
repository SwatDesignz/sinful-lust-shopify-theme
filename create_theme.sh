#!/usr/bin/env bash
# Safe theme creator and push script.
# - Does NOT hardcode tokens.
# - Expects you to authenticate with `gh auth login` or set $GITHUB_PAT locally (preferred).
# Usage:
#   1) Prefer: run `gh auth login` interactively, or
#   2) Export a PAT locally before running (do NOT commit it): export GITHUB_PAT="ghp_xxx"
#   3) Run: ./create_theme.sh
set -euo pipefail

DESKTOP="${HOME}/Desktop"
THEME="${DESKTOP}/sinful-lust-shopify-theme"
ASSETS_SRC="${DESKTOP}/Downloads"
GITHUB_USER="trappyjay93"
GITHUB_REPO="sinful-lust-shopify-theme"

# Helper for messages
info(){ printf "\n[INFO] %s\n" "$*"; }

# Ensure either gh is authenticated or GITHUB_PAT is provided
GH_AUTH_OK=false
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    GH_AUTH_OK=true
  fi
fi

if [ -z "${GITHUB_PAT:-}" ] && [ "$GH_AUTH_OK" = false ]; then
  printf "\nERROR: No GitHub authentication available.\n"
  printf "Either run: gh auth login\n"
  printf "Or export a PAT locally before running (example):\n"
  printf "  export GITHUB_PAT='your_token_here'\n\n"
  exit 1
fi

# If GITHUB_PAT is set and gh exists but not authenticated, use it to login (local-only)
if [ -n "${GITHUB_PAT:-}" ] && [ "$GH_AUTH_OK" = false ] && command -v gh >/dev/null 2>&1; then
  info "Authenticating gh CLI using provided GITHUB_PAT (local only)..."
  # NOTE: this reads token from env, do NOT echo it into logs in other contexts.
  echo "$GITHUB_PAT" | gh auth login --with-token >/dev/null 2>&1 || {
    printf "\nERROR: gh auth login failed. Ensure your token is valid and gh is installed.\n"
    exit 1
  }
  GH_AUTH_OK=true
fi

# --- CREATE / CLEAN FOLDER STRUCTURE ---
info "Creating theme directory at: $THEME"
rm -rf "$THEME"
mkdir -p "$THEME"/{assets,layout,sections,templates,config}
info "Folder structure created."

# --- ASSETS (copy if they exist) ---
if [ -f "$ASSETS_SRC/logo.png" ]; then
  cp "$ASSETS_SRC/logo.png" "$THEME/assets/"
  info "Copied logo.png"
else
  info "logo.png not found in $ASSETS_SRC — skipping"
fi

if [ -f "$ASSETS_SRC/favicon.ico" ]; then
  cp "$ASSETS_SRC/favicon.ico" "$THEME/assets/"
  info "Copied favicon.ico"
else
  info "favicon.ico not found in $ASSETS_SRC — skipping"
fi

# Create custom.css
cat > "$THEME/assets/custom.css" <<'EOL'
:root {
  --sin-red: #c4161c;
  --lust-purple: #7b2cbf;
  --lux-gold: #f2b705;
  --dark-bg: #0b0b0b;
  --panel-bg: #121212;
  --text-main: #f5f5f5;
  --text-muted: #b3b3b3;
}

body {
  background-color: var(--dark-bg);
  color: var(--text-main);
  font-family: 'Helvetica', sans-serif;
}

.btn {
  background: linear-gradient(135deg, var(--sin-red), var(--lust-purple));
  color: #fff;
  border-radius: 999px;
  font-weight: 700;
  padding: 10px 24px;
  box-shadow: 0 0 30px rgba(196,22,28,0.6), 0 0 30px rgba(123,44,191,0.6);
  transition: all 0.25s ease;
  border: none;
}

.btn:hover {
  box-shadow: 0 0 60px rgba(196,22,28,0.8), 0 0 60px rgba(123,44,191,0.8);
  transform: translateY(-2px);
}
EOL
info "Created assets/custom.css"

# Create custom.js
cat > "$THEME/assets/custom.js" <<'EOL'
// Example JS for modals, age verification, exit intent
document.addEventListener('DOMContentLoaded', () => {
  console.log('Sinful Lust JS loaded.');
});
EOL
info "Created assets/custom.js"

# --- SECTIONS ---
for section in age-verification cart-upsell email-capture exit-intent luxury-toggle; do
  cat > "$THEME/sections/${section}.liquid" <<EOL
<div class="${section}">
  <!-- ${section} content goes here -->
  <button class="btn">Click Me</button>
</div>
EOL
done
info "Created section files"

# --- LAYOUT ---
cat > "$THEME/layout/theme.liquid" <<'EOL'
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Sinful Lust</title>
  <link rel="stylesheet" href="{{ 'custom.css' | asset_url }}">
  <script src="{{ 'custom.js' | asset_url }}"></script>
  {{ content_for_header }}
</head>
<body>
  {{ content_for_layout }}
</body>
</html>
EOL
info "Created layout/theme.liquid"

# --- TEMPLATES ---
for template in index product cart; do
  cat > "$THEME/templates/${template}.liquid" <<'EOL'
{% if template == 'index' %}
  {% section 'age-verification' %}
  <h1>Welcome to Sinful Lust</h1>
  {% section 'email-capture' %}
  {% section 'luxury-toggle' %}
  {% section 'exit-intent' %}
  {% section 'cart-upsell' %}
{% endif %}
EOL
done
info "Created templates"

# --- CONFIG ---
cat > "$THEME/config/settings_schema.json" <<'EOL'
[]
EOL

cat > "$THEME/config/settings_data.json" <<'EOL'
{}
EOL
info "Created config files"

# --- ZIP THE THEME ---
cd "$DESKTOP"
zip -r sinful-lust-shopify-theme.zip sinful-lust-shopify-theme/ >/dev/null 2>&1 || true
info "Theme ZIP created at $DESKTOP/sinful-lust-shopify-theme.zip (if zip available)"

# --- GIT INIT & PUSH ---
cd "$THEME"
if [ -d .git ]; then
  info "Existing git data found — removing to start fresh"
  rm -rf .git
fi

git init
git add --all
git commit -m "Initial commit - Sinful Lust Shopify theme" || {
  info "No changes to commit or commit failed"
}

git branch -M main

# Ensure remote uses clean URL (do NOT embed tokens)
REMOTE_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
git remote remove origin >/dev/null 2>&1 || true
git remote add origin "$REMOTE_URL"

# Push: prefer gh CLI since it's authenticated, otherwise fallback to git push (may prompt)
if [ "$GH_AUTH_OK" = true ]; then
  info "Pushing to ${REMOTE_URL} using gh/git credentials..."
  git push -u origin main
  info "✅ Theme pushed to GitHub: ${REMOTE_URL}"
else
  info "Attempting git push (you may be prompted for credentials)..."
  git push -u origin main
  info "If push fails, authenticate with 'gh auth login' or export a valid GITHUB_PAT and re-run the script."
fi

info "Done."