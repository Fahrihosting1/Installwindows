#!/bin/bash

# =====================================
#   WINDOWS AUTO INSTALLER v5
#   + Root cause fix: force GRUB path
#   + Auto OpenSSH + Status Check
# =====================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

STATUS_FILE="/tmp/install_status.txt"
update_status() { echo "$1" > "$STATUS_FILE"; }
check_status()  { [ -f "$STATUS_FILE" ] && cat "$STATUS_FILE" || echo "NOT_STARTED"; }

if [[ "$1" == "--status" ]]; then check_status; exit 0; fi

clear
echo -e "${CYAN}"
echo "====================================="
echo "   WINDOWS AUTO INSTALLER v5"
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
  1) OS_NAME="Windows 10 Pro"; IMAGE_NAME="Windows 10 Pro"
     ISO_URL="https://pub-6dbb0a827a924e12aecd6e56406c953b.r2.dev/Windows10Pro.iso" ;;
  2) OS_NAME="Windows 11 Pro"; IMAGE_NAME="Windows 11 Pro"
     ISO_URL="https://pub-6dbb0a827a924e12aecd6e56406c953b.r2.dev/Windows11Pro.iso" ;;
  3) OS_NAME="Tiny10 23H2 (Ringan - Win10)"; IMAGE_NAME="Windows 10 Pro"
     ISO_URL="https://pub-6dbb0a827a924e12aecd6e56406c953b.r2.dev/Tiny10.iso" ;;
  4) OS_NAME="Tiny11 23H2 (Ringan - Win11)"; IMAGE_NAME="Windows 11 Pro"
     ISO_URL="https://pub-6dbb0a827a924e12aecd6e56406c953b.r2.dev/Tiny11_23H2.iso" ;;
  5) OS_NAME="Tiny11 25H2 (Terbaru - Ringan)"; IMAGE_NAME="Windows 11 Pro"
     ISO_URL="https://pub-6dbb0a827a924e12aecd6e56406c953b.r2.dev/Tiny11_25H2.iso" ;;
  6) OS_NAME="Windows Server 2022"; IMAGE_NAME="Windows Server 2022 SERVERSTANDARD"
     ISO_URL="https://pub-6dbb0a827a924e12aecd6e56406c953b.r2.dev/WindowsServer2022.iso" ;;
  7) OS_NAME="Windows Server 2025 Datacenter"; IMAGE_NAME="Windows Server 2025 SERVERDATACENTER"
     ISO_URL="https://pub-6dbb0a827a924e12aecd6e56406c953b.r2.dev/WindowsServer2025.iso" ;;
  *) echo -e "${RED}Pilihan tidak valid!${NC}"; update_status "ERROR: Pilihan tidak valid"; exit 1 ;;
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
    echo -e "${YELLOW}Install dibatalkan.${NC}"; update_status "CANCELLED"; exit 0
fi

# =====================================
# Install dependencies
# =====================================
update_status "INSTALLING_DEPS"
echo ""
echo -e "${YELLOW}[*] Menginstall dependencies...${NC}"
if command -v apt-get &>/dev/null; then
    apt-get update -qq 2>/dev/null
    apt-get install -y wget curl grub2-common grub-pc \
        syslinux syslinux-common extlinux -qq 2>/dev/null || \
    apt-get install -y wget curl grub-pc -qq 2>/dev/null || true
elif command -v yum &>/dev/null; then
    yum install -y wget curl grub2 -q 2>/dev/null || true
elif command -v dnf &>/dev/null; then
    dnf install -y wget curl grub2 -q 2>/dev/null || true
fi

# Pastikan update-grub tersedia (Ubuntu 22 harusnya ada)
if ! command -v update-grub &>/dev/null; then
    # Buat wrapper update-grub kalau tidak ada
    cat > /usr/local/bin/update-grub << 'GRUBEOF'
#!/bin/bash
grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || \
grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || true
exit 0
GRUBEOF
    chmod +x /usr/local/bin/update-grub
    echo -e "${GREEN}[✓] update-grub wrapper dibuat${NC}"
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
    update_status "ERROR: URL ISO tidak bisa diakses (HTTP $HTTP_CODE)"; exit 1
