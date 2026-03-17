#!/bin/sh
# NOTE: no 'set -e' — we handle errors manually so one failure doesn't kill the container

cd /var/www/html

# --- Permissions ---
chown -R www-data:www-data storage bootstrap/cache
chmod -R ug+rwx storage bootstrap/cache

# --- App key ---
if [ -z "$APP_KEY" ]; then
    echo "[entrypoint] Generating APP_KEY..."
    php artisan key:generate --force
fi

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

# --- Package discovery (skipped during docker build) ---
php artisan package:discover --ansi || echo "[entrypoint] package:discover warning (non-fatal)"

# --- Migrations (non-fatal: app can still serve if migrations fail) ---
php artisan migrate --force && echo "[entrypoint] Migrations complete" || echo "[entrypoint] Migration warning (non-fatal — check DB env vars)"

# --- Production caches ---
php artisan config:cache  || true
php artisan route:cache   || true
php artisan view:cache    || true

echo "[entrypoint] Starting Apache..."
exec "$@"
