# Playing a video inside the companion (in-app player)

Companion plan v1.0, layer L3, package EX-7. Switch: `content.companion_embeds` (seeded OFF; **switched on 2026-11-26** by migration `20261126060000`). Owners: `lib/widgets/companion/companion_player.dart`, `lib/models/companion/video_embed.dart`.

## What it does

When a learner's outside resource is a link to a single YouTube video, the companion screen offers **Play here (loads YouTube)**. The video then plays at the top of the screen, and the parts, what to look for and LearningApp's checks stay below it. If the learner pasted the video's chapter list (lines such as `2:15 Exponents`), each part gets **Play this part here, from 2:15**.

Everything else, including playlists, channels and other sites, opens outside LearningApp as before.

## Rules the code keeps

| Rule | How |
|---|---|
| Nothing is requested from YouTube until the learner taps play | The frame is created only on that tap |
| The player is YouTube's own, unchanged | A plain `iframe` to `https://www.youtube-nocookie.com/embed/<id>` with only `playsinline` and `start`. No IFrame Player API, no Data API, no key |
| Nothing covers the player | Our controls sit below it, never on it |
| At least 200 by 200 | Enforced in layout, including in a 320-wide split-view pane |
| No autoplay | The `autoplay` parameter is never set |
| The Referer is not suppressed | `strict-origin-when-cross-origin` on the frame and in the hosting headers |
| LearningApp does not see what is played | No listener on the frame; nothing is stored when a video plays |
| Playing is not evidence | A played video never marks a part studied and never reaches readiness |
| One more allowed origin | The hosting CSP gains `frame-src https://www.youtube-nocookie.com` and nothing else |

Only links whose host is exactly `youtube.com`, `www.youtube.com`, `m.youtube.com`, `www.youtube-nocookie.com` or `youtu.be`, over https, with an 11-character video id, are treated as a video.

## Provider wording (done 2026-11-26)

YouTube's API Services Developer Policies were read on 2026-11-25 (`developers.google.com/youtube/terms/developer-policies` and `/required-minimum-functionality`). The "required minimum functionality" page treats a site that uses the embedded player as an API Client. The policies then require two things that are not code:

1. **Terms of Service (policy III.A.1).** The app must link to YouTube's Terms of Service (`https://www.youtube.com/t/terms`) and its own terms must say that by using the feature, users agree to be bound by YouTube's Terms of Service.
2. **Privacy Policy (policy III.A.2).** The app's privacy policy must say that it uses YouTube API Services, link to the Google Privacy Policy (`http://www.google.com/policies/privacy`), and explain what is collected. For this feature the honest statement is: LearningApp collects nothing when a video plays; YouTube receives the request from the learner's browser and may set its own storage.

The player's offer shows the YouTube Terms link, the Google Privacy Policy link, the sentence "By playing, you agree to YouTube's Terms of Service" and **LearningApp privacy and terms for this player**, which opens `/outside-study-privacy.html` (`web/outside-study-privacy.html`, published with every web release). The owner asked the AI to choose the wording (2026-11-26); that page publishes it, and the drafts `docs/legal/TERMS_OF_SERVICE.md` §5.4 and `docs/legal/PRIVACY_POLICY.md` §2.5 carry the same text. The wording:

- Terms: "Some study resources can be played inside LearningApp using YouTube's embedded player. By playing a video this way you agree to be bound by the YouTube Terms of Service (https://www.youtube.com/t/terms)."
- Privacy: "LearningApp uses YouTube API Services to show YouTube's embedded player when you choose to play a video inside the app. LearningApp does not record what you watch. YouTube receives the request from your browser and handles it under the Google Privacy Policy (http://www.google.com/policies/privacy)."

Not confirmed from the two pages read: whether a plain frame with no API calls is an "API Client" in those exact words (the pages imply it), and any statement about the `youtube-nocookie.com` domain (not mentioned on either page). Only the first part of the developer policies page was read word for word.

## Verified before switching on (2026-11-26)

On the local stack under the production headers (CSP served from `firebase.json`), as a guest and signed in: no frame and no request to YouTube before the tap; a tap loaded YouTube's own player from `www.youtube-nocookie.com` at 456 by 257 in a 456-wide window, with `start` set for "Play this part here" and no `autoplay`; no CSP violation; nothing marked studied in the database. The published page is served and contains the YouTube API Services statement and both links.

## Switched off

No offer, no player, no request to YouTube. "Open (leaves LearningApp)" works as before. Start times saved on an outline are kept.
