# Store listing: LearningApp companion

Everything the Chrome Web Store, Edge Add-ons and Firefox Add-ons forms ask for, ready to copy. Companion plan v1.0, EX-9. What the extension does and can see: [README.md](README.md).

## What only the owner can do

1. **Create the developer accounts.**
   - Chrome Web Store: US$5 one-time registration fee (approved by the owner on 2026-11-26).
   - Edge Add-ons (Microsoft Partner Center): free.
   - Firefox Add-ons (addons.mozilla.org): free.
2. **Publish a privacy policy that covers the extension, and paste its address into each form.** Every store asks for one, because the extension handles a page address. `docs/legal/PRIVACY_POLICY.md` is still marked as a draft pending legal review and does not mention the extension. Suggested wording is in [Privacy policy wording](#privacy-policy-wording-suggested-for-the-owner) below; adopting it is the owner's decision.
3. **Upload and submit.** Build the packages first:

   ```
   python tool/package_extension.py
   ```

   This writes `build/extension/learningapp-companion-chrome-<version>.zip`, which is also the Edge upload, and `build/extension/learningapp-companion-firefox-<version>.zip`.

Nothing else needs a decision. The app route the extension opens (`content.companion_extension`) was switched on by migration `20261126040000`, so reviewers see it working.

## Listing text

**Name:** LearningApp companion

**Summary** (manifest description, 125 of 132 characters):
Opens your LearningApp study plan beside the course, video or article you are on. Reads the page address only when you click.

**Category:** Education. In Chrome, pick the closest education category the form offers.

**Language:** English (United States)

**Description:**

> Studying with an outside course, video or textbook? Click the LearningApp button on its page and your LearningApp companion opens beside it.
>
> • If the page is one you already added to a LearningApp goal, you see its step-by-step plan: the part you are on, what to look for in it, and LearningApp's own checks for what it covers.
> • If it is a new page, LearningApp offers to add it to one of your goals, with its name and link filled in. Nothing is saved until you choose Add.
>
> What the extension can see:
> • One permission, activeTab. The browser lets the extension read the address and title of the tab you are on only at the moment you click the button.
> • No access to your browsing history, other tabs or page content. No content scripts, no storage, and no network requests of its own.
> • The address is passed to LearningApp after the # of LearningApp's own address, a part a browser does not send to any server. LearningApp's servers only learn about the page if you choose to save it.
>
> Works without an account: as a guest, what you add stays on your device.
>
> LearningApp is free. The extension is not affiliated with the course, video or book sites you use it on.

**Website:** https://learningapp-2ed8a.web.app

**Support:** the repository's issue tracker, https://github.com/RACCHUS/LearningApp/issues (the owner may prefer a support email address).

## Images

| Store asset | File | Size |
|---|---|---|
| Store icon | `extension/store-assets/store-icon-128.png` | 128×128 (96×96 artwork, transparent padding) |
| Small promo tile (Chrome, Edge) | `extension/store-assets/promo-small-440x280.png` | 440×280 |
| Screenshot | `extension/store-assets/store-shot-1-add-from-page.png`: the live site opened by the extension on an OpenStax page, as a guest, with the name and link filled in | 1280×800 |

The icon is the app's own icon (`web/icons/icon-512.png`), so the extension matches the installed app. It is a detailed picture, and at 16 pixels in the toolbar it reads only as a dark square with a light spot. A simpler mark would be clearer; that is a branding choice for the owner.

## Privacy and permissions tab (Chrome; Edge and Firefox ask similar questions)

**Single purpose:** Open the learner's LearningApp companion for the page they are on, beside that page.

**Permission justification for `activeTab`:** When the learner clicks the toolbar button, the extension reads the address and title of the current tab and opens LearningApp's companion for that page. It needs nothing at any other time and asks for no other permission.

**Remote code:** No. All code is in the package (`background.js`, under 50 lines), with no `eval` and no scripts fetched at run time.

**Data usage.** These are the honest answers; the owner makes the declaration.

- **Web history:** yes. The address of the current page, read only when the learner clicks.
- **Website content:** yes. The page's title, used to fill in the name.
- **Everything else** (personally identifiable information, health, financial, authentication, personal communications, location, user activity): no.
- **Certifications:**
  - The data is not sold or transferred to third parties.
  - It is not used for purposes unrelated to the single purpose.
  - It is not used for creditworthiness or lending.

**Firefox:** the manifest declares `data_collection_permissions: required: ["browsingActivity"]`, so Firefox shows this at install time.

## Notes for the store reviewers (paste into the test-instructions field)

> No account is needed. First open https://learningapp-2ed8a.web.app, choose a goal in the Library (for example CLEP College Algebra) and press Start Learning, so there is a goal to add pages to. Then install the extension, open any https page (for example https://openstax.org/books/college-algebra/pages/1-introduction-to-prerequisites), and click the LearningApp companion button.
>
> In Chrome and Edge, a narrow window opens beside the browser with LearningApp's "Add a course, video or book" form, its name and link filled in from the page. Choosing a goal and Add saves it on the device (guest mode). Clicking the button again on the same page then opens its step-by-step companion instead.
>
> The extension uses activeTab only and makes no network requests itself.

## Privacy policy wording (suggested, for the owner)

A section the owner may add to the privacy policy before submitting:

> **Browser extension.** The LearningApp companion extension for Chrome, Edge and Firefox has one permission, activeTab. When you click its button, your browser lets it read the address and title of the tab you are on. It passes them to LearningApp in the part of the address after the "#", which browsers do not send to servers, so our servers do not receive them unless you choose to save the page as one of your resources. The extension does not read page content, other tabs or your browsing history, does not store anything, and makes no network requests of its own. If you save a page, its name and link are kept with your account (or on your device as a guest) and can be deleted at any time.

## Releasing an update

1. Bump `version` in both manifests; the packager refuses to build if they differ.
2. Run `python tool/package_extension.py`.
3. Upload the new zip in each developer dashboard.
4. CI runs `python tool/package_extension.py --check` on every change.
