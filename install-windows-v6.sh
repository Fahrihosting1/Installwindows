#!/bin/bash

# =====================================
#   WINDOWS AUTO INSTALLER v11 FAST
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

clear 2>/dev/null || true
echo -e "${CYAN}"
echo "====================================="
echo "   WINDOWS AUTO INSTALLER v11 FAST"
echo "====================================="
echo -e "${NC}"
echo -e "${YELLOW}Pilih OS yang mau diinstall:${NC}"
echo ""
echo -e "  ${GREEN}[1]${NC} Windows 10 Pro (Original)"
echo -e "  ${GREEN}[2]${NC} Windows 11 Pro (Original)"
echo -e "  ${GREEN}[3]${NC} Tiny10 23H2 x64 (Ringan - Win10)"
echo -e "  ${GREEN}[4]${NC} Tiny11 24H2 x64 (26100.6899 - Ringan)"
echo -e "  ${GREEN}[5]${NC} Windows Server 2022"
echo -e "  ${GREEN}[6]${NC} Windows Server 2025 Datacenter"
echo ""
if [[ -n "${BOT_OS:-}" ]]; then PILIHAN="$BOT_OS"; else read -p "Masukkan pilihan [1-6]: " PILIHAN; fi

case $PILIHAN in
  1) OS_NAME="Windows 10 Pro"; IMAGE_NAME="Windows 10 Pro"
     ISO_URL="https://pub-6dbb0a827a924e12aecd6e56406c953b.r2.dev/Windows10Pro.iso" ;;
  2) OS_NAME="Windows 11 Pro"; IMAGE_NAME="Windows 11 Pro"
     ISO_URL="https://pub-6dbb0a827a924e12aecd6e56406c953b.r2.dev/Windows11Pro.iso" ;;
  3) OS_NAME="Tiny10 23H2 (Ringan - Win10)"; IMAGE_NAME="Windows 10 Pro"
     ISO_URL="https://pub-6dbb0a827a924e12aecd6e56406c953b.r2.dev/Tiny10.iso" ;;
  4) OS_NAME="Tiny11 24H2 (build 26100.6899 - Ringan)"; IMAGE_NAME="Windows 11 Pro"
     ISO_URL="https://huggingface.co/datasets/Biaapoke/windows-iso/resolve/main/tiny1126100.6899.iso" ;;
  5) OS_NAME="Windows Server 2022"; IMAGE_NAME="Windows Server 2022 SERVERSTANDARD"
     ISO_URL="https://pub-6dbb0a827a924e12aecd6e56406c953b.r2.dev/WindowsServer2022.iso" ;;
  6) OS_NAME="Windows Server 2025 Datacenter"; IMAGE_NAME="Windows Server 2025 SERVERDATACENTER"
     ISO_URL="https://pub-6dbb0a827a924e12aecd6e56406c953b.r2.dev/WindowsServer2025.iso" ;;
  *) echo -e "${RED}Pilihan tidak valid!${NC}"; update_status "ERROR: Pilihan tidak valid"; exit 1 ;;
esac

