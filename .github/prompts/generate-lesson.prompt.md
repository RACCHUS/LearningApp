---
description: "Quick shortcut to generate a lesson on any topic"
mode: agent
agent: lesson-generator
---

Generate a complete lesson on the topic: ${input:subject}

Difficulty: ${input:difficulty|beginner,intermediate,advanced}

Use existing lessons in assets/lessons/ as reference for quality and format. After generating, verify the JSON is valid and summarize what was created.
