#!/usr/bin/env bash
# Runs the whole system LOCALLY: Firebase emulators (Auth, Firestore, Functions),
# a seeded demo center, and the web app. Nothing here touches a real project.
#
# Needs: Flutter, Node 20 (nvm), Java (for the Firestore emulator).
# Then open http://127.0.0.1:8765 and sign in (password demo-pass-123) as
#   director@demo.test   teacher@demo.test   student@demo.test
set -euo pipefail
cd "$(dirname "$0")/.."
source ~/.nvm/nvm.sh >/dev/null 2>&1 || true

(cd firebase/functions && npm ci --silent && npx tsc)
(cd firebase/rules-tests && npm ci --silent)

( cd firebase/rules-tests && ./node_modules/.bin/firebase emulators:start \
    --only auth,firestore,functions --project demo-quran-center --config ../firebase.json \
    > /tmp/quran-emulators.log 2>&1 ) &
EMU=$!
trap 'kill $EMU 2>/dev/null || true' EXIT
until curl -s http://127.0.0.1:9099 >/dev/null && curl -s http://127.0.0.1:5001 >/dev/null; do sleep 1; done

(cd firebase/rules-tests && node seed-demo.mjs)
flutter build web --dart-define=USE_EMULATORS=true --no-tree-shake-icons
echo "Serving on http://127.0.0.1:8765 (Ctrl-C to stop)"
cd build/web && python3 -m http.server 8765 --bind 127.0.0.1