# Optional prebuilt Windows 10 disk image; ISO remains default.
FAST_IMAGE="${WIN10_DD_URL:-}"
INSTALL_MODE=iso
if [[ "$PILIHAN" == 1 && -n "$FAST_IMAGE" ]]; then
    [[ "$FAST_IMAGE" == https://* ]] || { echo "DD image must use HTTPS"; exit 1; }
    INSTALL_MODE=dd
fi
if [[ $EUID -ne 0 ]]; then echo "Run as root"; exit 1; fi
VPS_IP=$(curl -4 -s -m 8 ifconfig.me 2>/dev/null || curl -4 -s -m 8 icanhazip.com 2>/dev/null || echo 'unknown')

WIN_PASSWORD="${WIN_PASSWORD:-}"
if [[ -z "$WIN_PASSWORD" ]]; then
    WIN_PASSWORD="Aa9!$(od -An -N12 -tx1 /dev/urandom | tr -d ' \n')"
fi
umask 077
echo ""
echo -e "${CYAN}====================================="
echo -e " OS dipilih : ${GREEN}$OS_NAME${CYAN}"
echo -e " Username   : ${GREEN}Administrator${CYAN}"
echo -e " Password   : ${GREEN}${WIN_PASSWORD}${CYAN}"
echo -e " RDP Port   : ${GREEN}3389${CYAN}"
echo -e " Mode       : ${GREEN}$INSTALL_MODE${CYAN}"
echo -e " IP VPS     : ${GREEN}$VPS_IP${CYAN}"
echo -e "=====================================${NC}"
echo ""
echo -e "${RED}WARNING: Semua data di VPS akan TERHAPUS!${NC}"
echo ""
read -p "Lanjut install? [y/N]: " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo -e "${YELLOW}Install dibatalkan.${NC}"; update_status "CANCELLED"; exit 42
fi

# =====================================
# Install dependencies
# =====================================
update_status "INSTALLING_DEPS"
echo ""
echo -e "${YELLOW}[*] Mengecek dependencies...${NC}"
if command -v wget >/dev/null && command -v curl >/dev/null && command -v python3 >/dev/null && command -v grub-mkconfig >/dev/null && command -v update-grub >/dev/null; then
    echo "Dependencies sudah tersedia"
else
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
# Resolve link Google Drive (file besar -> halaman konfirmasi virus scan)
# Tanpa ini aria2 cuma ngedownload HTML (~0 B) -> "mount: /iso: unable to read superblock"
# =====================================
resolve_gdrive() {
python3 - "$1" << 'PYEOF3'
import sys, re, html, urllib.request, urllib.parse, http.cookiejar
url = sys.argv[1]
m = re.search(r'[?&]id=([\w-]+)', url) or re.search(r'/d/([\w-]+)', url)
if not m:
    print(url); sys.exit(0)
fid = m.group(1)
base = "https://drive.usercontent.google.com/download"
first = base + "?id=%s&export=download&confirm=t" % fid
op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
op.addheaders = [("User-Agent", "Mozilla/5.0")]
try:
    r = op.open(first, timeout=30)
    if "text/html" not in r.headers.get("Content-Type", ""):
        r.close(); print(first); sys.exit(0)
    body = r.read().decode("utf-8", "replace")
except Exception as e:
    print("ERR: %s" % e, file=sys.stderr); sys.exit(1)
if "Quota exceeded" in body or "Too many users" in body:
    print("ERR: kuota download Google Drive habis (coba lagi nanti / pakai R2)", file=sys.stderr); sys.exit(1)
fm = re.search(r'<form[^>]+action="([^"]+)"', body)
if not fm:
    print("ERR: file Drive tidak public / halaman konfirmasi tidak dikenali", file=sys.stderr); sys.exit(1)
params = {k: html.unescape(v) for k, v in re.findall(r'<input[^>]+name="([^"]+)"[^>]+value="([^"]*)"', body)}
print(html.unescape(fm.group(1)) + "?" + urllib.parse.urlencode(params))
PYEOF3
}

if [[ "$ISO_URL" == *drive.google.com* || "$ISO_URL" == *drive.usercontent.google.com* ]]; then
    update_status "RESOLVING_GDRIVE"
    echo ""
    echo -e "${YELLOW}[*] Resolve link Google Drive...${NC}"
    ISO_URL=$(resolve_gdrive "$ISO_URL")
    if [[ -z "$ISO_URL" || "$ISO_URL" == ERR* ]]; then
        echo -e "${RED}[!] Gagal resolve link Drive (pastikan file 'Anyone with the link').${NC}"
        update_status "ERROR: gdrive resolve gagal"; exit 1
    fi
    echo -e "${GREEN}[✓] Link Drive OK${NC}"
fi

# =====================================
# Cek URL ISO (harus bukan HTML & ukuran masuk akal)
# =====================================
update_status "CHECKING_URL"
echo ""
echo -e "${YELLOW}[*] Mengecek URL ISO...${NC}"
CHECK_URL="$ISO_URL"
[[ "$INSTALL_MODE" == dd ]] && CHECK_URL="$FAST_IMAGE"
HDR=$(curl -sS -I -L --max-time 15 "$CHECK_URL" | tr -d '\r')
if ! echo "$HDR" | grep -Eq '^HTTP/[^ ]+ (200|206)'; then
    HDR=$(curl -s -o /dev/null -D - -L --max-time 15 --max-filesize 1048576 -r 0-0 "$CHECK_URL" | tr -d '\r')
fi
HTTP_CODE=$(echo "$HDR" | grep -i '^HTTP' | tail -1 | awk '{print $2}')
if [[ "$HTTP_CODE" != "200" && "$HTTP_CODE" != "206" ]]; then
    echo -e "${RED}[!] URL ISO tidak bisa diakses (HTTP $HTTP_CODE)${NC}"
    update_status "ERROR: URL ISO tidak bisa diakses (HTTP $HTTP_CODE)"; exit 1
fi
LAST_HDR=$(echo "$HDR" | awk 'BEGIN{b=""} /^HTTP/{b=""} {b=b"\n"$0} END{print b}')
if echo "$LAST_HDR" | grep -iq '^content-type: *text/html'; then
    echo -e "${RED}[!] URL ISO ngembaliin halaman HTML, bukan file ISO (link Drive private / kuota habis).${NC}"
    update_status "ERROR: URL ISO bukan file ISO"; exit 1
fi
echo -e "${GREEN}[✓] URL ISO OK (HTTP $HTTP_CODE)${NC}"

# Ukuran asli ISO (dari Content-Range). Dipakai buat nentuin ukuran partisi installer,
# karena wget --spider di installer salah baca ukuran di link redirect (HuggingFace dll)
# -> partisi cuma 200M -> "cp: cannot create regular file /os/installer/..."
ISO_SIZE=$(echo "$LAST_HDR" | grep -i '^content-range:' | tail -1 | sed 's|.*/||' | tr -dc '0-9')
if [[ -z "$ISO_SIZE" ]]; then
    ISO_SIZE=$(echo "$LAST_HDR" | awk 'tolower($1)=="content-length:" {print $2}' | tail -1 | tr -dc "0-9")
fi
if [[ -z "$ISO_SIZE" || "$ISO_SIZE" -lt 104857600 ]]; then
    ISO_SIZE=$((10 * 1024 * 1024 * 1024))
    echo -e "${YELLOW}[!] Ukuran ISO nggak kebaca, pakai default 10GB${NC}"
else
    echo -e "${GREEN}[✓] Ukuran ISO: $((ISO_SIZE / 1024 / 1024)) MiB${NC}"
fi
echo "$ISO_SIZE" > /tmp/iso_size_bytes

# =====================================
# Deteksi provider (override: PROVIDER=linode|other bash install-windows.sh)
# =====================================
detect_provider() {
    local v
    v=$(cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/bios_vendor 2>/dev/null | tr 'A-Z' 'a-z')
    echo "$v" | grep -q digitalocean && { echo other; return; }
    echo "$v" | grep -q linode && { echo linode; return; }
    # Linode metadata service: hanya Linode yang ngasih token di sini
    if curl -fs -m 4 -X PUT -H "Metadata-Token-Expiry-Seconds: 60" \
        http://169.254.169.254/v1/token 2>/dev/null | grep -q .; then
        echo linode; return
    fi
    echo other
}
PROVIDER="${PROVIDER:-$(detect_provider)}"
if [[ "$INSTALL_MODE" == dd && "$PROVIDER" == linode ]]; then
    update_status "ERROR: DD Linode belum diuji"; echo "DD Linode belum diuji; gunakan ISO atau uji pada VPS disposable."; exit 1
fi
echo -e "${YELLOW}[*] Provider terdeteksi: ${GREEN}$PROVIDER${NC}"
if [ "$PROVIDER" = "linode" ]; then
    echo -e "${YELLOW}    (mode Linode: patch bootloader + auto Direct Disk)${NC}"
else
    echo -e "${YELLOW}    (mode normal: reinstall.sh upstream tanpa patch paksa)${NC}"
fi

if [ "$PROVIDER" = "linode" ]; then
# =====================================
# LINODE FIX: otomatis ganti boot ke Direct Disk
# (host GRUB 2 Linode nggak bisa baca NTFS -> "prefix isn't set")
# =====================================
update_status "LINODE_API"
echo ""
echo -e "${YELLOW}[*] Setup Linode API (auto Direct Disk)...${NC}"
LINODE_TOKEN="${LINODE_TOKEN:-}"
if [ -z "$LINODE_TOKEN" ]; then
    read -rp "Linode API token (scope Linodes: Read/Write): " LINODE_TOKEN
fi
LINODE_TOKEN=$(echo "$LINODE_TOKEN" | tr -d '[:space:]')
echo -e "${YELLOW}    Panjang token: ${#LINODE_TOKEN} karakter (normal: 64)${NC}"

LINODE_IDS=$(LINODE_TOKEN="$LINODE_TOKEN" VPS_IP="$VPS_IP" python3 - << 'PYEOF2'
import json, os, urllib.request
tok, ip = os.environ["LINODE_TOKEN"], os.environ["VPS_IP"]
def api(path):
    r = urllib.request.Request("https://api.linode.com/v4" + path,
                               headers={"Authorization": "Bearer " + tok})
    return json.load(urllib.request.urlopen(r, timeout=20))
try:
    for l in api("/linode/instances?page_size=500")["data"]:
        if ip in l.get("ipv4", []):
            cfgs = api("/linode/instances/%d/configs" % l["id"])["data"]
            print("%d %d" % (l["id"], cfgs[0]["id"]))
            break
    else:
        print("ERR: IP %s tidak ada di akun ini" % ip, file=__import__("sys").stderr)
except Exception as e:
    print("ERR: %s" % e, file=__import__("sys").stderr)
PYEOF2
)
LINODE_ID=$(echo "$LINODE_IDS" | awk '{print $1}')
LINODE_CFG=$(echo "$LINODE_IDS" | awk '{print $2}')
if [[ -z "$LINODE_ID" || -z "$LINODE_CFG" ]]; then
    echo -e "${RED}[!] Linode ID/config nggak ketemu (cek token & scope). Dibatalkan biar VPS nggak nyangkut.${NC}"
    update_status "ERROR: Linode API gagal"; exit 1
fi
echo -e "${GREEN}[✓] Linode ID=$LINODE_ID config=$LINODE_CFG${NC}"

# Perintah yang disisipkan LANGSUNG ke trans.sh (bukan file terpisah, karena
# tahap 2 installer cuma nyalin trans.sh), jalan tepat sebelum reboot
cat > /tmp/linode_fix.sh << LFEOF
{
apk add curl ca-certificates >/dev/null 2>&1
for i in 1 2 3 4 5; do
    curl -fsS -X PUT \\
      -H "Authorization: Bearer $LINODE_TOKEN" \\
      -H "Content-Type: application/json" \\
      -d '{"kernel":"linode/direct-disk"}' \\
      https://api.linode.com/v4/linode/instances/$LINODE_ID/configs/$LINODE_CFG && break
    sleep 3
done
} || true
LFEOF
cat > /tmp/linode_inject.py << 'INJEOF'
import sys
p = sys.argv[1]
fix = open('/tmp/linode_fix.sh').read()
lines = open(p).read().split('\n')
out, n = [], 0
for l in lines:
    if l == 'reboot':
        out.append(fix.rstrip('\n'))
        n += 1
    out.append(l)
open(p, 'w').write('\n'.join(out))
print("linode hook disisipkan: %d tempat" % n)
if n == 0:
    sys.exit(1)
INJEOF
fi

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

if [ "$PROVIDER" = "linode" ]; then
# =====================================
# ROOT CAUSE PATCH — 4 target spesifik
# =====================================
echo -e "${YELLOW}[*] Patching reinstall.sh (root cause fix)...${NC}"

python3 << 'PYEOF'
with open('/tmp/reinstall.sh', 'r', errors='replace') as f:
    lines = f.readlines()

new_lines = []
i = 0
while i < len(lines):
    line = lines[i]

    # PATCH 1: paksa deteksi bootloader = GRUB
    # Upstream LAMA: is_mbr_using_grub() { ... }  -> body diganti return 0
    if 'is_mbr_using_grub()' in line and '{' in line:
        new_lines.append(line)
        i += 1
        while i < len(lines):
            if lines[i].strip() == '}':
                new_lines.append('    # patched: force GRUB path\n')
                new_lines.append('    return 0\n')
                new_lines.append(lines[i])
                i += 1
                break
            i += 1
        continue
    # Upstream BARU: get_local_bootloader_type() cek marker "GRUB" di MBR.
    # Di Linode (Direct Disk) MBR tidak ada marker GRUB -> hilangkan syarat itu.
    if 'head -c 446 /dev/$xda' in line and 'tail -c 128' in line and 'grep -a -Fq GRUB' in line:
        indent = ' ' * (len(line) - len(line.lstrip()))
        new_lines.append(indent + 'true; then  # patched: force GRUB path\n')
        i += 1
        continue

    # PATCH 2: jangan error kalau bootloader tidak terdeteksi, fallback ke grub
    # Upstream LAMA: error_and_exit "unsupported bootloader."
    if 'error_and_exit' in line and 'unsupported bootloader' in line:
        indent = ' ' * (len(line) - len(line.lstrip()))
        new_lines.append(indent + 'true  # patched: skip unsupported bootloader\n')
        i += 1
        continue
    # Upstream BARU: error_and_exit "Unknown bootloader type."
    if 'error_and_exit' in line and 'Unknown bootloader type' in line:
        indent = ' ' * (len(line) - len(line.lstrip()))
        new_lines.append(indent + '_bootloader_type="grub"  # patched: skip unsupported bootloader\n')
        i += 1
        continue

    # PATCH 3: extlinux --clear-once → tambah || true
    if 'extlinux --clear-once' in line and '|| true' not in line:
        new_lines.append(line.rstrip() + ' || true  # patched: clear-once\n')
        i += 1
        continue

    # PATCH 4: sisipkan fix Direct Disk ke trans.sh (jalan sebelum reboot terakhir)
    if line.strip() == 'curl -Lo $initrd_dir/trans.sh $confhome/trans.sh':
        indent = ' ' * (len(line) - len(line.lstrip()))
        new_lines.append(line)
        new_lines.append(indent + '# patched: linode direct-disk\n')
        new_lines.append(indent + 'python3 /tmp/linode_inject.py $initrd_dir/trans.sh\n')
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

if 'patched: clear-once' in content:
    print("[✓] Patch 3: extlinux --clear-once || true")
    patches_ok += 1
else:
    print("[!] Patch 3 GAGAL")

if 'patched: linode direct-disk' in content:
    print("[✓] Patch 4: Linode Direct Disk hook")
    patches_ok += 1
else:
    print("[!] Patch 4 GAGAL")

print(f"Patch selesai: {patches_ok}/4 berhasil")
if patches_ok < 4:
    raise SystemExit(1)
PYEOF
if [ $? -ne 0 ]; then
    echo -e "${RED}[!] Patch gagal, dibatalkan (reinstall.sh upstream mungkin berubah).${NC}"
    update_status "ERROR: patch gagal"; exit 1
fi

echo -e "${GREEN}[✓] Patch selesai${NC}"
else
    echo -e "${GREEN}[✓] Non-Linode: pakai reinstall.sh asli, tanpa patch${NC}"
fi

# =====================================
# PATCH UKURAN PARTISI INSTALLER (semua provider)
# =====================================
if [[ "$INSTALL_MODE" == iso ]]; then
cat > /tmp/size_inject.py << 'SZEOF'
import sys
p = sys.argv[1]
size = int(open('/tmp/iso_size_bytes').read().strip())
t = open(p).read()
key = 'part_size="$((size_bytes / 1024 / 1024 + 200))MiB"'
if key not in t:
    sys.exit(1)
fix = ('size_bytes=%d  # patched: real ISO size\n        ' % size) + key
t = t.replace(key, fix, 1)
# locale kosong/invalid (image Tiny tanpa metadata Default Language) -> Setup nampilin pilih bahasa
lk = "locale=$(get_selected_image_prop 'Default Language')"
if lk in t:
    t = t.replace(lk, lk + '\n    case "$locale" in [a-z][a-z]-*|[a-z][a-z][a-z]-*) ;; *) locale=en-US ;; esac', 1)
# Speed up ISO downloads when the server supports byte ranges.
old = 'if aria2c "$url" "$@"; then'
new = 'if (case "$url" in *.iso|*.iso\\?*) aria2c -x 8 -s 8 -k 4M --file-allocation=none "$url" "$@" ;; *) aria2c "$url" "$@" ;; esac); then'
if t.count(old) == 1:
    t = t.replace(old, new, 1)
else:
    print("Download hook not matched; retaining upstream downloader")
open(p, 'w').write(t)
print("ukuran partisi installer dipatch: %d bytes" % size)
SZEOF
python3 - << 'PYEOF4'
lines = open('/tmp/reinstall.sh', errors='replace').read().split('\n')
out, n = [], 0
for l in lines:
    out.append(l)
    if l.strip() == 'curl -Lo $initrd_dir/trans.sh $confhome/trans.sh':
        ind = l[:len(l) - len(l.lstrip())]
        out.append(ind + '# patched: real iso size')
        out.append(ind + 'python3 /tmp/size_inject.py $initrd_dir/trans.sh || { echo "gagal patch ukuran partisi"; exit 1; }')
        n += 1
if n == 0:
    print("[!] Patch ukuran partisi GAGAL (reinstall.sh upstream berubah)")
    raise SystemExit(1)
open('/tmp/reinstall.sh', 'w').write('\n'.join(out))
print("[✓] Patch ukuran partisi installer: %d tempat" % n)
PYEOF4
if [ $? -ne 0 ]; then
    echo -e "${RED}[!] Patch ukuran partisi gagal, dibatalkan.${NC}"
    update_status "ERROR: patch ukuran gagal"; exit 1
fi

# =====================================
fi

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
echo -e "${YELLOW}[*] Mode $INSTALL_MODE; durasi bergantung pada jaringan dan disk...${NC}"
echo ""

# ISO setup: OpenSSH is optional, to avoid delaying RDP readiness.
OPENSSH_SCRIPT='Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0; Start-Service sshd; Set-Service -Name sshd -StartupType Automatic; New-NetFirewallRule -Name sshd -DisplayName "OpenSSH Server" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22'
if [[ "$INSTALL_MODE" == dd ]]; then
    echo "Fast mode: deploying prepared Windows image"
    bash /tmp/reinstall.sh dd --img "$FAST_IMAGE" --password "$WIN_PASSWORD" --rdp-port 3389
    RESULT=$?
else
    args=(windows --image-name "$IMAGE_NAME" --iso "$ISO_URL" --username Administrator --password "$WIN_PASSWORD")
    if [[ "${ENABLE_OPENSSH:-0}" == 1 ]] && bash /tmp/reinstall.sh --help 2>&1 | grep -q 'firstboot-powershell'; then
        args+=(--firstboot-powershell "$OPENSSH_SCRIPT")
    fi
    bash /tmp/reinstall.sh "${args[@]}"
    RESULT=$?
fi
if [[ $RESULT -ne 0 ]]; then
    update_status "ERROR: reinstall exit $RESULT"
    echo "Installer failed; automatic reboot cancelled."
    exit "$RESULT"
fi

update_status "REBOOTING"
echo ""
echo -e "${GREEN}====================================="
echo -e " Persiapan selesai! VPS akan reboot untuk instalasi..."
echo -e " Akses setelah Windows dan RDP siap:"
echo -e " IP       : $VPS_IP"
echo -e " RDP Port : 3389"
echo -e " SSH Windows: opsional (ENABLE_OPENSSH=1 untuk ISO jika didukung)"
echo -e " Username : Administrator"
echo -e " Password : ${WIN_PASSWORD}"
echo -e "=====================================${NC}"

update_status "REBOOTING: IP=$VPS_IP RDP=3389 (Windows belum terverifikasi)"

reboot
