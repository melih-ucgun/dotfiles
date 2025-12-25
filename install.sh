#!/bin/bash
set -e

# --- Tokyo Night Color Palette ---
BOLD='\033[1m'
TN_PURPLE='\033[1;35m' # #bb9af7
TN_BLUE='\033[1;34m'   # #7aa2f7
TN_CYAN='\033[1;36m'   # #7dcfff
TN_GREEN='\033[1;32m'  # #9ece6a
TN_RED='\033[1;31m'    # #f7768e
TN_YELLOW='\033[1;33m' # #e0af68
NC='\033[0m' # No Color

# --- Global Variables ---
SUDO_PID=""
FAILED_PACKAGES=()
DRY_RUN=false
BACKUP_DIR="$HOME/.monarch_backups/$(date +%Y%m%d_%H%M%S)"

# --- Helper Functions ---

print_banner() {
    clear
    echo -e "${TN_PURPLE}${BOLD}"
    cat << "EOF"
                                                                     oooo        
                                                                     `888        
ooo. .oo.  .oo.    .ooooo.  ooo. .oo.    .oooo.   oooo d8b  .ooooo.   888 .oo.   
`888P"Y88bP"Y88b  d88' `88b `888P"Y88b  `P  )88b  `888""8P d88' `"Y8  888P"Y88b  
 888   888   888  888   888  888   888   .oP"888   888     888        888   888  
 888   888   888  888   888  888   888  d8(  888   888     888   .o8  888   888  
o888o o888o o888o `Y8bod8P' o888o o888o `Y888""8o d888b    `Y8bod8P' o888o o888o 
                                                                                 
                                                                                 
                                                                                 
                                               
EOF
    echo -e "${TN_BLUE}   >> a hyprland workstation by melih <<${NC}"
    echo -e "${TN_PURPLE}$(printf '%*s' "$(tput cols)" '' | tr ' ' '=')${NC}\n"
}

header() {
    echo -e "\n${TN_PURPLE}${BOLD}==>${NC} ${TN_BLUE}${BOLD}$1${NC}"
    echo -e "${TN_PURPLE}$(printf '%*s' "$(tput cols)" '' | tr ' ' '-')${NC}"
}

step() {
    echo -e "${TN_GREEN}${BOLD}:: [$1] $2${NC}"
}

log() {
    echo -e "  ${TN_CYAN}->${NC} $1"
}

warn() {
    echo -e "  ${TN_YELLOW}[!] $1${NC}"
}

error() {
    echo -e "  ${TN_RED}[ERROR] $1${NC}"
}

success() {
    echo -e "  ${TN_GREEN}[✓] $1${NC}"
}

# Cleanup function
cleanup() {
    if [ -n "$SUDO_PID" ]; then
        kill "$SUDO_PID" 2>/dev/null
        log "Cleaned up sudo keep-alive process"
    fi
}

# Trap EXIT signal
trap cleanup EXIT INT TERM

# Backup function
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        mkdir -p "$BACKUP_DIR"
        local backup_path="$BACKUP_DIR/$(basename "$file")"
        cp "$file" "$backup_path"
        log "Backed up: $file -> $backup_path"
        return 0
    fi
    return 1
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check disk space (in KB)
check_disk_space() {
    local required_space=10485760  # 10GB in KB
    local free_space=$(df / | awk 'NR==2 {print $4}')
    
    if [ "$free_space" -lt "$required_space" ]; then
        error "Insufficient disk space. Required: 10GB, Available: $((free_space / 1024 / 1024))GB"
        exit 1
    fi
    success "Disk space check passed (Available: $((free_space / 1024 / 1024))GB)"
}

