# 🧠 LearningApp Model Context Protocol (MCP) Server

A high-performance, zero-overhead Model Context Protocol (MCP) server written in pure Dart. Exposes LearningApp's curriculum blueprints, evidence engine, FSRS learner models, item analytics, and pedagogical validation gates to any AI assistant (Claude Desktop, Cursor, Antigravity, VS Code, ChatGPT).

---

## 🚀 Quick Start

Run directly via the Dart CLI (uses standard JSON-RPC 2.0 over `stdio`):

```bash
# Offline mode using local curriculum manifests in content/ and data/
dart run tool/mcp_server/bin/learningapp_mcp.dart

# Or explicitly specifying the Supabase credentials
dart run tool/mcp_server/bin/learningapp_mcp.dart \
  --supabase-url https://your-project.supabase.co \
  --supabase-key your-service-role-or-anon-key

# Verbose protocol logging to stderr
dart run tool/mcp_server/bin/learningapp_mcp.dart -v
```

---

## 🛠️ MCP Tools

| Tool | Parameters | Description |
|---|---|---|
| **`search_catalog`** | `query`, `category`, `limit` | Discovers learning targets, certifications (e.g. CompTIA Security+), academic degrees (e.g. BS Computer Science), and career pathways. |
| **`get_target_outline`** | `target_slug`, `version` | Returns the hierarchical curriculum structure: domains, nodes, knowledge concepts, learning objectives, and weightings. |
| **`get_exam_blueprint`** | `target_version_id` | Retrieves official examination blueprints, domain weight breakdown, passing score threshold, and test constraints. |
| **`get_learner_state`** | `user_id`, `target_version_id`, `exam_date` | Evaluates learner exam readiness using server-calibrated FSRS retrievability, due counts, and weakest concept analysis. |
| **`get_due_items`** | `user_id`, `target_id`, `limit` | Retrieves items currently scheduled for memory review under FSRS spaced repetition. |
| **`explain_item`** | `item_id` | Returns question prompt, options, correct answer, rationale, and official source citations for grounded tutoring. |
| **`compute_item_analytics`** | `item_id` | Computes Classical Test Theory facility $p$-value, point-biserial discrimination $r_{pbis}$, distractor selection rates, and psychometric defect flags. |
| **`submit_review`** | `user_id`, `item_id`, `rating`, `response_option_id`, `latency_ms` | Ingests a review event into the evidence pipeline with audit provenance (`ai_generated` or `user_import`) and client identifier. |
| **`validate_lesson`** | `content` | Evaluates lesson or curriculum manifest against formal JSON Schema and Haladyna (2002) item-writing quality rules. |
| **`propose_item_fix`** | `item_id`, `reason`, `suggested_stem`, `suggested_options`, `suggested_explanation` | Flags an item or submits a suggested correction directly into the moderation queue. |

---

## 📚 MCP Resources

| URI | Name | MIME Type | Description |
|---|---|---|---|
| `learningapp://schema/curriculum_manifest` | Curriculum Manifest Schema | `application/json` | Formal JSON Schema contract for LearningApp curriculum and course manifests. |
| `learningapp://schema/lesson` | Lesson Format Schema | `application/json` | Structure definition for modular lessons, flashcards, terms, and questions. |
| `learningapp://rubrics/item_writing` | Item Writing Rubric | `text/markdown` | Evidence-based Haladyna (2002) psychometric rules for exam questions. |
| `learningapp://catalog/targets` | Catalog Index | `application/json` | Full index of available published learning targets. |
| `learningapp://curriculum/{target_version_id}` | Dynamic Curriculum | `application/json` | Full curriculum manifest and node hierarchy for a specific target. |
| `learningapp://readiness/{user_id}/{target_id}` | Dynamic Learner Readiness | `application/json` | Real-time calibrated readiness evaluation and retention projection. |
| `learningapp://item_analytics/{item_id}` | Dynamic Item Psychometrics | `application/json` | Psychometric facility, discrimination, and distractor efficiency metrics. |

---

## 💡 MCP Prompts

1. **`study_weak_concepts`**:
   - Focuses retrieval practice on the learner's weakest concepts identified by FSRS retention data.
   - Arguments: `target_slug` (required), `concept_limit` (optional).
2. **`socratic_tutor`**:
   - Configures the AI agent as a rigorous Socratic educator guiding the learner step-by-step through a concept without revealing answers.
   - Arguments: `concept_slug` (required), `learner_level` (optional).
3. **`exam_readiness_coaching`**:
   - Synthesizes exam blueprint weights and retention gaps into an actionable weekly study plan.
   - Arguments: `target_slug` (required), `exam_date` (optional).

---

## 🔌 Client Setup Guides

### 1. Claude Desktop
Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "learningapp": {
      "command": "dart",
      "args": [
        "run",
        "tool/mcp_server/bin/learningapp_mcp.dart"
      ]
    }
  }
}
```

### 2. Cursor
Add to `.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "learningapp": {
      "command": "dart",
      "args": [
        "run",
        "tool/mcp_server/bin/learningapp_mcp.dart"
      ]
    }
  }
}
```

### 3. Antigravity / Gemini CLI
Add to `~/.gemini/config/mcp_config.json`:

```json
{
  "mcpServers": {
    "learningapp": {
      "command": "dart",
      "args": [
        "run",
        "tool/mcp_server/bin/learningapp_mcp.dart"
      ]
    }
  }
}
```
