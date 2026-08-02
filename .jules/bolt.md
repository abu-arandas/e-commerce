## 2024-05-19 - Dart Environment Variable Parsing
**Learning:** `double.fromEnvironment` is not available in Dart. Using `const int.fromEnvironment(...) * 1.0` limits it to integers. The best way is to use `double.tryParse(const String.fromEnvironment(...))` and make the constant variable `static final` rather than `static const`.
**Action:** When fixing environment variable issues related to double values, use `double.tryParse` with `String.fromEnvironment`.