# Install package with error handling
install_package() {
    local pkg="$1"
    local use_aur="${2:-false}"
    
    if [ "$DRY_RUN" = true ]; then
        log "[DRY-RUN] Would install: $pkg"
        return 0
    fi
    
    if [ "$use_aur" = true ]; then
        if paru -S --needed --noconfirm "$pkg" 2>/dev/null; then
            return 0
        fi
    else
        if sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null; then
            return 0
        fi
    fi
    
    FAILED_PACKAGES+=("$pkg")
    warn "Failed to install: $pkg"
    return 1
}

# Enable service with idempotency
enable_service() {
    local service="$1"
    
    if [ "$DRY_RUN" = true ]; then
        log "[DRY-RUN] Would enable: $service"
        return 0
    fi
    
    if systemctl is-enabled "$service" &>/dev/null; then
        log "[ALREADY ENABLED] $service"
    else
        if sudo systemctl enable --now "$service" &>/dev/null; then
            success "[ENABLED] $service"
        else
            warn "Failed to enable: $service"
            return 1
        fi
    fi
}

# =============================================================================
# PHASE 0: PRE-FLIGHT CHECKS
# =============================================================================

print_banner

# Parse arguments
if [ "$1" = "--dry-run" ]; then
    DRY_RUN=true
    warn "Running in DRY-RUN mode. No changes will be made."
    sleep 2
fi

log "Initializing Monarch protocol..."
log "Target System: Lenovo Ideapad Slim 5 (Ryzen 7)"

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    error "Please do not run this script as root or with sudo!"
    exit 1
fi

# Check disk space
check_disk_space

# Check internet connectivity
if ! ping -c 1 archlinux.org &> /dev/null; then
    error "No internet connection detected!"
    exit 1
fi
success "Internet connection verified"

# Request Sudo Privileges
log "Requesting sudo privileges..."
if ! sudo -v; then
    error "Failed to obtain sudo privileges"
    exit 1
fi

# Keep-alive: update existing sudo time stamp with proper cleanup
if [ "$DRY_RUN" = false ]; then
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    SUDO_PID=$!
fi

# Collect Git Identity
GIT_USER=""
GIT_EMAIL=""

echo -e "\n${TN_YELLOW}:: Configure Git Identity (Press Enter to skip)${NC}"
read -p "   Git Username: " GIT_USER
read -p "   Git Email: "    GIT_EMAIL

log "Inputs received. Starting automated installation..."
log "Sit back and relax. This will take a while."
[ "$DRY_RUN" = false ] && sleep 3

# =============================================================================
# CONFIGURATION VARIABLES
# =============================================================================

DOTFILES_REPO="https://github.com/melih-ucgun/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

# Package Lists
OFFICIAL_PACKAGES=(
    base base-devel linux-cachyos linux-cachyos-headers linux-cachyos-lts linux-cachyos-lts-headers
    linux-firmware amd-ucode chwd mkinitcpio systemd-boot-manager efibootmgr efitools refind 
    sudo git stow wget curl btop fastfetch lsb-release man-db man-pages
    pacman-contrib pkgfile plocate reflector rsync tealdeer which 
    zip unzip unrar p7zip ufw firejail dosfstools e2fsprogs xfsprogs btrfs-progs
    exfatprogs ntfs-3g hdparm smartmontools duf ncdu ripgrep less
    brightnessctl cpupower power-profiles-daemon upower 
    networkmanager network-manager-applet iwd bluez bluez-utils bluetui modemmanager
    usbutils usb_modeswitch
    cachyos-hello cachyos-hooks cachyos-kernel-manager cachyos-keyring
    cachyos-mirrorlist cachyos-packageinstaller cachyos-plymouth-bootanimation
    cachyos-rate-mirrors cachyos-settings cachyos-snapper-support
    cachyos-v3-mirrorlist cachyos-v4-mirrorlist
    hyprland hyprlock hyprpaper hyprpolkitagent hyprshot 
    xdg-desktop-portal-hyprland xdg-user-dirs waybar waypaper rofi-wayland
    swaync swayosd nwg-look cliphist qt6-wayland
    kitty helium-browser-bin zen-browser-bin imv mpv zathura zathura-pdf-mupdf
    pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber
    pavucontrol alsa-utils alsa-firmware alsa-plugins sof-firmware
    bitwig-studio cardinal-vst surge-xt yabridge yabridgectl audacity pd impala rtkit
    neovim python python-pip python-packaging python-lsp-server python-defusedxml
    nodejs npm rustup lldb perl godot gamescope steam obsidian obs-studio 
    docker docker-buildx ananicy-cpp
    ttf-jetbrains-mono-nerd ttf-meslo-nerd ttf-dejavu ttf-liberation
    ttf-opensans ttf-bitstream-vera noto-fonts noto-fonts-cjk noto-fonts-emoji
    noto-color-emoji-fontconfig awesome-terminal-fonts cantarell-fonts adwaita-icon-theme
    gst-libav gst-plugin-pipewire gst-plugin-va gst-plugins-bad gst-plugins-ugly
    ffmpegthumbnailer libdvdcss bitwarden localsend onlyoffice-bin
    thunar thunar-archive-plugin thunar-media-tags-plugin thunar-volman tumbler
    gvfs gvfs-mtp gvfs-smb file-roller satty yazi zed zsh proton-vpn-gtk-app
)

