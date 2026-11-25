# 🚀 LearningApp Production Deployment Guide

This guide details the canonical, production deployment workflow for **LearningApp**.

**Architecture:** Flutter Progressive Web App (PWA) on **Firebase Hosting** backed by **Supabase** (PostgreSQL, Auth, Storage, and Row Level Security).

---

## 📋 Pre-Deployment Checklist

Before building or deploying the client web bundle:

1. **Verify Static Analysis & Automated Tests:**
   ```bash
   dart analyze
   flutter test
   ```
2. **Apply Pending Database Migrations to Hosted Supabase:**
   - Any new migration files in `supabase/migrations/` (such as `20261009000005_learning_target_catalog_provenance.sql`) must be applied to the remote Supabase project **before** deploying the web client that depends on them.
   - See [Hosted Migration Rollout](../HOSTED_MIGRATION_ROLLOUT.md) for execution details.
3. **Verify Environment Variables:**
   - Ensure production `.env` contains valid public keys:
     - `SUPABASE_URL`
     - `SUPABASE_ANON_KEY`
   - *Never* place `SUPABASE_SERVICE_ROLE_KEY` or secret credentials into `.env` or client bundles.

---

## 🛠️ Step-by-Step Deployment Workflow

### Step 1: Compile the Production Release Web Build

Run the Flutter release compiler with the production settings:

```bash
flutter build web --release --no-web-resources-cdn \
  --dart-define=SITE_FEATURE_RPC_READY=true \
  --dart-define=WEB_PUSH_VAPID_PUBLIC_KEY=<public key>
```

All three are required:

- `--no-web-resources-cdn` serves Flutter's renderer (CanvasKit) from the
  site itself. The hosting Content-Security-Policy only allows connections to
  the site, Supabase and `fonts.gstatic.com`, so a CDN build shows a blank
  page (2026-11-16 incident).
- `SITE_FEATURE_RPC_READY=true` makes the app read the feature switches.
  Without it, no switch in `/admin/features` has any effect in the browser.
- `WEB_PUSH_VAPID_PUBLIC_KEY` is the study-reminders public key
  (`docs/deployment/STUDY_REMINDERS_WEB_PUSH.md`). Public; never the private key.

A local `python -m http.server` test does not send the CSP header. Check a
build on a preview channel first, which serves the real headers:

```bash
firebase hosting:channel:deploy preview --expires 1d --project learningapp-2ed8a
firebase hosting:clone learningapp-2ed8a:preview learningapp-2ed8a:live --project learningapp-2ed8a
```

*Output Directory:* `build/web/`  
*Contents:*
- `index.html` — HTML5 entrypoint with PWA shell
- `main.dart.js` / `flutter_bootstrap.js` — Compiled, tree-shaken Dart web bundle with async bootstrap loader. The app is online-first; offline behavior is feature-specific and does not guarantee offline app-shell launch.
- `manifest.json` — PWA installation metadata and icons
- `assets/` — Application images, fonts, and data catalogs

---

### Step 2: Verify the Build Locally (Optional Smoke Test)

Before pushing to production, serve the compiled bundle locally to verify headers and asset delivery:

```bash
# Using Python
cd build/web
python -m http.server 8080

# OR using Firebase local emulator
firebase emulators:start --only hosting
```

Open `http://localhost:8080` in Chrome:
- Check DevTools Console for missing asset 404s or unhandled exceptions.
- Verify Network calls connect to the Supabase endpoint.

---

### Step 3: Deploy to Firebase Hosting

Deploy the production build using the Firebase CLI:

```bash
# Ensure you are logged into Firebase
firebase login

# Deploy directly to Firebase Hosting
firebase deploy --only hosting
```

*Target Project:* `learningapp-2ed8a` (configured in `.firebaserc`)  
*Hosting Config:* Defined in `firebase.json` with no-cache headers on `index.html`, `flutter_bootstrap.js`, and `version.json`. The retired custom `flutter_service_worker.js` is not part of the source tree.

---

## 📱 PWA & Caching Verification

Once the deployment completes:

1. **Cache Control Verification:**
   - `index.html`, `flutter_bootstrap.js`, and `version.json` are configured with `Cache-Control: no-cache, no-store, must-revalidate` so learners receive new app versions promptly. `main.dart.js` and its deferred parts (`main.dart.js_*.part.js`) are `no-cache` (revalidated on every load). The parts keep the same names in every build, so caching them would let a new `main.dart.js` load an old part after a release and fail with "Error Loading Component". A tab left open across a release still holds the old app in memory and needs a reload to open screens it hasn't loaded yet. The old custom Flutter service worker was removed because it did not implement app-shell caching; **do not assume offline launch is supported**.
2. **Connectivity & Synchronization:**
   - The app currently operates online-first with progressive outbox sync; persistent offline queueing is scheduled for Phase 1.
3. **PWA Installability:**
   - Verify the install prompt appears on mobile and desktop Chrome ("Install LearningApp").
4. **Supabase Connectivity:**
   - Test user login, target browsing, and lesson progress sync in production.

---

## 🔄 Rollback Procedure

If a production defect is discovered:

```bash
# Roll back to previous Firebase Hosting release via Firebase CLI
firebase hosting:clone learningapp-2ed8a:previous-release learningapp-2ed8a:live
```
Or open the [Firebase Console](https://console.firebase.google.com/) $\rightarrow$ **Hosting** $\rightarrow$ select the previous release and click **Rollback**.