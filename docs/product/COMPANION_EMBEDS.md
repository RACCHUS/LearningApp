# Playing a video inside the companion (in-app player)

Companion plan v1.0, layer L3, package EX-7. Switch: `content.companion_embeds` (default OFF). Owners: `lib/widgets/companion/companion_player.dart`, `lib/models/companion/video_embed.dart`.

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

## What must be true before the switch is turned on (owner)

YouTube's API Services Developer Policies were read on 2026-11-25 (`developers.google.com/youtube/terms/developer-policies` and `/required-minimum-functionality`). The "required minimum functionality" page treats a site that uses the embedded player as an API Client. The policies then require two things that are not code:

1. **Terms of Service (policy III.A.1).** The app must link to YouTube's Terms of Service (`https://www.youtube.com/t/terms`) and its own terms must say that by using the feature, users agree to be bound by YouTube's Terms of Service.
2. **Privacy Policy (policy III.A.2).** The app's privacy policy must say that it uses YouTube API Services, link to the Google Privacy Policy (`http://www.google.com/policies/privacy`), and explain what is collected. For this feature the honest statement is: LearningApp collects nothing when a video plays; YouTube receives the request from the learner's browser and may set its own storage.

The player's offer already shows the YouTube Terms link, the Google Privacy Policy link and the sentence "By playing, you agree to YouTube's Terms of Service". **Wording adopted 2026-11-26** (the owner asked the AI to choose it): `docs/legal/TERMS_OF_SERVICE.md` §5.4 and `docs/legal/PRIVACY_POLICY.md` §2.5 now carry it. Both documents are still drafts that are not published on the site, and the policies require the privacy policy to be available to users, so **the switch stays off until a privacy policy that includes this wording is published.** The adopted wording, as first suggested:

- Terms: "Some study resources can be played inside LearningApp using YouTube's embedded player. By playing a video this way you agree to be bound by the YouTube Terms of Service (https://www.youtube.com/t/terms)."
- Privacy: "LearningApp uses YouTube API Services to show YouTube's embedded player when you choose to play a video inside the app. LearningApp does not record what you watch. YouTube receives the request from your browser and handles it under the Google Privacy Policy (http://www.google.com/policies/privacy)."

Not confirmed from the two pages read: whether a plain frame with no API calls is an "API Client" in those exact words (the pages imply it), and any statement about the `youtube-nocookie.com` domain (not mentioned on either page). Only the first part of the developer policies page was read word for word.

## Switched off

No offer, no player, no request to YouTube. "Open (leaves LearningApp)" works as before. Start times saved on an outline are kept.
