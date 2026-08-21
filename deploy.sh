#!/bin/bash

# IFIXMOBILEVPN - اسکریپت نصب و اجرای خودکار
# برای Ubuntu/Debian

set -e  # خروج در صورت بروز خطا

# رنگ‌ها برای پیام‌ها
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # رنگی نه

# تابع برای نمایش پیام‌ها
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# بررسی دسترسی root
if [[ $EUID -ne 0 ]]; then
   print_error "این اسکریپت باید با sudo اجرا شود"
   exit 1
fi

print_info "شروع نصب IFIXMOBILEVPN..."

# بروزرسانی سیستم
print_info "بروزرسانی پکیج‌های سیستم..."
apt-get update -qq
apt-get upgrade -y -qq

# نصب ابزارهای مورد نیاز
print_info "نصب ابزارهای مورد نیاز..."
apt-get install -y -qq \
    git \
    curl \
    wget \
    unzip \
    build-essential \
    python3 \
    python3-pip \
    nodejs \
    npm

# دانلود پروژه
WORK_DIR="/opt/IFIXMOBILEVPN"
print_info "ایجاد دایرکتوری کاری در $WORK_DIR..."
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# دانلود فایل ZIP از GitHub
print_info "دانلود IFIXMOBILEVPN.zip..."
if ! wget -q https://github.com/Mahanfix/IFIXMOBILEVPN/raw/main/IFIXMOBILEVPN.zip -O IFIXMOBILEVPN.zip; then
    print_error "خطا در دانلود فایل"
    exit 1
fi

# استخراج ZIP
print_info "استخراج فایل..."
unzip -q IFIXMOBILEVPN.zip -d .

# پاک‌کردن فایل ZIP
rm -f IFIXMOBILEVPN.zip

# بررسی فایل‌های مهم
print_info "بررسی ساختار پروژه..."
ls -la

# اگر package.json وجود دارد، وابستگی‌ها را نصب کن
if [ -f "package.json" ]; then
    print_info "نصب وابستگی‌های Node.js..."
    npm install
fi

# اگر requirements.txt وجود دارد، وابستگی‌های Python را نصب کن
if [ -f "requirements.txt" ]; then
    print_info "نصب وابستگی‌های Python..."
    pip3 install -r requirements.txt
fi

# ایجاد سرویس systemd برای اجرای خودکار
print_info "ایجاد سرویس systemd..."
cat > /etc/systemd/system/ifixmobilevpn.service << EOF
[Unit]
Description=IFIXMOBILEVPN Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$WORK_DIR
ExecStart=/bin/bash -c 'cd $WORK_DIR && ./start.sh'
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# فعال‌کردن سرویس
print_info "فعال‌کردن سرویس systemd..."
systemctl daemon-reload
systemctl enable ifixmobilevpn.service

print_info "شروع سرویس..."
systemctl start ifixmobilevpn.service

# نمایش وضعیت
print_info "وضعیت سرویس:"
systemctl status ifixmobilevpn.service --no-pager

print_info "✅ نصب و راه‌اندازی با موفقیت انجام شد!"
print_info "📁 دایرکتوری کاری: $WORK_DIR"
print_info "🔧 برای مشاهده وضعیت: sudo systemctl status ifixmobilevpn.service"
print_info "📝 برای مشاهده لاگ: sudo journalctl -u ifixmobilevpn.service -f"
