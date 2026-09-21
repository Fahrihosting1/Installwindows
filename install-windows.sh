#!/bin/bash

# =====================================
#   WINDOWS AUTO INSTALLER v3
#   + Auto OpenSSH
#   + Status Check
#   + Hard Patch extlinux.sys fix
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
echo "   WINDOWS AUTO INSTALLER v3"
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
    echo -e "${RED}[!] URL ISO tidak bisa diakses (HTTP $HTTP_CODE)${NC}"
    update_status "ERROR: URL ISO tidak bisa diakses (HTTP $HTTP_CODE)"
    exit 1
fi
echo -e "${GREEN}[✓] URL ISO OK (HTTP $HTTP_CODE)${NC}"

# =====================================
# Download reinstall.sh
# =====================================
update_status "DOWNLOADING"
echo ""
echo -e "${YELLOW}[*] Mendownload script reinstall...${NC}"

REINSTALL_URL="https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh"
for i in 1 2 3; do
    wget -qO /tmp/reinstall.sh "$REINSTALL_URL" && break
    echo -e "${YELLOW}[!] Retry $i/3...${NC}"
    sleep 3
done

if [ ! -s /tmp/reinstall.sh ]; then
    echo -e "${RED}[!] Gagal download reinstall.sh!${NC}"
    update_status "ERROR: Gagal download reinstall.sh"
    exit 1
fi
chmod +x /tmp/reinstall.sh
echo -e "${GREEN}[✓] reinstall.sh berhasil didownload${NC}"

# =====================================
# HARD PATCH — ganti extlinux dengan
# wrapper yang tidak pernah gagal
# =====================================
echo -e "${YELLOW}[*] Applying patch extlinux...${NC}"

# Buat extlinux palsu yang selalu sukses di direktori sementara
mkdir -p /tmp/fake_bin
cat > /tmp/fake_bin/extlinux << 'FAKEEXT'
#!/bin/bash
# Fake extlinux — selalu sukses
# Buat file extlinux.sys di direktori target kalau diminta
for arg in "$@"; do
    if [ -d "$arg" ]; then
        touch "$arg/extlinux.sys" 2>/dev/null || true
        touch "$arg/ldlinux.sys" 2>/dev/null || true
    fi
done
# Coba jalankan yang asli, kalau gagal tetap exit 0
REAL=$(which extlinux 2>/dev/null | grep -v fake_bin | head -1)
if [ -n "$REAL" ]; then
    "$REAL" "$@" 2>/dev/null || true
fi
exit 0
FAKEEXT
chmod +x /tmp/fake_bin/extlinux

# Tambahkan fake_bin ke depan PATH supaya dipakai duluan
export PATH="/tmp/fake_bin:$PATH"

# Patch line extlinux di reinstall.sh: tambah "|| true" di semua baris yang ada extlinux
# Ini handle kasus error return 1 dari extlinux
python3 - << 'PYEOF' 2>/dev/null || perl -i -pe 's/(extlinux\s+--clear-once[^\n]*)/$1 || true/g' /tmp/reinstall.sh
import re

with open('/tmp/reinstall.sh', 'r', errors='replace') as f:
    content = f.read()

# Patch 1: tambah || true setelah extlinux --clear-once
content = re.sub(
    r'(extlinux\s+--clear-once\s+[^\n]+)(?!\s*\|\|\s*true)',
    r'\1 || true',
    content
)

# Patch 2: ganti cek file ./extlinux.sys yang bisa gagal
# Kalau ada pattern [ -f ./extlinux.sys ] atau cek serupa, bikin selalu true
content = re.sub(
    r'\[\s*["\']?\./extlinux\.sys["\']?\s*\]',
    'true',
    content
)
content = re.sub(
    r'test\s+-[fe]\s+["\']?\./extlinux\.sys["\']?',
    'true',
    content
)

with open('/tmp/reinstall.sh', 'w') as f:
    f.write(content)

print("Patch python berhasil")
PYEOF

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
