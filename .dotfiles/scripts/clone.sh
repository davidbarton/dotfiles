#!/bin/bash

# Use this script to safely checkout dotfiles git
# repository. It takes care of backing up any
# existing files that would be overwritten.

# Define function for dotfiles. Use git command with
# custom work tree and .git directory paths set.
function my_dotfiles {
  git --work-tree="${DOTFILES_WORK_TREE_PATH}" --git-dir="${DOTFILES_GIT_PATH}" "$@"
}

# Define function for cloning dotfiles repository.
function clone_repo {
  # Exit with error if git clone arguments are empty.
  if [[ -z ${DOTFILES_GIT_CLONE_URL} ]]; then
    echo "Error: Repository URL not provided. Aborting dotfiles clone."
    exit 1
  fi

  # Exit with error if work tree directory does not exists.
  if [[ ! -d ${DOTFILES_WORK_TREE_PATH} ]]; then
    echo "Error: Work tree directory ${DOTFILES_WORK_TREE_PATH} does not exist. Aborting dotfiles clone."
    exit 1
  fi

  # Exit with error if project directory already exists.
  if [[ -d ${DOTFILES_PROJECT_PATH} ]]; then
    echo "Error: Dotfiles project directory ${DOTFILES_PROJECT_PATH} already exists. Aborting dotfiles clone."
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

# Define function for tracking remote branches.
function track_remote {
  # Remove read-only remote.
  my_dotfiles remote remove "${DOTFILES_ORIGIN}" > /dev/null 2>&1

  # Re-add origin remote. It now has proper branch tracking.
  my_dotfiles remote add "${DOTFILES_ORIGIN}" "${DOTFILES_GIT_CLONE_URL}" > /dev/null 2>&1

  # Fetch all branches.
  my_dotfiles fetch --all --quiet
}

# Define function for checking out git files. Tries to backup any conflicts.
function checkout_with_backup {
  # Try to quietly checkout files from repository. Run backup if checkout failed.
  if ! my_dotfiles checkout "$@" > /dev/null 2>&1; then

    # Inform user about backup.
    echo "Backing up existing files:"

    # Create backup directory structure.
    my_dotfiles checkout "$@" 2>&1 \
      | grep -E "^\s+.+$" \
      | xargs -I{} dirname "${DOTFILES_BACKUP_PATH}"/{} \
      | xargs -I{} mkdir -p {}

    # Move existing files to backup directory.
    my_dotfiles checkout "$@" 2>&1 \
      | grep -E "^\s+.+$" \
      | xargs -I{} mv {} "${DOTFILES_BACKUP_PATH}"/{}

    # Inform user about backed up files.
    find "${DOTFILES_BACKUP_PATH}" -type f

    # Try to checkout files from repository again. Report error if checkout failed again.
    if ! my_dotfiles checkout "$@" > /dev/null 2>&1; then

      # Inform user about backup failure.
      echo "Error: Backup of existing files failed. Aborting dotfiles checkout."
      exit 1
    fi
  fi
}

# Define main function for cloning dotfiles repository.
function main {
  # Clone dotfiles repository.
  clone_repo

  # Track remote branches.
  track_remote

  # Checkout files (with backup if needed).
  checkout_with_backup "${DOTFILES_CHECKOUT_BRANCH}"

  # Inform user about success.
  echo "Succesfully cloned dotfiles repository."
}

# Set git clone arguments to first script argument.
DOTFILES_GIT_CLONE_URL="$1"

# Set dotfiles project directory path (if not set).
DOTFILES_PROJECT_PATH="${DOTFILES_PROJECT_PATH:-"${HOME}/.dotfiles"}"

# Set path for bare git repository (if not set).
DOTFILES_GIT_PATH="${DOTFILES_GIT_PATH:-"${DOTFILES_PROJECT_PATH}/.git"}"

# Set path for git work tree directory (if not set).
DOTFILES_WORK_TREE_PATH="${DOTFILES_WORK_TREE_PATH:-"${HOME}"}"

# Set origin remote name (if not set).
DOTFILES_ORIGIN="${DOTFILES_ORIGIN:-"origin"}"

# Set branch name to be used during git clone command (if not set).
DOTFILES_CLONE_BRANCH="${DOTFILES_CLONE_BRANCH:-"init"}"

# Set branch name to checkout after cloned (if not set).
DOTFILES_CHECKOUT_BRANCH="${DOTFILES_CHECKOUT_BRANCH:-"main"}"

# Set backup path prefix (if not set).
DOTFILES_BACKUP_PREFIX="${DOTFILES_BACKUP_PREFIX:-".dotfiles_backup_"}"

# Set backup path (if not set).
DOTFILES_BACKUP_PATH="${DOTFILES_BACKUP_PATH:-"${HOME}/${DOTFILES_BACKUP_PREFIX}$(date +%s)"}"

# Run main function if script is executed and not sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
