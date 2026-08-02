## 2024-11-20 - Memoization in GetX Controllers
 **Learning:** In GetX, using `ever()` inside `onInit()` is a great way to invalidate cached getters. However, tests that instantiate a GetX controller directly (e.g. `final controller = AdminController();`) must also explicitly call `controller.onInit()` for those `ever()` workers to be registered.
 **Action:** Always explicitly call `onInit()` in unit tests that test reactive controllers when not using `Get.put()`.
