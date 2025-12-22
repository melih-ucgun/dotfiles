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

# =============================================================================
# PHASE 0: INITIALIZATION (USER INPUTS)
# =============================================================================

print_banner
log "Initializing Monarch protocol..."
log "Target System: Lenovo Ideapad Slim 5 (Ryzen 7)"

# 1. Request Sudo Privileges Immediately
log "Requesting sudo privileges..."
sudo -v
# Keep-alive: update existing sudo time stamp if set, otherwise do nothing.
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# 2. Collect Git Identity (To be applied in Phase 6)
# Asking this NOW so the user doesn't have to wait during the installation.
GIT_USER=""
GIT_EMAIL=""

echo -e "${TN_YELLOW}:: Configure Git Identity (Press Enter to skip)${NC}"
read -p "   Git Username: " GIT_USER
read -p "   Git Email: "    GIT_EMAIL

log "Inputs received. Starting automated installation..."
log "Sit back and relax. This will take a while."
sleep 3

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
sudo pacman -Syu --noconfirm

log "Checking core tools (git, base-devel, stow)..."
sudo pacman -S --needed --noconfirm git base-devel stow

if ! command -v paru &> /dev/null; then
    warn "Paru (AUR Helper) not found. Compiling..."
    if ! sudo pacman -S --needed --noconfirm paru; then
        git clone https://aur.archlinux.org/paru.git /tmp/paru
        cd /tmp/paru && makepkg -si --noconfirm && cd - && rm -rf /tmp/paru
    fi
else
    log "Paru is already installed."
fi

# =============================================================================
# PHASE 2: PACKAGE INJECTION
# =============================================================================
header "PHASE 2/7: Package Injection"
log "Downloading and installing packages..."

step "2/7" "Installing Official Packages..."
sudo pacman -S --needed --noconfirm "${OFFICIAL_PACKAGES[@]}"

step "2/7" "Installing AUR Packages..."
paru -S --needed --noconfirm "${AUR_PACKAGES[@]}"

# =============================================================================
# PHASE 3: SHELL & THEME
# =============================================================================
header "PHASE 3/7: Shell Configuration"
step "3/7" "Oh My Zsh & Powerlevel10k Setup"

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log "Downloading Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    rm -f "$HOME/.zshrc"
    log "Removed default .zshrc to avoid conflicts."
fi

if [ ! -d "${ZSH_CUSTOM}/themes/powerlevel10k" ]; then
    log "Fetching Powerlevel10k theme..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM}/themes/powerlevel10k
fi

log "Installing Zsh plugins..."
[ ! -d "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" ] && git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
[ ! -d "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" ] && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting
[ ! -d "${ZSH_CUSTOM}/plugins/zsh-completions" ] && git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM}/plugins/zsh-completions

# =============================================================================
# PHASE 4: DOTFILES
# =============================================================================
header "PHASE 4/7: Dotfiles Synchronization"
step "4/7" "Initiating Stow"

if [ ! -d "$DOTFILES_DIR" ]; then
    log "Cloning repository: $DOTFILES_REPO"
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
    log "Updating repository..."
    cd "$DOTFILES_DIR" && git pull && cd -
fi

cd "$DOTFILES_DIR"
for dir in */; do
    dirname=$(basename "$dir")
    if [ "$dirname" != ".git" ]; then
        log "Linking config: $dirname"
        stow --adopt -v "$dirname"
    fi
done
git reset --hard HEAD
cd "$HOME"
log "Dotfiles synchronized successfully."

# =============================================================================
# PHASE 5: SERVICES & LIMITS
# =============================================================================
header "PHASE 5/7: Service Management"
step "5/7" "Audio & Systemd Optimization"

LIMITS_FILE="/etc/security/limits.d/99-realtime-audio.conf"
if [ ! -f "$LIMITS_FILE" ]; then
    log "Setting up Realtime Audio Limits (Bitwig/Pipewire)..."
    echo "@audio   -  rtprio     95" | sudo tee -a "$LIMITS_FILE" > /dev/null
    echo "@audio   -  memlock    unlimited" | sudo tee -a "$LIMITS_FILE" > /dev/null
else
    log "Audio limits already configured."
fi

SERVICES=(NetworkManager iwd bluetooth ufw ananicy-cpp docker fstrim.timer snapper-cleanup.timer)
for service in "${SERVICES[@]}"; do
    sudo systemctl enable --now "$service" &>/dev/null
    log "[ENABLED] $service"
done

sudo usermod -aG wheel,video,audio,input,docker,uucp "$USER"
if command -v yabridgectl &> /dev/null; then
    yabridgectl sync &>/dev/null
    log "Yabridge VST sync complete."
fi

# =============================================================================
# PHASE 6: FINAL TWEAKS
# =============================================================================
header "PHASE 6/7: Final Tweaks"

# 1. Apply Git Configuration (Using inputs from Phase 0)
if [ -n "$GIT_USER" ] && [ -n "$GIT_EMAIL" ]; then
    log "Applying Git identity settings..."
    git config --global user.name "$GIT_USER"
    git config --global user.email "$GIT_EMAIL"
else
    warn "Git identity skipped (no input provided at start)."
fi

# 2. Change Shell
if [ "$(basename "$SHELL")" != "zsh" ]; then
    log "Changing default shell to Zsh..."
    chsh -s "$(which zsh)"
fi

# 3. Refresh Cache
log "Refreshing UI and Font cache..."
fc-cache -fv &>/dev/null
sudo glib-compile-schemas /usr/share/glib-2.0/schemas/ &>/dev/null

# 4. SSD Trim
log "Optimizing Disk (fstrim)..."
sudo fstrim -v /

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
echo -e "${TN_PURPLE}$(printf '%*s' "$(tput cols)" '' | tr ' ' '=')${NC}\n"
