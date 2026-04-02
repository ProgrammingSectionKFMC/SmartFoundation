#!/usr/bin/env bash
# ============================================================================
# Bulk Label Existing Issues
# Repository: Fahad1993/SmartFoundationTickets
#
# Usage:
#   export GH_TOKEN=<your-personal-access-token>
#   bash label_existing_issues.sh
#
# Prerequisites:
#   - GitHub CLI (gh) installed and authenticated
#   - Draft items must first be converted to issues in the project board
#
# What this does:
#   1. Creates team labels (Backend, Frontend) if they don't exist
#   2. Creates category labels (DB-Structure, DB-SP, etc.) if they don't exist
#   3. Creates spec labels (Spec-00, Spec-01, ...) if they don't exist
#   4. Scans all open issues and assigns labels based on title prefix and body
# ============================================================================

REPO="Fahad1993/SmartFoundationTickets"

echo "========================================="
echo " Bulk Label Issues - ${REPO}"
echo "========================================="
echo ""

# ── Step 1: Create labels if they don't exist ──────────────────────────────

declare -A LABEL_COLORS
LABEL_COLORS=(
  ["Backend"]="0E8A16"
  ["Frontend"]="1D76DB"
  ["DB-Structure"]="D93F0B"
  ["DB-SP"]="E4E669"
  ["DB-DL-View"]="F9D0C4"
  ["UI"]="BFD4F2"
  ["Test"]="C5DEF5"
  ["Docs"]="0075CA"
  ["Setup"]="FBCA04"
  ["Spec-00"]="6F42C1"
  ["Spec-01"]="6F42C1"
  ["Spec-02"]="6F42C1"
  ["Spec-03"]="6F42C1"
  ["Spec-04"]="6F42C1"
  ["Spec-05"]="6F42C1"
  ["Spec-06"]="6F42C1"
  ["Spec-07"]="6F42C1"
  ["Spec-08"]="6F42C1"
  ["Spec-09"]="6F42C1"
  ["Spec-10"]="6F42C1"
  ["Spec-11"]="6F42C1"
)

declare -A LABEL_DESCRIPTIONS
LABEL_DESCRIPTIONS=(
  ["Backend"]="Tasks for the backend team"
  ["Frontend"]="Tasks for the frontend team"
  ["DB-Structure"]="Database table creation tasks"
  ["DB-SP"]="Stored procedure tasks"
  ["DB-DL-View"]="Data layer and view tasks"
  ["UI"]="User interface tasks"
  ["Test"]="Testing tasks"
  ["Docs"]="Documentation tasks"
  ["Setup"]="Project setup tasks"
)

echo "--- Creating labels ---"
for label in "${!LABEL_COLORS[@]}"; do
  color="${LABEL_COLORS[$label]}"
  desc="${LABEL_DESCRIPTIONS[$label]:-Tasks belonging to ${label}}"
  if gh label create "$label" --repo "$REPO" --color "$color" --description "$desc" 2>/dev/null; then
    echo "  ✅ Created: $label"
  else
    echo "  ⏭️  Exists:  $label"
  fi
done
echo ""

# ── Step 2: Fetch all open issues and label them ───────────────────────────

echo "--- Labeling issues ---"

# Get all issues as JSON
ISSUES=$(gh issue list --repo "$REPO" --state open --limit 1000 --json number,title,body)

echo "$ISSUES" | jq -c '.[]' | while read -r issue; do
  NUMBER=$(echo "$issue" | jq -r '.number')
  TITLE=$(echo "$issue" | jq -r '.title')
  BODY=$(echo "$issue" | jq -r '.body // ""')

  LABELS_TO_ADD=()

  # Team labels from title
  if [[ "$TITLE" =~ ^\[Backend\] ]]; then
    LABELS_TO_ADD+=("Backend")
  fi
  if [[ "$TITLE" =~ ^\[Frontend\] ]]; then
    LABELS_TO_ADD+=("Frontend")
  fi

  # Spec label from title
  if [[ "$TITLE" =~ \[Spec-([0-9]+)\] ]]; then
    SPEC_NUM="${BASH_REMATCH[1]}"
    # Pad to 2 digits
    SPEC_LABEL="Spec-$(printf '%02d' "$SPEC_NUM")"
    LABELS_TO_ADD+=("$SPEC_LABEL")
  fi

  # Category label from body
  CATEGORIES=("DB-Structure" "DB-SP" "DB-DL-View" "UI" "Test" "Docs" "Setup")
  for cat in "${CATEGORIES[@]}"; do
    if echo "$BODY" | grep -qi "\*\*Category:\*\* ${cat}"; then
      LABELS_TO_ADD+=("$cat")
    fi
  done

  if [ ${#LABELS_TO_ADD[@]} -eq 0 ]; then
    echo "  ⏭️  #${NUMBER}: No matching prefixes - ${TITLE}"
    continue
  fi

  # Build comma-separated label list for gh cli
  LABEL_CSV=$(IFS=,; echo "${LABELS_TO_ADD[*]}")

  echo "  🏷️  #${NUMBER}: ${TITLE}"
  echo "       → Labels: ${LABEL_CSV}"

  gh issue edit "$NUMBER" --repo "$REPO" --add-label "$LABEL_CSV"
done

echo ""
echo "========================================="
echo " Done! All issues have been labeled."
echo "========================================="
