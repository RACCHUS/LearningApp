# Resource-to-objective maps

`<target_slug>__<resource_id>.yaml` says which objectives of one target an outside resource covers (companion plan v1.0 §3.4, rung 4). Resources are in `data/external_resources/`.

Check: `python tool/verify_external_resources.py` (CI).

A map is written from public facts only: titles, section names, durations and stated outcomes. Nothing is copied from the resource. A map is never evidence that a learner knows anything; only LearningApp's own checks count toward readiness.

## Shape

```yaml
target_slug: clep-college-algebra
resource_id: modern-states-college-algebra
method: How the map was made and from which public pages.
authored_by: ai-drafted-by-claude
review:
  status: pending            # pending | approved | changes_required
coverage:
- objective: '1.1'           # an objective code of the target's manifest
  covered: true
  sections:
  - label: 'Module 2: Exponents'
    locator: null            # https link to the section, or null
    start_seconds: null      # both null, or whole numbers with start < end
    end_seconds: null
    depth: teaches           # introduces | teaches | practises
    has_practice: null       # true | false | null (unknown)
    confidence: medium       # high | medium | low
- objective: '1.2'
  covered: false             # the resource does not cover it
  sections: []
```

Every objective of the target is listed exactly once. `covered: false` is how the app learns what the resource leaves out. "Teaches" with `has_practice: false` is the trigger for a LearningApp supplement.
