---
title: Hazel Privacy Policy
---

# Privacy Policy for Hazel

**Last updated:** July 13, 2026

Hazel is a personal-use application that connects to YNAB and Splitwise on
behalf of a single user (its developer) to add transactions and import bank
statement files. It is not distributed or offered as a service to the
public.

## Data we access

When you connect YNAB and/or Splitwise, Hazel requests OAuth access to:

- Read your YNAB budget, categories, and accounts, and create transactions
  in YNAB on your behalf.
- Read your Splitwise groups and friends, and create expenses in Splitwise
  on your behalf.

Hazel also processes bank/CSV statement files you choose to import, solely
to extract transaction data for import into YNAB.

## How data is handled and stored

- OAuth access tokens (and, where issued, refresh tokens) are stored only in
  the device's Keychain, protected by the operating system, and are never
  transmitted anywhere except directly to YNAB's or Splitwise's own APIs
  over HTTPS.
- Hazel has no backend server. There is no database, analytics service, or
  third party that receives your financial data — data obtained through the
  YNAB API or the Splitwise API is not knowingly passed to any third party.
- Imported statement files are read locally on-device to build transactions
  for YNAB; Hazel does not upload or retain copies of these files beyond
  what's needed to complete the import.

## Retention

Tokens remain in the device Keychain until you disconnect an account in
Hazel or delete the app, at which point they are removed. Hazel does not
retain transaction or budget data outside of what YNAB and Splitwise
themselves store.

## Deleting your data

- To remove Hazel's access, disconnect YNAB and/or Splitwise from within the
  app (this deletes the local tokens), and/or revoke Hazel's access from
  your YNAB or Splitwise account security settings.
- Deleting the app removes all locally stored tokens.

## Changes to this policy

If this policy changes in a way that affects how your data is used, you
will be asked to re-authorize before continuing to use the affected
integration. The "Last updated" date above reflects the most recent
revision.

## Contact

Questions about this policy, or data-deletion requests, can be filed as an
issue at https://github.com/fer0n/Hazel/issues.

## Disclaimers

Hazel is not affiliated, associated, or in any way officially connected
with YNAB or You Need A Budget, or with Splitwise, Inc., nor endorsed by
them.
