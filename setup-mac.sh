#!/bin/bash
set -e
shopt -s extglob

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Ensure TERM is set for tput
export TERM="${TERM:-xterm-256color}"

# ── Colors & Symbols ──────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
MAGENTA='\033[35m'
RESET='\033[0m'
CHECK="${GREEN}◉${RESET}"
UNCHECK="${DIM}○${RESET}"
ARROW="${CYAN}▸${RESET}"
BLANK=" "
PASS="${GREEN}✓${RESET}"
FAIL="${RED}✗${RESET}"

# ── Flags ─────────────────────────────────────────────────────────
OVERWRITE=false
ALL=false
for arg in "$@"; do
  case "$arg" in
    --overwrite) OVERWRITE=true ;;
    --all)       ALL=true ;;
  esac
done

# ── Backup helper ─────────────────────────────────────────────────
BACKUP_DIR="$HOME/.setup-backup/$(date +%Y%m%d-%H%M%S)"
backup_file() {
  local file="$1"
  if [ -f "$file" ]; then
    mkdir -p "$BACKUP_DIR"
    cp "$file" "$BACKUP_DIR/$(basename "$file")"
    echo -e "  ${DIM}Backed up $file${RESET}"
  fi
}

# ── Module definitions ────────────────────────────────────────────
# Sections are visually grouped with headers (empty name = section header)
MODULES=(
  ""
  "Xcode CLT"
  "Xcode"
  "TestFlight"
  "Homebrew"
  ""
  "CLI tools"
  "Dev apps"
  "Office apps"
  "Other apps"
  "VibeProxy"
  "Java & Maven (AEM)"
  ""
  "Rosetta & Node 14 (AEM)"
  "Node.js LTS"
  "npm global packages"
  "Bun"
  "Deno"
  "Expo CLI"
  "Factory CLI"
  ""
  "Zsh config"
  "Starship config"
  "Tmux config"
  "Hammerspoon config"
  "iTerm2 preferences"
  "Claude Code settings"
  "Cursor config"
  ""
  "Spotlight & Raycast"
  "macOS defaults"
  "Screenshots config"
  "Maintenance jobs"
)

DESCRIPTIONS=(
  "─── Prerequisites ───────────────────────────"
  "Install Xcode Command Line Tools"
  "Install full Xcode IDE from App Store"
  "Install TestFlight from App Store"
  "Install Homebrew package manager"
  "─── Packages & Apps ─────────────────────────"
  "gh, starship, tmux, nvm, wireguard, etc."
  "Claude Code, Codex, Cursor, Docker, iTerm2, Postman"
  "Excel, Outlook, PowerPoint, Teams, Word"
  "1Password, Chrome, Hammerspoon, Raycast, Tailscale"
  "LLM proxy menu bar app (automazeio/vibeproxy)"
  "OpenJDK 11, Maven 3.6.3"
  "─── Runtimes ────────────────────────────────"
  "Rosetta 2 + Node 14.21.3 x86_64 for AEM"
  "Install Node.js LTS via nvm"
  "pnpm, opencode, pi-coding-agent"
  "Install Bun runtime"
  "Install Deno runtime"
  "Install Expo CLI (React Native)"
  "Install Factory CLI"
  "─── Dotfiles & Config ──────────────────────"
  "Write ~/.zshrc with aliases & plugins"
  "Write ~/.config/starship.toml"
  "Write ~/.tmux.conf"
  "Write ~/.hammerspoon/init.lua"
  "Import iTerm2 plist"
  "Write ~/.claude/settings.json"
  "Keybindings, settings, and extensions"
  "─── System ─────────────────────────────────"
  "Disable Spotlight, configure Raycast"
  "Dock, keyboard, Finder, wallpaper, dark mode"
  "Screenshot folder & settings"
  "Daily cleanup LaunchAgents"
)