AUR_PACKAGES=(paru pacseek npcamixer spotify zoom tokyonight-gtk-theme-git)

# =============================================================================
# PHASE 1: SYSTEM PREPARATION
# =============================================================================
header "PHASE 1/7: System Preparation"

step "1/7" "Updating Pacman Database..."
if [ "$DRY_RUN" = false ]; then
    if ! sudo pacman -Syu --noconfirm; then
        error "Failed to update system. Please check your internet connection."
        exit 1
    fi
fi

log "Checking core tools (git, base-devel, stow)..."
for tool in git base-devel stow; do
    install_package "$tool" false
done

if ! command_exists paru; then
    warn "Paru (AUR Helper) not found. Installing..."
    if [ "$DRY_RUN" = false ]; then
        if ! sudo pacman -S --needed --noconfirm paru 2>/dev/null; then
            log "Compiling paru from AUR..."
            if ! git clone https://aur.archlinux.org/paru.git /tmp/paru; then
                error "Failed to clone paru repository"
                exit 1
            fi
            cd /tmp/paru
            if ! makepkg -si --noconfirm; then
                error "Failed to build paru"
                exit 1
            fi
            cd - > /dev/null
            rm -rf /tmp/paru
        fi
    fi
else
    success "Paru is already installed."
fi

# =============================================================================
# PHASE 2: PACKAGE INJECTION
# =============================================================================
header "PHASE 2/7: Package Injection"

step "2/7" "Installing Official Packages..."
log "This may take a while..."

for pkg in "${OFFICIAL_PACKAGES[@]}"; do
    install_package "$pkg" false
done

step "2/7" "Installing AUR Packages..."
for pkg in "${AUR_PACKAGES[@]}"; do
    install_package "$pkg" true
done

if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
    warn "The following packages failed to install:"
    for pkg in "${FAILED_PACKAGES[@]}"; do
        echo -e "    ${TN_RED}- $pkg${NC}"
    done
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Installation aborted by user"
        exit 1
    fi
fi

# =============================================================================
# PHASE 3: SHELL & THEME
# =============================================================================
header "PHASE 3/7: Shell Configuration"
step "3/7" "Oh My Zsh & Powerlevel10k Setup"

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log "Downloading Oh My Zsh..."
    if [ "$DRY_RUN" = false ]; then
        backup_file "$HOME/.zshrc"
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        rm -f "$HOME/.zshrc"
        log "Removed default .zshrc to avoid conflicts."
    fi
else
    success "Oh My Zsh already installed"
fi

