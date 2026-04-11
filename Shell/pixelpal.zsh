# PixelPal shell integration for zsh
# Add to .zshrc: source /path/to/pixelpal.zsh
# Works in any terminal — Ghostty, cmux, iTerm2, Terminal.app

typeset -g _PP_SOCK="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}pixelpal.sock"
typeset -g _PP_HAS_ZSOCKET=0
typeset -g _PP_CMD_START=""

zmodload zsh/net/unix 2>/dev/null && _PP_HAS_ZSOCKET=1

_pp_send() {
    [[ -S "$_PP_SOCK" ]] || return 0
    if (( _PP_HAS_ZSOCKET )); then
        local fd
        zsocket "$_PP_SOCK" 2>/dev/null || return 0
        fd=$REPLY
        print -u $fd -r -- "$1" 2>/dev/null
        exec {fd}>&- 2>/dev/null
    else
        print -r -- "$1" | nc -w0 -U "$_PP_SOCK" 2>/dev/null &!
    fi
}

_pp_preexec() {
    _PP_CMD_START=$EPOCHSECONDS
    local cmd="${1//\"/\\\"}"
    # Truncate long commands
    (( ${#cmd} > 200 )) && cmd="${cmd:0:200}..."
    _pp_send "{\"e\":\"exec\",\"t\":$EPOCHSECONDS,\"cmd\":\"$cmd\"}"
}

_pp_precmd() {
    local exit_code=$? dur=0
    if [[ -n "$_PP_CMD_START" ]]; then
        dur=$(( EPOCHSECONDS - _PP_CMD_START ))
    fi
    local git_branch=""
    git_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
    local pwd_escaped="${PWD//\"/\\\"}"

    _pp_send "{\"e\":\"prompt\",\"t\":$EPOCHSECONDS,\"exit\":$exit_code,\"dur\":$dur,\"pwd\":\"$pwd_escaped\",\"git\":\"${git_branch}\"}"
    _PP_CMD_START=""
}

# Only register hooks once
if (( ! ${+_PP_HOOKS_REGISTERED} )); then
    typeset -g _PP_HOOKS_REGISTERED=1
    autoload -Uz add-zsh-hook
    add-zsh-hook preexec _pp_preexec
    add-zsh-hook precmd _pp_precmd
fi
