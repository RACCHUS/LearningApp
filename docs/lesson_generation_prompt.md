# Lesson Generation AI Prompt

Reference guide for generating educational content with any AI tool (ChatGPT, Claude, Gemini, etc.). There are two modes:

1. **Quick Generate** — single prompt, get a full lesson in one shot (simpler, less consistent)
2. **Phased Pipeline** — 5-step guided process in the app (higher quality, maintains terminology)

Both are free — just copy/paste prompts into any AI chat.

---

## Mode 1: Quick Generate (Single Prompt)

Copy this into any AI, fill in the `[PARAMETERS]`, get back importable JSON.

```
You are an expert educational content creator. Create a complete lesson in JSON format.

PARAMETERS:
Subject: [ENTER_SUBJECT_HERE]
Target Audience: [beginner/intermediate/advanced/professional]
Duration: [15-120] minutes
Difficulty: [beginner/intermediate/advanced]
Content Focus: [theoretical/practical/balanced]

Return ONLY valid JSON matching this exact schema:

{
  "title": "Lesson title",
  "description": "2-3 sentence description",
  "tags": ["tag1", "tag2"],
  "terms": [
    {
      "id": "unique_id",
      "term": "Term name",
      "definition": "Clear definition",
      "example": "Practical example"
    }
  ],
  "concepts": [
    {
      "id": "unique_id",
      "concept_text": "Concept title",
      "example_text": "Detailed explanation with examples"
    }
  ],
  "questions": [
    {
      "id": "unique_id",
      "question": "Question text",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correct_answer": 0,
      "explanation": "Why this answer is correct"
    }
  ]
}

REQUIREMENTS:
- Content mix: ~30% terms, ~40% concepts, ~30% questions
- Logical flow from basic definitions to complex applications
- MCQs test understanding, not memorization
- correct_answer is a 0-based index into the options array
- All IDs should be unique strings
```

### Import: Copy the JSON → open the app → JSON Import → paste → import.

---

## Mode 2: Phased Pipeline (In-App Guided Generation)

This is the recommended approach for high-quality lessons. The app walks you through 5 phases, generating one prompt at a time. Each phase feeds its output into the next prompt so terminology stays locked.

### How it works:

1. Open **Guided Lesson Generation** in the app
2. Fill in subject, audience, duration, difficulty, focus
3. Click **Start Generation**
4. For each phase:
   - Click **Copy Prompt to Clipboard**
   - Paste into your AI tool
   - Copy the AI's JSON response
   - Paste back into the app → click **Submit Response**
5. Repeat until all phases are done
6. Click **Import Lesson**

### The 5 Phases:

| Phase | What it generates | Token cost |
|-------|------------------|------------|
| 1. Plan | Lesson blueprint + terminology glossary + content manifest | ~1K in, ~1K out |
| 2a. Terms | Term definitions (batched, max 8 per prompt) | ~1.5K in, ~1K out |
| 2b. Concepts | Concept explanations referencing terms (batched, max 4) | ~1.5K in, ~1.5K out |
| 2c. MCQs | Questions testing concepts (batched, max 5) | ~2K in, ~1.5K out |
| 3. Review | AI self-reviews all content for consistency (optional) | ~3K in, ~1K out |

### Key features:
- **Terminology glossary** from Phase 1 is injected into every later prompt
- **Batching** prevents quality degradation on large lessons
- **Context compression** keeps prompts within free-tier token limits (~2K token budget)
- **Auto-save** — session survives page refresh, navigation, browser restart
- **Resume prompt** — switch to a different AI mid-session via "Copy Resume Prompt"
- **Export/Import session** — backup or share session state as JSON

### Switching AI tools mid-session:

If you run out of free messages on one AI, or want to try a different one:
1. Click **Copy Resume Prompt** in the Session Tools section
2. Open a new AI chat (different tool, different day, whatever)
3. Paste the resume prompt — it contains compressed context of everything so far
4. Copy the AI's response back into the app

---

## Course Generation

Courses are ordered lists of lessons. Generate the structure first, then generate each lesson individually using the phased pipeline above.

```
You are a curriculum designer. Design a course structure for:

Topic: [ENTER_TOPIC]
Audience: [beginner/intermediate/advanced]
Difficulty Progression: [e.g. "beginner to intermediate"]
Total Hours: [ENTER_HOURS]

Return ONLY valid JSON:
{
  "course": {
    "title": "...",
    "description": "...",
    "category": "...",
    "difficulty": "beginner-to-intermediate",
    "estimated_hours": 20,
    "tags": []
  },
  "lessons": [
    {
      "order": 1,
      "title": "Lesson title",
      "description": "What this lesson covers",
      "difficulty": "beginner",
      "estimated_minutes": 30,
      "prerequisites": [],
      "learning_objectives": [],
      "suggested_content": { "terms": 6, "concepts": 4, "mcqs": 5 }
    }
  ],
  "progression_notes": "How difficulty builds across the course"
}

Create 4-12 lessons, each 15-60 minutes. Clear prerequisite chain, gradual difficulty.
```

**After generating:** For each lesson in the output, use its title + description + objectives as the `subject` input to the phased pipeline.

---

## Career Path Generation

Career paths are ordered lists of courses. Generate the roadmap first, then each course, then each lesson.

```
You are a career development strategist. Design a learning path for:

Career Goal: [ENTER_GOAL]
Current Level: [beginner/some experience/intermediate]
Time Commitment: [e.g. "10 hours/week for 6 months"]

Return ONLY valid JSON:
{
  "career_path": {
    "title": "...",
    "description": "...",
    "estimated_months": 6,
    "target_role": "Job title"
  },
  "skills": [
    { "name": "...", "importance": "core|intermediate|supplementary", "description": "..." }
  ],
  "courses": [
    {
      "order": 1,
      "title": "...",
      "description": "...",
      "is_required": true,
      "estimated_hours": 20,
      "skills_covered": ["Skill name"],
      "suggested_lesson_count": 8,
      "prerequisites": []
    }
  ],
  "milestones": [
    { "after_course": 2, "achievement": "What you can do", "skills_unlocked": [] }
  ]
}
```

**The generation chain:**
```
Career Path prompt → Course prompt (for each course) → Phased Lesson pipeline (for each lesson)
    (skeleton)           (skeleton)                        (full content — already built)
```

---

## Content Improvement Prompt

Use this to review and improve an existing lesson:

```
You are an educational content quality expert. Analyze this lesson and provide specific improvements:

[PASTE LESSON JSON HERE]

Provide feedback on:
1. Content quality (clarity, examples, completeness)
2. Structure & flow (logical progression, balance)
3. Assessment quality (MCQ effectiveness, distractors)
4. Specific actionable recommendations
5. Engagement factors
```

---

## JSON Field Reference

### Lesson (top-level)
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| title | string | yes | 5-100 chars |
| description | string | yes | 50-500 chars |
| tags | string[] | no | For categorization |
| terms | array | yes | Term objects |
| concepts | array | yes | Concept objects |
| questions | array | yes | Question objects |

### Term
| Field | Type | Required |
|-------|------|----------|
| id | string | no (auto-generated) |
| term | string | yes |
| definition | string | yes |
| example | string | no |

### Concept
| Field | Type | Required |
|-------|------|----------|
| id | string | no (auto-generated) |
| concept_text | string | yes |
| example_text | string | no |

### Question (MCQ)
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| id | string | no (auto-generated) |
| question | string | yes | Also accepts `question_text` |
| options | string[] | yes | Exactly 4 options |
| correct_answer | int | yes | 0-based index into options |
| explanation | string | no | Why the answer is correct |

