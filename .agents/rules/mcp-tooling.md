# MCP Tooling Rule: Chrome DevTools & Playwright

This rule informs AI agents of available Model Context Protocol (MCP) servers in this workspace for browser inspection and automation.

## Available Servers
- **`chrome-devtools`**: Chrome DevTools MCP (`chrome-devtools-mcp@latest --categoryPwa=true --isolated`). Use for:
  - Reading browser console messages and uncaught runtime errors (`list_console_messages`, `get_console_message`).
  - Monitoring network requests (`list_network_requests`).
  - Evaluating JavaScript in the live DOM (`evaluate_script`).
  - Auditing PWA performance and Core Web Vitals (`lighthouse_audit`, `performance_analyze_insight`).
- **`playwright`**: Playwright MCP (`@playwright/mcp@latest --browser=chrome`). Use for:
  - Automated user journeys, cross-tab navigation (`browser_navigate`, `browser_tabs`).
  - Clicking, filling forms, and selecting elements (`browser_click`, `browser_type`, `browser_fill_form`).
  - Inspecting snapshots and layout rendering (`browser_snapshot`, `browser_take_screenshot`).

## Flutter PWA Workflow
When verifying web layout issues or end-to-end features:
1. Start or build the web client (`flutter run -d chrome` or `flutter build web --release`).
2. Utilize `chrome-devtools` and `playwright` tools via `call_mcp_tool` to interact with and inspect the web app.
3. Profile isolation is enabled by default to prevent profile locking issues.
