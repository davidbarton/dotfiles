#!/bin/bash

DOTFILES_CRON_ENTRY="*/5 * * * * /path/to/job -with args"

# Add new entry to crontab.
(crontab -l 2>/dev/null; echo $DOTFILES_CRON_ENTRY) | crontab -
