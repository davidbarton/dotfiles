#!/bin/bash

# Indent STDIN with 2 spaces.
function _indent() {
  sed -e 's/^/  /'
}

# Run git checkout and try to stash any conflicts.
function main() {
  # Try checkout (hide error output).
  # Try to stash conflicts if checkout failed.
  if ! git checkout "$@" 2> /dev/null; then
    # Define label for this stash.
    local -r stash_label
    stash_label="checkout-conflicts-$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    # Try to stash conflicts.
    git checkout "$@" 2>&1 \
      | grep -E "^\s+.+$" \
      | xargs -I {} /bin/bash -c \
        "git stash push --quiet --include-untracked --message ${stash_label} {}"

    # Get reflog selector for this stash.
    local -r stash_reflog_selector
    stash_reflog_selector=$(git stash list --max-count=1 --pretty=format:%gd)

    # Report stash if it was created.
    if [[ -n "${stash_reflog_selector}" ]]; then
      # Print full stash name.
      echo "Stashing changes to:"
      git stash list \
        | grep -E "${stash_reflog_selector}" \
        | _indent
      echo ""

      # Print list of stashed files.
      echo "Stashed files:"
      git stash show --include-untracked --name-only "${stash_reflog_selector}" \
        | _indent
      echo ""

      # Print instructions how to unstash.
      echo "Unstash changes with:"
      echo "git stash apply ${stash_reflog_selector}" \
        | _indent
      echo ""
    fi

    # Try checkout again.
    git checkout "$@"
  fi
}

main "$@"
