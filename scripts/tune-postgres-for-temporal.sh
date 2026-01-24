#!/bin/bash
#
# PostgreSQL tuning script for Temporal workloads
# Run this on the PostgreSQL server (192.168.69.11)
#

set -e

echo "=== PostgreSQL Tuning for Temporal ==="
echo ""

# Detect PostgreSQL version and config directory
PG_VERSION=$(psql -U postgres -t -c "SHOW server_version;" | grep -oP '^\d+')
PG_CONFIG="/etc/postgresql/${PG_VERSION}/main/postgresql.conf"

if [ ! -f "$PG_CONFIG" ]; then
    echo "Error: PostgreSQL config not found at $PG_CONFIG"
    echo "Please update PG_CONFIG variable in this script"
    exit 1
fi

echo "Found PostgreSQL $PG_VERSION config at: $PG_CONFIG"
echo ""

# Backup original config
sudo cp "$PG_CONFIG" "${PG_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
echo "✓ Created backup of postgresql.conf"

# Get system memory
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_MB=$((TOTAL_RAM_KB / 1024))
echo "System RAM: ${TOTAL_RAM_MB}MB"
echo ""

# Calculate optimal settings (assuming 25% of RAM for PostgreSQL)
SHARED_BUFFERS_MB=$((TOTAL_RAM_MB / 4))
EFFECTIVE_CACHE_SIZE_MB=$((TOTAL_RAM_MB * 3 / 4))
MAINTENANCE_WORK_MEM_MB=$((TOTAL_RAM_MB / 16))

cat << EOF | sudo tee /tmp/pg_temporal_tuning.conf
# Temporal-specific PostgreSQL tuning
# Generated on $(date)

# Connection Settings
max_connections = 250
superuser_reserved_connections = 5

# Memory Settings
shared_buffers = ${SHARED_BUFFERS_MB}MB
effective_cache_size = ${EFFECTIVE_CACHE_SIZE_MB}MB
maintenance_work_mem = ${MAINTENANCE_WORK_MEM_MB}MB
work_mem = 16MB

# WAL Settings (Write-Ahead Log)
wal_buffers = 16MB
checkpoint_completion_target = 0.9
max_wal_size = 2GB
min_wal_size = 1GB

# Query Planner Settings
random_page_cost = 1.1
effective_io_concurrency = 200

# Monitoring & Logging
log_connections = on
log_disconnections = on
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_lock_waits = on
log_temp_files = 0
log_autovacuum_min_duration = 0

# Autovacuum Settings (critical for Temporal's high write volume)
autovacuum = on
autovacuum_max_workers = 4
autovacuum_naptime = 10s
autovacuum_vacuum_scale_factor = 0.05
autovacuum_analyze_scale_factor = 0.02

# Statement Timeout (prevent runaway queries)
statement_timeout = 60000  # 60 seconds
idle_in_transaction_session_timeout = 300000  # 5 minutes

# Connection Lifetime
tcp_keepalives_idle = 60
tcp_keepalives_interval = 10
tcp_keepalives_count = 3
EOF

echo "✓ Created tuning configuration file"
echo ""
echo "Recommended settings:"
cat /tmp/pg_temporal_tuning.conf
echo ""
echo "================================================"
echo "To apply these settings:"
echo "1. Review the settings above"
echo "2. Append to postgresql.conf:"
echo "   sudo cat /tmp/pg_temporal_tuning.conf >> $PG_CONFIG"
echo "3. Restart PostgreSQL:"
echo "   sudo systemctl restart postgresql"
echo "4. Verify settings:"
echo "   sudo -u postgres psql -c 'SHOW max_connections;'"
echo "================================================"
