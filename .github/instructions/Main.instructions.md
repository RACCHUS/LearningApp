---
applyTo: '**'
---
# Architecture & Clean Code
- **Flutter structure:** reusable UI belongs in `lib/widgets/` (feature widgets in subfolders); do not create a parallel `lib/components/` tree. Route screens stay in `lib/screens/`, state in `lib/providers/`, services in `lib/services/`, and models in `lib/models/`.
- **Cleanup safety:** verify imports, route registrations, generated-code dependencies, asset declarations, and CI usage before deleting/moving files. Keep Supabase migrations append-only and local `.temp` metadata out of Git.
- **Cohesion over line count:** Split only when responsibilities are independently owned and a representative edit needs less total parent/child/contract/test context. Count navigation hops and state/callback coupling; do not split solely because a file or function crosses a numeric line threshold.
- **Preserve behavior:** For a proposed extraction, document contracts and required tests. Avoid unrelated abstractions and keep privacy, grading, feature-gate and persistence boundaries intact.

# Quality Assurance
- **Strategic Testing:** Prioritize unit tests for complex logic, calculations, and data mutations. Do not suggest tests for trivial UI or boilerplate code.
- **Robustness:** Ensure critical paths (data fetching, file I/O, user input) have error handling that provides helpful feedback rather than silent failures.