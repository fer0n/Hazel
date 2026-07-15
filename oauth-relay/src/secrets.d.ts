// Secrets set via `wrangler secret put` (see README.md) aren't declared in
// wrangler.jsonc, so `wrangler types` can't discover them when generating
// worker-configuration.d.ts. Declared here instead, merging into the
// generated global `Env` interface.
interface Env {
  YNAB_CLIENT_SECRET: string;
  SPLITWISE_CLIENT_SECRET: string;
}
