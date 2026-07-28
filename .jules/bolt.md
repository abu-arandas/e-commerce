## 2024-07-28 - Avoid chained map/where/toList in Dart
**Learning:** Dart's `.where(...).toList()` and `.map(...).toList()` chained together on Iterables cause unnecessary intermediate List allocations. In hot paths (like sorting or filtering visible products on every keystroke), this creates garbage collection overhead.
**Action:** When filtering or calculating aggregates (min/max) over lists that run frequently, prefer a single-pass filter inside `.where(...)` or a standard `for` loop over chained higher-order functions.
