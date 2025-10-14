#!/bin/bash

# ==============================================================================
# Taiga.io Auto-Installation Script for Ubuntu 20.04 / 22.04
#
# ATTENTION:
# - Run this script on a FRESH server.
# - Review the variables below before running.
# - This script must be run with sudo privileges.
#
# Based on: https://docs.taiga.io/installation.html
# ==============================================================================

# Exit immediately if a command exits with a non-zero status.
set -e

# --- CONFIGURATION VARIABLES ---
# IMPORTANT: Change these values before running the script!

# The domain name where Taiga will be accessible.
# You MUST own this domain and point its A record to this server's IP.
DOMAIN="taiga.yourdomain.com"

# Taiga Superuser credentials
ADMIN_EMAIL="admin@example.com"
ADMIN_PASSWORD="admin12345" # CHANGE THIS!

# Database credentials
DB_NAME="taiga"
DB_USER="taiga"
DB_PASSWORD="taiga-db-password" # CHANGE THIS!

# Email settings (for notifications)
# Leave as is if you don't have an SMTP server. Taiga will still work.
EMAIL_HOST="localhost"
EMAIL_PORT=587
EMAIL_HOST_USER=""
EMAIL_HOST_PASSWORD=""
EMAIL_USE_TLS="True"

# --- END OF CONFIGURATION ---


# --- SCRIPT LOGIC (Do not edit below this line) ---

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root (use sudo)."
fi

# Check if it's a fresh Ubuntu install
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        print_error "This script is designed for Ubuntu only."
    fi
else
    print_error "Cannot determine OS. This script is designed for Ubuntu."
fi

print_status "Starting Taiga installation on $DOMAIN..."

# 1. System Update & Install Dependencies
print_status "Step 1: Updating system and installing base dependencies..."
apt-get update
apt-get install -y build-essential git curl wget python3-pip python3-dev python3-venv libpq-dev libxml2-dev libxslt1-dev libjpeg-dev zlib1g-dev libffi-dev

# 2. Install and Configure PostgreSQL
print_status "Step 2: Installing and configuring PostgreSQL..."
apt-get install -y postgresql postgresql-contrib
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

# 3. Install and Configure Redis
print_status "Step 3: Installing and configuring Redis..."
apt-get install -y redis-server
systemctl enable redis-server
systemctl start redis-server

# 4. Install and Configure RabbitMQ
print_status "Step 4: Installing and configuring RabbitMQ..."
apt-get install -y rabbitmq-server
systemctl enable rabbitmq-server
systemctl start rabbitmq-server
rabbitmqctl add_user taiga taiga-rabbitmq-password # A simple password for internal use
rabbitmqctl add_vhost taiga
rabbitmqctl set_permissions -p taiga taiga ".*" ".*" ".*"

# 5. Install Taiga Backend
print_status "Step 5: Installing Taiga Backend..."
useradd -m -s /bin/bash taiga || true # Create user if not exists
cd /home/taiga
sudo -u taiga git clone https://github.com/taigaio/taiga-back.git taiga-back
cd taiga-back
sudo -u taiga git checkout stable
sudo -u taiga python3 -m venv venv
sudo -u taiga source venv/bin/activate
sudo -u taiga pip install --upgrade pip
sudo -u taiga pip install -r requirements.txt

# 6. Configure Taiga Backend
print_status "Step 6: Configuring Taiga Backend..."
cd /home/taiga/taiga-back
SECRET_KEY=$(python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')

# Create local.py config file
sudo -u taiga tee config/local.py > /dev/null <<EOF
from .common import *

# This is your TAIGA_SECRET_KEY. Keep it safe!
SECRET_KEY = "$SECRET_KEY"

# Database settings
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": "$DB_NAME",
        "USER": "$DB_USER",
        "PASSWORD": "$DB_PASSWORD",
        "HOST": "localhost",
        "PORT": "",
    }
}

# Email settings
EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
DEFAULT_FROM_EMAIL = "$ADMIN_EMAIL"
EMAIL_HOST = "$EMAIL_HOST"
EMAIL_PORT = $EMAIL_PORT
EMAIL_HOST_USER = "$EMAIL_HOST_USER"
EMAIL_HOST_PASSWORD = "$EMAIL_HOST_PASSWORD"
EMAIL_USE_TLS = $EMAIL_USE_TLS
EMAIL_SUBJECT_PREFIX = "[Taiga] "

# Server settings
SITES = {"domain": "$DOMAIN"}
FRONTEND_SCHEME = "http" # Change to "https" after setting up SSL

# Taiga Async
CELERY_ENABLED = True
EVENTS_PUSH_BACKEND = "taiga.events.backends.rabbitmq.EventsPushBackend"
EVENTS_PUSH_BACKEND_OPTIONS = {"url": "amqp://taiga:taiga-rabbitmq-password@localhost:5672/taiga"}

# Telemetry
TELEMETRY_ENABLED = False
PUBLIC_REGISTER_ENABLED = True
EOF

# Populate database
sudo -u taiga python manage.py migrate --noinput
sudo -u taiga python manage.py loaddata initial_user.json
sudo -u taiga python manage.py loaddata initial_project_templates.json
sudo -u taiga python manage.py compilemessages
sudo -u taiga python manage.py collectstatic --noinput

