@echo off
rem Voikerchat Androidエミュレーター起動スクリプト(Windows用)
rem 使い方:
rem   tool\run_android.bat            … 接続済みデバイス/起動済みエミュレーターで起動
rem   tool\run_android.bat emu        … AVD "pixel" を起動してから flutter run
rem 事前: エミュレーターの「…」→ Microphone → Enable Host Microphone Access を ON

setlocal
if "%1"=="emu" (
  echo AVD pixel を起動します...
  call flutter emulators --launch pixel
  timeout /t 20 /nobreak >nul
)

echo == branch:
git branch --show-current

rem SUPABASE_PUBLISHABLE_KEY はクライアント配布前提の公開可能キー
flutter run ^
  --dart-define=SUPABASE_URL=https://rfwbwwhqclabhnbsrygw.supabase.co ^
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_jirMoWsnc0AtQc4c2tUJ6Q_3uc43qHT
endlocal
