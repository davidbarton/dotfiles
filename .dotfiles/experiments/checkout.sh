#!/bin/bash

DOTFILES_WORK_TREE_PATH=$HOME
DOTFILES_GIT_PATH=$HOME/.dotfiles/.git

function dotfiles {
  git --work-tree=$DOTFILES_WORK_TREE_PATH --git-dir=$DOTFILES_GIT_PATH "$@"
}

function checkout {
  # Try to quietly checkout files from repository.
  dotfiles checkout "$@" > /dev/null 2>&1

  # Run backup if checkout failed.
  if [ $? -ne 0 ]; then

    # Define path for this backup.
    DOTFILES_BACKUP_PATH=$HOME/.dotfiles_backup_$(date +%s)

    # Inform user about backup.
    echo "Backing up existing files:"

    # Create backup directory structure.
    dotfiles checkout "$@" 2>&1 | grep -E "^\s+.+$" | xargs -I{} dirname $DOTFILES_BACKUP_PATH/{} | xargs -I{} mkdir -p {}

    # Move existing files to backup directory.
    dotfiles checkout "$@" 2>&1 | grep -E "^\s+.+$" | xargs -I{} mv {} $DOTFILES_BACKUP_PATH/{}

    # Inform user about backed up files.
    find $DOTFILES_BACKUP_PATH -type f

    # Try to checkout files from repository again.
    dotfiles checkout "$@"

    # Report error if checkout failed again.
    if [ $? -ne 0 ]; then
      # Inform user about backup failure.
      echo "Error: backup of existing files failed."
      exit 1
    fi
  fi
}

checkout "$@"

# Inform user about success.
echo "Succesfully cloned dotfiles repository."
