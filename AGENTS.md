# AGENTS.md

## What it is

Automated clock-in for Arktic Control Horario (Axpe backend) via GitHub Actions, with optional Telegram notifications.

## Structure

- `clock-in.sh` — main script: login, clock in, undo day.
- `.github/workflows/clock-in.yml` — manual run with optional date; cron commented out by design (each fork enables it).
- `.github/workflows/undo.yml` — mark a day as not worked (manual only).
- `README.md` — user-facing setup and usage.

## API integration

The API was **reverse-engineered by replaying browser requests with `curl`** (DevTools → copy as cURL). A Swagger UI exists at `https://controlhorario.arktic.es/ch/swagger-ui/index.html` but was never usable in practice (incomplete/blocked), so curl probing is the source of truth for endpoint behavior.

- **Login**: `GET https://controlhorario.arktic.es/ch/perform_login` with `Authorization: Basic base64(USER//:PASSWORD)`. Returns a JWT (`token`) and `fullName`.
- **Clock in**: `https://controlhorario.axpe.com/ch/v1/hora/` (POST to create, PUT to modify). Requires `Authorization: Bearer <token>` and `Origin`/`Referer` headers pointing to `controlhorario.arktic.es`.
- **Fields**: `entrada1`/`salida1` (first shift), `entrada2`/`salida2` (second shift) as `HH:mm:ss`. Empty slots = `"::"`. Up to 5 pairs.
- **No DELETE**: to withdraw a day, send a PUT with `notrabajado: true`.
- **GET returns today only**: without a `dia` param it returns the current day. Past days cannot be queried, so specific-date mode does a PUT without a prior check.
- **Day format**: `"YYYY-MM-DDT00:00:00.000Z"`.

## clock-in.sh modes

| Invocation | Action |
|------------|--------|
| no args | Clock in today (cron mode). Skips weekends. Idempotent (GET first). |
| `YYYY-MM-DD` | Clock in a specific date (manual). Direct PUT, no check. |
| `--undo [YYYY-MM-DD]` | Mark day as not worked (`notrabajado: true`). Empty = today. |

Shift times come from `IN1/OUT1/IN2/OUT2` env vars (defaults `08:00/14:00/15:00/17:00`).

## Secrets / GitHub variables

| Name | Type | Description |
|------|------|-------------|
| `ARKTIC_USER` | secret | Control Horario user |
| `ARKTIC_PASS` | secret | Password |
| `TELEGRAM_BOT_TOKEN` | secret | Bot token |
| `TELEGRAM_CHAT_ID` | variable | Chat ID (falls back to secret) |
| `CLOCK_IN_ENABLED` | variable | `false` pauses the cron workflow (holidays/vacation) |

## Testing

The script is plain bash + curl + jq. Verify changes without touching the real API by putting a stub `curl` first in `PATH` that emulates the endpoints (login JSON, GET body, POST/PUT capture + status code). Cover: already-clocked-in skip, create with defaults and custom times, specific date, `--undo`, login failure, write failure.

```bash
bash -n clock-in.sh   # syntax check
```
