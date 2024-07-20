#!/bin/bash

source "$(dirname "$(readlink -f "$0")")/common.sh"

dotfiles remote remove "${DOTFILES_READ_ONLY_REMOTE}" > /dev/null 2>&1
dotfiles remote remove "${DOTFILES_ORIGIN_REMOTE}" > /dev/null 2>&1
dotfiles remote remove "${DOTFILES_BACKUP_REMOTE}" > /dev/null 2>&1
dotfiles remote remove "${DOTFILES_TEMPLATE_REMOTE}" > /dev/null 2>&1

dotfiles remote add "${DOTFILES_ORIGIN_REMOTE}" git@github.com:davidbarton/dotfiles.git
dotfiles remote add "${DOTFILES_BACKUP_REMOTE}" git@github.com:davidbarton/dotfiles-backup.git
dotfiles remote add "${DOTFILES_TEMPLATE_REMOTE}" git@github.com:davidbarton/dotfiles-template.git

dotfiles fetch --all --prune
