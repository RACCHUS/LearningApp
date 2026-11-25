# Outside-resource catalog

Reviewed, public, link-only records of resources that stay outside LearningApp: courses, videos, books (companion plan v1.0, `LEARNINGAPP_EXTERNAL_RESOURCE_COMPANION_PLAN_V1_0_2026-11-25.md`, §3.3 to §3.5 and §7.2). Maps from a resource to a target's objectives are in `data/resource_maps/`.

Check: `python tool/verify_external_resources.py` (CI).

This is not the reuse policy (`data/content_sources.json`) and not source research (`data/research/sources/`). A record here never allows copying, importing or AI transformation. A learner's own resources are private account data and never appear here.

## Resource record: `<id>.yaml`

| Field | Rule |
|---|---|
| `id` | Lowercase with hyphens; equals the file name |
| `kind` | `video`, `video_series`, `course`, `book`, `article`, `podcast`, `class`, `other` |
| `publisher`, `title`, `locale` | Required |
| `canonical_url` | https, or null for a resource with no link (a printed book) |
| `access` | `free_no_login`, `free_with_login`, `paid` |
| `price` | Null unless paid. Paid: `band` (`under_25`, `25_to_100`, `100_to_500`, `over_500`, `subscription`), `currency`, `checked_at`. A band and a date, never a live price |
| `rights_posture` | `link_only` |
| `embed` | `allowed: false`, or `allowed: true` with `provider` and the https `terms_url` that allows it |
| `has_practice`, `captions`, `transcript` | true, false, or null when unknown |
| `stated_length_hours` | Positive number, or null |
| `targets` | Slugs of manifests in `content/` |
| `metadata_checked_at` | Date the facts were last checked |
| `facts` | One or more `claim` with an https `source_url` |
| `authored_by`, `review` | As in `data/concept_mappings/`: `status` is `pending`, `approved` or `changes_required`; an approved review names `reviewer_kind` (`ai` or `human`), `reviewer_model` for AI, and `reviewed_on` |

## Rules the checker enforces

- **Unknown is null, never guessed.** List what is unknown under `unknown`.
- **Ranking isolation (plan §3.5).** No field may carry a paid placement, affiliate, sponsorship or ranking value. The checker rejects such keys anywhere in a file. The ranking is computed from coverage, accuracy, practice, cost, time, accessibility and freshness, and nothing else.
- **No personal fields.**
- A resource is shown as a recommendation only when its review is approved and it has an approved map (enforced in the app, EX-5).
