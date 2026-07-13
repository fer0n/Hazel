# Hazel

Personal app replacing an Apple Shortcuts workflow: authenticate with YNAB
and Splitwise, add transactions to both, and import bank/CSV statement
files into YNAB. See [docs/project-goals.md](docs/project-goals.md).

## YNAB API Terms of Service — constraints on this codebase

Source: https://api.ynab.com/#terms — re-check this page if anything below
seems out of date before relying on it.

- **Token handling**: access tokens must never be logged, exposed to a
  third party, or sent anywhere except YNAB's own API. Store only in
  Keychain (see `Hazel/Auth/KeychainStore.swift`). Never request or store
  the user's actual YNAB/bank login credentials — only OAuth tokens.
- **Rate limit**: each access token is capped at **200 requests/hour**
  (rolling window); exceeding it returns HTTP 429. Any code that calls the
  YNAB API in bulk (e.g. file import creating many transactions) must
  batch/throttle and handle 429 with backoff rather than hammering retries.
- **No third-party sharing**: data pulled from the YNAB API must not be
  passed to any third party (analytics SDKs, crash reporters that capture
  request bodies, etc.) without updating the privacy policy and
  re-prompting consent first.
- **No undocumented endpoints**: only call documented YNAB API endpoints.
- **Required attribution**: the app must display, somewhere a user will
  see it (e.g. an About/Settings screen — not just the privacy policy),
  the disclaimer: "We are not affiliated, associated, or in any way
  officially connected with YNAB or any of its subsidiaries or
  affiliates." This is not yet implemented in the UI — add it when
  building Settings/About.
- **Naming/branding**: never name the app or a feature "YNAB ___"; "___
  for YNAB" is fine. Don't alter YNAB's logo/branding.
- **Privacy policy must stay accurate**: [docs/privacy-policy.md](docs/privacy-policy.md)
  describes exactly how tokens/data are stored and deleted today. If token
  storage, retention, or third-party usage changes, update that file (and
  bump "Last updated") before shipping the change.

## Splitwise

Splitwise's API terms haven't been reviewed yet — check
https://dev.splitwise.com/ and fold any constraints in here before relying
on production Splitwise API usage beyond auth.
