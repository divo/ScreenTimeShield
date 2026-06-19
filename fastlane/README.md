# fastlane — App Store Connect listing automation

Replaces the earlier hand-written ASC API scripts. `deliver` (`upload_to_app_store`)
pushes localized metadata + screenshots to App Store Connect declaratively.

## Layout
- `metadata/<locale>/*.txt` — name, subtitle, description, keywords, release_notes,
  support_url, marketing_url, privacy_url. **These are the source of truth** — edit them
  directly for future releases.
- `screenshots/<locale>/` — symlinks to `Marketing/<folder>/` (the output of the
  `Marketing/render_captions.py` content pipeline; ASC locale codes map to those folders,
  e.g. `de-DE → ../../Marketing/de`, `es-ES`/`es-MX → ../../Marketing/es`).
- Locales: en-US, de-DE, es-ES, es-MX, fr-FR, it, pt-PT, ja, ko, zh-Hans, zh-Hant.

## Credentials (one-time)
App Store Connect API key (App Manager role) in the gitignored `.secrets/` at repo root:
```
.secrets/AuthKey_XXXXXXXXXX.p8
.secrets/asc_api.env   # ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_P8_PATH=.secrets/AuthKey_XXXXXXXXXX.p8
```
Generate/revoke at: ASC → Users and Access → Integrations → App Store Connect API.

## Usage
```bash
# install once (Ruby gem); on this machine: nix-shell -p fastlane
gem install fastlane            # or: bundle

fastlane ios check_listing      # precheck metadata (no upload)
fastlane ios upload_listing     # upload metadata + screenshots as DRAFTS (never submits)
```
`upload_listing` does **not** submit for review or change release settings — submit manually
in App Store Connect after reviewing.

## Screenshots refresh
Regenerate the localized caption images with `python3 Marketing/render_captions.py`
(content creation, separate from submission); the symlinks pick them up automatically.

## History
The original REST-API scripts that performed the first localization pass live in git history
(commit before this fastlane migration), if ever needed for reference.