NUM_MODULES=${#MODULES[@]}

# All selected by default (headers are never selected)
SELECTED=()
IS_HEADER=()
for ((i=0; i<NUM_MODULES; i++)); do
  if [ -z "${MODULES[$i]}" ]; then
    SELECTED+=("false")
    IS_HEADER+=("true")
  else
    SELECTED+=("true")
    IS_HEADER+=("false")
  fi
done

# ── Interactive picker ────────────────────────────────────────────
# Start cursor on first non-header
CURSOR=1

draw_menu() {
  if [ "$1" = "redraw" ]; then
    printf '\033[%dA' "$((NUM_MODULES + 5))"
  fi

  echo -e ""
  echo -e "  ${BOLD}${CYAN}↑↓${RESET} navigate  ${BOLD}${CYAN}space${RESET} toggle  ${BOLD}${CYAN}a${RESET} all/none  ${BOLD}${CYAN}enter${RESET} run"
  echo -e ""

  for ((i=0; i<NUM_MODULES; i++)); do
    if [ "${IS_HEADER[$i]}" = "true" ]; then
      printf "       ${DIM}${DESCRIPTIONS[$i]}${RESET}\n"
      continue
    fi

    local cursor_char="$BLANK"
    local check_char="$UNCHECK"
    local name="${MODULES[$i]}"
    local desc="${DESCRIPTIONS[$i]}"

    [ "$i" -eq "$CURSOR" ] && cursor_char="$ARROW"
    [ "${SELECTED[$i]}" = "true" ] && check_char="$CHECK"

    if [ "$i" -eq "$CURSOR" ]; then
      printf "  %b %b  ${BOLD}%-26s${RESET} ${DIM}%s${RESET}\n" "$cursor_char" "$check_char" "$name" "$desc"
    else
      printf "  %b %b  %-26s ${DIM}%s${RESET}\n" "$cursor_char" "$check_char" "$name" "$desc"
    fi
  done

  local count=0
  local total=0
  for ((i=0; i<NUM_MODULES; i++)); do
    [ "${IS_HEADER[$i]}" = "true" ] && continue
    ((total++))
    [ "${SELECTED[$i]}" = "true" ] && ((count++))
  done
  echo -e ""
  echo -e "  ${DIM}${count}/${total} selected${RESET}"
}

move_cursor() {
  local dir="$1"
  local next=$CURSOR
  while true; do
    ((next += dir))
    if [ "$next" -lt 0 ] || [ "$next" -ge "$NUM_MODULES" ]; then
      return  # hit boundary, don't move
    fi
    if [ "${IS_HEADER[$next]}" != "true" ]; then
      CURSOR=$next
      return
    fi
  done
}

run_picker() {
  tput civis
  trap 'tput cnorm' EXIT

  draw_menu "first"

  while true; do
    IFS= read -rsn1 key

    case "$key" in
      $'\x1b')
        read -rsn2 seq
        case "$seq" in
          '[A') move_cursor -1 ;;
          '[B') move_cursor 1 ;;
        esac
        ;;
      ' ')
        if [ "${SELECTED[$CURSOR]}" = "true" ]; then
          SELECTED[$CURSOR]="false"
        else
          SELECTED[$CURSOR]="true"
        fi
        ;;
      'a'|'A')
        local any_selected=false
        for ((i=0; i<NUM_MODULES; i++)); do
          [ "${IS_HEADER[$i]}" = "true" ] && continue
          [ "${SELECTED[$i]}" = "true" ] && any_selected=true && break
        done
        local new_val="true"
        $any_selected && new_val="false"
        for ((i=0; i<NUM_MODULES; i++)); do
          [ "${IS_HEADER[$i]}" = "true" ] && continue
          SELECTED[$i]="$new_val"
        done
        ;;
      '')
        break
        ;;
    esac

    draw_menu "redraw"
  done

  tput cnorm
  echo ""
}

# ── Header ────────────────────────────────────────────────────────
clear
echo -e ""
echo -e "  ${BOLD}${MAGENTA}┌───────────────────────────────┐${RESET}"
echo -e "  ${BOLD}${MAGENTA}│${RESET}  ${BOLD}Mac Dev Environment Setup${RESET}  ${BOLD}${MAGENTA}│${RESET}"
echo -e "  ${BOLD}${MAGENTA}└───────────────────────────────┘${RESET}"

if $OVERWRITE; then
  echo -e "  ${YELLOW}--overwrite: configs will be backed up and replaced${RESET}"
fi

if ! $ALL; then
  run_picker
fi

# ── Count selected ────────────────────────────────────────────────
TOTAL=0
for ((i=0; i<NUM_MODULES; i++)); do
  [ "${IS_HEADER[$i]}" = "true" ] && continue
  [ "${SELECTED[$i]}" = "true" ] && ((TOTAL++))
done

if [ "$TOTAL" -eq 0 ]; then
  echo -e "  ${DIM}Nothing selected. Exiting.${RESET}"
  exit 0
fi

# ── Run helpers ───────────────────────────────────────────────────
is_selected() {
  local name="$1"
  for ((i=0; i<NUM_MODULES; i++)); do
    if [ "${MODULES[$i]}" = "$name" ]; then
      [ "${SELECTED[$i]}" = "true" ] && return 0 || return 1
    fi
  done
  return 1
}

# Pre-authenticate sudo once — password is reused for all modules
echo -e "  ${DIM}Authenticating (password used for all modules that need it)...${RESET}"
read -rsp "  Password: " SUDO_PASS
echo ""
# Create a SUDO_ASKPASS helper that echoes the stored password
ASKPASS_HELPER="$(mktemp)"
printf '#!/bin/bash\necho "%s"\n' "$SUDO_PASS" > "$ASKPASS_HELPER"
chmod 700 "$ASKPASS_HELPER"
export SUDO_ASKPASS="$ASKPASS_HELPER"
# Validate the password
if ! sudo -A -v 2>/dev/null; then
  echo -e "  ${RED}Incorrect password.${RESET}"
  rm -f "$ASKPASS_HELPER"
  exit 1
