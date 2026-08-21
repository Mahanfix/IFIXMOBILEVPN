#!/bin/bash

# IFIXMOBILEVPN - اسکریپت نصب و بیلد Gradle
# برای Ubuntu/Debian

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
   print_error "لطفاً با sudo اجرا کنید"
   exit 1
fi

print_info "═══════════════════════════════════════════════════════"
print_info "نصب IFIXMOBILEVPN - Gradle/Java پروژه"
print_info "═══════════════════════════════════════════════════════"

# ترمیم broken packages
print_info "ترمیم بسته‌های broken..."
apt-get --fix-broken install -y 2>/dev/null || true
apt-get autoremove -y -qq 2>/dev/null || true
apt-get autoclean -y -qq 2>/dev/null || true

# بروزرسانی
print_info "بروزرسانی سیستم..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq -o Dpkg::Options::="--force-confnew"

# نصب Java
print_info "نصب Java Development Kit..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    openjdk-17-jdk \
    openjdk-17-jre

# نصب دیگر ابزارها
print_info "نصب ابزارهای اضافی..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    curl wget unzip git build-essential

print_success "تمام ابزارها نصب شدند"

# ایجاد دایرکتوری کاری
WORK_DIR="/opt/ifixmobilevpn"
print_info "ایجاد دایرکتوری: $WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# دانلود و استخراج
print_info "دانلود IFIXMOBILEVPN.zip..."
wget -q --show-progress https://github.com/Mahanfix/IFIXMOBILEVPN/raw/main/IFIXMOBILEVPN.zip -O IFIXMOBILEVPN.zip

print_info "استخراج فایل..."
unzip -q IFIXMOBILEVPN.zip -d .
rm -f IFIXMOBILEVPN.zip

print_success "فایل استخراج شد"

# نمایش ساختار
print_info "ساختار پروژه:"
ls -lh
echo ""

# بیلد با Gradle
print_info "شروع بیلد Gradle..."
if [ -f "gradlew" ]; then
    print_info "استفاده از ./gradlew (موجود در پروژه)"
    chmod +x gradlew
    ./gradlew clean build -q || print_warning "بیلد ناموفق - لطفاً لاگ‌ها را بررسی کنید"
elif command -v gradle &> /dev/null; then
    print_info "استفاده از gradle سیستم"
    gradle clean build -q || print_warning "بیلد ناموفق"
else
    print_error "Gradle نصب نشده"
    exit 1
fi

print_success "بیلد تمام شد"

# ایجاد فایل start.sh
print_info "ایجاد فایل start.sh..."
cat > start.sh << 'STARTSCRIPT'
#!/bin/bash
cd "$(dirname "$0")"

# لاگ فایل
LOG_FILE="app.log"

echo "$(date) - IFIXMOBILEVPN شروع شد" >> "$LOG_FILE"

# بررسی فایلهای JAR
if [ -f "build/libs/"*.jar ]; then
    JAR_FILE=$(find build/libs -name "*.jar" | head -1)
    echo "$(date) - اجرای: $JAR_FILE" >> "$LOG_FILE"
    exec java -jar "$JAR_FILE" >> "$LOG_FILE" 2>&1
else
    echo "$(date) - خطا: فایل JAR پیدا نشد" >> "$LOG_FILE"
    echo "لطفاً ابتدا ./gradlew build را اجرا کنید"
    exit 1
fi
STARTSCRIPT

chmod +x start.sh
print_success "start.sh ایجاد شد"

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
StandardOutput=append:$WORK_DIR/app.log
StandardError=append:$WORK_DIR/app.log

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
sleep 3

# چک وضعیت
if systemctl is-active --quiet ifixmobilevpn.service; then
    print_success "سرویس در حال اجرا است ✓"
else
    print_warning "سرویس اجرا نشد - لاگ‌ها را بررسی کنید"
fi

echo ""
print_success "═══════════════════════════════════════════════════════"
print_success "✓ نصب و بیلد تمام شد!"
echo ""
print_info "📁 دایرکتوری: $WORK_DIR"
print_info "☕ Java: $(java -version 2>&1 | head -n 1)"
print_info "📋 دستورات:"
echo "  • وضعیت:    sudo systemctl status ifixmobilevpn.service"
echo "  • لاگ:      tail -f $WORK_DIR/app.log"
echo "  • متوقف:    sudo systemctl stop ifixmobilevpn.service"
echo "  • شروع:     sudo systemctl restart ifixmobilevpn.service"
echo "  • بیلد:     cd $WORK_DIR && ./gradlew clean build"
print_success "═══════════════════════════════════════════════════════"
