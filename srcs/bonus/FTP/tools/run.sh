#!/bin/bash
set -e

mkdir -p /var/run/vsftpd/empty

# Create FTP user if it doesn't exist
if ! id "$FTP_USER" >/dev/null 2>&1; then
    useradd \
        -m \
        -d "/home/$FTP_USER" \
        -s /bin/bash \
        "$FTP_USER"
fi

# Set/update password
echo "$FTP_USER:$(cat /run/secrets/ftp_password)" | chpasswd

# Create FTP root if it doesn't exist
mkdir -p /var/www/html

# Give ownership of the WordPress files
chown -R "$FTP_USER:$FTP_USER" /var/www/html

# Replace passive IP in config
sed -i "s|PASV_ADDRESS|${FTP_PASV_ADDRESS}|g" /etc/vsftpd.conf

# Start vsftpd in foreground
exec /usr/sbin/vsftpd /etc/vsftpd.conf