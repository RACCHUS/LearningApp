#!/usr/bin/env python3
"""Import sections of an approved open textbook as LearningApp lessons.

Turns OpenStax sections into a curriculum manifest (``content/open_*.yaml``)
that goes through the normal checks and owner-run ingestion, so open
content reaches learners as real lessons before anyone generates content
with AI (master plan v2.6 §4.3 step 3; runbook
docs/content_intelligence/CONTENT_INGESTION_RUNBOOK.md).

    python tool/import_open_textbook.py --source openstax-college-algebra-1e --chapters 1
    python tool/import_open_textbook.py --source openstax-prealgebra-1e --chapters 6 7

What each section becomes:
  * reading blocks (markdown with $…$ LaTeX converted from MathML),
    one per subsection; notes become call-outs; worked examples keep
    their solutions;
  * every "Try It" exercise becomes a practice prompt whose answer comes
    from the book's answer key (exercises without an answer are left out);
  * glossary terms the section defines, with the book's definitions;
  * a closing credit block (title, publisher, link, license, changes,
    "not reviewed by a person").
Images are not copied (they can carry separate rights); the text points to
the original section instead. End-of-section exercise sets are skipped.

Safety: the source must be registered in data/content_sources.json with
``adapt`` and ``redistribute`` allowed and status ``approved``, and the
license the publisher's archive reports must match the registry, or nothing
is written. Reading blocks stay close to the book text, so the manifest
declares ``redistribute`` (owner decision D-7, 2026-11-24).
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
import time
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
REGISTRY = REPO / "data" / "content_sources.json"
# Bump when importer output changes for the same book version, so the
# corrected lessons publish as a new target version (published versions are
# immutable). Publish it with retire_previous to replace the old one.
IMPORT_REVISION = 3

# Topic tags per section, so "Learning help" offers the Bridges for that
# topic (content/bridges/*.bridge.json `applies_to_tags`). A section that
# is not listed gets only the book's subject tags.
TOPIC_TAGS: dict[str, dict[str, list[str]]] = {
    "openstax-college-algebra-1e": {
        "1.1": ["real-numbers", "order-of-operations"],
        "1.2": ["exponents", "scientific-notation"],
        "1.3": ["radicals", "exponents"],
        "1.6": ["rational-expressions"],
    },
    "openstax-prealgebra-1e": {
        "6.1": ["percent"], "6.2": ["percent"], "6.3": ["percent"],
        "6.4": ["percent"], "6.5": ["percent"],
    },
}
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_open_content_index import (  # noqa: E402
    ARCHIVE, ARCHIVE_LICENSE, BOOKS, USER_AGENT, plain, split_number,
)

LICENSE_TEXT = {
    "cc_by_4": ("Creative Commons Attribution 4.0 International (CC BY 4.0)",
                "CC BY 4.0", "https://creativecommons.org/licenses/by/4.0/"),
}


class ImportProblem(Exception):
    pass


def txt(e: ET.Element) -> str:
    """Readable text inside an element (never the text after it)."""
    return re.sub(r"\s+", " ", "".join(e.itertext())).strip()


def ln(e: ET.Element) -> str:
    """Local tag name; answer keys put MathML in the XHTML namespace."""
    return e.tag.rsplit("}", 1)[-1]


# ---------------------------------------------------------------- MathML

_GREEK = {
    "α": r"\alpha", "β": r"\beta", "γ": r"\gamma", "δ": r"\delta", "Δ": r"\Delta",
    "ε": r"\varepsilon", "θ": r"\theta", "λ": r"\lambda", "μ": r"\mu", "π": r"\pi",
    "ρ": r"\rho", "σ": r"\sigma", "Σ": r"\Sigma", "τ": r"\tau", "φ": r"\varphi",
    "ω": r"\omega", "Ω": r"\Omega",
}
_OPS = {
    "⋅": r"\cdot", "·": r"\cdot", "×": r"\times", "÷": r"\div", "−": "-", "–": "-",
    "≤": r"\le", "≥": r"\ge", "≠": r"\ne", "±": r"\pm", "∓": r"\mp", "∞": r"\infty",
    "→": r"\to", "←": r"\leftarrow", "⇒": r"\Rightarrow", "⇔": r"\Leftrightarrow",
    "…": r"\ldots", "⋯": r"\cdots", "∈": r"\in", "∉": r"\notin", "∪": r"\cup",
    "∩": r"\cap", "⊂": r"\subset", "⊆": r"\subseteq", "≈": r"\approx", "∘": r"\circ",
    "°": r"^\circ", "√": r"\surd", "∑": r"\sum", "∏": r"\prod", "∫": r"\int",
    "{": r"\{", "}": r"\}", "%": r"\%", "#": r"\#", "&": r"\&", "∠": r"\angle",
    "$": r"\text{\textdollar}",
    "⊥": r"\perp", "∥": r"\parallel", "≅": r"\cong", "∼": r"\sim", "′": "'",
    "⁡": "", "⁢": "", "⁣": "", " ": " ",
}
_FUNCS = {"log", "ln", "sin", "cos", "tan", "sec", "csc", "cot", "exp", "lim",
          "max", "min", "arcsin", "arccos", "arctan", "det", "gcd"}


def _sym(text: str) -> str:
    out = []
    for ch in text:
        if ch in _GREEK:
            out.append(_GREEK[ch] + " ")
        elif ch in _OPS:
            out.append(_OPS[ch] + (" " if _OPS[ch].startswith("\\") and _OPS[ch][-1].isalpha() else ""))
        else:
            out.append(ch)
    return "".join(out)


def _escape_text(text: str) -> str:
    # "$" would end the surrounding $…$ in lesson markdown; use \textdollar.
    text = re.sub(r"([{}%#&_])", r"\\\1", text)
    return text.replace("$", r"\textdollar ")


def tex(e: ET.Element, warnings: list[str] | None = None) -> str:
    """Presentation MathML → LaTeX that flutter_math can render."""
    warnings = warnings if warnings is not None else []
    n = ln(e)
    kids = [c for c in e if ln(c) not in ("annotation", "annotation-xml")]

    def j(nodes):
        return "".join(tex(c, warnings) for c in nodes)

    def g(node):
        s = tex(node, warnings).strip()
        return s if len(s) == 1 else "{" + s + "}"

    text = (e.text or "").strip()
    if n in ("math", "mrow", "mstyle", "mpadded", "menclose", "merror", "semantics"):
        if n == "semantics":
            return tex(kids[0], warnings) if kids else ""
        return j(kids)
    if n == "mphantom":
        return ""
    if n == "mi":
        if text in _FUNCS:
            return "\\" + text + " "
        if len(text) > 1 and text.isalpha():
            return r"\mathrm{" + text + "}"
        return _sym(text)
    if n == "mn":
        return _sym(text)
    if n == "mo":
        return _sym(text)
    if n == "mtext":
        return r"\text{" + _escape_text(e.text or "") + "}" if (e.text or "").strip() else " "
    if n == "ms":
        return r"\text{" + _escape_text(text) + "}"
    if n == "mspace":
        return r"\;"
    if n in ("msup", "msub") and len(kids) >= 2:
        # Some source MathML puts extra siblings in the base; keep them.
        base = "".join(tex(c, warnings) for c in kids[:-1]).strip()
        base = base if len(base) == 1 else "{" + base + "}"
        return base + ("^" if n == "msup" else "_") + g(kids[-1])
    if n == "mmultiscripts" and kids:
        def part(node):
            return "" if ln(node) == "none" else tex(node, warnings)
        post, pre, target = [], [], None
        rest = kids[1:]
        for node in rest:
            if ln(node) == "mprescripts":
                target = pre
                continue
            (target if target is not None else post).append(node)
        out = ""
        for i in range(0, len(pre) - 1, 2):
            out += "{}_{" + part(pre[i]) + "}^{" + part(pre[i + 1]) + "}"
        out += g(kids[0])
        for i in range(0, len(post) - 1, 2):
            out += "_{" + part(post[i]) + "}^{" + part(post[i + 1]) + "}"
        return out
    if n == "msubsup" and len(kids) == 3:
        return g(kids[0]) + "_" + g(kids[1]) + "^" + g(kids[2])
    if n == "mfrac" and len(kids) == 2:
        if e.get("linethickness") in ("0", "0px", "0em"):
            return r"\binom{" + tex(kids[0], warnings) + "}{" + tex(kids[1], warnings) + "}"
        return r"\frac{" + tex(kids[0], warnings) + "}{" + tex(kids[1], warnings) + "}"
    if n == "msqrt":
        return r"\sqrt{" + j(kids) + "}"
    if n == "mroot" and len(kids) == 2:
        return r"\sqrt[" + tex(kids[1], warnings) + "]{" + tex(kids[0], warnings) + "}"
    if n == "mover" and len(kids) == 2:
        over = "".join(kids[1].itertext()).strip()
        base = tex(kids[0], warnings)
        if over in ("¯", "‾", "_", "―", "—"):
            return r"\overline{" + base + "}"
        if over in ("^", "ˆ"):
            return r"\hat{" + base + "}"
        if over in ("→", "⇀"):
            return r"\vec{" + base + "}"
        if over in ("︷", "⏞"):
            return r"\overbrace{" + base + "}"
        return r"\overset{" + tex(kids[1], warnings) + "}{" + base + "}"
    if n == "munder" and len(kids) == 2 and "".join(kids[1].itertext()).strip() in ("︸", "⏟"):
        return r"\underbrace{" + tex(kids[0], warnings) + "}"
    if n == "munder" and len(kids) == 2:
        return r"\underset{" + tex(kids[1], warnings) + "}{" + tex(kids[0], warnings) + "}"
    if n == "munderover" and len(kids) == 3:
        return g(kids[0]) + "_" + g(kids[1]) + "^" + g(kids[2])
    if n == "mfenced":
        open_, close = e.get("open", "("), e.get("close", ")")
        seps = e.get("separators", ",").strip() or ","
        inner = (seps[0] + " ").join(tex(c, warnings) for c in kids)
        return r"\left" + (_sym(open_) or ".") + inner + r"\right" + (_sym(close) or ".")
    if n == "mtable":
        rows = [c for c in kids if ln(c) in ("mtr", "mlabeledtr")]
        cols = max((len([d for d in r if ln(d) == "mtd"]) for r in rows), default=1)
        body = r" \\ ".join(
            " & ".join(tex(d, warnings) for d in r if ln(d) == "mtd") for r in rows)
        return r"\begin{array}{" + "l" * cols + "}" + body + r"\end{array}"
    if n in ("mtd", "mtr"):
        return j(kids)
    warnings.append(f"unsupported MathML <{n}>; kept its text")
    return _sym("".join(e.itertext()).strip())


def math_markdown(e: ET.Element, warnings: list[str], inline_only: bool = False) -> str:
    latex = re.sub(r"\s+", " ", tex(e, warnings)).strip()
    if not latex:
        return ""
    if e.get("display") == "block" and not inline_only:
        return f"\n\n$${latex}$$\n\n"
    return f"${latex}$"


# ---------------------------------------------------------------- HTML

def _md_text(text: str) -> str:
    """Escape markdown emphasis characters in source prose."""
    return re.sub(r"([*_`])", r"\\\1", re.sub(r"\s+", " ", text))


def inline(e: ET.Element, warnings: list[str]) -> str:
    """Inline content of an element as markdown (text, math, emphasis)."""
    out = [_md_text(e.text or "")]
    for c in e:
        n = ln(c)
        if n == "math":
            # Inside a sentence, math stays inline even when the source
            # marks it as display, so the sentence is not split.
            out.append(math_markdown(c, warnings, inline_only=True))
        elif n in ("em", "i"):
            inner = inline(c, warnings).strip()
            out.append(f"*{inner}*" if inner else "")
        elif n in ("strong", "b"):
            inner = inline(c, warnings).strip()
            out.append(f"**{inner}**" if inner else "")
        elif n == "span" and c.get("data-type") == "term":
            inner = inline(c, warnings).strip()
            out.append(f"**{inner}**" if inner else "")
        elif n == "sup":
            out.append("^" + inline(c, warnings).strip())
        elif n == "sub":
            out.append("_" + inline(c, warnings).strip())
        elif n == "br":
            out.append("  \n")
        elif n in ("img", "figure"):
            out.append("")
        else:
            out.append(inline(c, warnings))
        out.append(_md_text(c.tail or ""))
    return "".join(out)


def _title(e: ET.Element) -> str:
    for c in e:
        if ln(c) in ("h2", "h3", "h4", "h5") or c.get("data-type") == "title":
            return txt(c)
    for c in e.iter():
        if c is not e and c.get("data-type") == "title":
            return txt(c)
    return ""


def blocks_markdown(e: ET.Element, warnings: list[str], skip_titles: bool = True) -> str:
    """Block content (paragraphs, lists, equations, tables) as markdown."""
    parts: list[str] = []
    for c in e:
        n, dtype, cls = ln(c), c.get("data-type", ""), c.get("class", "")
        if skip_titles and (n in ("h2", "h3", "h4", "h5") or dtype in ("title", "solution-title")):
            continue
        if n == "p":
            text = inline(c, warnings).strip()
            if text:
                parts.append(text)
        elif n in ("ul", "ol"):
            items = []
            for li in c:
                if ln(li) == "li":
                    body = inline(li, warnings).strip()
                    nested = blocks_markdown(li, warnings) if any(
                        ln(x) in ("ul", "ol", "p", "div") for x in li) else ""
                    items.append("- " + (body or nested.replace("\n", " ")).strip())
            if items:
                parts.append("\n".join(items))
        elif dtype == "equation" or n == "math":
            maths = [m for m in c.iter() if ln(m) == "math"]
            for m in maths if n != "math" else [c]:
                m.set("display", "block")
                parts.append(math_markdown(m, warnings).strip())
        elif n == "figure" or dtype == "figure" or cls.startswith("os-figure"):
            # One caption only (figcaption wraps os-caption), with math
            # converted, not raw MathML text (which repeats annotations).
            caps = ([x for x in c.iter() if ln(x) == "figcaption"]
                    or [x for x in c.iter() if x.get("class") == "os-caption"])
            caption = re.sub(r"\s+", " ", inline(caps[0], warnings)).strip() if caps else ""
            caption = re.sub(r"\.\$$", "$", caption).rstrip(". ")
            # Underscore emphasis, so italic terms (*N*) inside stay nested.
            parts.append(f"_(Figure in the original section{': ' + caption if caption else ''}.)_")
        elif n == "table" or cls == "os-table":
            parts.append(table_markdown(c, warnings))
        elif n in ("div", "section", "span", "blockquote"):
            inner = blocks_markdown(c, warnings, skip_titles)
            if inner:
                parts.append(inner)
    return "\n\n".join(p for p in parts if p.strip())


def table_markdown(e: ET.Element, warnings: list[str]) -> str:
    rows = [r for r in e.iter() if ln(r) == "tr"]
    grid = [[inline(c, warnings).strip().replace("|", r"\|").replace("\n", " ")
             for c in r if ln(c) in ("td", "th")] for r in rows]
    grid = [r for r in grid if r]
    if not grid:
        return ""
    width = max(len(r) for r in grid)
    grid = [r + [""] * (width - len(r)) for r in grid]
    lines = ["| " + " | ".join(grid[0]) + " |", "|" + " --- |" * width]
    lines += ["| " + " | ".join(r) + " |" for r in grid[1:]]
    return "\n".join(lines)


# ---------------------------------------------------------------- questions

_PART = re.compile(r"^-\s*([ⓐ-ⓩ])\s*(.*)$", re.S)


def split_parts(markdown: str) -> tuple[str, list[tuple[str, str]]]:
    """Stem text and the lettered parts (ⓐ, ⓑ, …) of a problem or answer."""
    stem, parts = [], []
    for line in markdown.split("\n"):
        m = _PART.match(line.strip())
        if m:
            parts.append((m.group(1), m.group(2).strip()))
        elif not parts:
            stem.append(line)
    return "\n".join(stem).strip(), parts


def numeric_answer(answer: str) -> str | None:
    """The answer as a plain number when it is exactly one number (whole,
    decimal, percent or a fraction with a terminating decimal); else None.
    Expressions are never turned into graded questions."""
    a = answer.strip().rstrip(".")
    a = re.sub(r"^\$(.*)\$$", r"\1", a).strip().rstrip(".")
    a = a.replace(r"\,", "").replace(" ", "").replace(r"\%", "%").replace(",", "")
    a = a.replace(r"\text{%}", "%")
    m = re.fullmatch(r"(-?)\\frac\{(\d+)\}\{(\d+)\}", a)
    if m:
        num, den = int(m.group(2)), int(m.group(3))
        if den == 0:
            return None
        d = den
        for p in (2, 5):
            while d % p == 0:
                d //= p
        if d != 1 and num % den != 0:
            return None
        value = (num / den) if num % den else num // den
        text = f"{value:.10f}".rstrip("0").rstrip(".") if isinstance(value, float) else str(value)
        return m.group(1) + text
    m = re.fullmatch(r"(-?\d+(?:\.\d+)?)%?", a)
    return m.group(1) if m else None


def numeric_questions(problem_md: str, answer_md: str, id_prefix: str, citation: str,
                      start: int) -> list[dict]:
    """Graded numeric-entry items for the numeric parts of one exercise
    (graded on the server by grade_assessment_items)."""
    stem, parts = split_parts(problem_md)
    _, answer_parts = split_parts(answer_md)
    pairs = []
    if parts and answer_parts:
        answers = dict(answer_parts)
        pairs = [(f"{stem}\n\n{token} {text}".strip(), answers.get(token)) for token, text in parts]
    elif not parts and not answer_parts:
        pairs = [(problem_md, answer_md)]
    out = []
    for question, answer in pairs:
        value = numeric_answer(answer or "")
        if value is None or not question.strip():
            continue
        number = float(value)
        out.append({
            "id": f"{id_prefix}-q{start + len(out)}",
            "interaction_type": "numeric_entry",
            "prompt": question + "\n\nAnswer with a number.",
            "response_spec": {},
            "scoring_spec": {
                "correct_value": int(number) if number.is_integer() else number,
                "tolerance": 0,
            },
            "explanation": f"Answer from the book's answer key: {answer}",
            "difficulty": "intermediate",
            "cognitive_level": "application",
            "citation": citation,
        })
    return out


# ---------------------------------------------------------------- sections

def _find(e: ET.Element, dtype: str) -> ET.Element | None:
    for x in e.iter():
        if x.get("data-type") == dtype:
            return x
    return None


def answers_by_exercise(answer_key_html: str) -> dict[str, str]:
    root = ET.fromstring(answer_key_html)
    out = {}
    for s in root.iter():
        sid = s.get("id", "")
        if s.get("data-type") == "solution" and sid.endswith("-solution"):
            body = next((c for c in s if "os-solution-container" in c.get("class", "")), None)
            if body is not None:
                warnings: list[str] = []
                text = blocks_markdown(body, warnings) or inline(body, warnings).strip()
                if text and not warnings:
                    out[sid[: -len("-solution")]] = text
    return out


def glossary(key_terms_html: str) -> dict[str, str]:
    root = ET.fromstring(key_terms_html)
    out = {}
    for d in root.iter():
        if ln(d) != "dl":
            continue
        dts = [x for x in d if ln(x) == "dt"]
        dds = [x for x in d if ln(x) == "dd"]
        if dts and dds:
            term = txt(dts[0])
            definition = txt(dds[0])
            if term and definition and not any(ln(x) == "math" for x in dds[0].iter()):
                out[term.lower()] = definition
    return out


def section_lesson(page_html: str, meta: dict, answers: dict[str, str],
                   terms: dict[str, str]) -> tuple[dict, list[str]]:
    """One OpenStax section → one manifest lesson."""
    warnings: list[str] = []
    root = ET.fromstring(page_html)
    page = _find(root, "page")
    if page is None:
        raise ImportProblem("no page element")

    blocks: list[dict] = []

    def add(block_type: str, content: dict) -> None:
        blocks.append({"sort_order": len(blocks) + 1, "block_type": block_type, "content": content})

    abstract = _find(page, "abstract")
    objectives = []
    if abstract is not None:
        objectives = [inline(li, warnings).strip() for li in abstract.iter() if ln(li) == "li"]
        if objectives:
            add("markdown", {"text": "### In this section, you will:\n\n" +
                             "\n".join(f"- {o}" for o in objectives)})

    practice = 0
    skipped_practice = 0
    questions: list[dict] = []
    id_prefix = re.sub(r"[^a-z0-9]+", "-", f"{meta['source_id']}-{meta['number']}".lower()).strip("-")
    q_citation = f"{meta['book']} (OpenStax), Section {meta['number']}, answer key, {meta['url']}"

    def walk(container: ET.Element, heading: str) -> None:
        nonlocal practice, skipped_practice, questions
        buffer: list[str] = [f"### {heading}"] if heading else []

        def flush() -> None:
            text = "\n\n".join(b for b in buffer if b.strip())
            if text.strip() and text.strip() not in (f"### {heading}",):
                add("markdown", {"text": text})
            buffer.clear()

        for c in container:
            n, dtype, cls = ln(c), c.get("data-type", ""), c.get("class", "")
            if n in ("h2", "h3", "h4") or dtype in ("title", "document-title", "abstract"):
                continue
            if n == "section":
                if "section-exercises" in cls:
                    # Odd-numbered exercises have answers; numeric ones become
                    # graded questions. The set itself is not copied.
                    for ex in (x for x in c.iter() if x.get("data-type") == "exercise"):
                        problem = _find(ex, "problem")
                        answer = answers.get(ex.get("id", ""))
                        if problem is None or not answer or len(questions) >= 12:
                            continue
                        found = numeric_questions(blocks_markdown(problem, warnings), answer,
                                                  id_prefix, q_citation, len(questions) + 1)
                        questions.extend(found[: 12 - len(questions)])
                    continue
                if "review-exercises" in cls or "practice-test" in cls:
                    continue
                flush()
                walk(c, _title(c))
                continue
            if dtype == "example":
                flush()
                problem = _find(c, "problem")
                solution = _find(c, "solution")
                title = _title(problem) if problem is not None else ""
                head = txt(c[0]) if len(c) else "Example"
                parts = [f"**{head}" + (f": {title}" if title else "") + "**"]
                if problem is not None:
                    parts.append(blocks_markdown(problem, warnings))
                if solution is not None:
                    parts.append("**Solution**\n\n" + blocks_markdown(solution, warnings))
                add("markdown", {"text": "\n\n".join(p for p in parts if p.strip())})
                continue
            if dtype == "note" and "try" in cls:
                flush()
                for ex in (x for x in c.iter() if x.get("data-type") == "exercise"):
                    problem = _find(ex, "problem")
                    answer = answers.get(ex.get("id", ""))
                    if problem is None or not answer:
                        skipped_practice += 1
                        continue
                    practice += 1
                    problem_md = blocks_markdown(problem, warnings)
                    add("practice_prompt", {
                        "prompt": problem_md,
                        "answer": answer,
                        "explanation": "Answer from the book's answer key.",
                    })
                    questions.extend(numeric_questions(problem_md, answer, id_prefix, q_citation,
                                                       len(questions) + 1))
                continue
            if dtype == "note":
                flush()
                body = blocks_markdown(c, warnings)
                if body:
                    add("callout", {"type": "key_concept", "title": _title(c) or "Note", "body": body})
                continue
            # Convert the element as a whole (so a figure, table or list
            # directly in a section is handled, not just its children).
            wrapper = ET.Element("div")
            wrapper.append(c)
            md = blocks_markdown(wrapper, warnings)
            if md:
                buffer.append(md)
        flush()

    walk(page, "")

    defined = {txt(t).lower()
               for t in page.iter() if t.get("data-type") == "term"}
    body = txt(page).lower()
    used = {t for t in terms if len(re.findall(r"\b" + re.escape(t) + r"\b", body)) >= 2}
    chosen = sorted((defined | used) & set(terms), key=lambda t: (t not in defined, t))[:10]
    lesson_terms = [{"term": t, "definition": terms[t]} for t in chosen]

    lic_full, lic_short, lic_url = LICENSE_TEXT[meta["license"]]
    credit = (
        f"Adapted from *{meta['book']}* by OpenStax, Rice University, Section {meta['number']} "
        f"([{meta['url']}]({meta['url']})), licensed under [{lic_short}]({lic_url}).\n\n"
        "**Changes:** converted to LearningApp lesson format; math converted from MathML; "
        "Try It exercises turned into practice prompts with answers from the book's answer key; "
        "images and end-of-section exercise sets omitted (see the original section). "
        "OpenStax and Rice University do not endorse LearningApp.\n\n"
        "**Review:** imported automatically; not reviewed by a person."
    )
    add("callout", {"type": "info", "title": "Source and license", "body": credit})

    lesson = {
        "title": f"{meta['number']} {meta['title']}",
        "description": ("; ".join(o.rstrip(". ") for o in objectives) + "."
                        if objectives else meta["title"])[:500],
        "emoji": "📘",
        "tags": ["open-textbook", "openstax", lic_short.lower().replace(" ", "-"),
                 *meta["subject"].split(),
                 *TOPIC_TAGS.get(meta["source_id"], {}).get(meta["number"], []),
                 "unreviewed"],
        "citation": f"{meta['book']} (OpenStax), Section {meta['number']}, {meta['url']}, {lic_short}",
        "source_release_id": meta["source_id"],
        "blocks": blocks,
        "terms": lesson_terms,
        "assessment_items": questions,
    }
    if skipped_practice:
        warnings.append(f"{skipped_practice} Try It exercise(s) had no answer and were left out")
    return lesson, warnings


# ---------------------------------------------------------------- book

def fetch(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def check_source(source_id: str) -> tuple[dict, dict]:
    registry = {s["id"]: s for s in json.loads(REGISTRY.read_text(encoding="utf-8"))["sources"]}
    source = registry.get(source_id)
    book = next((b for b in BOOKS if b["source_id"] == source_id), None)
    if source is None or book is None:
        raise ImportProblem(f"{source_id} is not a registered, indexed open book")
    if source.get("status") != "approved" or not {"adapt", "redistribute"} <= set(source["allowed_uses"]):
        raise ImportProblem(f"{source_id} is not approved for adapting and redistributing")
    if source["license"] not in LICENSE_TEXT:
        raise ImportProblem(f"{source_id}: importing {source['license']} content is not supported")
    return source, book


def import_book(source_id: str, chapters: set[int], delay: float) -> tuple[dict, list[str]]:
    source, book = check_source(source_id)
    meta = fetch(f"{ARCHIVE}{book['book']}.json")
    reported = ARCHIVE_LICENSE.get((meta.get("license") or {}).get("name", ""), "unknown")
    if reported != source["license"]:
        raise ImportProblem(f"archive reports {reported}, registry says {source['license']}")
    tree = meta["tree"]["contents"]
    answer_key = next((c for c in tree if c.get("slug") == "answer-key"), None)
    all_warnings: list[str] = []
    left_out: list[str] = []
    domains = []
    for node in tree:
        title = plain(node.get("title", ""))
        m = re.match(r"^Chapter\s+(\d+)\s+(.*)$", title)
        if not m or int(m.group(1)) not in chapters:
            continue
        number, chapter_title = int(m.group(1)), m.group(2)
        answers: dict[str, str] = {}
        if answer_key:
            ak = next((c for c in answer_key.get("contents", []) if c.get("slug") == f"chapter-{number}"), None)
            if ak:
                answers = answers_by_exercise(
                    fetch(f"{ARCHIVE}{book['book']}:{ak['id'].split('@')[0]}.json")["content"])
        terms: dict[str, str] = {}
        for sub in node.get("contents", []):
            for leaf in sub.get("contents", []) or []:
                if plain(leaf.get("title", "")).lower() == "key terms":
                    terms = glossary(fetch(f"{ARCHIVE}{book['book']}:{leaf['id'].split('@')[0]}.json")["content"])
        objectives = []
        for leaf in node.get("contents", []):
            if leaf.get("contents"):
                continue
            sec_number, sec_title = split_number(plain(leaf.get("title", "")))
            if not sec_number:
                continue
            page = fetch(f"{ARCHIVE}{book['book']}:{leaf['id'].split('@')[0]}.json")
            time.sleep(delay)
            info = {
                "source_id": source_id, "license": source["license"], "book": meta.get("title", ""),
                "number": sec_number, "title": sec_title, "subject": book["subject"],
                "url": f"https://openstax.org/books/{book['slug']}/pages/{leaf['slug']}",
            }
            lesson, warnings = section_lesson(page["content"], info, answers, terms)
            all_warnings += [f"{sec_number}: {w}" for w in sorted(set(warnings))]
            if not lesson["assessment_items"]:
                left_out.append(f"{sec_number} {sec_title}")
                continue
            concept = "open-" + re.sub(r"[^a-z0-9]+", "-", f"{source_id}-{sec_number}".lower()).strip("-")
            lesson["concept_slugs"] = [concept]
            for q in lesson["assessment_items"]:
                q["concept_slugs"] = [concept]
            objectives.append({
                "code": sec_number,
                "title": sec_title,
                "description": lesson["description"],
                "sort_order": len(objectives) + 1,
                "importance": "recommended",
                "citation": lesson["citation"],
                "source_release_id": source_id,
                "concepts": [{
                    "slug": concept,
                    "name": sec_title,
                    "short_definition": lesson["description"][:200],
                    "citation": lesson["citation"],
                    "source_release_id": source_id,
                }],
                "lessons": [lesson],
            })
        if not objectives:
            continue
        domains.append({
            "code": f"CH{number}",
            "title": chapter_title,
            "sort_order": number,
            "importance": "recommended",
            "citation": f"{meta.get('title', '')} (OpenStax), Chapter {number}",
            "source_release_id": source_id,
            "objectives": objectives,
        })
    if not domains:
        raise ImportProblem(f"no chapters {sorted(chapters)} found")
    lic_full, lic_short, _ = LICENSE_TEXT[source["license"]]
    manifest = {
        "source_releases": [{
            "id": source_id,
            "publisher": "OpenStax, Rice University",
            "title": meta.get("title", ""),
            "version": f"{book['book'].split('@')[1]} (archive {ARCHIVE.rstrip('/').split('/')[-2]})",
            "source_url": f"https://openstax.org/books/{book['slug']}/pages/preface",
            "retrieved_at": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "license": lic_full,
            "license_name": lic_short,
            "rights_note": (f"Adapted under {lic_short} (owner-approved, data/content_sources.json). "
                            "OpenStax and Rice University names and logos are not covered by the "
                            "license; no endorsement implied. Imported automatically; not reviewed "
                            "by a person."),
            "metadata": {"use": "redistribute", "imported_by": "tool/import_open_textbook.py",
                         "chapters": sorted(chapters)},
        }],
        "target": {
            "slug": f"open-{source_id}",
            "title": f"{meta.get('title', '')} (open textbook)",
            "version_code": f"OPENSTAX-{book['book'].split('@')[1].upper()}-R{IMPORT_REVISION}",
            "version_title": f"{meta.get('title', '')} by OpenStax, {lic_short}",
            "version_description": "Open textbook sections imported as LearningApp lessons.",
            # Plan v2.6 §7.1: math definitions and methods are timeless (V0).
            "volatility_class": "V0",
        },
        "domains": domains,
    }
    for title in left_out:
        all_warnings.append(f"left out {title}: no answer can be graded automatically "
                            "(it stays reachable as an open textbook link)")
    return manifest, all_warnings


class _Literal(str):
    pass


def _literal(dumper, data):
    return dumper.represent_scalar("tag:yaml.org,2002:str", data, style="|")


def write_manifest(manifest: dict, path: Path) -> None:
    import yaml

    def mark(x):
        if isinstance(x, dict):
            return {k: mark(v) for k, v in x.items()}
        if isinstance(x, list):
            return [mark(v) for v in x]
        if isinstance(x, str) and "\n" in x:
            return _Literal(x.replace("\r", "").rstrip() + "\n")
        return x

    yaml.SafeDumper.add_representer(_Literal, _literal)
    header = ("# Generated by tool/import_open_textbook.py — do not edit by hand; re-run the tool.\n"
              "# Source license and approval: data/content_sources.json.\n")
    path.write_text(header + yaml.safe_dump(mark(manifest), allow_unicode=True, sort_keys=False,
                                            width=1000), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--source", required=True)
    ap.add_argument("--chapters", type=int, nargs="+", required=True)
    ap.add_argument("--delay", type=float, default=0.3)
    args = ap.parse_args(argv)
    try:
        manifest, warnings = import_book(args.source, set(args.chapters), args.delay)
    except ImportProblem as e:
        print(f"ERROR: {e}")
        return 1
    out = REPO / "content" / f"open_{args.source.replace('-', '_')}.yaml"
    write_manifest(manifest, out)
    lessons = sum(len(o["lessons"]) for d in manifest["domains"] for o in d["objectives"])
    prompts = sum(1 for d in manifest["domains"] for o in d["objectives"] for l in o["lessons"]
                  for b in l["blocks"] if b["block_type"] == "practice_prompt")
    graded = sum(len(l["assessment_items"]) for d in manifest["domains"] for o in d["objectives"]
                 for l in o["lessons"])
    for w in warnings:
        print(f"WARNING: {w}")
    print(f"wrote {out.relative_to(REPO)}: {lessons} lessons, {prompts} practice prompts, "
          f"{graded} graded questions, "
          f"{len(warnings)} warning(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
