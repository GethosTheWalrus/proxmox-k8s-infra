#!/bin/bash
#
# Check PostgreSQL health from Kubernetes cluster
# This script runs the health check from inside a Temporal pod
#

kubectl exec -n temporal deploy/temporal-admintools -- sh -c '
export PGPASSWORD=postgres
PGHOST=192.168.69.11
PGUSER=postgres

echo "=== PostgreSQL Health Check ==="
echo "Time: $(date)"
echo ""

echo "=== Connection Statistics ==="
psql -h $PGHOST -U $PGUSER -d postgres -c "
SELECT 
    max_conn,
    used,
    res_for_super,
    max_conn - used - res_for_super as available,
    round((used::float / max_conn::float) * 100, 2) as pct_used
FROM 
    (SELECT count(*) used FROM pg_stat_activity) t1,
    (SELECT setting::int res_for_super FROM pg_settings WHERE name = '\''superuser_reserved_connections'\'') t2,
    (SELECT setting::int max_conn FROM pg_settings WHERE name = '\''max_connections'\'') t3;
"

echo ""
echo "=== Connection States ==="
psql -h $PGHOST -U $PGUSER -d postgres -c "
SELECT 
    state,
    count(*) as connections
FROM pg_stat_activity 
WHERE state IS NOT NULL
GROUP BY state 
ORDER BY connections DESC;
"

echo ""
echo "=== Top 10 Longest Running Queries ==="
psql -h $PGHOST -U $PGUSER -d postgres -c "
SELECT 
    pid,
    usename,
    state,
    round(EXTRACT(EPOCH FROM (now() - query_start)), 2) as duration_sec,
    left(query, 100) as query_preview
FROM pg_stat_activity 
WHERE state = '\''active'\''
  AND query NOT LIKE '\''%pg_stat_activity%'\''
ORDER BY query_start
LIMIT 10;
" || echo "No active queries"

echo ""
echo "=== Recommendations ==="
IDLE=$(psql -h $PGHOST -U $PGUSER -d postgres -t -c "SELECT count(*) FROM pg_stat_activity WHERE state = '\''idle'\'';" | xargs)
echo "Idle connections: $IDLE"
if [ "$IDLE" -gt 50 ]; then
    echo "⚠️  HIGH: Deploy PgBouncer to reduce idle connection waste"
elif [ "$IDLE" -gt 20 ]; then
    echo "⚠️  MODERATE: Consider deploying PgBouncer"
else
    echo "✓ Idle connections are acceptable"
fi
'