# Update admin user
sudo -u taiga python manage.py shell <<EOF
from django.contrib.auth import get_user_model
User = get_user_model()
user = User.objects.get(username="admin")
user.email = "$ADMIN_EMAIL"
user.set_password("$ADMIN_PASSWORD")
user.save()
print("Admin user updated.")
EOF

# 7. Install Taiga Frontend
print_status "Step 7: Installing Taiga Frontend..."
cd /home/taiga
sudo -u taiga git clone https://github.com/taigaio/taiga-front-dist.git taiga-front-dist
cd taiga-front-dist
sudo -u taiga git checkout stable

# 8. Configure Taiga Frontend
print_status "Step 8: Configuring Taiga Frontend..."
sudo -u taiga tee dist/conf.json > /dev/null <<EOF
{
    "api": "http://$DOMAIN/api/v1/",
    "eventsUrl": "ws://$DOMAIN/events",
    "debug": false,
    "publicRegisterEnabled": true,
    "feedbackEnabled": true,
    "privacyPolicyUrl": null,
    "termsOfServiceUrl": null,
    "maxUploadFileSize": null,
    "githubClientId": null,
    "gitlabClientId": null,
    "gitlabUrl": null,
    "bitbucketClientId": null,
    "googleClientId": null,
    "microsoftClientId": null,
    "slackClientId": null,
    "discordClientId": null,
    "loginFormType": "normal",
    "saml2Enabled": false,
    "saml2AutoCreateUsers": false,
    "blockThirdPartyCookies": false,
    "prometheusEnabled": false,
    "prometheusMetricsPath": "/metrics",
    "trackPerformance": false,
    "exportableFormats": ["json", "xlsx"],
    "importers": ["trello", "jira", "asana", "github"]
}
EOF

# 9. Install and Configure Nginx
print_status "Step 9: Installing and configuring Nginx..."
apt-get install -y nginx
rm -f /etc/nginx/sites-enabled/default

# Create Nginx config for Taiga
tee /etc/nginx/sites-available/taiga > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    # Large uploads support
    client_max_body_size 100M;

    # Static files
    location / {
        alias /home/taiga/taiga-front-dist/dist/;
        try_files \$uri \$uri/ /index.html;
    }

    # API
    location /api/ {
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_pass http://127.0.0.1:8001/api/;
        proxy_redirect off;
    }

    # Admin access (/admin/)
    location /admin/ {
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_pass http://127.0.0.1:8001/admin/;
        proxy_redirect off;
    }

    # Static files for Django
    location /static/ {
        alias /home/taiga/taiga-back/static/;
    }

    # Media files for Django
    location /media/ {
        alias /home/taiga/taiga-back/media/;
    }

    # Events (WebSocket)
    location /events {
        proxy_pass http://127.0.0.1:8001/events;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }
}
EOF

ln -s /etc/nginx/sites-available/taiga /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# 10. Configure Systemd services for Taiga
print_status "Step 10: Creating Systemd services for Taiga Backend..."

# Service for Gunicorn (Taiga API)
tee /etc/systemd/system/taiga-back.service > /dev/null <<EOF
[Unit]
Description=Taiga Back
After=network.target postgresql.service redis.service rabbitmq-server.service

[Service]
Type=notify
User=taiga
Group=taiga
WorkingDirectory=/home/taiga/taiga-back
Environment=PATH=/home/taiga/taiga-back/venv/bin
ExecStart=/home/taiga/taiga-back/venv/bin/gunicorn --workers 4 --timeout 60 --bind 127.0.0.1:8001 taiga.wsgi:application
NotifyAccess=all
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Service for Celery (Taiga Async)
tee /etc/systemd/system/taiga-async.service > /dev/null <<EOF
[Unit]
Description=Taiga Async
After=network.target postgresql.service redis.service rabbitmq-server.service

[Service]
Type=exec
User=taiga
Group=taiga
WorkingDirectory=/home/taiga/taiga-back
Environment=PATH=/home/taiga/taiga-back/venv/bin
ExecStart=/home/taiga/taiga-back/venv/bin/celery -A taiga.celery worker -l info
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Enable and start services
systemctl daemon-reload
systemctl enable taiga-back taiga-async
systemctl start taiga-back taiga-async

# --- FINALIZATION ---
print_status "=================================================================="
print_status "Taiga installation complete!"
print_status "=================================================================="
echo
print_warning "IMPORTANT NEXT STEPS:"
echo
echo "1. DNS: Point the A record of '$DOMAIN' to this server's IP address."
echo "2. SSL: It is highly recommended to secure your site with HTTPS."
echo "   Run these commands after DNS has propagated:"
echo "   sudo apt-get install certbot python3-certbot-nginx"
echo "   sudo certbot --nginx -d $DOMAIN"
echo
echo "3. Update Taiga Frontend Config for HTTPS:"
echo "   After SSL is installed, edit /home/taiga/taiga-front-dist/dist/conf.json"
echo "   and change 'http://' to 'https://' in the 'api' and 'eventsUrl' fields."
echo "   Then restart Nginx: sudo systemctl restart nginx"
echo
echo "4. Firewall: Consider enabling a firewall (e.g., sudo ufw allow 'Nginx Full')."
echo
print_status "You can now access Taiga at: http://$DOMAIN"
print_status "Login with the following credentials:"
echo "   Username: admin"
echo "   Password: $ADMIN_PASSWORD"
echo
print_status "Please change the admin password immediately after logging in."
print_status "=================================================================="
