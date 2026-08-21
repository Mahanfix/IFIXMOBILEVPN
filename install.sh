#!/bin/bash

# IFIXMOBILEVPN - اسکریپت نصب و اجرای خودکار (بهتر شده)
# برای Ubuntu/Debian

set -e

# رنگ‌ها
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# بررسی root
if [[ $EUID -ne 0 ]]; then
   print_error "لطفاً با sudo اجرا کنید"
   exit 1
fi

print_info "═══════════════════════════════════════════════════════"
print_info "شروع نصب IFIXMOBILEVPN"
print_info "════════��══════════════════════════════════════════════"

# حل کردن مشکل بسته‌های broken
print_info "ترمیم بسته‌های broken..."
apt-get --fix-broken install -y 2>/dev/null || true
apt-get autoremove -y -qq 2>/dev/null || true
apt-get autoclean -y -qq 2>/dev/null || true

# بروزرسانی
print_info "بروزرسانی سیستم..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq -o Dpkg::Options::="--force-confnew"

# نصب ابزارهای اساسی
print_info "نصب ابزارهای اساسی..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    curl \
    wget \
    unzip \
    git \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# نصب Node.js (اختیاری)
print_info "نصب Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - 2>/dev/null || true
apt-get install -y -qq nodejs 2>/dev/null || print_warning "Node.js نصب نشد (اختیاری)"

# نصب Python
print_info "نصب Python..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    python3 \
    python3-pip \
    python3-venv

print_success "تمام ابزارها نصب شدند"

# ایجاد دایرکتوری کاری
WORK_DIR="/opt/ifixmobilevpn"
print_info "ایجاد دایرکتوری کاری: $WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# دانلود فایل ZIP
print_info "دانلود IFIXMOBILEVPN.zip..."
if [ -f "IFIXMOBILEVPN.zip" ]; then
    print_warning "فایل ZIP قبلاً دانلود شده است"
else
    wget -q --show-progress https://github.com/Mahanfix/IFIXMOBILEVPN/raw/main/IFIXMOBILEVPN.zip -O IFIXMOBILEVPN.zip || {
        print_error "دانلود ناموفق"
        exit 1
    }
fi

print_success "فایل دانلود شد"

# استخراج
print_info "استخراج فایل..."
unzip -q IFIXMOBILEVPN.zip -d . 2>/dev/null || {
    print_error "مشکل در استخراج"
    exit 1
}
print_success "فایل استخراج شد"

# پاک‌کردن ZIP
rm -f IFIXMOBILEVPN.zip

# نمایش ساختار
print_info "ساختار پروژه:"
ls -lh

# نصب وابستگی‌های Python
if [ -f "requirements.txt" ]; then
    print_info "نصب وابستگی‌های Python..."
    python3 -m pip install --upgrade pip -q
    python3 -m pip install -r requirements.txt -q
    print_success "وابستگی‌های Python نصب شدند"
fi

# نصب وابستگی‌های Node
if [ -f "package.json" ]; then
    print_info "نصب وابستگی‌های Node.js..."
    npm install -q 2>/dev/null || print_warning "npm install ناموفق"
    print_success "وابستگی‌های Node.js نصب شدند"
fi

# ایجاد فایل شروع اگر وجود ندارد
if [ ! -f "start.sh" ]; then
    print_info "ایجاد فایل start.sh..."
    cat > start.sh << 'STARTSCRIPT'
#!/bin/bash
cd "$(dirname "$0")"
echo "IFIXMOBILEVPN شروع شد - $(date)" >> app.log

# اگر Python app است
if [ -f "app.py" ]; then
    python3 app.py >> app.log 2>&1
# اگر Node app است
elif [ -f "index.js" ] || [ -f "server.js" ]; then
    node index.js >> app.log 2>&1 || node server.js >> app.log 2>&1
# اگر Bash script است
elif [ -f "main.sh" ]; then
    bash main.sh >> app.log 2>&1
else
    echo "فایل شروع پیدا نشد" >> app.log
fi
STARTSCRIPT
    chmod +x start.sh
    print_success "start.sh ایجاد شد"
fi

# ایجاد systemd service
print_info "ایجاد سرویس systemd..."
cat > /etc/systemd/system/ifixmobilevpn.service << EOF
[Unit]
Description=IFIXMOBILEVPN Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$WORK_DIR
ExecStart=/bin/bash $WORK_DIR/start.sh
Restart=on-failure
RestartSec=10
StandardOutput=append:$WORK_DIR/service.log
StandardError=append:$WORK_DIR/service.log

[Install]
WantedBy=multi-user.target
EOF

chmod 644 /etc/systemd/system/ifixmobilevpn.service
systemctl daemon-reload
systemctl enable ifixmobilevpn.service 2>/dev/null

print_success "سرویس ایجاد شد"

# شروع سرویس
print_info "شروع سرویس..."
systemctl restart ifixmobilevpn.service
sleep 2

# چک وضعیت
if systemctl is-active --quiet ifixmobilevpn.service; then
    print_success "سرویس در حال اجرا است ✓"
else
    print_warning "سرویس اجرا نشد - برای بیشتر اطلاعات لاگ‌ها را بررسی کنید"
fi

print_success "═══════════════════════════════════════════════════════"
print_success "✓ نصب تمام شد!"
echo ""
print_info "📁 دایرکتوری کاری: $WORK_DIR"
print_info "📋 دستورات مفید:"
echo "  • مشاهده وضعیت:    sudo systemctl status ifixmobilevpn.service"
echo "  • مشاهده لاگ:      tail -f $WORK_DIR/service.log"
echo "  • متوقف کردن:      sudo systemctl stop ifixmobilevpn.service"
echo "  • شروع مجدد:       sudo systemctl restart ifixmobilevpn.service"
print_success "═══════════════════════════════════════════════════════"
