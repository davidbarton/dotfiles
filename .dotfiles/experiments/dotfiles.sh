#!/bin/bash

DOTFILES_WORK_TREE_PATH=$HOME
DOTFILES_GIT_PATH=$HOME/.dotfiles/.git

function _dt {
  _gt --work-tree=$DOTFILES_WORK_TREE_PATH --git-dir=$DOTFILES_GIT_PATH "$@"
}

export -f _dt
