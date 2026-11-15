// send-study-reminders: called on a schedule (every 5 minutes) to deliver
// due study reminders as Web Push notifications.
//
// Required secrets (supabase secrets set ...):
//   WEB_PUSH_VAPID_PUBLIC_KEY, WEB_PUSH_VAPID_PRIVATE_KEY, WEB_PUSH_SUBJECT
//   (mailto: or https: contact URL), REMINDER_CRON_SECRET.
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by the platform.
//
// The learning.study_reminders gate is enforced in SQL: with it OFF,
// claim_due_study_reminders returns no rows and nothing is sent.
import { createClient } from 'jsr:@supabase/supabase-js@2.49.4';
import webpush from 'npm:web-push@3.6.7';
import { dispatchDueReminders, DueReminder, secretMatches } from './dispatch.ts';

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }
  if (!secretMatches(req.headers.get('x-reminder-cron-secret'),
                     Deno.env.get('REMINDER_CRON_SECRET'))) {
    return new Response('Forbidden', { status: 403 });
  }

  const publicKey = Deno.env.get('WEB_PUSH_VAPID_PUBLIC_KEY');
  const privateKey = Deno.env.get('WEB_PUSH_VAPID_PRIVATE_KEY');
  const subject = Deno.env.get('WEB_PUSH_SUBJECT');
  if (!publicKey || !privateKey || !subject) {
    return Response.json({ error: 'web_push_not_configured' }, { status: 503 });
  }
  webpush.setVapidDetails(subject, publicKey, privateKey);

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );

  const summary = await dispatchDueReminders({
    async claimDue(limit) {
      const { data, error } = await supabase.rpc('claim_due_study_reminders', {
        p_limit: limit,
      });
      if (error) throw error;
      return (data ?? []) as DueReminder[];
    },
    async send(target, payload) {
      const result = await webpush.sendNotification(target, payload, {
        TTL: 60 * 60,
        urgency: 'normal',
      });
      return result.statusCode;
    },
    async record(subscriptionId, status) {
      const { error } = await supabase.rpc('record_push_delivery', {
        p_subscription_id: subscriptionId,
        p_http_status: status,
      });
      if (error) console.error('record_push_delivery failed', error.message);
    },
  });

  // Counts only: no endpoints or user ids in logs.
  console.log('study reminders', summary);
  return Response.json(summary);
});
