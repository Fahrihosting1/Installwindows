#!/bin/bash

# =====================================
#   WINDOWS AUTO INSTALLER
#   Fixed: image-name sesuai pilihan OS
# =====================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

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
echo -e "  ${GREEN}[4]${NC} Tiny11 23H2 x64 (Ringan - Win11 - Atlas Ready!)"
echo -e "  ${GREEN}[5]${NC} Windows Server 2022"
echo ""
read -p "Masukkan pilihan [1-5]: " PILIHAN

case $PILIHAN in
  1)
    OS_NAME="Windows 10 Pro"
    IMAGE_NAME="Windows 10 Pro"
    ISO_URL="https://archive.org/download/windows-10-22h2/Windows10_22H2_x64.iso"
    ;;
  2)
    OS_NAME="Windows 11 Pro"
    IMAGE_NAME="Windows 11 Pro"
    ISO_URL="https://archive.org/download/windows-11-23h2/Windows11_23H2_x64.iso"
    ;;
  3)
    OS_NAME="Tiny10 23H2 (Ringan - Win10)"
    IMAGE_NAME="Windows 10 Pro"
    ISO_URL="https://archive.org/download/tiny-10-23-h2/tiny10%20x64%2023h2.iso"
    ;;
  4)
    OS_NAME="Tiny11 23H2 (Ringan - Win11 - Atlas Ready!)"
    IMAGE_NAME="Windows 11 Pro"
    ISO_URL="https://archive.org/download/tiny-11-NTDEV/tiny11%2023H2%20x64.iso"
    ;;
  5)
    OS_NAME="Windows Server 2022"
    IMAGE_NAME="Windows Server 2022 SERVERSTANDARD"
    ISO_URL="https://archive.org/download/windows-server-2022/WindowsServer2022.iso"
    ;;
  *)
    echo -e "${RED}Pilihan tidak valid!${NC}"
    exit 1
    ;;
esac

echo ""
echo -e "${CYAN}====================================="
echo -e " OS dipilih : ${GREEN}$OS_NAME${CYAN}"
echo -e " Username   : ${GREEN}Administrator${CYAN}"
echo -e " Password   : ${GREEN}Admin123${CYAN}"
echo -e " RDP Port   : ${GREEN}3389${CYAN}"
echo -e "=====================================${NC}"
echo ""
echo -e "${RED}WARNING: Semua data di VPS akan TERHAPUS!${NC}"
echo ""
read -p "Lanjut install? [y/N]: " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo -e "${YELLOW}Install dibatalkan.${NC}"
    exit 0
fi

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

echo -e "${YELLOW}[*] Menjalankan instalasi Windows...${NC}"
echo -e "${YELLOW}[*] Proses ini membutuhkan waktu 30-60 menit...${NC}"
echo ""

bash /tmp/reinstall.sh windows \
  --image-name "$IMAGE_NAME" \
  --iso "$ISO_URL" \
  --username Administrator \
  --password Admin123 \
  --rdp-port 3389

echo ""
echo -e "${GREEN}====================================="
echo -e " Install selesai! VPS akan reboot..."
echo -e " Tunggu 15-30 menit lalu RDP ke:"
echo -e " IP       : $(curl -s ifconfig.me 2>/dev/null || echo 'cek di panel VPS')"
echo -e " Port     : 3389"
echo -e " Username : Administrator"
echo -e " Password : Admin123"
echo -e "=====================================${NC}"

reboot
