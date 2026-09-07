#!/usr/bin/env bash
#
# B3 — is each shipped Google key application-restricted?
#
#   ./tools/security/check_routes_key_restrictions.sh
#
# Reads the keys from .env (git-ignored) and fires six live probes at the Routes
# API. It prints HTTP status codes ONLY: no key, no route, no response body is
# ever echoed.
#
# Expected once the keys are correctly restricted in the GCP console:
#   correct identity ....... 200
#   no identity header ..... 403
#   wrong identity ......... 403
#
# On 2026-09-05 the iOS key returned 200 for all three. On 2026-09-07 BOTH keys
# returned 200 for all three — see docs/release-blockers.md B3. The client sends
# the right headers (lib/services/routes_client_identity.dart); they are only
# load-bearing once the server enforces them.
#
# NOTE: each run makes real, billable Routes calls against the project's GCP
# account. Six of them is negligible, but do not loop this.
set -uo pipefail
cd "$(dirname "$0")/../.."

ENVF="${ENVF:-.env}"
[[ -f "$ENVF" ]] || { echo "no $ENVF — nothing to check"; exit 1; }

readkey () { grep -E "^$1=" "$ENVF" | cut -d= -f2- | tr -d '"'"'"' \r'; }
IOSKEY=$(readkey GOOGLE_MAPS_IOS_ROUTES_KEY)
ANDKEY=$(readkey GOOGLE_MAPS_ANDROID_ROUTES_KEY)

APPID="au.edu.mq.astronomy.aon2026"
# The upload key's SHA-1. A Play-installed build sends the PLAY APP SIGNING
# cert instead — both must be registered on the key. See B3.
CERT="${AON_CERT_SHA1:-A4:26:BD:18:EF:21:BC:FD:05:FA:95:A2:D5:EF:C3:03:A5:CD:92:6D}"
URL="https://routes.googleapis.com/directions/v2:computeRoutes"
# West 6 parking -> Macquarie Theatre, the same pair used in the 2026-09-05 check.
BODY='{"origin":{"location":{"latLng":{"latitude":-33.773681,"longitude":151.1075241}}},"destination":{"location":{"latLng":{"latitude":-33.7746334,"longitude":151.1122714}}},"travelMode":"WALK"}'

probe () {
  local label="$1" key="$2"; shift 2
  [[ -n "$key" ]] || { printf '  %-44s (key not set)\n' "$label"; return; }
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$URL" \
    -H "Content-Type: application/json" \
    -H "X-Goog-Api-Key: ${key}" \
    -H "X-Goog-FieldMask: routes.distanceMeters,routes.duration" \
    "$@" -d "$BODY" 2>/dev/null)
  printf '  %-44s HTTP %s\n' "$label" "$code"
}

echo "--- iOS Routes key ---"
probe "correct bundle id      -> want 200" "$IOSKEY" -H "X-Ios-Bundle-Identifier: $APPID"
probe "no identity header     -> want 403" "$IOSKEY"
probe "wrong bundle id        -> want 403" "$IOSKEY" -H "X-Ios-Bundle-Identifier: com.example.notours"

echo "--- Android Routes key ---"
probe "correct package+cert   -> want 200" "$ANDKEY" -H "X-Android-Package: $APPID" -H "X-Android-Cert: $CERT"
probe "no identity headers    -> want 403" "$ANDKEY"
probe "wrong package          -> want 403" "$ANDKEY" -H "X-Android-Package: com.example.notours" -H "X-Android-Cert: $CERT"

unset IOSKEY ANDKEY
