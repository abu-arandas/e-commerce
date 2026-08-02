## 2024-08-02 - Caching String Regex Execution

**Learning:** When string parsing via regex is repetitively executed inside widget rebuilding paths (like resolving grid spans in `FB5Col`), introducing a simple string-keyed cache avoids redundant match/parse overhead, especially as class names per widget remain mostly static.

**Action:** Use Map-based caches when executing repeated static-heavy computations within layout build loops.
