#!/bin/sh
set -e

cd /var/www/html

# --- Permissions ---
chown -R www-data:www-data storage bootstrap/cache
chmod -R ug+rwx storage bootstrap/cache

# --- .env: ensure it exists (Railway injects real vars via environment, not .env) ---
if [ ! -f ".env" ]; then
    cp .env.example .env 2>/dev/null || touch .env
fi

# --- App key ---
# --- SQLite: create the database file if using sqlite ---
DB=${DB_CONNECTION:-sqlite}
if [ "$DB" = "sqlite" ]; then
    DB_FILE=${DB_DATABASE:-/var/www/html/database/database.sqlite}
    if [ ! -f "$DB_FILE" ]; then
        echo "[entrypoint] Creating SQLite database: $DB_FILE"
        mkdir -p "$(dirname $DB_FILE)"
        touch "$DB_FILE"
        chown www-data:www-data "$DB_FILE"
    fi
fi

# --- Production caches ---
php artisan config:cache || true
php artisan route:cache || true
php artisan view:cache || true

echo "[entrypoint] Starting Apache..."
exec "$@"