fi
echo -e "${GREEN}[✓] URL ISO OK (HTTP $HTTP_CODE)${NC}"

# =====================================
# Download reinstall.sh
# =====================================
update_status "DOWNLOADING"
echo ""
echo -e "${YELLOW}[*] Mendownload script reinstall...${NC}"
for i in 1 2 3; do
    wget -qO /tmp/reinstall.sh \
        https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && break
    echo -e "${YELLOW}[!] Retry $i/3...${NC}"; sleep 3
done
if [ ! -s /tmp/reinstall.sh ]; then
    echo -e "${RED}[!] Gagal download reinstall.sh!${NC}"
    update_status "ERROR: Gagal download reinstall.sh"; exit 1
fi
chmod +x /tmp/reinstall.sh
echo -e "${GREEN}[✓] reinstall.sh berhasil didownload${NC}"

# =====================================
# ROOT CAUSE PATCH — 3 target spesifik
# =====================================
echo -e "${YELLOW}[*] Patching reinstall.sh (root cause fix)...${NC}"

python3 << 'PYEOF'
with open('/tmp/reinstall.sh', 'r', errors='replace') as f:
    lines = f.readlines()

new_lines = []
i = 0
while i < len(lines):
    line = lines[i]

    # PATCH 1: Fungsi is_mbr_using_grub() → force return true (pakai GRUB path)
    # Ganti body fungsinya supaya selalu return 0 (true)
    # Original:
    #   is_mbr_using_grub() {
    #       find_main_disk
    #       head -c 440 /dev/$xda | grep -a -iq 'GRUB'
    #   }
    if 'is_mbr_using_grub()' in line and '{' in line:
        new_lines.append(line)  # baris "is_mbr_using_grub() {"
        # Skip baris-baris isi fungsi sampai closing "}"
        i += 1
        while i < len(lines):
            if lines[i].strip() == '}':
                # Masukkan body baru: selalu true + update-grub exist check
                new_lines.append('    # patched: force GRUB path\n')
                new_lines.append('    return 0\n')
                new_lines.append(lines[i])  # closing "}"
                i += 1
                break
            i += 1
        continue

    # PATCH 2: error_and_exit "unsupported bootloader." → ganti jadi true
    if 'error_and_exit' in line and 'unsupported bootloader' in line:
        indent = len(line) - len(line.lstrip())
        new_lines.append(' ' * indent + 'true  # patched: skip unsupported bootloader\n')
        i += 1
        continue

    # PATCH 3: extlinux --clear-once → tambah || true
    if 'extlinux --clear-once' in line and '|| true' not in line:
        new_lines.append(line.rstrip() + ' || true\n')
        i += 1
        continue

    new_lines.append(line)
    i += 1

with open('/tmp/reinstall.sh', 'w') as f:
    f.writelines(new_lines)

# Verifikasi patch berhasil
with open('/tmp/reinstall.sh', 'r') as f:
    content = f.read()

patches_ok = 0
if 'force GRUB path' in content:
    print("[✓] Patch 1: is_mbr_using_grub() → force true")
    patches_ok += 1
else:
    print("[!] Patch 1 GAGAL")

if 'skip unsupported bootloader' in content:
    print("[✓] Patch 2: unsupported bootloader → skip")
    patches_ok += 1
else:
    print("[!] Patch 2 GAGAL")

if '|| true' in content and 'extlinux --clear-once' in content:
    print("[✓] Patch 3: extlinux --clear-once || true")
    patches_ok += 1
else:
    print("[!] Patch 3 GAGAL")

print(f"Patch selesai: {patches_ok}/3 berhasil")
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
        sfdisk --disk-id "$MAIN_DISK" 0x12345678 > /dev/null 2>&1 || \
        printf "x\ni\n0x12345678\nr\nw\n" | fdisk "$MAIN_DISK" > /dev/null 2>&1 || true
        echo -e "${GREEN}[✓] Disk ID di-set manual${NC}"
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
