#!/bin/sh
# SVG trong tool/icons → PNG cho app + icon của hai nền tảng. Chạy sau tool/export_icons.mts.
# Cần: rsvg-convert (brew install librsvg) và sips (có sẵn trên macOS).
set -e
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)

# Icon trong app: hiện tối đa ~48 px logic ⇒ 144 px là đủ nét ở màn 3x.
mkdir -p assets/icons
for name in agent shield chat success error bolt warning trash clipboard camera logo_mark; do
  rsvg-convert -w 144 -h 144 "tool/icons/$name.svg" -o "assets/icons/$name.png"
done

# Widget màn hình chính của Android không đọc được asset của Flutter ⇒ chép các hình nó dùng vào res/ (tiền tố w_).
mkdir -p android/app/src/main/res/drawable-nodpi
for name in logo_mark shield chat success error agent warning; do
  cp "assets/icons/$name.png" "android/app/src/main/res/drawable-nodpi/w_$name.png"
done

# iOS: icon app. Qua BMP để BỎ kênh alpha — App Store từ chối icon có alpha.
rsvg-convert -w 1024 -h 1024 tool/icons/logo.svg -o "$tmp/logo.png"
sips -s format bmp "$tmp/logo.png" --out "$tmp/logo.bmp" >/dev/null
for file in ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png; do
  size=$(sips -g pixelWidth "$file" | awk '/pixelWidth/{print $2}')
  sips -s format png -z "$size" "$size" "$tmp/logo.bmp" --out "$file" >/dev/null
done

# Android: lớp trước của icon thích ứng (108dp ở mật độ xxxhdpi = 432 px). Nền + lớp một màu là vector trong res/drawable.
mkdir -p android/app/src/main/res/mipmap-xxxhdpi
rsvg-convert -w 432 -h 432 tool/icons/logo_adaptive.svg -o android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png

rm -rf "$tmp"
echo "Đã dựng: assets/icons, AppIcon.appiconset, ic_launcher_foreground.png"
