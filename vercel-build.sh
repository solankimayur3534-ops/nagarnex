#!/usr/bin/env bash
set -e

if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
fi

export PATH="$HOME/flutter/bin:$PATH"
flutter config --enable-web --no-analytics
flutter pub get
flutter build web --release --source-maps \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}" \
  --dart-define=ADMIN_PASSCODE="${ADMIN_PASSCODE:-}"
