#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '

# Firefox add $VISUAL
export VISUAL="vim"

# Go Version Manager
\n[[ -s "/home/archie/.gvm/scripts/gvm" ]] && source "/home/archie/.gvm/scripts/gvm"
