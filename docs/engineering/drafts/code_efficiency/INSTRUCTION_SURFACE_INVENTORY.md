# Instruction surface inventory and map-freshness proposal (DRAFT)

Pinned to `06221ed`. Sizes are Git blob bytes. Which files a given agent auto-loads was **not** measured.

## 1. Inventory

| File | Bytes | Lines | Scope / audience | Overlap and notes |
|---|---:|---:|---|---|
| `AGENTS.md` | 7,263 | 90 | All agents (portable) | Owns migration, deploy, FLAG/BYOK/Fast and legacy rules. Its MCP section names `~/.gemini/config/mcp_config.json` tools that other agents may not have |
| `.github/instructions/Main.instructions.md` | 1,138 | 12 | Copilot, `applyTo: '**'` | Repeats AGENTS.md layout rule (lib/widgets etc.). **400/50-line triggers conflict with the plan** — fix drafted |
| `.agents/rules/mcp-tooling.md` | 1,409 | 20 | Antigravity/Gemini agents | Overlaps AGENTS.md MCP section |
| `.github/agents/lesson-generator.agent.md` | 4,653 | 106 | Copilot lesson-generation agent | Domain-specific; no conflict found |
| `.github/prompts/generate-lesson.prompt.md` | 384 | 11 | Copilot prompt | Points to the agent above |
| `.github/pull_request_template.md` | 1,987 | 29 | Human + agent PR authors | Feature-preservation and Test Quality checklists |
| **Total** | **16,834** | 268 | | |

Precedence today is implicit. Proposed one-line statement (for the owner to place, not applied): *`AGENTS.md` is authoritative for repository rules; tool-specific files may add, never relax, its rules.*

## 2. Proposed changes (drafts in this folder; none applied)

| Draft | Touched lines | Net lines | Byte change |
|---|---:|---:|---:|
| `AGENTS_md_retrieval_guidance.diff` | 7 | +7 | 7,263 → 7,945 (+682) |
| `Main_instructions_cohesion_rule.diff` | 4 (2 removed, 2 added) | 0 | 1,138 → 1,375 (+237) |
| `CODEBASE_MAP.md` (read by section, not always loaded) | new | 188 | 14,416 |

Caps from the plan: `AGENTS.md` ≤ 40 touched / ≤ +20 net — **met** (7 / +7). Map ≤ 250 lines / 20 KB — **met** (188 / 14.4 KB). Always-on surface grows by 919 bytes (+5.5%) if both diffs are applied.

The `AGENTS.md` diff only points to the map and states default exclusions with exceptions; it does not restate migration, FLAG, BYOK or Fast rules, which stay verbatim.

## 3. Map freshness (proposal for the PR template, not applied)

Add one checkbox under the existing feature-preservation list:

```
- [ ] If this PR moves, renames or changes the owner/contract/tests of a feature in docs/engineering/CODEBASE_MAP.md, the map section is updated (or N/A).
```

Plus a periodic human check (suggested: with the weekly `test-quality-audit.yml` review) that each section's owner is still the owner — the validator cannot see that.
