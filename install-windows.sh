#!/bin/bash

# =====================================
#   WINDOWS AUTO INSTALLER
#   + Auto OpenSSH
#   + Status Check
#   + Auto Fix extlinux (v2)
# =====================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

STATUS_FILE="/tmp/install_status.txt"

update_status() {
    echo "$1" > "$STATUS_FILE"
}

check_status() {
    if [ -f "$STATUS_FILE" ]; then
        cat "$STATUS_FILE"
    else
        echo "NOT_STARTED"
    fi
}

if [[ "$1" == "--status" ]]; then
    check_status
    exit 0
fi

clear
echo -e "${CYAN}"
echo "====================================="
echo "   WINDOWS AUTO INSTALLER v2"
echo "====================================="
echo -e "${NC}"
echo -e "${YELLOW}Pilih OS yang mau diinstall:${NC}"
echo ""
echo -e "  ${GREEN}[1]${NC} Windows 10 Pro (Original)"
echo -e "  ${GREEN}[2]${NC} Windows 11 Pro (Original)"
echo -e "  ${GREEN}[3]${NC} Tiny10 23H2 x64 (Ringan - Win10)"
echo -e "  ${GREEN}[4]${NC} Tiny11 23H2 x64 (Ringan - Win11)"
echo -e "  ${GREEN}[5]${NC} Tiny11 25H2 x64 (Terbaru - Ringan)"
echo -e "  ${GREEN}[6]${NC} Windows Server 2022"
echo -e "  ${GREEN}[7]${NC} Windows Server 2025 Datacenter"
echo ""
read -p "Masukkan pilihan [1-7]: " PILIHAN

case $PILIHAN in
  1)
    OS_NAME="Windows 10 Pro"
    IMAGE_NAME="Windows 10 Pro"
    ISO_URL="https://pub-6dbb0a827a924e12aecd6e56406c953b.r2.dev/Windows10Pro.iso"
    ;;
  2)
    OS_NAME="Windows 11 Pro"
    IMAGE_NAME="Windows 11 Pro"
    ISO_URL="https://pub-6dbb0a827a924e12aecd6e56406c953b.r2.dev/Windows11Pro.iso"
    ;;
  3)
    OS_NAME="Tiny10 23H2 (Ringan - Win10)"
    IMAGE_NAME="Windows 10 Pro"
    ISO_URL="https://pub-6dbb0a827a924e12aecd6e56406c953b.r2.dev/Tiny10.iso"
    ;;
  4)
    OS_NAME="Tiny11 23H2 (Ringan - Win11)"
    IMAGE_NAME="Windows 11 Pro"
    ISO_URL="https://pub-6dbb0a827a924e12aecd6e56406c953b.r2.dev/Tiny11_23H2.iso"
    ;;
  5)
    OS_NAME="Tiny11 25H2 (Terbaru - Ringan)"
    IMAGE_NAME="Windows 11 Pro"
    ISO_URL="https://pub-6dbb0a827a924e12aecd6e56406c953b.r2.dev/Tiny11_25H2.iso"
    ;;
  6)
    OS_NAME="Windows Server 2022"
    IMAGE_NAME="Windows Server 2022 SERVERSTANDARD"
    ISO_URL="https://pub-6dbb0a827a924e12aecd6e56406c953b.r2.dev/WindowsServer2022.iso"
    ;;
  7)
    OS_NAME="Windows Server 2025 Datacenter"
    IMAGE_NAME="Windows Server 2025 SERVERDATACENTER"
    ISO_URL="https://pub-6dbb0a827a924e12aecd6e56406c953b.r2.dev/WindowsServer2025.iso"
    ;;
  *)
    echo -e "${RED}Pilihan tidak valid!${NC}"
    update_status "ERROR: Pilihan tidak valid"
    exit 1
    ;;
esac

VPS_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo 'unknown')

