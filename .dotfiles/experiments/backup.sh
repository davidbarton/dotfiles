#!/bin/bash

# Import common functions and variables.
source "$(dirname $(readlink -f "$0"))/common.sh"

# Checkout git branch for backups.
dotfiles checkout $DOTFILES_BACKUP_BRANCH || dotfiles checkout -b $DOTFILES_BACKUP_BRANCH

# Stage and commit all changes to tracked files.
dotfiles commit --all --message="Backup"

# Push backup commit to backup remote.
dotfiles push $DOTFILES_BACKUP_REMOTE $DOTFILES_BACKUP_BRANCH
