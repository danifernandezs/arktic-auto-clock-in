#!/bin/bash
set -euo pipefail

LOGIN_URL="https://controlhorario.arktic.es/ch/perform_login"
HORA_URL="https://controlhorario.axpe.com/ch/v1/hora/"

: "${ARKTIC_USER:?Missing ARKTIC_USER}"
: "${ARKTIC_PASS:?Missing ARKTIC_PASS}"

# Work schedule (HH:MM), first and second shift
IN1="${IN1:-08:00}"
OUT1="${OUT1:-14:00}"
IN2="${IN2:-15:00}"
OUT2="${OUT2:-17:00}"

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed"
    exit 1
fi

notify() {
    if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
        return
    fi
    curl -s -o /dev/null "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=$1" \
        -d "parse_mode=Markdown" || true
}

payload() {
    printf '{"comentarios":null,"dia":"%s","entrada1":"%s:00","entrada2":"%s:00","entrada3":"::","entrada4":"::","entrada5":"::","salida1":"%s:00","salida2":"%s:00","salida3":"::","salida4":"::","salida5":"::","notrabajado":%s}' \
        "$1" "$IN1" "$IN2" "$OUT1" "$OUT2" "$2"
}

# Weekend check only in automatic mode (no arguments)
if [ -z "${1:-}" ]; then
    DOW=$(date +%u)
    if [ "$DOW" -ge 6 ]; then
        echo "Weekend, skipping clock-in."
        exit 0
    fi
fi

B64=$(echo -n "${ARKTIC_USER}//:${ARKTIC_PASS}" | base64)
echo "Logging in..."
LOGIN=$(curl -s -w '\n%{http_code}' "$LOGIN_URL" -H "Authorization: Basic $B64")
HTTP_CODE="${LOGIN##*$'\n'}"
LOGIN_BODY="${LOGIN%$'\n'*}"

if [ "$HTTP_CODE" != "200" ]; then
    echo "ERROR login HTTP $HTTP_CODE"
    echo "  $LOGIN_BODY"
    exit 1
fi

TOKEN=$(echo "$LOGIN_BODY" | jq -r '.token')
FULL_NAME=$(echo "$LOGIN_BODY" | jq -r '.fullName')
echo "Login OK: $FULL_NAME"

if [ "${1:-}" = "--undo" ]; then
    UNDO_DATE="${2:-}"
    if [ -z "$UNDO_DATE" ]; then
        TARGET_ISO=$(date -u +"%Y-%m-%dT00:00:00.000Z")
        UNDO_DATE=$(date -u +"%Y-%m-%d")
    else
        TARGET_ISO="${UNDO_DATE}T00:00:00.000Z"
    fi
    echo "Marking $UNDO_DATE as not worked..."
    UNDO_FULL=$(curl -s -w '\n%{http_code}' -X PUT "$HORA_URL" \
        -H "Authorization: Bearer $TOKEN" \
        -H 'Content-Type: application/json' \
        -H 'Origin: https://controlhorario.arktic.es' \
        -H 'Referer: https://controlhorario.arktic.es/' \
        --data-raw "$(payload "$TARGET_ISO" true)")
    HTTP_CODE="${UNDO_FULL##*$'\n'}"
    if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
        echo "OK $UNDO_DATE marked as not worked"
        notify "🚫 *Day marked as not worked* ($FULL_NAME): $UNDO_DATE"
    else
        echo "ERROR HTTP $HTTP_CODE marking $UNDO_DATE as not worked"
        echo "  ${UNDO_FULL%$'\n'*}"
        notify "❌ *ERROR marking $UNDO_DATE as not worked* (HTTP $HTTP_CODE)"
        exit 1
    fi
    exit 0
fi

# Clock in a specific date (manual)
if [ -n "${1:-}" ] && [ "$1" != "--undo" ]; then
    TARGET_DATE="$1"
    TARGET_ISO="${TARGET_DATE}T00:00:00.000Z"
    echo "Clocking in $TARGET_DATE..."
    PUT_FULL=$(curl -s -w '\n%{http_code}' -X PUT "$HORA_URL" \
        -H "Authorization: Bearer $TOKEN" \
        -H 'Content-Type: application/json' \
        -H 'Origin: https://controlhorario.arktic.es' \
        -H 'Referer: https://controlhorario.arktic.es/' \
        --data-raw "$(payload "$TARGET_ISO" false)")
    HTTP_CODE="${PUT_FULL##*$'\n'}"
    if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
        echo "OK $TARGET_DATE clocked in ($IN1-$OUT1 / $IN2-$OUT2)"
        notify "✅ *Clock-in created* ($FULL_NAME): $TARGET_DATE - $IN1-$OUT1 / $IN2-$OUT2"
    else
        echo "ERROR HTTP $HTTP_CODE clocking in $TARGET_DATE"
        echo "  ${PUT_FULL%$'\n'*}"
        notify "❌ *ERROR clocking in $TARGET_DATE* (HTTP $HTTP_CODE)"
        exit 1
    fi
    exit 0
fi

echo "Checking today's clock-in..."
GET_FULL=$(curl -s -w '\n%{http_code}' "$HORA_URL" \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -H 'Origin: https://controlhorario.arktic.es' \
    -H 'Referer: https://controlhorario.arktic.es/')
HTTP_CODE="${GET_FULL##*$'\n'}"
GET_BODY="${GET_FULL%$'\n'*}"

if [ "$HTTP_CODE" = "200" ] && [ -n "$GET_BODY" ]; then
    EXISTING=$(echo "$GET_BODY" | jq -r '.entrada1 // empty')
    if [ -n "$EXISTING" ] && [ "$EXISTING" != "null" ]; then
        echo "Already clocked in today (entrada1=$EXISTING), skipping."
        notify "⚠️ *Clock-in skipped*: already clocked in today (entrada=$EXISTING)"
        exit 0
    fi
fi

echo "Creating clock-in..."
TODAY_ISO=$(date -u +"%Y-%m-%dT00:00:00.000Z")
POST_FULL=$(curl -s -w '\n%{http_code}' -X POST "$HORA_URL" \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/plain, */*' \
    -H 'Origin: https://controlhorario.arktic.es' \
    -H 'Referer: https://controlhorario.arktic.es/' \
    --data-raw "$(payload "$TODAY_ISO" false)")
HTTP_CODE="${POST_FULL##*$'\n'}"

if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "OK Clock-in created ($IN1-$OUT1 / $IN2-$OUT2)"
    notify "✅ *Clock-in created* ($FULL_NAME): $IN1-$OUT1 / $IN2-$OUT2"
else
    echo "ERROR HTTP $HTTP_CODE creating clock-in"
    echo "  ${POST_FULL%$'\n'*}"
    notify "❌ *ERROR clocking in today* (HTTP $HTTP_CODE)"
    exit 1
fi