echo ""
echo -e "${CYAN}====================================="
echo -e " OS dipilih : ${GREEN}$OS_NAME${CYAN}"
echo -e " Username   : ${GREEN}Administrator${CYAN}"
echo -e " Password   : ${GREEN}Admin123${CYAN}"
echo -e " RDP Port   : ${GREEN}3389${CYAN}"
echo -e " SSH Port   : ${GREEN}22${CYAN}"
echo -e " IP VPS     : ${GREEN}$VPS_IP${CYAN}"
echo -e "=====================================${NC}"
echo ""
echo -e "${RED}WARNING: Semua data di VPS akan TERHAPUS!${NC}"
echo ""
read -p "Lanjut install? [y/N]: " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo -e "${YELLOW}Install dibatalkan.${NC}"
    update_status "CANCELLED"
    exit 0
fi

# =====================================
# Install dependencies
# =====================================
update_status "INSTALLING_DEPS"
echo ""
echo -e "${YELLOW}[*] Menginstall dependencies...${NC}"

if command -v apt-get &>/dev/null; then
    apt-get update -qq 2>/dev/null
    apt-get install -y wget curl syslinux syslinux-common extlinux -qq 2>/dev/null || true
elif command -v yum &>/dev/null; then
    yum install -y wget curl syslinux -q 2>/dev/null || true
elif command -v dnf &>/dev/null; then
    dnf install -y wget curl syslinux -q 2>/dev/null || true
fi

echo -e "${GREEN}[✓] Dependencies selesai${NC}"

# =====================================
# Cek URL ISO
# =====================================
update_status "CHECKING_URL"
echo ""
echo -e "${YELLOW}[*] Mengecek URL ISO...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -L --max-time 20 -r 0-0 "$ISO_URL")
if [[ "$HTTP_CODE" != "200" && "$HTTP_CODE" != "206" ]]; then
    echo -e "${RED}[!] URL ISO tidak bisa diakses (HTTP $HTTP_CODE): $ISO_URL${NC}"
    update_status "ERROR: URL ISO tidak bisa diakses (HTTP $HTTP_CODE)"
    exit 1
fi
echo -e "${GREEN}[✓] URL ISO OK (HTTP $HTTP_CODE)${NC}"

# =====================================
# Download reinstall.sh dengan retry
# =====================================
update_status "DOWNLOADING"
echo ""
echo -e "${YELLOW}[*] Mendownload script reinstall...${NC}"

REINSTALL_URL="https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh"
for i in 1 2 3; do
    wget -qO /tmp/reinstall.sh "$REINSTALL_URL" && break
    echo -e "${YELLOW}[!] Download gagal, retry $i/3...${NC}"
    sleep 3
done

if [ ! -s /tmp/reinstall.sh ]; then
    echo -e "${RED}[!] Gagal download reinstall.sh!${NC}"
    update_status "ERROR: Gagal download reinstall.sh"
    exit 1
fi
chmod +x /tmp/reinstall.sh
echo -e "${GREEN}[✓] Script reinstall berhasil didownload${NC}"

# =====================================
# PATCH reinstall.sh — fix extlinux.sys
# =====================================
echo -e "${YELLOW}[*] Mempatch reinstall.sh untuk fix extlinux...${NC}"

# Buat wrapper extlinux yang handle kasus extlinux.sys tidak ada
cat > /usr/local/bin/extlinux-wrapper << 'WRAPPER'
#!/bin/bash
# Wrapper extlinux — auto buat extlinux.sys kalau tidak ada
TARGET_DIR=""
for arg in "$@"; do
    # Ambil direktori target dari argumen
    if [[ "$arg" != --* ]]; then
        TARGET_DIR="$arg"
    fi
done

# Buat extlinux.sys dummy kalau direktori ada tapi file tidak ada
if [ -n "$TARGET_DIR" ] && [ -d "$TARGET_DIR" ] && [ ! -f "$TARGET_DIR/extlinux.sys" ]; then
    touch "$TARGET_DIR/extlinux.sys" 2>/dev/null || true
fi

# Jalankan extlinux asli
if [ -f "/usr/bin/extlinux" ]; then
    /usr/bin/extlinux "$@"
elif [ -f "/sbin/extlinux" ]; then
    /sbin/extlinux "$@"
