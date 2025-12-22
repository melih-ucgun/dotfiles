#!/bin/bash

# Seçenekleri tanımla
options="󰾆 Power Saver\n󰚅 Balanced\n󰓅 Performance"

# Rofi ile menüyü aç
# -p: İstemi ayarlar, -dmenu: Seçim listesi sunar
chosen=$(echo -e "$options" | rofi -dmenu -p "Güç Profili" -i)

# Seçime göre işlemi yap
case $chosen in
    *"Power Saver"*)
        powerprofilesctl set power-saver ;;
    *"Balanced"*)
        powerprofilesctl set balanced ;;
    *"Performance"*)
        powerprofilesctl set performance ;;
esac
