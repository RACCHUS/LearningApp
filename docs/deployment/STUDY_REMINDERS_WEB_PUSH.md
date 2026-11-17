# Study reminders (web push): owner setup

Feature key: `learning.study_reminders` (default **OFF**). Until every step
below is done, Settings › Study reminders says reminders are planned or not
set up, and nothing is sent.

## How it works

1. A learner adds reminders (local time, weekdays) and turns them on for a
   browser. The browser registers a push subscription with
   `register_push_subscription`, which accepts only the real Web Push
   services (Google FCM, Mozilla, Apple, Windows) over https.
2. The server stores each reminder's IANA time zone and computes
   `next_fire_at`; browsers never write it.
3. Every 5 minutes a scheduler calls the `send-study-reminders` Edge
   Function. It calls `claim_due_study_reminders` (at most once per
   occurrence, skips anything more than 30 minutes late), sends one
   encrypted push per browser (again only to those push services), and
   reports each result with `record_push_delivery` (404/410 removes the
   subscription).
4. `web/push_sw.js` shows the notification and opens Learn when tapped.

With the gate OFF the claim returns no rows, so scheduled runs send nothing.

## One-time setup

1. **Deploy the migration** (guarded path only):
   ```bash
   dart run tool/guarded_supabase_deploy.dart
   ```
2. **Create a VAPID key pair** (keep the private key secret):
   ```bash
   npx web-push generate-vapid-keys
   ```
3. **Set Edge Function secrets**:
   ```bash
   supabase secrets set WEB_PUSH_VAPID_PUBLIC_KEY=<public> WEB_PUSH_VAPID_PRIVATE_KEY=<private> WEB_PUSH_SUBJECT=mailto:<contact address> REMINDER_CRON_SECRET=<long random string>
   ```
4. **Deploy the function**:
   ```bash
   supabase functions deploy send-study-reminders
   ```
   `supabase/config.toml` sets `verify_jwt = false` for this function: this
   project's publishable keys are not JWTs, and the function authenticates
   the scheduler itself with `REMINDER_CRON_SECRET`.
5. **Schedule it** every 5 minutes (Dashboard › Integrations › Cron): an HTTP
   POST to the function URL with the header
   `x-reminder-cron-secret: <REMINDER_CRON_SECRET>`. No Authorization header
   is needed.
6. **Give the web build the public key** with the build flag (web builds do
   not read `.env`):
   ```bash
   flutter build web --release --no-web-resources-cdn \
     --dart-define=SITE_FEATURE_RPC_READY=true \
     --dart-define=WEB_PUSH_VAPID_PUBLIC_KEY=<public>
   ```
   then deploy as in `DEPLOYMENT_GUIDE.md` (preview channel first). All three
   flags are needed: see that guide. It is a public key; never put the
   private key in the client.
7. **Check it is idle**: with the gate still OFF, the function logs should
   show runs with `claimed: 0`.
8. **Turn it on** in `/admin/features`: enabled + release-ready.
9. **Test one real delivery**: add a reminder 2–3 minutes ahead, turn it on
   for this browser, close the tab, and wait up to 5 minutes. Switching the
   gate OFF stops all sending at once.

Run these steps yourself, signed in on your own machine. Do not paste the
private key, service role key or deploy tokens into a chat.

## Turning it off

Switch the key OFF. Saving and browser registration are refused at once and
the dispatcher sends nothing. Learners can still delete reminders. Unschedule
the cron job to stop the empty runs entirely.

## Privacy

Push endpoints and keys are personal data: owner-read only, never logged by
the function (it logs counts), and deleted with the account
(`ON DELETE CASCADE`). Notification text is fixed and neutral; it contains no
lesson or account details.

## Browser support

Chrome, Edge and Firefox on desktop and Android. Safari on iPhone and iPad
only after the learner adds LearningApp to the Home Screen and opens it from
there.
