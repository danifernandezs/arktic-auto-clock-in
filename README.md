# arktic-auto-clock-in

[![License: CC BY-SA 4.0](https://img.shields.io/badge/License-CC_BY--SA_4.0-blue?style=flat-square)](http://creativecommons.org/licenses/by-sa/4.0/)

Automated clock-in for Arktic Control Horario (Axpe backend) via GitHub Actions. Runs on a cron, skips weekends, never duplicates a day, and notifies you on Telegram.

## How it works

- Logs in to `controlhorario.arktic.es` with your user/password (Basic auth) and gets a JWT.
- Checks if today is already clocked in; if not, writes a split shift (`entrada1/salida1` + `entrada2/salida2`).
- Weekends are skipped in automatic mode.
- Optionally sends a Telegram message on success, skip or error.

Default schedule: **08:00–14:00 / 15:00–17:00** (configurable via env vars).

## Setup (fork & configure)

1. **Fork this repo.** Scheduled workflows are disabled on forks until you enable them — uncommenting the cron (step 3) counts as the enabling commit.
2. **Add your secrets** (Settings → Secrets and variables → Actions):

   | Secret | Required | Description |
   |--------|----------|-------------|
   | `ARKTIC_USER` | Yes | Your Control Horario user |
   | `ARKTIC_PASS` | Yes | Your password |
   | `TELEGRAM_BOT_TOKEN` | No | Bot token from `@BotFather` |
   | `TELEGRAM_CHAT_ID` | No | Chat/channel ID (add as variable, or as secret) |

3. **Enable the cron**: edit `.github/workflows/clock-in.yml` in your fork and uncomment the schedule lines:

   ```yaml
   on:
     schedule:
       - cron: '0 7 * * 1-5'   # weekdays 07:00 UTC = 09:00 CEST
   ```

   GitHub cron is always UTC — adjust to your timezone.

4. (Optional) **Kill switch**: create a repository variable `CLOCK_IN_ENABLED` with value `false` to pause the cron (holidays, vacation) without touching code. Any other value or absent = runs normally.

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ARKTIC_USER` | — | Control Horario user (required) |
| `ARKTIC_PASS` | — | Password (required) |
| `IN1` / `OUT1` | `08:00` / `14:00` | First shift in/out (`HH:MM`) |
| `IN2` / `OUT2` | `15:00` / `17:00` | Second shift in/out (`HH:MM`) |
| `TELEGRAM_BOT_TOKEN` | — | Enables Telegram notifications |
| `TELEGRAM_CHAT_ID` | — | Destination chat ID |

## Workflows

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| **Daily clock-in** | Cron (commented out) or manual | Clocks in today, or a given date via the `date` input (`YYYY-MM-DD`, empty = today) |
| **Mark day as not worked** | Manual only | Marks a day as not worked (`date` input, empty = today). Use it to undo a wrong day |

Both are visible in the **Actions** tab → select workflow → **Run workflow**.

## Script usage (local)

Requires `curl` and `jq`.

```bash
export ARKTIC_USER="your_user"
export ARKTIC_PASS="your_password"

./clock-in.sh                    # clock in today (skips weekends, idempotent)
./clock-in.sh 2026-08-03         # clock in a specific date
./clock-in.sh --undo 2026-08-03  # mark a date as not worked (empty = today)
```

## Disclaimer

Use responsibly and in accordance with your employer's time-tracking policy.

## License

This work is licensed under the [Creative Commons Attribution-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-sa/4.0/).

Please read the [LICENSE](LICENSE.txt) file for more details.
