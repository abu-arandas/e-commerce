## 2024-11-20 - GetX Getter Optimization
 **Learning:** In GetX projects, expensive nested loops inside getters accessed by Obx widgets cause significant performance bottlenecks due to frequent recalculation.
 **Action:** Introduce a private reactive cache (e.g., `_lowStock = <LowStockEntry>[].obs`) updated via a worker (`ever`) only when the source reactive dependencies change, exposing the cache directly in the getter.
