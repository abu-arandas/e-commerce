## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
- `graphify update .` is the canonical rebuild and the only one whose output
  is committed. The post-commit hook rebuilds incrementally from the commit's
  changed files, which can land a node or two off; re-running `graphify update .`
  normalises it. If a commit leaves graphify-out/ dirty, that is why — rebuild
  and amend rather than committing the hook's intermediate result.
- graphify-out/ dated directories are relabel snapshots, not history. They are
  gitignored; do not add them.

## Verifying the database contract

`supabase/tests/20_contract.sh` is the one command that checks what reading the
code cannot: that `schema.sql` provisions an empty database idempotently, that
it and `migrations/0001..0006` produce the identical database (function bodies
compared by hash, not just signatures), that every RPC the Flutter client calls
exists with exactly the parameter names the client sends, and that the
behavioural suite still passes. It needs a reachable PostgreSQL and exits
non-zero on any mismatch.

The client/database boundary is a bare string on the Dart side
(`rpcPlaceOrder = 'place_order'`), so nothing links the two statically — no
compiler, and no AST tool including this graph. Run the script after touching
either side.
