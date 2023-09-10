#!/bin/bash

# Define git checkout-with-stash function.
# It stashes any checkout conflicts.
function checkout-with-stash {
  # Try checkout (hide error output).
  _gt checkout "$@" 2> /dev/null

  # Stash conflicts if checkout failed.
  if [ $? -ne 0 ]; then
    # Define label for this stash.
    _GT_STASH_LABEL="checkout-conflict-$(date +%s)"

    # Stash conflicts.
    _gt checkout "$@" 2>&1 | grep -E "^\s+.+$" | xargs -I {} /bin/bash -c "_gt stash push --quiet --message $_GT_STASH_LABEL {}"

    # Print full stash name.
    echo "Stashing changes to:"
    _gt stash list | grep -E $_GT_STASH_LABEL | sed -e 's/^/  /'
    echo ""

    # Print list of stashed files.
    echo "Stashed files:"
    _gt stash show --name-only | sed -e 's/^/  /'
    echo ""

    # Try checkout again.
    _gt checkout "$@"
  fi
}
