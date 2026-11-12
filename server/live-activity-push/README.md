# Live Activity push server

Starts the Hasta Live Activity before an event with an APNs push-to-start. The app posts each device's upcoming countdowns to `/v1/schedule`. A cron trigger runs every minute and sends the push once `lead hours` before the event.

Not deployed and not tested against APNs.

Setup:

1. `wrangler kv namespace create SCHEDULE`, then put the id in `wrangler.toml`.
2. `wrangler secret put APNS_KEY_P8` (full `.p8` contents), `APNS_KEY_ID`, `APNS_TEAM_ID`. The key needs APNs enabled.
3. `wrangler deploy`.

Known limits:

- Anyone with a device token can post a schedule for it. The token is only known to the device and Apple.
- No end push. The activity shows "Now" once stale and iOS removes it later.
- Repeating events are scheduled for their next occurrence only. The app refreshes the schedule whenever it opens.
