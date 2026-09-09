---
applyTo: '**'
---
# Architecture & Clean Code
- **Modularize:** Suggest breaking a file into separate modules if it exceeds 400 lines or starts handling multiple distinct responsibilities.
- **Function Focus:** Keep functions focused. If a function exceeds 50 lines, suggest extracting helper functions.

# Quality Assurance
- **Strategic Testing:** Prioritize unit tests for complex logic, calculations, and data mutations. Do not suggest tests for trivial UI or boilerplate code.
- **Robustness:** Ensure critical paths (data fetching, file I/O, user input) have error handling that provides helpful feedback rather than silent failures.