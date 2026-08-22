#!/usr/bin/env bash
#
# Checks the three things that reading the code cannot tell you:
#
#   1. schema.sql takes an empty database to a working one, and re-running it
#      is a no-op.
#   2. schema.sql and migrations/0001..0006 produce the *same* database --
#      every column, constraint, index, policy, trigger, grant, and function
#      body. schema.sql is the final state, not a replay, so nothing but a
#      diff proves the two stay in step.
#   3. Every RPC the Flutter client calls exists, with exactly the parameter
#      names the client sends. This boundary is a bare string on the Dart side
#      (`rpcPlaceOrder = 'place_order'`), so no compiler or AST tool sees it;
#      a renamed parameter fails at runtime, in checkout, in production.
#   4. The behavioural suite (10_tests.sql) still passes against the database
#      schema.sql just built.
#
# Usage:
#   supabase/tests/20_contract.sh              # uses your ambient PG* env
#   PSQL='psql -U postgres' supabase/tests/20_contract.sh
#
# Creates and drops two scratch databases. Exits non-zero on any mismatch.

set -euo pipefail

PSQL="${PSQL:-psql}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SQL="$ROOT/supabase"
WORK="$(mktemp -d)"
DB_SCHEMA="${DB_SCHEMA:-contract_schema}"
DB_MIGR="${DB_MIGR:-contract_migr}"
trap 'rm -rf "$WORK"' EXIT

