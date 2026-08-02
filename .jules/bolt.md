## 2026-02-18 - [Dart 3 double.fromEnvironment]
**Learning:** Dart 3 does not support `double.fromEnvironment`. It throws a compilation error when running tests.
**Action:** To define constant doubles from environment variables, use `int.fromEnvironment('KEY') * 1.0` instead.
