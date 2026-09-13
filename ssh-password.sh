#!/bin/bash

set -e

echo "======================================"
echo " SSH Key -> Password Login"
echo "======================================"

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] Jalankan script sebagai root."
    exit 1
fi

# Backup konfigurasi SSH
BACKUP="/root/ssh-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"

cp -a /etc/ssh/sshd_config "$BACKUP/sshd_config"

if [ -d /etc/ssh/sshd_config.d ]; then
    cp -a /etc/ssh/sshd_config.d "$BACKUP/sshd_config.d"
fi

echo "[OK] Backup dibuat di: $BACKUP"

# Set password root - baca dari /dev/tty agar bisa interaktif saat curl | bash
echo
echo "Buat password baru untuk user root:"

while true; do
    read -s -p "New password: " PASSWORD < /dev/tty
    echo
    read -s -p "Retype new password: " PASSWORD2 < /dev/tty
    echo

    if [ "$PASSWORD" != "$PASSWORD2" ]; then
        echo "[ERROR] Password tidak cocok, coba lagi."
        continue
    fi

    if [ -z "$PASSWORD" ]; then
        echo "[ERROR] Password tidak boleh kosong, coba lagi."
        continue
    fi

    echo "root:$PASSWORD" | chpasswd
    echo "[OK] Password root berhasil diperbarui."
    unset PASSWORD PASSWORD2
    break
done

# Buat override config agar tidak bentrok dengan cloud-init/config lain
cat > /etc/ssh/sshd_config.d/99-password-login.conf <<'EOF'
PasswordAuthentication yes
KbdInteractiveAuthentication yes
PubkeyAuthentication no
PermitRootLogin yes
EOF

echo "[OK] Konfigurasi SSH diperbarui."

# Validasi konfigurasi
echo
echo "Memeriksa konfigurasi SSH..."

if ! sshd -t; then
    echo "[ERROR] Konfigurasi SSH tidak valid."
    echo "[INFO] Memulihkan konfigurasi backup..."

    rm -f /etc/ssh/sshd_config.d/99-password-login.conf
    cp "$BACKUP/sshd_config" /etc/ssh/sshd_config

    echo "[ERROR] Perubahan dibatalkan."
    exit 1
fi

# Restart SSH
systemctl restart ssh 2>/dev/null || systemctl restart sshd

echo
echo "======================================"
echo " BERHASIL"
echo "======================================"

echo
echo "Konfigurasi sekarang:"
sshd -T | grep -E 'passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|permitrootlogin'

echo
echo "Login SSH sekarang:"
echo "ssh root@IP_VPS"
echo
echo "Gunakan password root yang baru dibuat."
echo
echo "Backup:"
echo "$BACKUP"
