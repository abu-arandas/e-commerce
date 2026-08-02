## 2023-11-20 - [Performance Optimization]
**Learning:** Flutter's GetX triggers `availableCategories` repeatedly when the UI rebuilds (via `Obx`).
**Action:** Cache the category list and only update it when `products` change.
