## 2024-05-19 - Dart Type Promotion Convention
 **Learning:** Dart's flow analysis does not promote the type of getters or static fields like `Get.arguments`. If we use an `is` check on a getter, we still have to cast it (`as Order`), which the analyzer complains about as redundant/dead code because technically it was already proven.
 **Action:** Always assign the getter to a local variable first (e.g., `final args = Get.arguments`) before performing type checks, enabling type promotion and avoiding redundant casts.
