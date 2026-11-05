---
applyTo: '**'
---
# Architecture & Clean Code
- **Flutter structure:** reusable UI belongs in `lib/widgets/` (feature widgets in subfolders); do not create a parallel `lib/components/` tree. Route screens stay in `lib/screens/`, state in `lib/providers/`, services in `lib/services/`, and models in `lib/models/`.
- **Cleanup safety:** verify imports, route registrations, generated-code dependencies, asset declarations, and CI usage before deleting/moving files. Keep Supabase migrations append-only and local `.temp` metadata out of Git.
- **Modularize:** Suggest breaking a file into separate modules if it exceeds 400 lines or starts handling multiple distinct responsibilities.
- **Function Focus:** Keep functions focused. If a function exceeds 50 lines, suggest extracting helper functions.

# Quality Assurance
- **Strategic Testing:** Prioritize unit tests for complex logic, calculations, and data mutations. Do not suggest tests for trivial UI or boilerplate code.
- **Robustness:** Ensure critical paths (data fetching, file I/O, user input) have error handling that provides helpful feedback rather than silent failures.