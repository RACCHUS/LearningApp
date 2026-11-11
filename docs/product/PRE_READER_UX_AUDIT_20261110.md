# Non-reader / spoken-learning usability audit — 2026-11-10

Scope: current Flutter Learn home, pre-reader entry/setup, literacy hub,
picture directory, practical life skills, milestones, and shared speech
navigation. This is a source-level review with regression tests; it is **not**
a substitute for an observed usability study with non-reading learners.

## Problems reported and resolutions

| User experience / risk | Concrete change | Protection |
|---|---|---|
| Clicking unrelated homepage areas can enter literacy | Entry background is no longer tappable. A dedicated **Start with Pictures** button is the only entry action. Standard Learn/Library destinations retain their own handlers | `pre_reader_home_navigation_test.dart` covers noninteractive background, speaker isolation, and actual Learn zero-state Library action |
| Hard-to-find non-reader starting point | Large 🔤 picture emblem, companion 👂/👆/🖼️ cues, prominent start and contrasting large speaker action; entry remains available even with an active goal | Widget regression tests |
| Spoken onboarding gives the wrong order | First-time guidance: picture start → choose Adult or Kids → Start. Returning users hear Continue rather than choosing again | Navigation/setup tests |
| Adult was silently selected by default | Start is disabled until learner explicitly taps the Adult or Kids picture choice | Navigation/setup tests |
| Setup may attempt navigation with a disposed dialog context | Capture GoRouter before dismissing the setup dialog | Navigation/setup test |
| Home narration cannot pause or restart | Shared Pause / Resume / Restart / Stop bar installed above the router, visible during/after narrated activities | Global playback controls widget tests |
| Speech is discarded by Pause / Resume | Keep transcript; try engine pause, resume near latest spoken word when boundary callbacks exist, otherwise restart from the beginning; Restart always plays complete narration | Underlying audio service implementation and remaining cross-platform validation |
| Global audio breaks after a lesson or provider disposal | Do not dispose the shared singleton AudioService from short-lived features; cancel only the provider's own stream listeners | Code review |
| Hidden horizontal navigation in the non-reader path | Show literacy, milestone and life-skill category choices in wrapping rows rather than a horizontally clipped strip | Widget tests / targeted UI review |
| No obvious way to repeat audio or return Home from life hubs | Add large speaker and Home icons, retaining audible announcements and auto-speak preference | Widgets and source inspection |
| Picture tile speaker too small | 48 dp minimum touch target, larger pictograms, more tile space | Widget tests |
| A completed letter auto-advances after user switches activities | Delayed advance checks current activity and selected letter before mutating state | Source guard |

## Design requirements (must remain true)

1. Never depend on reading, hover, scrolling a hidden strip, or a video to
   discover how to begin.
2. A learner hears what **will happen before** pressing Start; speaker taps
   must never navigate.
3. Learner choice of Adult vs Kids is deliberate, visually distinct, and
   reversible.
4. Controls should be consistent on desktop, touch, phone and keyboard, with
   tooltips and semantics for assistive technology.
5. All narration should offer Pause, Resume, Restart and Stop. Some TTS
   engines do not provide word positions; in those cases Resume may repeat
   from the beginning rather than invent a precise resume point.
6. Auto-speak OFF must not be contradicted by unconditional entry or
   category-change narration. Manual speaker controls continue to work.
7. Literacy mode is not a mandatory gate: ordinary Learn and Library buttons
   must remain independently navigable.

## Proposed optional how-to video (not implemented)

A short, phone-first **silent-visual-first** walkthrough (roughly 30–45s):
1. Home: highlight the large 🔤 picture start and its 🔊 speaker.
2. Show the Adult 🧑‍💼 / Kids 🧒 choice and a tap.
3. Show the Start button.
4. Demonstrate selecting a picture lesson and the global pause/replay buttons.

Use clear animated taps, slow pacing, real captions and optional human narration;
make it playable by an explicit video button with a recognizable ▶ symbol.
Do not autoplay it. Keep a static visual fallback if the video cannot load
or audio is disabled. Use compressed, low-bandwidth media and test with users
who cannot read before investing in further video production.

## Still requiring human/device validation

- Real iOS/Android/browser TTS pause and word-level resume behavior,
  especially platforms without speech-boundary events and asynchronous
  cancellation callbacks.
- Keyboard, screen reader, 320px/360px/400px mobile layouts and low-end PWA
  touch responsiveness.
- Non-reader understanding of emojis and icon meanings; replace ambiguous
  emojis with tested illustrations in a future design pass if necessary.
- Spoken guidance and picture-based navigation *inside every individual
  high-stakes lesson/simulator*, not just the top-level hubs.
- Localization and non-English narration; current text/images are English
  first. Tutor/field-pilot tools should remain separated from core learner
  guidance in later design iterations.

No production deployment or database migration is part of this patch.
