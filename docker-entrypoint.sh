#!/bin/sh
# NOTE: no 'set -e' — we handle errors manually so one failure doesn't kill the container

cd /var/www/html

# --- Apache MPM fix (Railway): ensure ONLY one MPM is loaded ---
rm -f /etc/apache2/mods-enabled/mpm_*.load /etc/apache2/mods-enabled/mpm_*.conf
cat > /etc/apache2/mods-enabled/000-mpm.load <<'EOF'
LoadModule mpm_prefork_module /usr/lib/apache2/modules/mod_mpm_prefork.so
EOF
[ -f /etc/apache2/mods-available/mpm_prefork.conf ] && cp /etc/apache2/mods-available/mpm_prefork.conf /etc/apache2/mods-enabled/000-mpm.conf

# --- Permissions ---
chown -R www-data:www-data storage bootstrap/cache
chmod -R ug+rwx storage bootstrap/cache

# --- .env: ensure it exists (Railway injects real vars via environment, not .env) ---
if [ ! -f ".env" ]; then
    cp .env.example .env 2>/dev/null || touch .env
fi

# --- App key ---
if [ -z "$APP_KEY" ]; then
    echo "[entrypoint] Generating APP_KEY..."
    php artisan key:generate --force || echo "[entrypoint] key:generate warning (non-fatal)"
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
