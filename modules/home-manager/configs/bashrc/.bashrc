EDITOR=nano

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias la='ls -A'
alias ll='ls -alF'
alias l='ls -CF'
alias bnix="cd $HOME/nixos && git add . && sudo nixos-rebuild switch --flake .#laptop && git commit -m 'Updates' && git push"
alias cniri="sudo $EDITOR $HOME/nixos/modules/home-manager/configs/niri/config.kdl"

PS1='[\u@\h \W]\$ '
