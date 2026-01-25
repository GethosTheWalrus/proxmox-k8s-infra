#!/bin/bash
#
# PostgreSQL health monitoring for Temporal
# Run this to check database performance and connection status
#

set -e

PGHOST="${PGHOST:-192.168.69.11}"
PGUSER="${PGUSER:-postgres}"
PGPASSWORD="${PGPASSWORD:-postgres}"
PGDATABASE="${PGDATABASE:-postgres}"

export PGPASSWORD

echo "=== PostgreSQL Health Check for Temporal ==="
echo "Host: $PGHOST"
echo "Time: $(date)"
echo ""

# Check if database is reachable
if ! psql -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE" -c "SELECT 1;" > /dev/null 2>&1; then
    echo "❌ ERROR: Cannot connect to PostgreSQL at $PGHOST"
    exit 1
fi

echo "✓ Database connection successful"
echo ""

# Connection statistics
echo "=== Connection Statistics ==="
psql -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE" -c "
SELECT 
    max_conn,
    used,
    res_for_super,
    max_conn - used - res_for_super as available,
    round(((used::numeric / max_conn::numeric) * 100), 2) as pct_used
FROM 
    (SELECT count(*) used FROM pg_stat_activity) t1,
    (SELECT setting::int res_for_super FROM pg_settings WHERE name = 'superuser_reserved_connections') t2,
    (SELECT setting::int max_conn FROM pg_settings WHERE name = 'max_connections') t3;
"

echo ""
echo "=== Connection States ==="
psql -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE" -c "
SELECT 
    state,
    count(*) as connections,
    round(avg(EXTRACT(EPOCH FROM (now() - state_change)))::numeric, 2) as avg_duration_sec
FROM pg_stat_activity 
WHERE state IS NOT NULL
GROUP BY state 
ORDER BY connections DESC;
"

echo ""
echo "=== Active Queries (>5 seconds) ==="
psql -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE" -c "
SELECT 
    pid,
    usename,
    datname,
    state,
    round(EXTRACT(EPOCH FROM (now() - query_start))::numeric, 2) as duration_sec,
    left(query, 80) as query_preview
FROM pg_stat_activity 
WHERE state = 'active' 
  AND query_start < now() - interval '5 seconds'
  AND query NOT LIKE '%pg_stat_activity%'
ORDER BY query_start
LIMIT 10;
"

echo ""
echo "=== Database Size ==="
psql -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE" -c "
SELECT 
    datname,
    pg_size_pretty(pg_database_size(datname)) as size
FROM pg_database 
WHERE datname IN ('temporal', 'temporal_visibility')
ORDER BY pg_database_size(datname) DESC;
"

echo ""
echo "=== Locks ==="
psql -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE" -c "
SELECT 
    mode,
    count(*) as lock_count
FROM pg_locks 
GROUP BY mode
ORDER BY lock_count DESC;
"

echo ""
echo "=== Recent Deadlocks ==="
psql -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE" -c "
SELECT 
    datname,
    deadlocks
FROM pg_stat_database 
WHERE datname IN ('temporal', 'temporal_visibility');
"

echo ""
echo "=== Table Bloat (Top 5) ==="
psql -h "$PGHOST" -U "$PGUSER" -d "temporal" -c "
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    n_live_tup as live_rows,
    n_dead_tup as dead_rows,
    round((n_dead_tup::numeric / NULLIF(n_live_tup + n_dead_tup, 0)::numeric) * 100, 2) as dead_pct
FROM pg_stat_user_tables
WHERE n_dead_tup + n_live_tup > 0
ORDER BY n_dead_tup DESC
LIMIT 5;
" 2>/dev/null || echo "No temporal database found"

echo ""
echo "=== Recommendations ==="

# Check connection usage
CONN_PCT=$(psql -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE" -t -c "
SELECT round((count(*)::numeric / (SELECT setting::int FROM pg_settings WHERE name = 'max_connections')::numeric) * 100, 0)
FROM pg_stat_activity;
" | xargs)

if [ "$CONN_PCT" -gt 80 ]; then
    echo "⚠️  Connection usage at ${CONN_PCT}% - Consider deploying PgBouncer"
elif [ "$CONN_PCT" -gt 60 ]; then
    echo "⚠️  Connection usage at ${CONN_PCT}% - Monitor closely"
else
    echo "✓ Connection usage at ${CONN_PCT}% - Healthy"
fi

# Check idle connections
IDLE_CONNS=$(psql -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE" -t -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'idle';" | xargs)
if [ "$IDLE_CONNS" -gt 50 ]; then
    echo "⚠️  $IDLE_CONNS idle connections - Deploy PgBouncer to reduce waste"
fi

echo ""
echo "=== Done ==="