fi
# Keep sudo alive in the background
while true; do sudo -A -n true; sleep 50; done >/dev/null 2>&1 &
SUDO_PID=$!
trap 'kill $SUDO_PID 2>/dev/null; wait $SUDO_PID 2>/dev/null; rm -f "$ASKPASS_HELPER"; rm -rf "$_SUDO_WRAPPER_DIR"; tput cnorm 2>/dev/null' EXIT
unset SUDO_PASS

# Wrapper so child processes (brew cask post-install, etc.) use ASKPASS
_SUDO_WRAPPER_DIR="$(mktemp -d)"
cat > "$_SUDO_WRAPPER_DIR/sudo" << 'SUDOWRAP'
#!/bin/bash
/usr/bin/sudo -A "$@"
SUDOWRAP
chmod +x "$_SUDO_WRAPPER_DIR/sudo"
export PATH="$_SUDO_WRAPPER_DIR:$PATH"

echo ""
echo -e "  ${BOLD}Running ${TOTAL} modules...${RESET}"
echo ""

CURRENT_MODULE_NAME=""
STREAM_LINES=0
LOG_BUFFER=()
SPIN_IDX=0
SPIN_CHARS='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

PRINTED_LINES=0  # number of lines on screen for current module (header + log lines)

start_module() {
  CURRENT_MODULE_NAME="$1"
  LOG_BUFFER=()
  SPIN_IDX=0
  PRINTED_LINES=1
  printf "  ${CYAN}⠋${RESET} ${BOLD}%s${RESET}\n" "$CURRENT_MODULE_NAME"
}

