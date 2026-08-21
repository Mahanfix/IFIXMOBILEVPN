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
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq -o Dpkg::Options::="--force-confnew" 2>/dev/null || true

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
if [ ! -d "app" ] || [ ! -f "build.gradle.kts" ]; then
    wget -q --show-progress https://github.com/Mahanfix/IFIXMOBILEVPN/raw/main/IFIXMOBILEVPN.zip -O IFIXMOBILEVPN.zip
    print_info "استخراج فایل..."
    unzip -q -o IFIXMOBILEVPN.zip -d .
    rm -f IFIXMOBILEVPN.zip
    print_success "فایل استخراج شد"
else
    print_warning "پروژه قبلاً دانلود شده است"
fi

# نمایش ساختار
print_info "ساختار پروژه:"
ls -lh
echo ""

# بررسی gradle-wrapper.properties
print_info "بررسی نسخه Gradle مورد نیاز..."
if [ -f "gradle/wrapper/gradle-wrapper.properties" ]; then
    REQUIRED_GRADLE=$(grep "distributionUrl" gradle/wrapper/gradle-wrapper.properties | grep -oP 'gradle-\K[0-9.]+' || echo "9.3.1")
    print_info "نسخه Gradle مورد نیاز: $REQUIRED_GRADLE"
else
    REQUIRED_GRADLE="9.3.1"
    print_warning "فایل gradle-wrapper.properties پیدا نشد - استفاده از $REQUIRED_GRADLE"
fi

# نصب Gradle
GRADLE_HOME="/opt/gradle"
print_info "نصب Gradle $REQUIRED_GRADLE..."

if [ ! -d "$GRADLE_HOME/gradle-$REQUIRED_GRADLE" ]; then
    mkdir -p "$GRADLE_HOME"
    cd "$GRADLE_HOME"
    
    GRADLE_URL="https://services.gradle.org/distributions/gradle-${REQUIRED_GRADLE}-bin.zip"
    print_info "دانلود Gradle از: $GRADLE_URL"
    wget -q --show-progress "$GRADLE_URL" 2>&1 || {
        print_error "دانلود Gradle ناموفق"
        exit 1
    }
    
    print_info "استخراج Gradle..."
    unzip -q "gradle-${REQUIRED_GRADLE}-bin.zip"
    rm -f "gradle-${REQUIRED_GRADLE}-bin.zip"
    
    chmod +x "gradle-${REQUIRED_GRADLE}/bin/gradle"
    print_success "Gradle نصب شد"
else
    print_warning "Gradle قبلاً نصب است"
fi

# تنظیم PATH
export PATH="$GRADLE_HOME/gradle-$REQUIRED_GRADLE/bin:$PATH"
echo "export PATH=$GRADLE_HOME/gradle-$REQUIRED_GRADLE/bin:\$PATH" > /etc/profile.d/gradle.sh
source /etc/profile.d/gradle.sh

# بیلد با Gradle
cd "$WORK_DIR"
print_info "شروع بیلد Gradle (این زمان می‌برد)..."
print_info "لاگ بیلد:"

if gradle --version > /dev/null 2>&1; then
    print_info "gradle version: $(gradle --version | head -1)"
    gradle clean build 2>&1 | tee build.log || {
        print_error "بیلد ناموفق - لاگ:"
        tail -50 build.log
        exit 1
    }
else
    print_error "Gradle به درستی نصب نشد"
    exit 1
fi

print_success "بیلد تمام شد ✓"

# بررسی JAR
if ls build/libs/*.jar 1> /dev/null 2>&1; then
    JAR_FILE=$(ls build/libs/*.jar | head -1)
    print_success "✓ JAR ایجاد شد: $(basename $JAR_FILE)"
else
    print_warning "هیچ JAR فایل پیدا نشد"
fi

# ایجاد فایل start.sh
print_info "ایجاد فایل start.sh..."
cat > start.sh << 'STARTSCRIPT'
#!/bin/bash
cd "$(dirname "$0")"

LOG_FILE="app.log"
echo "$(date) - IFIXMOBILEVPN شروع شد" >> "$LOG_FILE"

# بررسی فایلهای JAR
if ls build/libs/*.jar 1> /dev/null 2>&1; then
    JAR_FILE=$(ls build/libs/*.jar | head -1)
    echo "$(date) - اجرای: $JAR_FILE" >> "$LOG_FILE"
    
    # اگر app.properties وجود دارد
    if [ -f "app.properties" ]; then
        exec java -jar "$JAR_FILE" --spring.config.location=file:./app.properties >> "$LOG_FILE" 2>&1
    else
        exec java -jar "$JAR_FILE" >> "$LOG_FILE" 2>&1
    fi
else
    echo "$(date) - خطا: فایل JAR پیدا نشد" >> "$LOG_FILE"
    echo "لطفاً ابتدا gradle clean build را اجرا کنید"
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
Environment="PATH=$GRADLE_HOME/gradle-$REQUIRED_GRADLE/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/bin/bash $WORK_DIR/start.sh
Restart=on-failure
RestartSec=10
StandardOutput=append:$WORK_DIR/app.log
StandardError=append:$WORK_DIR/app.log
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

chmod 644 /etc/systemd/system/ifixmobilevpn.service
systemctl daemon-reload
systemctl enable ifixmobilevpn.service 2>/dev/null || print_warning "systemd نتوانست فعال شود (محیط مختلف)"

print_success "سرویس ایجاد شد"

# شروع سرویس (اگر systemd دستیاب باشد)
if command -v systemctl &> /dev/null && systemctl is-system-running > /dev/null 2>&1; then
    print_info "شروع سرویس..."
    systemctl restart ifixmobilevpn.service
    sleep 3

    # چک وضعیت
    if systemctl is-active --quiet ifixmobilevpn.service; then
        print_success "سرویس در حال اجرا است ✓"
        echo ""
        systemctl status ifixmobilevpn.service --no-pager | head -10
    else
        print_warning "سرویس اجرا نشد - لاگ‌ها را بررسی کنید"
        echo "لاگ:"
        tail -20 "$WORK_DIR/app.log" 2>/dev/null || echo "هنوز لاگی تولید نشده"
    fi
else
    print_warning "systemd دستیاب نیست - می‌توانید دستی اجرا کنید:"
    echo "  cd $WORK_DIR && ./start.sh"
fi

echo ""
print_success "═══════════════════════════════════════════════════════"
print_success "✓ نصب و بیلد تمام شد!"
echo ""
print_info "📁 دایرکتوری: $WORK_DIR"
print_info "☕ Java: $(java -version 2>&1 | head -n 1)"
print_info "🔨 Gradle: $REQUIRED_GRADLE"
print_info "📋 دستورات:"
echo "  • لاگ:      tail -f $WORK_DIR/app.log"
echo "  • وضعیت:    sudo systemctl status ifixmobilevpn.service"
echo "  • متوقف:    sudo systemctl stop ifixmobilevpn.service"
echo "  • شروع:     sudo systemctl restart ifixmobilevpn.service"
echo "  • بیلد:     cd $WORK_DIR && gradle clean build"
echo "  • دستی:     cd $WORK_DIR && ./start.sh"
print_success "═══════════════════════════════════════════════════════"
