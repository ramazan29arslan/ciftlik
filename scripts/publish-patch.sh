#!/bin/bash
# Yamayi yayinlar ve surum notlarini commit mesajlarindan uretip Firestore'a yazar.
#
# Kullanim:  ./scripts/publish-patch.sh [release-version]
# Surum verilmezse pubspec.yaml'daki kullanilir.
#
# NOT: Imzalama Claude'un kabugundan calismiyor; bu betigi kendi
# terminalinizden calistirin.

set -euo pipefail
cd "$(dirname "$0")/.."

export PATH="$HOME/.shorebird/bin:$PATH"

PLATFORM="ios"
RELEASE_VERSION="${1:-$(grep '^version:' pubspec.yaml | awk '{print $2}')}"

if [ -n "$(git status --porcelain)" ]; then
  echo "UYARI: calisma dizininde commit edilmemis degisiklik var." >&2
  echo "       Notlar commit mesajlarindan uretildigi icin once commit edin." >&2
  exit 1
fi

echo "==> Yama olusturuluyor (release $RELEASE_VERSION)"
LOG="$(mktemp -t shorebird-patch)"
trap 'rm -f "$LOG"' EXIT

# `yes` yerine tek seferlik girdi: `yes` sonsuza kadar yazdigi icin shorebird
# okumayi birakinca SIGPIPE ile oluyor, pipefail bunu hata sayip `set -e`
# betigi sessizce sonlandiriyordu.
set +e
printf 'y\ny\ny\n' | shorebird patch "$PLATFORM" --release-version="$RELEASE_VERSION" \
  -- --dart-define-from-file=env.json 2>&1 | tee "$LOG"
PATCH_STATUS=${PIPESTATUS[1]}
set -e
if [ "$PATCH_STATUS" -ne 0 ]; then
  echo "HATA: shorebird patch basarisiz oldu (cikis $PATCH_STATUS)." >&2
  exit 1
fi

PATCH_NUMBER="$(grep -oE 'Published Patch [0-9]+' "$LOG" | tail -1 | grep -oE '[0-9]+' || true)"
if [ -z "$PATCH_NUMBER" ]; then
  echo "HATA: yama numarasi okunamadi — yama yayinlanmamis olabilir." >&2
  exit 1
fi

# Notlar: son yamadan bu yana yazilan commit basliklari.
LAST_TAG="$(git tag --list 'patch-*' --sort=-creatordate | head -1)"
if [ -n "$LAST_TAG" ]; then
  RANGE="$LAST_TAG..HEAD"
  echo "==> Notlar toplaniyor ($RANGE)"
  NOTES="$(git log "$RANGE" --no-merges --pretty=format:'%s' | grep -v '\[dahili\]$' || true)"
else
  echo "==> Ilk yama: son 10 commit kullaniliyor"
  NOTES="$(git log -n 10 --no-merges --pretty=format:'%s' | grep -v '\[dahili\]$' || true)"
fi

printf '%s\n' "$NOTES" | node scripts/update-notes.mjs "$PATCH_NUMBER" "$PLATFORM"

git tag -f "patch-$PATCH_NUMBER"
echo
echo "==> Bitti. Yama #$PATCH_NUMBER yayinda, notlar Firestore'da."
echo "    Etiketi gondermek icin: git push --tags"