_redraw() {
  # Move cursor up to erase all printed lines, clear each
  if [ "$PRINTED_LINES" -gt 0 ]; then
    tput cuu "$PRINTED_LINES"
  fi
  tput ed

  # Advance spinner
  SPIN_IDX=$((SPIN_IDX + 1))
  local ch="${SPIN_CHARS:$((SPIN_IDX % ${#SPIN_CHARS})):1}"
  printf "  ${CYAN}%s${RESET} ${BOLD}%s${RESET}\n" "$ch" "$CURRENT_MODULE_NAME"

  # Print last 4 from buffer
  local buf_len=${#LOG_BUFFER[@]}
  local start=$((buf_len > 4 ? buf_len - 4 : 0))
  local cols
  cols=$(tput cols 2>/dev/null || echo 80)
  local max=$((cols - 6))
  PRINTED_LINES=1
  for ((n=start; n<buf_len; n++)); do
    local text="${LOG_BUFFER[$n]}"
    if [ ${#text} -gt $max ]; then
      text="${text:0:$((max - 1))}…"
    fi
    printf "    ${DIM}%s${RESET}\n" "$text"
    PRINTED_LINES=$((PRINTED_LINES + 1))
  done
}

log() {
  local text="$1"
  text="${text//$'\r'/}"
  text="${text//$'\x1b'\[*([0-9;])m/}"
  local clean="${text//[$'\t ']/}"
  [[ -z "$clean" ]] && return

  [[ "$text" == *"Warning: Found a likely App Store"* ]] && return
  [[ "$text" == *"Indexing now, which will not complete"* ]] && return
  [[ "$text" == *"Disable auto-indexing via"* ]] && return
  [[ "$text" == *"MAS_NO_AUTO_INDEX"* ]] && return
  [[ "$text" == *"sometime after mas e"* ]] && return

  LOG_BUFFER+=("$text")
  _redraw
}

_collapse() {
  local symbol="$1"
  if [ "$PRINTED_LINES" -gt 0 ]; then
    tput cuu "$PRINTED_LINES"
  fi
  tput ed
  echo -e "  ${symbol} ${BOLD}${CURRENT_MODULE_NAME}${RESET}"
  PRINTED_LINES=0
  LOG_BUFFER=()
}

finish_ok()   { _collapse "${PASS}"; }
finish_fail() { _collapse "${FAIL}"; }

# Filter noisy mas/brew output
_filter_noise() {
  grep -v -E "Warning: Found a likely App Store|Indexing now, which will not complete|Disable auto-indexing via|sometime after mas|MAS_NO_AUTO_INDEX|Warning: No installed apps found|If this is unexpected|mdimport |# Individual apps|# All apps|# All file system|<LargeAppVolume>|installer\[|PackageKi|IFPKInstall|IFDInstall|Current Path:|Preparing disk|Free space on|Create temporary|Configuring volume|Starting installation|Using authorization|Will use PK session|authorization level|Authorization is being|Administrator authorization|Packages have been authorized|Set authorization level|installer: The upgrade|Standard error:|^\s*$"
}

# Run brew bundle with streaming output
brew_bundle() {
  local file="$1"
  while IFS= read -r line; do
    log "$line"
  done < <(MAS_NO_AUTO_INDEX=1 brew bundle --file="$SCRIPT_DIR/brew/$file" --verbose 2>&1 | _filter_noise)
}

# ── Module implementations ────────────────────────────────────────

# --- Prerequisites ---

if is_selected "Xcode CLT"; then
  start_module "Xcode CLT"
  if ! xcode-select -p &>/dev/null; then
    xcode-select --install
    until xcode-select -p &>/dev/null; do sleep 5; done
  fi
  finish_ok
fi

if is_selected "Xcode"; then
  start_module "Xcode"
  if [ -d "/Applications/Xcode.app" ]; then
    log "Already installed"
  else
    log "Installing Xcode from App Store (this may take a while)..."
    if command -v mas &>/dev/null; then
      while IFS= read -r line; do log "$line"; done < <(MAS_NO_AUTO_INDEX=1 mas install 497799835 2>&1 | _filter_noise)
    else
      log "mas not found — install CLI tools first, then re-run"
      finish_fail
    fi
  fi
  if [ -d "/Applications/Xcode.app" ]; then
    log "Accepting license..."
    sudo -A xcodebuild -license accept 2>/dev/null || true
    log "Setting Xcode as active developer directory..."
    sudo -A xcode-select -s /Applications/Xcode.app/Contents/Developer 2>/dev/null || true
  fi
  finish_ok
fi

if is_selected "TestFlight"; then
  start_module "TestFlight"
  if MAS_NO_AUTO_INDEX=1 mas list 2>/dev/null | grep -q "899247664"; then
    log "Already installed"
  else
    log "Installing TestFlight from App Store..."
    if command -v mas &>/dev/null; then
      while IFS= read -r line; do log "$line"; done < <(MAS_NO_AUTO_INDEX=1 mas install 899247664 2>&1 | _filter_noise)
    else
      log "mas not found — install CLI tools first, then re-run"
      finish_fail
    fi
  fi
  finish_ok
fi

if is_selected "Homebrew"; then
  start_module "Homebrew"
  if ! command -v brew &>/dev/null; then
    while IFS= read -r line; do log "$line"; done < <(/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" 2>&1)
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  finish_ok
fi

# --- Packages & Apps ---

if is_selected "CLI tools"; then
  start_module "CLI tools"
  brew_bundle "cli-tools.Brewfile"
  finish_ok
fi

if is_selected "Dev apps"; then
  start_module "Dev apps"
  brew_bundle "dev-apps.Brewfile"
  finish_ok
fi

if is_selected "Office apps"; then
  start_module "Office apps"
  brew_bundle "office-apps.Brewfile"
  finish_ok
fi

if is_selected "Other apps"; then
  start_module "Other apps"
  brew_bundle "other-apps.Brewfile"
  finish_ok
fi

if is_selected "VibeProxy"; then
  start_module "VibeProxy"
  if [ -d "/Applications/VibeProxy.app" ]; then
    log "Already installed"
  else
    ARCH="$(uname -m)"
    if [ "$ARCH" = "arm64" ]; then
      VP_ASSET="VibeProxy-arm64.zip"
    else
      VP_ASSET="VibeProxy-x86_64.zip"
    fi
    VP_URL="$(curl -fsSL https://api.github.com/repos/automazeio/vibeproxy/releases/latest \
      | grep "browser_download_url.*${VP_ASSET}\"" | head -1 | cut -d '"' -f 4)"
    if [ -n "$VP_URL" ]; then
      log "Downloading ${VP_ASSET}..."
      VP_TMP="$(mktemp -d)"
      curl -fsSL -o "$VP_TMP/$VP_ASSET" "$VP_URL"
      unzip -qo "$VP_TMP/$VP_ASSET" -d "$VP_TMP"
      cp -R "$VP_TMP/VibeProxy.app" /Applications/
      rm -rf "$VP_TMP"
    else
      log "Could not resolve download URL"
      finish_fail
    fi
  fi
  finish_ok
fi

if is_selected "Java & Maven (AEM)"; then
  start_module "Java & Maven (AEM)"
  brew_bundle "java-aem.Brewfile"
  sudo -A ln -sfn /opt/homebrew/opt/openjdk@11/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-11.jdk 2>/dev/null || true
  # Maven 3.6.3 (newer versions break AEM's AutoValue/bundle-plugin)
  if [ ! -d ~/.local/maven/apache-maven-3.6.3 ]; then
    log "Downloading Maven 3.6.3..."
    mkdir -p ~/.local/maven ~/.local/bin
    curl -sL https://archive.apache.org/dist/maven/maven-3/3.6.3/binaries/apache-maven-3.6.3-bin.tar.gz | tar xz -C ~/.local/maven/
  fi
  ln -sfn ~/.local/maven/apache-maven-3.6.3/bin/mvn ~/.local/bin/mvn
  finish_ok
fi

# --- Runtimes ---

if is_selected "Rosetta & Node 14 (AEM)"; then
  start_module "Rosetta & Node 14 (AEM)"
  log "Installing Rosetta 2..."
  softwareupdate --install-rosetta --agree-to-license &>/dev/null || true
  export NVM_DIR="$HOME/.nvm"
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
  while IFS= read -r line; do log "$line"; done < <(arch -x86_64 /bin/zsh -c "export NVM_DIR=\"$HOME/.nvm\" && source /opt/homebrew/opt/nvm/nvm.sh && nvm install 14.21.3" 2>&1)
  nvm use default &>/dev/null || true
  finish_ok
fi

if is_selected "Node.js LTS"; then
  start_module "Node.js LTS"
  export NVM_DIR="$HOME/.nvm"
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
  while IFS= read -r line; do log "$line"; done < <(nvm install --lts 2>&1)
  nvm alias default lts/* &>/dev/null
  finish_ok
fi

if is_selected "npm global packages"; then
  start_module "npm global packages"
  log "Installing pnpm..."
  while IFS= read -r line; do log "$line"; done < <(npm install -g pnpm 2>&1)
  log "Installing opencode..."
  while IFS= read -r line; do log "$line"; done < <(npm install -g opencode 2>&1)
  log "Installing pi-coding-agent..."
  while IFS= read -r line; do log "$line"; done < <(npm install -g @mariozechner/pi-coding-agent 2>&1)
  finish_ok
fi

if is_selected "Bun"; then
  start_module "Bun"
  if ! command -v bun &>/dev/null; then
    while IFS= read -r line; do log "$line"; done < <(curl -fsSL https://bun.sh/install | bash 2>&1)
  fi
  finish_ok
fi

if is_selected "Deno"; then
  start_module "Deno"
  if ! command -v deno &>/dev/null; then
    while IFS= read -r line; do log "$line"; done < <(curl -fsSL https://deno.land/install.sh | sh 2>&1)
  fi
  finish_ok
fi

if is_selected "Expo CLI"; then
  start_module "Expo CLI"
  if ! command -v expo &>/dev/null && ! npm list -g expo-cli &>/dev/null 2>&1; then
    log "Installing expo-cli globally..."
    while IFS= read -r line; do log "$line"; done < <(npm install -g expo-cli eas-cli 2>&1)
  else
    log "Already installed"
  fi
  finish_ok
fi

if is_selected "Factory CLI"; then
  start_module "Factory CLI"
  while IFS= read -r line; do log "$line"; done < <(curl -fsSL https://app.factory.ai/cli | sh 2>&1)
  finish_ok
fi

# --- Dotfiles & Config ---

if is_selected "Zsh config"; then
  start_module "Zsh config"
  if [ -f ~/.zshrc ] && ! $OVERWRITE; then
    log "Exists, skipping (use --overwrite)"
  else
    backup_file ~/.zshrc
    cat > ~/.zshrc << 'ZSHRC'
# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"

# java
export JAVA_HOME="/opt/homebrew/opt/openjdk@11/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

# aliases
alias cc='claude --dangerously-skip-permissions'

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# deno
export DENO_INSTALL="$HOME/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"

# factory cli
export PATH="$HOME/.local/bin:$PATH"

alias b="bun"
alias c="clear"
alias g="git"
alias gs="git status"
alias gp="git push"
alias snapai="npx snapai"

# history substring search (type partial command + up/down arrow)
bindkey '^[[A' history-beginning-search-backward
bindkey '^[[B' history-beginning-search-forward

# zsh plugins
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# starship prompt
eval "$(starship init zsh)"
ZSHRC
  fi
  finish_ok
fi

if is_selected "Starship config"; then
  start_module "Starship config"
  if [ -f ~/.config/starship.toml ] && ! $OVERWRITE; then
    log "Exists, skipping (use --overwrite)"
  else
    backup_file ~/.config/starship.toml
    mkdir -p ~/.config
    cat > ~/.config/starship.toml << 'STARSHIP'
format = "$directory"

[directory]
truncation_length = 1
truncate_to_repo = false
format = "$path › "
STARSHIP
  fi
  finish_ok
fi

if is_selected "Tmux config"; then
  start_module "Tmux config"
  if [ -f ~/.tmux.conf ] && ! $OVERWRITE; then
    log "Exists, skipping (use --overwrite)"
  else
    backup_file ~/.tmux.conf
    cat > ~/.tmux.conf << 'TMUXCONF'
set -g mouse on

# Vim-style pane switching with Ctrl+hjkl
bind -n C-h select-pane -L
bind -n C-j select-pane -D
bind -n C-k select-pane -U
bind -n C-l select-pane -R

# Copy to system clipboard
set -g set-clipboard on
bind -T copy-mode MouseDragEnd1Pane send -X copy-pipe-and-cancel "pbcopy"
bind -T copy-mode-vi MouseDragEnd1Pane send -X copy-pipe-and-cancel "pbcopy"

# Status bar with gray border line on top
set -g status 2
set -g status-format[0] "#[bg=black,fg=colour240]#{p-#{client_width}:─}"
set -g status-format[1] "#[bg=black,fg=white] #S  #W #[align=right] %H:%M %d-%b "
set -g status-style "bg=black,fg=white"

# Pane border colors
set -g pane-border-style fg=grey
set -g pane-active-border-style fg=green
TMUXCONF
  fi
  finish_ok
fi

if is_selected "Hammerspoon config"; then
  start_module "Hammerspoon config"
  if [ -f ~/.hammerspoon/init.lua ] && ! $OVERWRITE; then
    log "Exists, skipping (use --overwrite)"
  else
    backup_file ~/.hammerspoon/init.lua
    mkdir -p ~/.hammerspoon
    cat > ~/.hammerspoon/init.lua << 'HAMMERSPOON'
require("hs.ipc")

-- Option+Command+F: Maximize active window (not fullscreen)
hs.hotkey.bind({"alt", "cmd"}, "F", function()
  local win = hs.window.focusedWindow()
  if win then
    win:maximize()
  end
end)

-- Option+Command+Left: Left half of screen, full height
hs.hotkey.bind({"alt", "cmd"}, "Left", function()
  local win = hs.window.focusedWindow()
  if win then
    local screen = win:screen():frame()
    win:setFrame(hs.geometry.rect(screen.x, screen.y, screen.w / 2, screen.h))
  end
end)

-- Option+Command+Right: Right half of screen, full height
hs.hotkey.bind({"alt", "cmd"}, "Right", function()
  local win = hs.window.focusedWindow()
  if win then
    local screen = win:screen():frame()
    win:setFrame(hs.geometry.rect(screen.x + screen.w / 2, screen.y, screen.w / 2, screen.h))
  end
end)

-- Option+Command+Up: Top half of screen, full width
hs.hotkey.bind({"alt", "cmd"}, "Up", function()
  local win = hs.window.focusedWindow()
  if win then
    local screen = win:screen():frame()
    win:setFrame(hs.geometry.rect(screen.x, screen.y, screen.w, screen.h / 2))
  end
end)

-- Option+Command+Down: Bottom half of screen, full width
hs.hotkey.bind({"alt", "cmd"}, "Down", function()
  local win = hs.window.focusedWindow()
  if win then
    local screen = win:screen():frame()
    win:setFrame(hs.geometry.rect(screen.x, screen.y + screen.h / 2, screen.w, screen.h / 2))
  end
end)

-- Ctrl+Command+1: Left third of screen, full height
hs.hotkey.bind({"ctrl", "cmd"}, "1", function()
  local win = hs.window.focusedWindow()
  if win then
    local screen = win:screen():frame()
    win:setFrame(hs.geometry.rect(screen.x, screen.y, screen.w / 3, screen.h))
  end
end)

-- Ctrl+Command+2: Center third of screen, full height
hs.hotkey.bind({"ctrl", "cmd"}, "2", function()
  local win = hs.window.focusedWindow()
  if win then
    local screen = win:screen():frame()
    win:setFrame(hs.geometry.rect(screen.x + screen.w / 3, screen.y, screen.w / 3, screen.h))
  end
end)

-- Ctrl+Command+3: Right third of screen, full height
hs.hotkey.bind({"ctrl", "cmd"}, "3", function()
  local win = hs.window.focusedWindow()
  if win then
    local screen = win:screen():frame()
    win:setFrame(hs.geometry.rect(screen.x + 2 * screen.w / 3, screen.y, screen.w / 3, screen.h))
  end
end)

-- Ctrl+Option+Command+Arrow: Move window to monitor in that direction
local function moveToScreen(direction)
  local win = hs.window.focusedWindow()
  if not win then return end
  local current = win:screen()
  local target = current[direction](current)
  if target then
    win:moveToScreen(target, true, true)
  end
end

hs.hotkey.bind({"ctrl", "alt", "cmd"}, "Left", function() moveToScreen("toWest") end)
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "Right", function() moveToScreen("toEast") end)
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "Up", function() moveToScreen("toNorth") end)
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "Down", function() moveToScreen("toSouth") end)
HAMMERSPOON
  fi
  finish_ok
fi

if is_selected "iTerm2 preferences"; then
  start_module "iTerm2 preferences"
  if [ -f ~/Library/Preferences/com.googlecode.iterm2.plist ] && ! $OVERWRITE; then
    log "Exists, skipping (use --overwrite)"
  elif [ -f "$SCRIPT_DIR/iterm2-profile.plist" ]; then
    backup_file ~/Library/Preferences/com.googlecode.iterm2.plist
    cp "$SCRIPT_DIR/iterm2-profile.plist" ~/Library/Preferences/com.googlecode.iterm2.plist
    sed -i '' "s|/Users/mirzajoldic|$HOME|g" ~/Library/Preferences/com.googlecode.iterm2.plist
    defaults read com.googlecode.iterm2 &>/dev/null
  else
    log "iterm2-profile.plist not found, skipping"
  fi
  finish_ok
fi

if is_selected "Claude Code settings"; then
  start_module "Claude Code settings"
  if [ -f ~/.claude/settings.json ] && ! $OVERWRITE; then
    log "Exists, skipping (use --overwrite)"
  else
    backup_file ~/.claude/settings.json
    mkdir -p ~/.claude
    cat > ~/.claude/settings.json << CLAUDESETTINGS
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/rtk-rewrite.sh"
          }
        ]
      }
    ]
  },
  "skipDangerousModePermissionPrompt": true
}
CLAUDESETTINGS
  fi
  finish_ok
fi

if is_selected "Cursor config"; then
  start_module "Cursor config"
  CURSOR_USER_DIR="$HOME/Library/Application Support/Cursor/User"
  if [ -f "$CURSOR_USER_DIR/keybindings.json" ] && ! $OVERWRITE; then
    log "Keybindings exist, skipping (use --overwrite)"
  else
    backup_file "$CURSOR_USER_DIR/keybindings.json"
    mkdir -p "$CURSOR_USER_DIR"
    cat > "$CURSOR_USER_DIR/keybindings.json" << 'CURSORKEYS'
[
  {
    "key": "ctrl+p",
    "command": "workbench.action.quickOpen"
  },
  {
    "key": "ctrl+j",
    "command": "workbench.action.terminal.toggleTerminal"
  },
  {
    "key": "ctrl+k",
    "command": "workbench.action.focusActiveEditorGroup"
  },
  {
    "key": "ctrl+h",
    "command": "workbench.files.action.focusFilesExplorer",
    "when": "editorTextFocus"
  },
  {
    "key": "ctrl+h",
    "command": "workbench.action.focusActiveEditorGroup",
    "when": "auxiliaryBarFocus"
  },
  {
    "key": "ctrl+l",
    "command": "workbench.action.focusActiveEditorGroup",
    "when": "filesExplorerFocus && !inputFocus"
  },
  {
    "key": "ctrl+l",
    "command": "workbench.action.focusAuxiliaryBar",
    "when": "!filesExplorerFocus"
  },
  {
    "key": "ctrl+\\",
    "command": "workbench.action.toggleAuxiliaryBar"
  },
  {
    "key": "enter",
    "command": "-renameFile",
    "when": "explorerViewletVisible && filesExplorerFocus && !explorerResourceIsRoot && !explorerResourceIsReadonly && !inputFocus"
  },
  {
    "key": "enter",
    "command": "list.select",
    "when": "filesExplorerFocus && !inputFocus"
  }
]
CURSORKEYS
  fi
  if [ -f "$CURSOR_USER_DIR/settings.json" ] && ! $OVERWRITE; then
    log "Settings exist, skipping (use --overwrite)"
  else
    backup_file "$CURSOR_USER_DIR/settings.json"
    mkdir -p "$CURSOR_USER_DIR"
    cat > "$CURSOR_USER_DIR/settings.json" << 'CURSORSETTINGS'
{
    "window.commandCenter": true,
    "git.openRepositoryInParentFolders": "always"
}
CURSORSETTINGS
  fi
  log "Installing extensions..."
  if command -v cursor &>/dev/null; then
    while IFS= read -r line; do log "$line"; done < <(cursor --install-extension vscodevim.vim 2>&1)
  else
    log "Cursor CLI not found, skipping extensions"
  fi
  finish_ok
fi

# --- System ---

if is_selected "Spotlight & Raycast"; then
  start_module "Spotlight & Raycast"
  sudo -A mdutil -a -i off >/dev/null 2>&1
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 '{ enabled = 0; value = { parameters = (32, 49, 1048576); type = standard; }; }'
  defaults write com.raycast.macos raycastGlobalHotkey -string "Control-49"
  finish_ok
fi

if is_selected "macOS defaults"; then
  start_module "macOS defaults"
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock orientation -string "left"
  defaults write -g InitialKeyRepeat -int 15
  defaults write -g KeyRepeat -int 2
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  killall Finder 2>/dev/null || true
  defaults -currentHost write -g com.apple.keyboard.modifiermapping.0-0-0 -array \
    '<dict><key>HIDKeyboardModifierMappingSrc</key><integer>30064771129</integer><key>HIDKeyboardModifierMappingDst</key><integer>30064771300</integer></dict>'
  osascript -e 'tell application "System Events" to tell every desktop to set picture to "/System/Library/Desktop Pictures/Solid Colors/Black.png"' 2>/dev/null || true
  defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false
  defaults write com.apple.WindowManager StandardHideDesktopIcons -bool true
  defaults write -g AppleInterfaceStyle -string "Dark"
  killall Dock 2>/dev/null || true
  finish_ok
fi

if is_selected "Screenshots config"; then
  start_module "Screenshots config"
  mkdir -p ~/Screenshots
  defaults write com.apple.screencapture location ~/Screenshots
  defaults write com.apple.screencapture show-thumbnail -bool false
  killall SystemUIServer 2>/dev/null || true
  finish_ok
fi

if is_selected "Maintenance jobs"; then
  start_module "Maintenance jobs"
  mkdir -p ~/Library/LaunchAgents ~/.local/scripts

  cat > ~/.local/scripts/cleanup-screenshots.sh << 'SCRIPT'
#!/bin/bash
find ~/Screenshots -type f -delete 2>/dev/null
echo "$(date): Screenshots cleared" >> ~/.daily-cleanup.log
SCRIPT

  cat > ~/.local/scripts/cleanup-dev-cache.sh << 'SCRIPT'
#!/bin/bash
export PATH="/opt/homebrew/bin:$HOME/.bun/bin:$HOME/.nvm/versions/node/$(ls ~/.nvm/versions/node/ | tail -1)/bin:$PATH"
npm cache clean --force 2>/dev/null
bun pm cache rm 2>/dev/null
echo "$(date): Dev caches cleared" >> ~/.daily-cleanup.log
SCRIPT

  cat > ~/.local/scripts/cleanup-brew.sh << 'SCRIPT'
#!/bin/bash
/opt/homebrew/bin/brew cleanup --prune=7 2>/dev/null
echo "$(date): Homebrew cleaned" >> ~/.daily-cleanup.log
SCRIPT

  cat > ~/.local/scripts/upgrade-brew.sh << 'SCRIPT'
#!/bin/bash
/opt/homebrew/bin/brew update 2>/dev/null
/opt/homebrew/bin/brew upgrade 2>/dev/null
/opt/homebrew/bin/brew upgrade --cask --greedy 2>/dev/null
echo "$(date): Homebrew upgraded" >> ~/.daily-cleanup.log
SCRIPT

  cat > ~/.local/scripts/cleanup-logs.sh << 'SCRIPT'
#!/bin/bash
find ~/Library/Logs -type f -mtime +7 -delete 2>/dev/null
echo "$(date): Old logs cleared" >> ~/.daily-cleanup.log
SCRIPT

  cat > ~/.local/scripts/cleanup-browsers.sh << 'SCRIPT'
#!/bin/bash
rm -rf ~/Library/Caches/Google/Chrome/Default/Cache/* 2>/dev/null
rm -rf ~/Library/Caches/Google/Chrome/Default/Code\ Cache/* 2>/dev/null
rm -rf ~/Library/Caches/com.apple.Safari/WebKitCache/* 2>/dev/null
echo "$(date): Browser caches cleared" >> ~/.daily-cleanup.log
SCRIPT

  cat > ~/.local/scripts/cleanup-temp.sh << 'SCRIPT'
#!/bin/bash
find /tmp -maxdepth 1 -type f -mtime +7 -delete 2>/dev/null
find ~/Library/Caches -type f -mtime +7 -delete 2>/dev/null
echo "$(date): Temp/caches cleared" >> ~/.daily-cleanup.log
SCRIPT

  chmod +x ~/.local/scripts/cleanup-*.sh ~/.local/scripts/upgrade-*.sh

  create_cleanup_agent() {
    local name="$1" hour="$2" minute="$3" script="$4"
    local plist=~/Library/LaunchAgents/com.user.cleanup-${name}.plist
    if [ -f "$plist" ] && ! $OVERWRITE; then
      log "cleanup-${name} exists, skipping"
      return
    fi
    launchctl unload "$plist" 2>/dev/null || true
    cat > "$plist" << LAUNCHD
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.cleanup-${name}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${script}</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>${hour}</integer>
        <key>Minute</key>
        <integer>${minute}</integer>
    </dict>
</dict>
</plist>
LAUNCHD
    launchctl load "$plist"
  }

  create_cleanup_agent "screenshots"   3  0  "$HOME/.local/scripts/cleanup-screenshots.sh"
  create_cleanup_agent "dev-cache"     8  0  "$HOME/.local/scripts/cleanup-dev-cache.sh"
  create_cleanup_agent "brew"         12  0  "$HOME/.local/scripts/cleanup-brew.sh"
  create_cleanup_agent "brew-upgrade"  9  0  "$HOME/.local/scripts/upgrade-brew.sh"
  create_cleanup_agent "logs"         16  0  "$HOME/.local/scripts/cleanup-logs.sh"
  create_cleanup_agent "browsers"     20  0  "$HOME/.local/scripts/cleanup-browsers.sh"
  create_cleanup_agent "temp"         23  0  "$HOME/.local/scripts/cleanup-temp.sh"
  finish_ok
fi

# ── Done ──────────────────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}${GREEN}Setup complete!${RESET}"
if [ -d "$BACKUP_DIR" ]; then
  echo -e "  ${DIM}Backups: $BACKUP_DIR${RESET}"
fi
echo ""

zsh -c 'source ~/.zshrc' 2>/dev/null || true
