# Gnome keyring setup for SSH
# if [ -n "$DESKTOP_SESSION" ];then
#     eval $(gnome-keyring-daemon --start)
#     export SSH_AUTH_SOCK
# fi

set editing-mode vi
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
alias md5dir='$HOME/scripts/md5dir.sh'
set -o vi
stty -ixon
if [[ -z "$TMUX" ]]; then
        tmux list-sessions | grep -E -v '\(attached\)$' | while IFS='\n' read line; do
            tmux kill-session -t "${line%%:*}"
        done
fi

alias dot='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'

# if [ -z "$VIRTUAL_ENV" ]; then
#     read -p "Virtual Environment? " -n 1 -r
#     echo
#     if [[ $REPLY =~ ^[Yy]$ ]]; then
#         export VIRTUAL_ENV=$HOME/.pyenv
#     fi
# fi
# 
#if [[ -n "$TMUX" ]]; then
#    tmux set-environment VIRTUAL_ENV $HOME/.pyenv
#fi

if [ -n "$VIRTUAL_ENV" ]; then
    source $VIRTUAL_ENV/bin/activate;
fi
