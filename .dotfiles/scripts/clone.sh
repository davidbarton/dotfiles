#!/bin/bash

# Use this script to safely checkout dotfiles git
# repository. It takes care of backing up any
# existing files that would be overwritten.

# Set git clone arguments to first script argument.
DOTFILES_GIT_CLONE_URL="$1"

# Exit with error if git clone arguments are empty.
if [[ -z "${DOTFILES_GIT_CLONE_URL}" ]]; then
  echo "Error: Repository URL not provided."
  exit 1
fi

# Define path for bare git repository.
DOTFILES_PROJECT_PATH=${HOME}/.dotfiles
DOTFILES_GIT_PATH=${DOTFILES_PROJECT_PATH}/.git

# Exit with error if directory already exists.
if [[ -d ${DOTFILES_PROJECT_PATH} ]]; then
  echo "Error: Directory ${DOTFILES_PROJECT_PATH} already exists."
  exit 1
fi

# Define path for git work tree directory.
DOTFILES_WORK_TREE_PATH=${HOME}

# Define function for dotfiles. Use git command with
# custom work tree and .git directory paths set.
function dotfiles {
  git --work-tree="${DOTFILES_WORK_TREE_PATH}" --git-dir="${DOTFILES_GIT_PATH}" "$@"
}

# Jump to work tree directory.
cd "${DOTFILES_WORK_TREE_PATH}" || exit

# Clone repository with --bare flag.
git clone --quiet --bare --origin read-only "${DOTFILES_GIT_CLONE_URL}" "${DOTFILES_GIT_PATH}"

# Don't show untracked files for "dotfiles status".
dotfiles config --local status.showUntrackedFiles no

# Remove read-only remote.
dotfiles remote remove read-only > /dev/null 2>&1

# Re-add origin remote. It now has proper branch tracking.
dotfiles remote add origin "${DOTFILES_GIT_CLONE_URL}" > /dev/null 2>&1

# Fetch all branches.
dotfiles fetch --all --quiet

# Try to quietly checkout files from repository. Run backup if checkout failed.
if ! dotfiles checkout > /dev/null 2>&1; then

  # Define path for this backup.
  DOTFILES_BACKUP_PATH=${HOME}/.dotfiles_backup_$(date +%s)

  # Inform user about backup.
  echo "Backing up existing files:"

  # Create backup directory structure.
  dotfiles checkout 2>&1 | grep -E "^\s+.+$" | xargs -I{} dirname "${DOTFILES_BACKUP_PATH}"/{} | xargs -I{} mkdir -p {}

  # Move existing files to backup directory.
  dotfiles checkout 2>&1 | grep -E "^\s+.+$" | xargs -I{} mv {} "${DOTFILES_BACKUP_PATH}"/{}

  # Inform user about backed up files.
  find "${DOTFILES_BACKUP_PATH}" -type f

  # Try to checkout files from repository again. Report error if checkout failed again.
  if ! dotfiles checkout; then
    # Inform user about backup failure.
    echo "Error: Backup of existing files failed. Aborting dotfiles checkout."
    exit 1
  fi
fi

# Inform user about success.
echo "Succesfully cloned dotfiles repository."
