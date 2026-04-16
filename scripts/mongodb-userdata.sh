#!/bin/bash
# MongoDB 4.4 setup on Ubuntu 20.04 (Focal)
# Both Ubuntu 20.04 and MongoDB 4.4 are 1+ year outdated — intentional per exercise spec

set -euo pipefail
exec > >(tee /var/log/userdata.log) 2>&1

echo "=== Starting MongoDB setup ==="

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl gnupg awscli

# Install MongoDB 4.4 (outdated — intentional weakness)
curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" \
  | tee /etc/apt/sources.list.d/mongodb-org-4.4.list

apt-get update -y
apt-get install -y \
  mongodb-org=4.4.29 \
  mongodb-org-server=4.4.29 \
  mongodb-org-shell=4.4.29 \
  mongodb-org-mongos=4.4.29 \
  mongodb-org-tools=4.4.29

# Pin MongoDB version to prevent unintentional upgrades
echo "mongodb-org hold"        | dpkg --set-selections
echo "mongodb-org-server hold" | dpkg --set-selections
echo "mongodb-org-shell hold"  | dpkg --set-selections
echo "mongodb-org-mongos hold" | dpkg --set-selections
echo "mongodb-org-tools hold"  | dpkg --set-selections

# Configure MongoDB — listen on all interfaces, auth enabled
cat > /etc/mongod.conf << 'EOF'
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
net:
  port: 27017
  bindIp: 0.0.0.0
security:
  authorization: enabled
processManagement:
  timeZoneInfo: /usr/share/zoneinfo
EOF

systemctl daemon-reload
systemctl enable mongod
systemctl start mongod

echo "Waiting for MongoDB to start..."
sleep 10

# Bootstrap admin and app users (auth is disabled on first start without auth section,
# but we enabled it — use --noauth localhost exception for initial user creation)
systemctl stop mongod

# Temporarily start without auth to create users
sudo -u mongodb mongod --dbpath /var/lib/mongodb --noauth --fork --logpath /tmp/mongod-init.log

sleep 5

mongo --eval "
db = db.getSiblingDB('admin');
db.createUser({
  user: 'admin',
  pwd: '${mongodb_admin_password}',
  roles: [
    { role: 'userAdminAnyDatabase', db: 'admin' },
    { role: 'readWriteAnyDatabase', db: 'admin' },
    { role: 'clusterAdmin', db: 'admin' }
  ]
});
db = db.getSiblingDB('tododb');
db.createUser({
  user: 'wiz',
  pwd: '${mongodb_password}',
  roles: [{ role: 'readWrite', db: 'tododb' }]
});
print('Users created successfully');
"

# Shut down the temporary instance
sudo -u mongodb mongod --dbpath /var/lib/mongodb --shutdown

# Restart with auth enabled
systemctl start mongod

echo "=== MongoDB setup complete ==="

# -----------------------------------------------------------------------
# Daily backup script
# -----------------------------------------------------------------------
cat > /usr/local/bin/mongodb-backup.sh << 'BACKUP_SCRIPT'
#!/bin/bash
set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/tmp/mongodb-backup-$$"
S3_BUCKET="${s3_bucket_name}"
LOG_FILE="/var/log/mongodb-backup.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "Starting MongoDB backup..."

mkdir -p "$BACKUP_DIR"

mongodump \
  --uri="mongodb://admin:${mongodb_admin_password}@localhost:27017/?authSource=admin" \
  --out="$BACKUP_DIR"

ARCHIVE="/tmp/mongodb-backup-$TIMESTAMP.tar.gz"
tar -czf "$ARCHIVE" -C "$BACKUP_DIR" .
rm -rf "$BACKUP_DIR"

aws s3 cp "$ARCHIVE" "s3://$S3_BUCKET/backups/$TIMESTAMP/mongodb-backup.tar.gz"
rm -f "$ARCHIVE"

log "Backup uploaded to s3://$S3_BUCKET/backups/$TIMESTAMP/mongodb-backup.tar.gz"

# Keep only last 30 days of backups
CUTOFF=$(date -d '30 days ago' '+%Y%m%d' 2>/dev/null || date -v-30d '+%Y%m%d')
aws s3 ls "s3://$S3_BUCKET/backups/" | awk '{print $2}' | while read -r prefix; do
  folder=$(echo "$prefix" | cut -d'_' -f1 | tr -d '/')
  if [[ "$folder" < "$CUTOFF" ]]; then
    aws s3 rm "s3://$S3_BUCKET/backups/$prefix" --recursive
    log "Removed old backup: $prefix"
  fi
done

log "Backup complete."
BACKUP_SCRIPT

chmod +x /usr/local/bin/mongodb-backup.sh

# Cron job: daily at 02:00 UTC
echo "0 2 * * * root /usr/local/bin/mongodb-backup.sh" > /etc/cron.d/mongodb-backup
chmod 644 /etc/cron.d/mongodb-backup

# Run first backup immediately to validate the setup
/usr/local/bin/mongodb-backup.sh || echo "Initial backup failed — check /var/log/mongodb-backup.log"

echo "=== User data script complete ==="
