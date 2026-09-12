#!/bin/bash

# =====================================
#   WINDOWS AUTO INSTALLER
#   + Auto OpenSSH
#   + Status Check
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
echo "   WINDOWS AUTO INSTALLER"
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
    ISO_URL="https://massgrave.dev/img/Win10_22H2_English_x64.iso"
    ;;
  2)
    OS_NAME="Windows 11 Pro"
    IMAGE_NAME="Windows 11 Pro"
    ISO_URL="https://massgrave.dev/img/Win11_24H2_English_x64.iso"
    ;;
  3)
    OS_NAME="Tiny10 23H2 (Ringan - Win10)"
    IMAGE_NAME="Windows 10 Pro"
    ISO_URL="https://github.com/ntdevlabs/tiny11builder/releases/download/tiny10-23H2/tiny10_x64_23h2.iso"
    ;;
  4)
    OS_NAME="Tiny11 23H2 (Ringan - Win11)"
    IMAGE_NAME="Windows 11 Pro"
    ISO_URL="https://github.com/ntdevlabs/tiny11builder/releases/download/tiny11-23H2/tiny11_x64_23h2.iso"
    ;;
  5)
    OS_NAME="Tiny11 25H2 (Terbaru - Ringan)"
    IMAGE_NAME="Windows 11 Pro"
    ISO_URL="https://github.com/ntdevlabs/tiny11builder/releases/latest/download/tiny11_x64_25h2.iso"
    ;;
  6)
    OS_NAME="Windows Server 2022"
    IMAGE_NAME="Windows Server 2022 SERVERSTANDARD"
    ISO_URL="https://go.microsoft.com/fwlink/p/?LinkID=2195280&clcid=0x409&culture=en-us&country=US"
    ;;
  7)
    OS_NAME="Windows Server 2025 Datacenter"
    IMAGE_NAME="Windows Server 2025 SERVERDATACENTER"
    ISO_URL="https://go.microsoft.com/fwlink/?linkid=2293313&clcid=0x409&culture=en-us&country=US"
    ;;
  *)
    echo -e "${RED}Pilihan tidak valid!${NC}"
    update_status "ERROR: Pilihan tidak valid"
    exit 1
    ;;
esac

VPS_IP=$(curl -s ifconfig.me 2>/dev/null || echo 'unknown')

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

update_status "CHECKING_URL"
echo ""
echo -e "${YELLOW}[*] Mengecek URL ISO...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -L --max-time 20 -r 0-0 "$ISO_URL")
if [[ "$HTTP_CODE" != "200" && "$HTTP_CODE" != "206" ]]; then
    echo -e "${RED}[!] URL ISO tidak bisa diakses (HTTP $HTTP_CODE): $ISO_URL${NC}"
    echo -e "${RED}[!] Install dibatalkan. Coba pilih OS lain atau cek koneksi VPS.${NC}"
    update_status "ERROR: URL ISO tidak bisa diakses (HTTP $HTTP_CODE)"
    exit 1
fi
echo -e "${GREEN}[✓] URL ISO OK (HTTP $HTTP_CODE)${NC}"

update_status "DOWNLOADING"
echo ""
echo -e "${GREEN}[*] Memulai instalasi $OS_NAME...${NC}"
echo -e "${YELLOW}[*] Menginstall dependencies...${NC}"

apt-get update -qq && apt-get install -y wget curl -qq 2>/dev/null || \
yum install -y wget curl -q 2>/dev/null || \
dnf install -y wget curl -q 2>/dev/null || \
true

echo -e "${YELLOW}[*] Mendownload script reinstall...${NC}"
wget -qO /tmp/reinstall.sh https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
chmod +x /tmp/reinstall.sh

SUPPORT_FIRSTBOOT=$(bash /tmp/reinstall.sh --help 2>&1 | grep -c "firstboot-powershell" || true)

update_status "INSTALLING"
echo -e "${YELLOW}[*] Menjalankan instalasi Windows...${NC}"
echo -e "${YELLOW}[*] Proses ini membutuhkan waktu 30-60 menit...${NC}"
echo ""

OPENSSH_SCRIPT='Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0; Start-Service sshd; Set-Service -Name sshd -StartupType Automatic; New-NetFirewallRule -Name sshd -DisplayName "OpenSSH Server" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22'

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
