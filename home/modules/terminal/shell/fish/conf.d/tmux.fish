function __start_tmux
  if not command -v tmux > /dev/null
    return
  end

  if test -n "$TMUX"
    return
  end

  if string match -q "*cursor*" (ps -o comm= -p $fish_pid)
    return
  end

  if not tmux has-session -t screensaver 2>/dev/null
    if type -q bash
      bash -c '
        source ~/.dotfiles/home/modules/terminal/shell/screensaver.sh 2>/dev/null || true
        source ~/.dotfiles/home/modules/terminal/shell/tmux_main.sh 2>/dev/null || true
        _start_screensaver_tmux_session 2>/dev/null || true
        _start_main_tmux_session 2>/dev/null || true
      ' &
    end
  end

  tmux attach -t screensaver 2>/dev/null
end

# Wrapper function for bass-translated bash alias compatibility
function _start_tmux
  __start_tmux $argv
end

if status is-interactive && [ "$TERM" != "dumb" ]
  __start_tmux
end
