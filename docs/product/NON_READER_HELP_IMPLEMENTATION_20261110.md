# Non-reader Help implementation and remaining validation

**Branch:** `feat/non-reader-visual-audio-help`  
**Base:** `806f688914a8b92a4a22f05f8efdb54f1ee4f065` (PR #223)  
**Scope:** Local Help experience only. No migrations, paid services, new permissions, or production deployment.

## Goals

A person who cannot read must be able to find Help, identify a relevant topic
from pictures, listen to an explanation, follow visible steps and return to their
activity without typing, signing in, using a microphone or going through literacy
setup. Written search remains available.

## Implemented foundation

1. Open Help to see an illustrated, scrollable topic grid by default, with
   a clear dedicated Listen control on every card. Listening does not navigate;
   selecting a picture does.
2. Keep the existing search field. Typing a nonempty query switches to the
   original text search index. The user can also toggle the displayed index.
3. Every existing Help topic has a locally available icon, audio narration and
   visual step tiles. All 15 existing topics have hand-written,
   ordered spoken guidance; keep revising these steps from observed user behavior.
4. Each Help article has a large narration button and per-step replay buttons,
   plus its original full text and route action.
5. Use the pre-reader provider's existing audio service and track-aware speech;
   **do not** add another TTS player. PR #223's global overlay provides
   pause/resume/restart/stop for narration, with platform fallbacks.
6. Automatically narrate the Help introduction for configured pre-readers
   only when auto-speak is on; automatically narrate a picture-opened article
   only for these configured pre-readers. Other users can select Listen.
7. Retain Help's no-login and offline behavior. Do not force permissions,
   mutate learner progress, or require an external voice API.

## Follow-on work before claiming full non-reader independence

- **Real illustrations and usability:** Icons are interim pictograms. Observe
  adults and young learners who do not read; validate recognizability, text
  scaling, touch targets and 320–400dp screens. Replace ambiguous icons with
  tested illustrations; keep appropriate adult/child presentation.
- **Detailed guided walkthroughs:** Build safe, destination-aware Show Me
  overlays that point to real controls. The current help route actions only
  navigate; they do not yet highlight controls on the destination screen.
  Never automate permissions, answer submission, or destructive operations.
- **Review narrated topics with actual learners:** Refine the initial hand-written
  scripts so every instruction matches its live route and maturity state.
  Ensure unavailable or experimental features are accurately described.
- **Optional voice question/video:** Voice questions and short video
  demonstrations are NOT implemented. They must be opt-in, have tap-only
  fallbacks, and must not autoplay or silently require a microphone/network.
- **Device verification:** Validate playback pause/resume/restart on iOS,
  Android, Safari, Chromium, keyboard/screen-reader and weak/offline
  environments. Some TTS engines restart on resume.
- **Rollout control:** Preserve basic Help as fallback. The feature-registry
  runtime bootstrap is not universally active; do not claim a remotely
  operational kill switch until the feature is registered, enforced and
  end-to-end verified.

## Acceptance checks

- Picture grid is visible before any typing or literacy-mode selection.
- Listening to a picture never triggers navigation.
- Entering a search term still finds original indexed topics.
- All 15 Help topics have a nonempty spoken explanation and visual fallback.
- Core task topics present ordered guidance.
- Every topic can replay full narration or a step independently.
- Pre-reader auto-speak respects off preference and other users are not
  interrupted by automatic audio.
- Closing Help returns the user to their original activity.
- Global playback bar and all prior navigation/accessibility tests remain green.

**Validation status:** Repository additions and regression tests are included;
device tests, observed non-reader studies, and production verification are
required before claiming that all learners can complete help independently.