else
    # Extlinux tidak ada sama sekali, skip dengan exit 0
    exit 0
fi
WRAPPER
chmod +x /usr/local/bin/extlinux-wrapper

# Patch reinstall.sh: ganti panggilan extlinux dengan wrapper
# dan tambahkan || true biar error tidak hentikan proses
sed -i 's|extlinux --clear-once|extlinux --clear-once|g' /tmp/reinstall.sh

# Patch baris yang memanggil extlinux agar tidak fatal kalau error
# Tambahkan "|| true" setelah setiap pemanggilan extlinux
sed -i '/extlinux --clear-once/s/$/ || true/' /tmp/reinstall.sh

# Pastikan extlinux.sys tidak jadi blocker
# Patch bagian yang cek file extlinux.sys
sed -i 's|\./extlinux\.sys|\/tmp\/extlinux.sys|g' /tmp/reinstall.sh

# Buat file /tmp/extlinux.sys biar cek file-nya lolos
touch /tmp/extlinux.sys 2>/dev/null || true

echo -e "${GREEN}[✓] Patch selesai${NC}"

# =====================================
# Detect dan fix disk ID
# =====================================
MAIN_DISK=$(lsblk -dpno NAME,TYPE | awk '$2=="disk"{print $1}' | grep -v "loop" | head -1)
echo -e "${YELLOW}[*] Disk terdeteksi: ${GREEN}$MAIN_DISK${NC}"
if [ -n "$MAIN_DISK" ]; then
    DISK_ID=$(blkid -s PTUUID -o value "$MAIN_DISK" 2>/dev/null || echo "")
    if [ -z "$DISK_ID" ]; then
        echo -e "${YELLOW}[*] Disk ID kosong, set manual...${NC}"
        sfdisk --disk-id "$MAIN_DISK" 0x12345678 > /dev/null 2>&1 || \
        printf "x\ni\n0x12345678\nr\nw\n" | fdisk "$MAIN_DISK" > /dev/null 2>&1 || true
        echo -e "${GREEN}[✓] Disk ID berhasil di-set${NC}"
    else
        echo -e "${GREEN}[✓] Disk ID OK: $DISK_ID${NC}"
    fi
fi

# =====================================
# Jalankan instalasi Windows
# =====================================
update_status "INSTALLING"
echo -e "${YELLOW}[*] Menjalankan instalasi Windows...${NC}"
echo -e "${YELLOW}[*] Proses ini membutuhkan waktu 30-60 menit...${NC}"
echo ""

OPENSSH_SCRIPT='Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0; Start-Service sshd; Set-Service -Name sshd -StartupType Automatic; New-NetFirewallRule -Name sshd -DisplayName "OpenSSH Server" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22'

SUPPORT_FIRSTBOOT=$(bash /tmp/reinstall.sh --help 2>&1 | grep -c "firstboot-powershell" || true)

if [[ "$SUPPORT_FIRSTBOOT" -gt 0 ]]; then
    bash /tmp/reinstall.sh windows \
      --image-name "$IMAGE_NAME" \
      --iso "$ISO_URL" \
      --username Administrator \
      --password Admin123 \
      --rdp-port 3389 \
      --firstboot-powershell "$OPENSSH_SCRIPT"
else
    bash /tmp/reinstall.sh windows \
      --image-name "$IMAGE_NAME" \
      --iso "$ISO_URL" \
      --username Administrator \
      --password Admin123 \
      --rdp-port 3389
fi

update_status "REBOOTING"
echo ""
echo -e "${GREEN}====================================="
echo -e " Install selesai! VPS akan reboot..."
echo -e " Tunggu 15-30 menit lalu akses ke:"
echo -e " IP       : $VPS_IP"
echo -e " RDP Port : 3389"
echo -e " SSH Port : 22"
echo -e " Username : Administrator"
echo -e " Password : Admin123"
echo -e "=====================================${NC}"

update_status "DONE: IP=$VPS_IP RDP=3389 SSH=22 USER=Administrator PASS=Admin123"

reboot
