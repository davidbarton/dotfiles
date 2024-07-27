#!/bin/bash

# Use this script to safely checkout dotfiles git
# repository. It takes care of preserving any
# existing files that would be overwritten.

# Return 0 (0 is considered true in bash) if variable is set and not false.
function is_set_and_not_false() {
  if [[ -n "$1" ]] && [[ "$1" != "false" ]]; then
    return 0  # Return true
  else
    return 1  # Return false
  fi
}

# Execute dotfiles command with args.
function my_dotfiles {
  git --work-tree="${DOTFILES_WORK_TREE_PATH}" --git-dir="${DOTFILES_GIT_PATH}" "$@"
}

# Command to get reflog selector for git stash with given name.
function get_stash_selector {
  my_dotfiles stash list | grep --max-count 1 "$1" | cut -d: -f1
}

# Function to clone dotfiles repository.
function clone_repository {
  # Inform user about clone.
  if ! is_set_and_not_false "${DOTFILES_QUIET}"; then
    printf "Cloning repository %s\n" "${DOTFILES_GIT_CLONE_URL}"
  fi

  # Exit with error if git clone arguments are empty.
  if [[ -z ${DOTFILES_GIT_CLONE_URL} ]]; then
    printf "Error: Repository URL not provided. Aborting dotfiles clone.\n" >&2
    exit 1
  fi

  # Exit with error if work tree directory does not exists.
  if [[ ! -d ${DOTFILES_WORK_TREE_PATH} ]]; then
    printf "Error: Work tree directory %s does not exist. Aborting dotfiles clone.\n" "${DOTFILES_WORK_TREE_PATH}" >&2
    exit 1
  fi

  # Exit with error if project directory already exists.
  if [[ -d ${DOTFILES_PROJECT_PATH} ]]; then
    printf "Error: Dotfiles project directory %s already exists. Aborting dotfiles clone.\n" "${DOTFILES_PROJECT_PATH}" >&2
    exit 1
  fi

  # Jump to work tree directory.
  cd "${DOTFILES_WORK_TREE_PATH}" || exit

  # Clone repository with --bare flag.
  git clone \
    --quiet \
    --bare \
    --branch "${DOTFILES_CLONE_BRANCH}" \
    --origin "${DOTFILES_ORIGIN}" \
    "${DOTFILES_GIT_CLONE_URL}" \
    "${DOTFILES_GIT_PATH}"

  # Don't show untracked files for "dotfiles status".
  my_dotfiles config --local status.showUntrackedFiles no
}

# Function to setup tracking remote branches.
function track_remote {
  # Inform user about remote tracking.
  if ! is_set_and_not_false "${DOTFILES_QUIET}"; then
    printf "Fixing tracking for %s remote\n" "${DOTFILES_ORIGIN}"
  fi

  # Remove existing remote.
  my_dotfiles remote remove "${DOTFILES_ORIGIN}" > /dev/null 2>&1

  # Re-add origin remote. It now has proper branch tracking.
  my_dotfiles remote add "${DOTFILES_ORIGIN}" "${DOTFILES_GIT_CLONE_URL}" > /dev/null 2>&1

  # Fetch all branches.
  my_dotfiles fetch --all --quiet
}

# Function to checkout git files. Tries to backup any conflicts.
function checkout_with_backup {
  # Inform user about backup.
  if ! is_set_and_not_false "${DOTFILES_QUIET}"; then
    printf "Trying to checkout %s branch\n" "$@"
  fi

  # Try to quietly checkout files from repository. Run backup if checkout failed.
  if ! my_dotfiles checkout "$@" > /dev/null 2>&1; then

    # Inform user about backup.
    if ! is_set_and_not_false "${DOTFILES_QUIET}"; then
      printf "Backing up conflicting files to %s\n" "${DOTFILES_BACKUP_PATH}"
    fi

    # Save list of conflict files for backup.
    local backup_files
    backup_files=$(
      my_dotfiles checkout "$@" 2>&1 \
        | grep -E "^\s+.+$" \
        | xargs -I{} printf "%s\n" {}
    )

    # Create backup directory structure.
    printf "%s\n" "${backup_files}" \
      | xargs -I{} dirname "${DOTFILES_BACKUP_PATH}"/{} \
      | xargs -I{} mkdir -p {}

    # Move existing files to backup directory.
    printf "%s\n" "${backup_files}" \
      | xargs -I{} mv "${DOTFILES_WORK_TREE_PATH}"/{} "${DOTFILES_BACKUP_PATH}"/{}

    # Inform user about backed up files.
    if ! is_set_and_not_false "${DOTFILES_QUIET}"; then
      printf "%s\n" "${backup_files}" \
        | xargs -I{} printf "  %s\n" "${DOTFILES_BACKUP_PATH}"/{}
    fi

    # Try to checkout files from repository again. Report error if checkout failed again.
    if ! my_dotfiles checkout --quiet "$@"; then

      # Inform user about backup failure.
      printf "Error: Backup of existing files failed. Aborting dotfiles checkout.\n" >&2
      exit 1
    fi

    # Restore backup files.
    restore_backup "${backup_files}"
  fi
}

