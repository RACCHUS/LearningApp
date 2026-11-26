// LearningApp companion: browser extension (companion plan v1.0 §5.4, EX-9).
//
// This file is the whole extension. It does one thing: when the learner
// clicks the toolbar button, it opens LearningApp's companion for the page
// they are on. The page's address and title are read only at that click
// (the `activeTab` permission) and are placed after the `#` of LearningApp's
// address. A browser never sends that part to a server, so LearningApp's
// servers do not see the page unless the learner chooses to save it.
//
// There are no content scripts, no host permissions, no history access and
// no background work. Nothing is stored.
//
// The same file is used for Firefox and for Chrome and Edge; a test checks
// the two copies are identical.

const APP_ORIGIN = 'https://learningapp-2ed8a.web.app';
const api = globalThis.browser ?? globalThis.chrome;

function companionUrl(tab) {
  const params = new URLSearchParams();
  const url = tab && typeof tab.url === 'string' ? tab.url : '';
  // Only ordinary web pages. Browser pages, local files and very long
  // addresses are left out; LearningApp then opens its plain form.
  if (url.startsWith('https://') && url.length <= 2000) params.set('url', url);
  const title = tab && typeof tab.title === 'string' ? tab.title.slice(0, 200) : '';
  if (title) params.set('title', title);
  const query = params.toString();
  return APP_ORIGIN + '/#/companion-for' + (query ? '?' + query : '');
}

api.action.onClicked.addListener((tab) => {
  const target = companionUrl(tab);
  if (api.sidebarAction && api.sidebarAction.open) {
    // Firefox on a computer: a real side panel. open() has to be called
    // directly inside the click, before anything else.
    api.sidebarAction.open();
    api.sidebarAction.setPanel({ panel: target });
    return;
  }
  if (api.windows && api.windows.create) {
    // Chrome and Edge: their side panel can only show a page packaged in the
    // extension, so LearningApp opens in a narrow window beside the browser.
    api.windows.create({ url: target, type: 'popup', width: 420, height: 760 });
    return;
  }
  // Firefox for Android: no side panel and no extra windows.
  api.tabs.create({ url: target });
});
