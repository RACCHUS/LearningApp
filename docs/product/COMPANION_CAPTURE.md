# Sending a link into LearningApp (companion capture)

Companion plan v1.0, layer L2, package EX-6. Switch: `content.companion_capture` (default OFF). Owner: `lib/screens/companion/add_resource_screen.dart`.

## What it does

A learner who is on a course, video or article in a browser can send that page's link and name to LearningApp's "Add from a link" form. They choose the goal and press **Add to this goal**. Nothing is saved before that.

Route: `/#/add-resource?url=<encoded link>&title=<encoded name>`. Both parameters are optional; with none, the form opens empty.

## Privacy rules

- LearningApp is a hash-routed web app, so everything after `#` is the URL fragment. A browser does not send the fragment to a server. The captured link reaches Supabase only if the learner saves it.
- The link is cleaned on the device: https only, no sign-in details, tracking parameters removed. A link that fails is shown and refused.
- The name is treated as plain text: control characters removed, capped at 200 characters.
- LearningApp never opens or fetches the link.
- The save is the same server function as adding a resource from a goal, behind `content.learner_resources`. The capture switch only controls the entry points; it is not a second server gate.

## Entry points

| Entry | State | Notes |
|---|---|---|
| Bookmarklet (computer browsers) | Built | The form shows it under "Send a page here with one tap", with a Copy button. The learner makes a bookmark and pastes it as the address |
| Paste | Built | Open the form and paste a link, or add from a goal as before |
| Apple Shortcut (iPhone, iPad) | Steps below, not tested on a device | A published, shareable Shortcut needs an Apple device and account, so it is the owner's to publish |
| Android share sheet | Not built | See below |
| Browser extension | EX-9 | |

### Apple Shortcut (not tested on a device)

In the Shortcuts app, make a new Shortcut:

1. In its details, turn on **Show in Share Sheet** and accept **URLs** and **Safari web pages**.
2. Add **URL Encode** with the Shortcut Input.
3. Add **Open URLs** with `https://learningapp-2ed8a.web.app/#/add-resource?url=` followed by the encoded text from step 2.

Sharing a page to this Shortcut opens LearningApp's form with the link filled in. The name is left for the learner to type.

### Why the Android share sheet is not built yet

A web app joins the Android share sheet through `share_target` in `web/manifest.json`. With the simple GET form, the browser puts the shared link in the query string of the request, which the hosting server receives and may log. That breaks the rule above. Keeping the link off the server needs a POST share that the service worker intercepts and turns into the fragment route, and that has to be tested on an Android device with the app installed. It is left as its own change.

## Switched off

The route shows "Adding from a link is not available right now" and offers no way to save. The link on the goal card is hidden. Adding a resource from a goal, including pasting a link there, works as before.
