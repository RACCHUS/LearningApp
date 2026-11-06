# Data and source manifests

This directory contains reviewed source data and fixtures. It is **not** the canonical curriculum directory and files here are not automatically published to Supabase.

## Layout

- `catalog/` — source-backed catalog inputs and staged issuer/pathway manifests (for example Florida licensing and issuer-verified pilot data). Follow each manifest's review/provenance requirements.
- `taxonomy/` — taxonomy source registry and source-access/rights review metadata.
- `samples/` — lesson fixtures used by import/integration tests.
- `content/` (repository root) — versioned curriculum manifests validated and ingested by the curriculum pipeline.
- `assets/lessons/` (repository root) — bundled lesson content used by the app's lesson provider.

## Validation and ingestion

- Validate catalog manifests with the matching `tool/catalog_*.py validate` command.
- Validate curriculum manifests with `dart run tool/lint_manifest.dart --dir content/`.
- Use the documented guarded or service-role ingestion workflow only when explicitly authorized.

Do not treat staged candidates as official, reviewed, or published merely because they exist in this repository. Source provenance, rights, review status, and effective dates remain required.
