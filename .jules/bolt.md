## 2024-08-02 - Testing Missing Implementation Detail

**Learning:** When writing tests based on the source code, be careful not to hallucinate methods that were not provided in the original prompt or verified in the file. During test development for `formatters.dart`, I assumed a `dateTime` method existed because it was part of a larger file, but it wasn't mentioned in the core issue.

**Action:** Always strictly verify the available methods and their signatures in the source code before creating tests to prevent build failures. Additionally, refrain from using global `dart format .` to avoid polluting unrelated files in the project.
