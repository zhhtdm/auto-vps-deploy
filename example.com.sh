#!/bin/bash

set -euo pipefail

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
	echo; echo "Please run as root"
	exit 1
fi

# ===========================
PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINjLJbjPBNvwZvwUd7fWwBwRrP+fXfCeVeT0jOd4/h2v eddsa-key-20250430" # 改为自己的公钥
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Append public key if not exists
grep -qxF "$PUBKEY" ~/.ssh/authorized_keys 2>/dev/null || echo "$PUBKEY" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo; echo "✅ Public key added"; echo;

# Allow HTTP and HTTPS traffic
if command -v ufw >/dev/null 2>&1; then
	ufw allow 80
	ufw allow 443
	echo "ufw allowed ports 80 and 443";
else
	echo "ufw not installed, skipping firewall config";
fi
echo ""

# Install packages
apt update
apt install -y nginx certbot python3-certbot-nginx git python3-venv python3-pip
systemctl enable nginx
systemctl start nginx
echo; echo "✅ Nginx, Certbot, Git, Python venv installed"
# ===========================

# ===========================
# Detect CSV file path based on script name
MAIN_DOMAIN="$(basename "$0" .sh)"
CSV_FILE="$(dirname "$0")/$MAIN_DOMAIN.csv"
if [ ! -f "$CSV_FILE" ]; then
	echo; echo "CSV file not found: $CSV_FILE"; echo;
	exit 1
fi

EMAIL="example@example.com"		# For Let's Encrypt
WEBROOT="/var/www/html"
SITES_AVAILABLE="/etc/nginx/sites-available"
SITES_ENABLED="/etc/nginx/sites-enabled"

mkdir -p "$WEBROOT/.well-known/acme-challenge"

FIRST_LINE=1 # Skip the header row
while IFS=, read -r _GIT DIR SUBDOMAIN PORT NAME CMD REST; do
	if [ "$FIRST_LINE" -eq 1 ]; then
		FIRST_LINE=0
		continue
	fi
	[ -z "$_GIT" ] && continue

	# Strip surrounding quotes from each field
    for var in _GIT DIR SUBDOMAIN PORT NAME CMD; do
        val="${!var}"
        val="${val%\"}"
        val="${val#\"}"
        declare "$var=$val"
    done

	DOMAIN="$SUBDOMAIN.$MAIN_DOMAIN"
	CERT_DIR="/etc/letsencrypt/live/$DOMAIN"
	CONF_NAME="$DOMAIN.conf"

	# Issue certificate if not exists
	if [ ! -d "$CERT_DIR" ]; then
		echo; echo "🔐 Issuing certificate for $DOMAIN..."; echo;
		certbot certonly --webroot -w "$WEBROOT" -d "$DOMAIN" --email "$EMAIL" --agree-tos --no-eff-email --non-interactive || {
			echo; echo "❌ Failed to issue certificate for $DOMAIN"
			continue
		}
		echo; echo "✅ Certificate issued for $DOMAIN"; echo;
	else
		echo; echo "🔁 Certificate already exists for $DOMAIN"; echo;
	fi

	# Create nginx config
	cat > "$SITES_AVAILABLE/$CONF_NAME" <<EOF
server {
	listen 80;
	server_name $DOMAIN;

	location /.well-known/acme-challenge/ {
		root $WEBROOT;
	}

	location / {
		return 301 https://\$host\$request_uri;
	}
}

server {
	listen 443 ssl http2;
	server_name $DOMAIN;

	ssl_certificate $CERT_DIR/fullchain.pem;
	ssl_certificate_key $CERT_DIR/privkey.pem;

	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_ciphers HIGH:!aNULL:!MD5;

	location /.well-known/acme-challenge/ {
		root $WEBROOT;
	}

	location / {
		proxy_pass http://localhost:$PORT;
		proxy_http_version 1.1;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto \$scheme;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection "upgrade";
	}
}
EOF

	ln -sf "$SITES_AVAILABLE/$CONF_NAME" "$SITES_ENABLED/$CONF_NAME"
	nginx -t && systemctl reload nginx
	echo; echo "✅ Nginx configured for $DOMAIN"; echo;

	# Clone repository
	rm -rf "$DIR"
	git clone "$_GIT" "$DIR"
	echo; echo "📁 Cloned repo to $DIR"

	# Write .env file
	ENV_FILE="$DIR/.env"

	echo "$REST" | \
	awk -F, '{for(i=1;i<=NF;i++){gsub(/^"|"$/, "", $i); if($i!="") print $i}}' > "$ENV_FILE"
    
	chmod 600 "$ENV_FILE"
    echo; echo "✅ .env created for $NAME"


	# uninstall.sh
	cat > "$DIR/uninstall.sh" <<EOF
#!/bin/bash

if [ "\$EUID" -ne 0 ]; then
	echo; echo "Please run as root"
	exit 1
fi

echo; echo "🔻 Stopping service: $NAME"
systemctl stop "$NAME"
systemctl disable "$NAME"

echo; echo "🧹 Removing systemd service file"
rm -f /etc/systemd/system/$NAME.service
systemctl daemon-reload

echo; echo "🧹 Removing nginx config"
rm -f /etc/nginx/sites-enabled/$CONF_NAME
rm -f /etc/nginx/sites-available/$CONF_NAME

echo; echo "🔐 Deleting SSL certificate for $DOMAIN"
certbot delete --cert-name "$DOMAIN" -y

echo; echo "♻️ Reloading nginx"
nginx -t && systemctl reload nginx

cd /tmp
echo; echo "🗑️ Removing project directory"
rm -rf "$DIR"

echo; echo "✅ Uninstallation complete"
EOF
	chmod 700 "$DIR/uninstall.sh"
	echo; echo "✅ uninstall.sh created for $NAME"; echo;

	# If CMD is Python script, set up venv
	if [[ "$CMD" == *.py ]]; then
		cd "$DIR"
		python3 -m venv .venv
		source .venv/bin/activate
		pip install --upgrade pip
		pip install -r requirements.txt || true
		deactivate
		echo; echo "✅ Python dependencies installed"

		# Create upgrade.sh
		cat > "$DIR/upgrade.sh" <<EOF
#!/bin/bash

if [ "\$EUID" -ne 0 ]; then
	echo; echo "Please run as root"
	exit 1
fi

cd "$DIR"
git pull
source .venv/bin/activate
pip install -r requirements.txt
deactivate
echo; echo "✅ $NAME upgraded"
systemctl daemon-reload
systemctl restart $NAME
echo; echo "✅ $NAME.service restarted"
EOF
		chmod 700 "$DIR/upgrade.sh"
		echo; echo "✅ upgrade.sh created for $NAME"
	fi

	# Create systemd service
	cat > "/etc/systemd/system/$NAME.service" <<EOF
[Unit]
Description=Service for $NAME
After=network.target

[Service]
Type=simple
WorkingDirectory=$DIR
ExecStart=$CMD
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
	
	systemctl daemon-reexec
	systemctl daemon-reload
	echo ""
	systemctl enable --now "$NAME" && \
		echo "✅ $NAME.service started" || \
		echo "❌ Failed to start $NAME.service: check with journalctl -u $NAME"
	echo ""

done < "$CSV_FILE"
# ===========================