if [ ! -d "${ZSH_CUSTOM}/themes/powerlevel10k" ]; then
    log "Fetching Powerlevel10k theme..."
    if [ "$DRY_RUN" = false ]; then
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM}/themes/powerlevel10k
    fi
else
    success "Powerlevel10k already installed"
fi

log "Installing Zsh plugins..."
declare -A ZSH_PLUGINS=(
    ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
    ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
    ["zsh-completions"]="https://github.com/zsh-users/zsh-completions"
)

for plugin in "${!ZSH_PLUGINS[@]}"; do
    plugin_dir="${ZSH_CUSTOM}/plugins/${plugin}"
    if [ ! -d "$plugin_dir" ]; then
        if [ "$DRY_RUN" = false ]; then
            git clone "${ZSH_PLUGINS[$plugin]}" "$plugin_dir"
        fi
        log "Installed: $plugin"
    else
        success "$plugin already installed"
    fi
done

# =============================================================================
# PHASE 4: DOTFILES
# =============================================================================
header "PHASE 4/7: Dotfiles Synchronization"
step "4/7" "Initiating Stow"

if [ ! -d "$DOTFILES_DIR" ]; then
    log "Cloning repository: $DOTFILES_REPO"
    if [ "$DRY_RUN" = false ]; then
        if ! git clone "$DOTFILES_REPO" "$DOTFILES_DIR"; then
            error "Failed to clone dotfiles repository"
            exit 1
        fi
    fi
else
    log "Repository exists. Updating..."
    if [ "$DRY_RUN" = false ]; then
        cd "$DOTFILES_DIR" || exit 1
        if ! git pull; then
            error "Failed to update dotfiles"
            exit 1
        fi
        cd - > /dev/null
    fi
fi

if [ "$DRY_RUN" = false ]; then
    cd "$DOTFILES_DIR" || exit 1
    
    # Backup existing dotfiles before stowing
    log "Creating backups of existing configurations..."
    for dir in */; do
        dirname=$(basename "$dir")
        if [ "$dirname" != ".git" ]; then
            # Find all files that would be linked
            while IFS= read -r file; do
                target="$HOME/$file"
                if [ -f "$target" ] && [ ! -L "$target" ]; then
                    backup_file "$target"
                fi
            done < <(find "$dirname" -type f | sed "s|^$dirname/||")
        fi
    done
    
    # Now stow without --adopt to preserve repo
    log "Linking configurations..."
    for dir in */; do
        dirname=$(basename "$dir")
        if [ "$dirname" != ".git" ]; then
            log "Stowing: $dirname"
            if stow -v "$dirname" 2>&1 | grep -q "WARNING"; then
                warn "Conflicts detected in $dirname, using restow"
                stow -R -v "$dirname"
            fi
        fi
    done
    
    cd "$HOME" || exit 1
    success "Dotfiles synchronized successfully."
    [ -d "$BACKUP_DIR" ] && log "Backups saved to: $BACKUP_DIR"
fi

# =============================================================================
# PHASE 5: SERVICES & LIMITS
# =============================================================================
header "PHASE 5/7: Service Management"
step "5/7" "Audio & Systemd Optimization"

LIMITS_FILE="/etc/security/limits.d/99-realtime-audio.conf"
if [ ! -f "$LIMITS_FILE" ]; then
    log "Setting up Realtime Audio Limits (Bitwig/Pipewire)..."
    if [ "$DRY_RUN" = false ]; then
        echo "@audio   -  rtprio     95" | sudo tee "$LIMITS_FILE" > /dev/null
        echo "@audio   -  memlock    unlimited" | sudo tee -a "$LIMITS_FILE" > /dev/null
    fi
else
    success "Audio limits already configured."
fi

SERVICES=(NetworkManager iwd bluetooth ufw ananicy-cpp docker fstrim.timer snapper-cleanup.timer)
for service in "${SERVICES[@]}"; do
    enable_service "$service"
done

