#!/bin/bash

# Seçenekleri belirle
options="󰐥 Kapat\n󰜉 Yeniden Başlat\n󰤄 Uyku\n󰍃 Oturumu Kapat\n󰷛 Kilitle"

# Rofi ile menüyü aç
chosen=$(echo -e "$options" | rofi -dmenu -i -p "Sistem İşlemi" -theme-str 'window {width: 300px;}')

# Seçime göre işlemi yap
case $chosen in
    *"Kapat"*)
        systemctl poweroff ;;
    *"Yeniden Başlat"*)
        reboot ;;
    *"Uyku"*)
        systemctl suspend ;;
    *"Oturumu Kapat"*)
        hyprctl dispatch exit ;;
    *"Kilitle"*)
        # Eğer hyprlock yüklü değilse 'swaylock' veya 'gtklock' yazabilirsin
        hyprlock ;; 
esac
