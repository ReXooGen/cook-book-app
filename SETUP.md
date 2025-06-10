# Cook Book App Setup

## Supabase Configuration

1. Copy `lib/config/supabase_config.example.dart` to `lib/config/supabase_config.dart`
2. Replace the placeholder values with your actual Supabase credentials:
   - `YOUR_SUPABASE_URL_HERE` with your Supabase project URL
   - `YOUR_SUPABASE_ANON_KEY_HERE` with your Supabase anon key

## Environment Variables (Optional)

You can also set environment variables:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

## Running the App

```bash
flutter pub get
flutter run
```