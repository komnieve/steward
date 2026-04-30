# Delivery — Slack

Two paths to get Steward messages into Slack. Pick the one that fits your constraints.

---

## Path 1 — Incoming webhook (recommended default)

**Pros:** Works with any agent runtime. No plugin install. One URL you paste into
config. Trivial to revoke. Stays inside your existing Slack workspace perimeter.

**Cons:** One-way (steward posts to Slack; can't receive replies via this channel).

### Setup

1. Open your Slack workspace's admin panel or your personal Slack settings (depending
   on your workspace's policy).
2. Go to **Apps → Manage → Custom Integrations → Incoming Webhooks** (or whatever
   equivalent your Slack admin has enabled; modern Slack uses the **Apps → Add apps →
   Incoming Webhooks** route).
3. Pick a channel or direct message where the steward should post.
4. Create the webhook and copy the URL — it looks like
   `https://hooks.slack.com/services/T.../B.../xyz...`
5. During Steward setup, paste this URL when prompted. Or add to `$STEWARD_HOME/.env`
   directly:

   ```
   SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
   ```

### How it's used

The steward posts via plain `curl`:

```bash
curl -s -X POST -H 'Content-Type: application/json' \
  --data "{\"text\":\"$STEWARD_MESSAGE\"}" \
  "$SLACK_WEBHOOK_URL"
```

No Slack SDK, no OAuth, no token refresh. One URL, one shell call.

### Revoking

Open the webhook in Slack's admin UI, click revoke. Done.

---

## Path 2 — Slack MCP plugin (Claude Code users only)

**Pros:** Full bidirectional access — steward can read Slack history, send threaded
replies, search conversations, attach files. Supported and maintained by Anthropic +
Slack.

**Cons:** Only works with Claude Code. Requires Slack admin approval to install the
official Slack MCP app in your workspace. OAuth flow.

### Setup

From inside a Claude Code session:

```
/plugin install slack
```

Or from the command line:

```
claude plugin install slack
```

Follow the OAuth prompts. Once installed, the steward can use Slack tools directly
from any Claude Code session referencing `$STEWARD_HOME/CLAUDE.md`.

### Authoritative docs

- https://code.claude.com/docs/en/slack
- https://docs.slack.dev/ai/slack-mcp-server/connect-to-claude/

---

## Compliance note

Slack Incoming Webhooks send content to Slack's servers. If your workspace is Slack
Enterprise with appropriate data-handling agreements, this stays inside the perimeter
your organization already approved. If you're on a free workspace or personal Slack,
your content is going through Slack's standard infrastructure — fine for most uses,
but worth knowing.

For regulated-data environments (ITAR, HIPAA, export-controlled, attorney-client
privileged, etc.): the steward's *content* should never contain controlled data
regardless of delivery channel. That's a content discipline rule, not a transport
one. Scope the steward around planning and reflection, not around the sensitive
technical work itself.

---

## Two-way Slack (future)

Replying to a steward message and having the steward see your reply is not yet wired.
When it ships, it will use the Slack MCP plugin path (since webhooks are one-way by
design).
