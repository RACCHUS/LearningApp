# Agent & Developer Guidelines: Model Context Protocol (MCP) & Workflows

This document outlines the architecture, development standards, and Model Context Protocol (MCP) tooling available for AI agents and developers working on **LearningApp**.

---

## 🤖 Available MCP Servers

The following Model Context Protocol (MCP) servers are configured in the user/workspace configuration (`~/.gemini/config/mcp_config.json`) and available for agentic pair programming, browser inspection, and automated testing:

### 1. `chrome-devtools` (`chrome-devtools-mcp`)
- **Configuration**: Launches `chrome-devtools-mcp@latest` with `--categoryPwa=true --isolated`.
- **Primary Use Cases**:
  - **Console & Error Inspection**: Retrieve browser errors, warnings, and unhandled exceptions using `list_console_messages` and `get_console_message`.
  - **Network Monitoring**: Inspect network calls, Supabase REST/auth payloads, and asset fetching via `list_network_requests`.
  - **PWA & Performance Audits**: Perform Lighthouse audits (`lighthouse_audit`) and analyze Core Web Vitals (LCP, CLS, INP) or performance traces (`performance_start_trace`, `performance_analyze_insight`).
  - **JavaScript Evaluation & DOM State**: Execute expressions in the running web context with `evaluate_script` and inspect layout/DOM with `take_snapshot`.
  - **Page Navigation**: Navigate, reload, and manage pages with `navigate_page`, `list_pages`, and `close_page`.

### 2. `playwright` (`@playwright/mcp`)
- **Configuration**: Launches `@playwright/mcp@latest` with `--browser=chrome`.
- **Primary Use Cases**:
  - **End-to-End User Flow Automation**: Simulate learner actions such as clicking navigation rail items, opening the Help dialog, browsing the catalog, or working through flashcard/quiz sessions.
  - **Browser Actions**: Interactively drive browser sessions via `browser_click`, `browser_type`, `browser_fill_form`, `browser_press_key`, and `browser_hover`.
  - **Tab & Session Management**: Manage tabs with `browser_tabs` and navigate URLs with `browser_navigate`.
  - **Visual & DOM Verification**: Inspect accessibility trees and interactive elements with `browser_snapshot`, or capture rendered state with `browser_take_screenshot`.

---

## 🚀 How AI Agents & Developers Should Use MCP Tools

When tasked with debugging UI issues, testing new web features, or verifying responsive layouts:

1. **Serve the Application**:
   - Run the Flutter web client:
     ```bash
     flutter run -d chrome
     ```
   - Or test a release build served locally:
     ```bash
     flutter build web --release
     ```

2. **Verify in Browser via MCP**:
   - Use `chrome-devtools` (`list_pages`, `navigate_page`) to attach to the dev server or open the local web build.
   - Check for runtime errors, missing asset 404s, or Supabase connection issues using `list_console_messages` and `list_network_requests`.
   - Use `playwright` (`browser_click`, `browser_snapshot`) to simulate multi-step workflows like goal creation, library search, and study sessions.

3. **Validate PWA & Responsiveness**:
   - Test responsive breakpoints (e.g. NavigationRail on $\ge$900dp vs bottom navigation bar on smaller viewports).
   - Use `chrome-devtools` with `emulate` or `resize_page` to verify desktop, tablet, and mobile layouts.

---

## 📋 Core Architectural Rules for Agents

- **Navigation Baseline**: Three primary destinations: **Learn**, **Library**, and **Progress**. See [UI_ARCHITECTURE_LOCKED.md](UI_ARCHITECTURE_LOCKED.md).
- **Desktop/Tablet ($\ge$900dp)**: Collapsible `NavigationRail` with integrated Library search.
- **Chrome Requirement**: The searchable **Help** (`?`) control must always remain accessible in the top-right chrome.
- **Database Migrations**: Files in `supabase/migrations/` are **append-only**. Never rewrite or edit previously merged migrations.
- **Client Secrets**: Never place service-role keys or sensitive server credentials into `.env` or client bundles.
