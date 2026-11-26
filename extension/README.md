# LearningApp companion: browser extension

Companion plan v1.0, layer L5, package EX-9. App-side switch: `content.companion_extension` (default OFF). App route: `lib/screens/companion/companion_for_link_screen.dart`.

## What it does

One toolbar button. When the learner clicks it on a page they are studying, LearningApp opens beside that page:

- If the page is one of the learner's outside resources, its step-by-step companion opens.
- If not, the "add this as a resource" form opens with the page's name and link filled in. Nothing is saved until the learner presses Add.

| Browser | Where LearningApp opens |
|---|---|
| Firefox on a computer | The browser's own side panel |
| Chrome and Edge | A narrow window beside the browser |
| Firefox for Android | A new tab |

Chrome and Edge get a window, not a side panel, on purpose. Their side panel can only show a page packaged inside the extension, so showing LearningApp there would mean putting it in a frame, and the site forbids being framed (`X-Frame-Options: DENY`). That protection was kept. Firefox's side panel can load a web page directly, so no frame is involved.

## What it can see

- One permission: `activeTab`. The browser gives the extension the address and title of the current tab only at the moment the learner clicks the button.
- No content scripts, no host permissions, no history, no storage, no network requests of its own. It never reads what is on a page.
- The address and title are placed after the `#` of LearningApp's address. A browser does not send that part to a server, so LearningApp's servers do not see the page unless the learner saves it.
- Only `https://` pages are passed on. On a browser page or a local file the plain form opens.

`test/widgets/companion_for_link_test.dart` checks the manifests and script for these rules.

## Layout

`firefox/` and `chrome/` are each a complete extension. `background.js` is the same file in both (a test fails if they differ); only the manifests differ. `firefox/panel.html` is what Firefox's side panel shows before the button is first clicked.

To point a build at another copy of LearningApp, change `APP_ORIGIN` at the top of both `background.js` files.

## Trying it without a store listing

**Firefox:** open `about:debugging#/runtime/this-firefox`, choose "Load Temporary Add-on…", and pick `extension/firefox/manifest.json`. It stays until Firefox is closed.

**Chrome or Edge:** open `chrome://extensions` (or `edge://extensions`), turn on "Developer mode", choose "Load unpacked", and pick the `extension/chrome` folder.

Then open any https page and click the LearningApp button. If the app-side switch is turned off, LearningApp says the extension is not available.

## Publishing (owner)

Everything the store forms ask for, the packaging command and what only the owner can do: [STORE_LISTING.md](STORE_LISTING.md). In short:

- **Firefox Add-ons:** needs a developer account (free). The listing asks what data the extension collects; that declaration is the owner's to make. The honest description is in "What it can see" above.
- **Chrome Web Store:** needs a developer account with a one-time US$5 registration fee (plan decision X-11; approved by the owner 2026-11-26).
- **Edge Add-ons:** separate free account; the Chrome folder is what gets uploaded.
- **Safari:** not built (plan decision X-12).

## Not verified

See the plan's status table (§8.1, EX-9) for what was and was not seen working in a real browser.
