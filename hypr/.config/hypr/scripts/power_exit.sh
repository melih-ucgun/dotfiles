#!/bin/bash

# Seçenekleri belirle
options="󰐥 Kapat\n󰜉 Yeniden Başlat\n󰤄 Uyku\n󰍃 Oturumu Kapat\n󰷛 Kilitle"

# Rofi ile menüyü aç
# Eğer bir önceki adımda oluşturduğumuz Tokyo Night temasını kullanmak istersen:
# -theme-str 'window {width: 300px;}' kısmını silip yerine:
# -theme ~/.config/rofi/tokyonight_powermenu.rasi yazabilirsin.
chosen=$(echo -e "$options" | rofi -dmenu -i -p "Sistem İşlemi" -theme-str 'window {width: 300px;}')

# Seçime göre işlemi yap
case $chosen in
*"Kapat"*)
  systemctl poweroff
  ;;
*"Yeniden Başlat"*)
  systemctl reboot
  ;;
*"Uyku"*)
  # Önce hyprlock çalışıyor mu kontrol et, çalışmıyorsa çalıştır ve sonra uykuya dal
  pidof hyprlock || hyprlock &
  sleep 0.5 && systemctl suspend
  ;;
*"Oturumu Kapat"*)
  hyprctl dispatch exit
  ;;
*"Kilitle"*)
  # Eğer zaten kilitliyse tekrar komut gönderip hataya düşmesini engeller
  pidof hyprlock || hyprlock
  ;;
esac
