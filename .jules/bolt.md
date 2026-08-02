
## 2024-05-18 - Avoid dart format .
**Learning:** Running `dart format .` blindly will format all files and may pollute PRs with unrelated formatting changes.
**Action:** Always format specific files modified in the PR using `dart format <specific_file>`.

## 2024-05-18 - Use GetUtils for validation
**Learning:** GetX has built-in utilities like `GetUtils.isEmail` which are more robust than simple manual checks.
**Action:** Prefer `GetUtils` for common validations in GetX projects instead of writing custom regex.