log "Adding user to groups..."
if [ "$DRY_RUN" = false ]; then
    sudo usermod -aG wheel,video,audio,input,docker,uucp "$USER"
fi

if command_exists yabridgectl; then
    log "Syncing Yabridge VSTs..."
    if [ "$DRY_RUN" = false ]; then
        yabridgectl sync &>/dev/null
        success "Yabridge VST sync complete."
    fi
fi

# =============================================================================
# PHASE 6: FINAL TWEAKS
# =============================================================================
header "PHASE 6/7: Final Tweaks"

# 1. Apply Git Configuration
if [ -n "$GIT_USER" ] && [ -n "$GIT_EMAIL" ]; then
    log "Applying Git identity settings..."
    if [ "$DRY_RUN" = false ]; then
        git config --global user.name "$GIT_USER"
        git config --global user.email "$GIT_EMAIL"
        success "Git configured: $GIT_USER <$GIT_EMAIL>"
    fi
else
    warn "Git identity skipped (no input provided at start)."
fi

# 2. Change Shell
if [ "$(basename "$SHELL")" != "zsh" ]; then
    log "Changing default shell to Zsh..."
    if [ "$DRY_RUN" = false ]; then
        if ! sudo chsh -s "$(which zsh)" "$USER"; then
            warn "Failed to change shell. You may need to run: chsh -s \$(which zsh)"
        else
            success "Default shell changed to Zsh"
        fi
    fi
else
    success "Already using Zsh"
fi

# 3. Refresh Cache
log "Refreshing UI and Font cache..."
if [ "$DRY_RUN" = false ]; then
    fc-cache -fv &>/dev/null
    sudo glib-compile-schemas /usr/share/glib-2.0/schemas/ &>/dev/null
fi

# 4. SSD Trim
log "Optimizing Disk (fstrim)..."
if [ "$DRY_RUN" = false ]; then
    sudo fstrim -v / 2>/dev/null || warn "fstrim failed or not applicable"
fi

# =============================================================================
# PHASE 7: POST-INSTALLATION REPORT
# =============================================================================
header "PHASE 7/7: Installation Report"

echo ""
if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
    warn "Installation completed with ${#FAILED_PACKAGES[@]} failed packages:"
    for pkg in "${FAILED_PACKAGES[@]}"; do
        echo -e "    ${TN_RED}- $pkg${NC}"
    done
    echo ""
fi

if [ -d "$BACKUP_DIR" ]; then
    log "Configuration backups: $BACKUP_DIR"
fi

# =============================================================================
# COMPLETION
# =============================================================================
header "INSTALLATION SUCCESSFUL"
echo -e "${TN_PURPLE}"
cat << "EOF"
                                                                     oooo        
                                                                     `888        
ooo. .oo.  .oo.    .ooooo.  ooo. .oo.    .oooo.   oooo d8b  .ooooo.   888 .oo.   
`888P"Y88bP"Y88b  d88' `88b `888P"Y88b  `P  )88b  `888""8P d88' `"Y8  888P"Y88b  
 888   888   888  888   888  888   888   .oP"888   888     888        888   888  
 888   888   888  888   888  888   888  d8(  888   888     888   .o8  888   888  
o888o o888o o888o `Y8bod8P' o888o o888o `Y888""8o d888b    `Y8bod8P' o888o o888o 
                                                                                 
                                                                                 
                                                                                 
                                               
EOF
echo -e "${NC}"
echo -e "${TN_BLUE}>> SYSTEM IS READY FOR HYPRLAND <<${NC}"
echo -e "${TN_CYAN}Please reboot your system: ${BOLD}sudo reboot${NC}"

if [ "$DRY_RUN" = true ]; then
    echo -e "\n${TN_YELLOW}Note: This was a DRY-RUN. No actual changes were made.${NC}"
fi

echo -e "${TN_PURPLE}$(printf '%*s' "$(tput cols)" '' | tr ' ' '=')${NC}\n"