fail=0
say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32mPASS\033[0m  %s\n' "$*"; }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$*"; fail=1; }

q() { $PSQL -v ON_ERROR_STOP=1 -q "$@"; }

# --------------------------------------------------------------------------
say "1. schema.sql provisions an empty database, idempotently"
# --------------------------------------------------------------------------
q -d postgres -c "drop database if exists $DB_SCHEMA" -c "create database $DB_SCHEMA" >/dev/null
if q -d "$DB_SCHEMA" -f "$SQL/tests/00_shim.sql" -f "$SQL/schema.sql" >"$WORK/apply.log" 2>&1; then
  ok "applies from empty"
else
  bad "applies from empty"; tail -20 "$WORK/apply.log"
fi
if q -d "$DB_SCHEMA" -f "$SQL/schema.sql" >"$WORK/reapply.log" 2>&1; then
  ok "re-applying is a no-op"
else
  bad "re-applying is a no-op"; tail -20 "$WORK/reapply.log"
fi

# --------------------------------------------------------------------------
say "2. schema.sql == migrations/$(ls "$SQL"/migrations/*.sql | head -1 | xargs basename | cut -d_ -f1)..$(ls "$SQL"/migrations/*.sql | tail -1 | xargs basename | cut -d_ -f1)"
# --------------------------------------------------------------------------
q -d postgres -c "drop database if exists $DB_MIGR" -c "create database $DB_MIGR" >/dev/null
mig_args=(-f "$SQL/tests/00_shim.sql")
for m in "$SQL"/migrations/*.sql; do mig_args+=(-f "$m"); done
if q -d "$DB_MIGR" "${mig_args[@]}" >"$WORK/migr.log" 2>&1; then
  ok "migrations apply in order"
else
  bad "migrations apply in order"; tail -20 "$WORK/migr.log"
fi

# Every object as one flattened line. Function bodies are compared by md5 of
# prosrc, so a changed body is caught even when the signature is untouched.
cat > "$WORK/objects.sql" <<'EOF'
\pset tuples_only on
\pset format unaligned
select 'COL|'||c.table_name||'|'||c.column_name||'|'||c.data_type||'|'
       ||regexp_replace(coalesce(c.column_default,'-'),'\s+',' ','g')||'|'||c.is_nullable
  from information_schema.columns c where c.table_schema='public';
select 'CON|'||conrelid::regclass::text||'|'||conname||'|'
       ||regexp_replace(pg_get_constraintdef(oid),'\s+',' ','g')
  from pg_constraint where connamespace='public'::regnamespace;
select 'IDX|'||indexname||'|'||regexp_replace(indexdef,'\s+',' ','g')
  from pg_indexes where schemaname='public';
select 'FUN|'||p.proname||'|'||regexp_replace(pg_get_function_identity_arguments(p.oid),'\s+',' ','g')
       ||'|'||p.prosecdef::text||'|'||md5(p.prosrc)
  from pg_proc p where p.pronamespace='public'::regnamespace;
select 'POL|'||tablename||'|'||policyname||'|'||cmd||'|'||coalesce(roles::text,'-')||'|'
       ||regexp_replace(coalesce(qual,'-'),'\s+',' ','g')||'|'
       ||regexp_replace(coalesce(with_check,'-'),'\s+',' ','g')
  from pg_policies where schemaname='public';
select 'TRG|'||c.relname||'|'||t.tgname||'|'||regexp_replace(pg_get_triggerdef(t.oid),'\s+',' ','g')
  from pg_trigger t join pg_class c on c.oid=t.tgrelid
 where c.relnamespace='public'::regnamespace and not t.tgisinternal;
select 'ENU|'||t.typname||'|'||string_agg(e.enumlabel, ',' order by e.enumsortorder)
  from pg_type t join pg_enum e on e.enumtypid=t.oid
 where t.typnamespace='public'::regnamespace group by t.typname;
select 'GRT|'||routine_name||'|'||grantee||'|'||privilege_type
  from information_schema.routine_privileges where routine_schema='public';
select 'TBL|'||table_name||'|'||table_type
  from information_schema.tables where table_schema='public';
select 'SEQ|'||sequence_name||'|'||data_type
  from information_schema.sequences where sequence_schema='public';
select 'VIW|'||table_name||'|'||md5(view_definition)
  from information_schema.views where table_schema='public';
select 'TGRT|'||table_name||'|'||grantee||'|'||privilege_type
  from information_schema.role_table_grants where table_schema='public';
EOF

$PSQL -q -d "$DB_SCHEMA" -f "$WORK/objects.sql" | grep -v '^$' | sort > "$WORK/from_schema.txt"
$PSQL -q -d "$DB_MIGR"   -f "$WORK/objects.sql" | grep -v '^$' | sort > "$WORK/from_migr.txt"

n_schema=$(wc -l < "$WORK/from_schema.txt")
n_migr=$(wc -l < "$WORK/from_migr.txt")
if [ "$n_schema" -eq 0 ]; then
  bad "object dump came back empty -- nothing was compared"
elif diff -u "$WORK/from_schema.txt" "$WORK/from_migr.txt" > "$WORK/objects.diff"; then
  ok "$n_schema objects, zero differences"
else
  bad "$n_schema vs $n_migr objects differ"; head -40 "$WORK/objects.diff"
fi

# --------------------------------------------------------------------------
say "3. Dart RPC calls match pg_proc"
# --------------------------------------------------------------------------
python3 - "$ROOT" > "$WORK/from_dart.txt" <<'PY'
import re, sys, pathlib
root = pathlib.Path(sys.argv[1])

# Map the Dart constant to the SQL function name it holds.
consts = dict(re.findall(r"static const String (rpc\w+)\s*=\s*'([a-z_]+)'",
                         (root / 'lib/core/utils/app_constants.dart').read_text()))
if not consts:
    sys.exit("no rpc constants found in app_constants.dart")

seen = {}
for f in (root / 'lib').rglob('*.dart'):
    src = f.read_text()
    for m in re.finditer(r'\.rpc\(', src):
        i = src.index('(', m.start()); depth = 0; j = i
        while j < len(src):                      # walk to the matching paren
            if src[j] == '(': depth += 1
            elif src[j] == ')':
                depth -= 1
                if depth == 0: break
            j += 1
        body = src[i:j]
        const = next((c for c in consts if c in body), None)
        if const is None:
            sys.exit(f"{f}: .rpc() call does not use an AppConstants.rpc* name")
        seen.setdefault(consts[const], set()).update(re.findall(r"'(p_[a-z_]+)'", body))

for name in sorted(seen):
    args = ','.join(sorted(seen[name]))
    print(f"{name}|{args or '(none)'}")
PY

names=$(cut -d'|' -f1 "$WORK/from_dart.txt" | paste -sd, - | sed "s/[^,]*/'&'/g")
cat > "$WORK/procs.sql" <<EOF
\\pset tuples_only on
\\pset format unaligned
select p.proname||'|'||
  coalesce(nullif((select string_agg(a, ',' order by a)
                   from unnest(coalesce(p.proargnames,'{}')) a), ''), '(none)')
  from pg_proc p
 where p.pronamespace='public'::regnamespace and p.proname in ($names)
 order by 1;
EOF
$PSQL -q -d "$DB_SCHEMA" -f "$WORK/procs.sql" | grep -v '^$' | sort > "$WORK/from_pg.txt"

n_rpc=$(wc -l < "$WORK/from_dart.txt")
if diff -u "$WORK/from_dart.txt" "$WORK/from_pg.txt" > "$WORK/rpc.diff"; then
  ok "$n_rpc RPCs match, parameter for parameter"
else
  bad "client and database disagree (left = Dart, right = pg_proc)"
  cat "$WORK/rpc.diff"
fi

# --------------------------------------------------------------------------
say "4. Behavioural suite against schema.sql"
# --------------------------------------------------------------------------
# seed.sql is required: the assertions name promotion codes and SKUs it creates.
if q -d "$DB_SCHEMA" -f "$SQL/seed.sql" >"$WORK/seed.log" 2>&1; then
  if $PSQL -v ON_ERROR_STOP=1 -d "$DB_SCHEMA" -f "$SQL/tests/10_tests.sql" \
       >"$WORK/behaviour.log" 2>&1; then
    ok "$(grep -c 'pass:' "$WORK/behaviour.log") assertions passed"
  else
    bad "behavioural suite"
    grep -E 'FAIL|ERROR' "$WORK/behaviour.log" | head -10
  fi
else
  bad "seed.sql"; tail -20 "$WORK/seed.log"
fi

# --------------------------------------------------------------------------
q -d postgres -c "drop database if exists $DB_SCHEMA" -c "drop database if exists $DB_MIGR" >/dev/null
if [ "$fail" -eq 0 ]; then
  printf '\n\033[32m=== CONTRACT INTACT ===\033[0m\n'
else
  printf '\n\033[31m=== CONTRACT BROKEN ===\033[0m\n'
fi
exit "$fail"
