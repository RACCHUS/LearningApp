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

Run the Flutter release compiler:

```bash
flutter build web --release
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
*Hosting Config:* Defined in `firebase.json` with cache-control headers on `flutter_service_worker.js`, `index.html`, and `version.json`.

---

## 📱 PWA & Caching Verification

Once the deployment completes:

1. **Cache Control Verification:**
   - `index.html`, `flutter_bootstrap.js`, and `version.json` are configured with `Cache-Control: no-cache, no-store, must-revalidate` so learners receive new app versions promptly. The old custom Flutter service worker was removed because it did not implement app-shell caching; **do not assume offline launch is supported**.
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