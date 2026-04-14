#!/usr/bin/env bash
set -euo pipefail

script_name="Создать ярлык в меню запуска"
nautilus_scripts_dir="$HOME/.local/share/nautilus/scripts"
installed_script_path="$nautilus_scripts_dir/$script_name"

install_to_nautilus_scripts() {
  mkdir -p "$nautilus_scripts_dir"
  cp "$(readlink -f "$0")" "$installed_script_path"
  chmod +x "$installed_script_path"
}

if [[ "${1:-}" == "--install" ]]; then
  install_to_nautilus_scripts
  zenity --info \
    --title="Установка завершена" \
    --text="Пункт меню создан:\nСценарии -> $script_name\n\nПерезапустите Nautilus: nautilus -q"
  exit 0
fi

# Nautilus передает выбранные файлы через переменную окружения.
selected_paths="${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS:-}"

if [[ -z "$selected_paths" ]]; then
  install_to_nautilus_scripts
  zenity --info \
    --title="Скрипт установлен" \
    --text="Пункт меню создан:\nСценарии -> $script_name\n\nДальше нажмите ПКМ по AppImage/исполняемому файлу."
  exit 0
fi

# Берем только первый выбранный файл.
target_file="$(printf '%s\n' "$selected_paths" | head -n 1)"

if [[ ! -f "$target_file" ]]; then
  zenity --error --title="Создать ярлык" --text="Выбранный путь не является файлом."
  exit 1
fi

if [[ ! -x "$target_file" ]]; then
  zenity --error --title="Создать ярлык" --text="Файл не является исполняемым."
  exit 1
fi

app_name_default="$(basename "$target_file")"
app_name_default="${app_name_default%.AppImage}"

app_name="$(zenity --entry \
  --title="Создать ярлык в меню запуска" \
  --text="Введите имя ярлыка:" \
  --entry-text="$app_name_default")"

if [[ -z "${app_name:-}" ]]; then
  exit 0
fi

safe_id="$(printf '%s' "$app_name" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-')"

convert_jpg_icon_to_png() {
  local src_icon="$1"
  local icon_output_dir="$HOME/.local/share/icons/hicolor/256x256/apps"
  local converted_icon="$icon_output_dir/${safe_id}.png"

  mkdir -p "$icon_output_dir"

  if command -v magick >/dev/null 2>&1; then
    magick "$src_icon" "$converted_icon" && printf '%s\n' "$converted_icon" && return 0
  elif command -v convert >/dev/null 2>&1; then
    convert "$src_icon" "$converted_icon" && printf '%s\n' "$converted_icon" && return 0
  fi

  printf '%s\n' "$src_icon"
}

icon_value="application-x-executable"
icon_choice="$(zenity --question \
  --title="Выбор иконки" \
  --text="Выбрать иконку для ярлыка?" \
  --ok-label="Выбрать" \
  --cancel-label="Пропустить" \
  && zenity --file-selection \
    --title="Выберите иконку" \
    --file-filter="Изображения | *.ico *.png *.svg *.xpm *.jpg *.jpeg *.webp" \
    --file-filter="Все файлы | *" \
  || true)"

if [[ -n "${icon_choice:-}" && -f "$icon_choice" ]]; then
  if [[ "$icon_choice" =~ \.(jpg|jpeg)$ ]]; then
    icon_value="$(convert_jpg_icon_to_png "$icon_choice")"
  else
    icon_value="$icon_choice"
  fi
else
  icon_guess="${target_file%.*}.png"
  if [[ -f "$icon_guess" ]]; then
    icon_value="$icon_guess"
  else
    icon_guess_jpg="${target_file%.*}.jpg"
    icon_guess_jpeg="${target_file%.*}.jpeg"
    if [[ -f "$icon_guess_jpg" ]]; then
      icon_value="$(convert_jpg_icon_to_png "$icon_guess_jpg")"
    elif [[ -f "$icon_guess_jpeg" ]]; then
      icon_value="$(convert_jpg_icon_to_png "$icon_guess_jpeg")"
    fi
  fi
fi

desktop_dir="$HOME/.local/share/applications"
mkdir -p "$desktop_dir"

desktop_file="$desktop_dir/${safe_id}.desktop"

cat > "$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=$app_name
Exec=$target_file
Icon=$icon_value
Terminal=false
Categories=Utility;
StartupNotify=true
EOF

chmod 644 "$desktop_file"
update-desktop-database "$desktop_dir" >/dev/null 2>&1 || true

zenity --info \
  --title="Создать ярлык" \
  --text="Ярлык создан:\n$desktop_file\n\nОн появится в меню приложений GNOME."