# Function for restoring backup files.
function restore_backup {
  # Inform user about restore.
  if ! is_set_and_not_false "${DOTFILES_QUIET}"; then
    printf "Restoring conflicting files to %s\n" "${DOTFILES_WORK_TREE_PATH}"
  fi

  # Create restore directory structure.
  printf "%s\n" "${backup_files}" \
    | xargs -I{} dirname "${DOTFILES_WORK_TREE_PATH}"/{} \
    | xargs -I{} mkdir -p {}

  # Move existing files to restore directory.
  printf "%s\n" "${backup_files}" \
    | xargs -I{} mv "${DOTFILES_BACKUP_PATH}"/{} "${DOTFILES_WORK_TREE_PATH}"/{}

  # Inform user about restored files.
  if ! is_set_and_not_false "${DOTFILES_QUIET}"; then
    printf "%s\n" "${backup_files}" \
      | xargs -I{} printf "  %s\n" "${DOTFILES_WORK_TREE_PATH}"/{}
  fi

  # Remove backup directory.
  if ! is_set_and_not_false "${DOTFILES_KEEP_BACKUP}"; then

    # Inform user about removing backup directory.
    if ! is_set_and_not_false "${DOTFILES_QUIET}"; then
      printf "Removing backup directory %s\n" "${DOTFILES_BACKUP_PATH}"
    fi

    # Remove backup directory.
    rm -rf "${DOTFILES_BACKUP_PATH}"
  fi
}

# Function for stashing changes.
function stash_changes {
  # Stash changes to tracked files.
  my_dotfiles stash push --quiet --no-keep-index --message "${DOTFILES_BACKUP_NAME}"

  # Get reflog selector for this stash.
  local stash_reflog_selector
  stash_reflog_selector=$(get_stash_selector "${DOTFILES_BACKUP_NAME}")

  if [[ -n "${stash_reflog_selector}" ]]; then
    if ! is_set_and_not_false "${DOTFILES_QUIET}"; then
      # Inform user about stashing changes.
      printf "Stashing changes to %s\n" "${DOTFILES_BACKUP_NAME}"

      # Print list of stashed files.
      my_dotfiles stash show --include-untracked --name-only "${stash_reflog_selector}" \
        | xargs -I{} printf "  %s\n" {}

      # Print instructions how to view stashed diff and how to unstash it.
      printf "
Show stashed changes:
    dotfiles stash show --patch %s

Unstash changes:
    dotfiles stash apply %s
\n" "${stash_reflog_selector}" "${stash_reflog_selector}"
    fi
  fi
}

# Main function for cloning dotfiles repository.
function main {
  # Clone dotfiles repository.
  clone_repository

  # Track remote branches.
  track_remote

  # Checkout files (with backup and restore if needed).
  checkout_with_backup "${DOTFILES_CHECKOUT_BRANCH}"

  # Stash changes to any tracked files.
  stash_changes

  # Inform user about success.
  if ! is_set_and_not_false "${DOTFILES_QUIET}"; then
    printf "Succesfully cloned dotfiles repository\n"
  fi
}

# Set CI environment variable to false (if not set).
CI="${CI:-"false"}"

# Set QUIET flag to false (if not set).
DOTFILES_QUIET="${DOTFILES_QUIET:-"false"}"

# Set git clone arguments to first script argument.
DOTFILES_GIT_CLONE_URL="$1"

# Set path for git work tree directory (if not set).
DOTFILES_WORK_TREE_PATH="${DOTFILES_WORK_TREE_PATH:-"${HOME}"}"

# Set dotfiles project directory path (if not set).
DOTFILES_PROJECT_PATH="${DOTFILES_PROJECT_PATH:-"${DOTFILES_WORK_TREE_PATH}/.dotfiles"}"

# Set path for bare git repository (if not set).
DOTFILES_GIT_PATH="${DOTFILES_GIT_PATH:-"${DOTFILES_PROJECT_PATH}/.git"}"

# Set origin remote name (if not set).
DOTFILES_ORIGIN="${DOTFILES_ORIGIN:-"origin"}"

# Set branch name to be used during git clone command (if not set).
DOTFILES_CLONE_BRANCH="${DOTFILES_CLONE_BRANCH:-"init"}"

# Set branch name to checkout after cloned (if not set).
DOTFILES_CHECKOUT_BRANCH="${DOTFILES_CHECKOUT_BRANCH:-"main"}"

# Set backup path prefix (if not set).
DOTFILES_BACKUP_PREFIX="${DOTFILES_BACKUP_PREFIX:-"dotfiles_backup_"}"

# Set backup filename (if not set).
DOTFILES_BACKUP_NAME="${DOTFILES_BACKUP_NAME:-"${DOTFILES_BACKUP_PREFIX}$(date -u +"%Y%m%d%H%M%S")"}"

# Set backup path (if not set).
DOTFILES_BACKUP_PATH="${DOTFILES_BACKUP_PATH:-"${DOTFILES_WORK_TREE_PATH}/.${DOTFILES_BACKUP_NAME}"}"

# Set keep backup flag to false (if not set).
DOTFILES_KEEP_BACKUP="${DOTFILES_KEEP_BACKUP:-"false"}"

# Run main function if script is executed and not sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

  # Log all commands if CI environment variable is set.
  if is_set_and_not_false "${CI}"; then
    set -x
  fi

  # Run main function.
  main
fi
