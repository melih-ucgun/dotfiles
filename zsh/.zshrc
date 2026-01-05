if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
export LANG=en_US.UTF-8
export TERMINAL=kitty
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin


ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(
  git
  zsh-completions
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
  exec start-hyprland
fi

alias dot='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
export SUDO_EDITOR=nvim

alias snvim='sudo -E nvim'

alias lg='lazygit'
export PATH=$PATH:$HOME/go/bin

export MONARCH_KEY="AGE-SECRET-KEY-1X7Y0XGMVRSUMAUHQQ3Q5T2NZV5KLG96GLSAZLPA65UF69SWTXZCQW4SQ2J"

eval "$(mise activate zsh)"
