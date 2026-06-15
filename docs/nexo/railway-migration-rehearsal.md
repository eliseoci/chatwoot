# Railway staging migration rehearsal

Rehearsal date: June 15, 2026.

Target:

- Project: `93404cd1-0fc9-4a0f-9319-722685cc81f0`
- Environment: `27ca71ff-726f-4f76-8117-506bc5a62ca4` (`staging`)
- Production environment remained unchanged:
  `e1870bd4-1808-4b29-9d4f-a6e4b4caa9cb`

## Recovery point

A mode-`0600` PostgreSQL plain-SQL backup was created in the operator's private
backup directory:

```text
staging-pre-nexo-4.14.2-nexo.0-20260615.sql
sha256:15aebf0005aa14646932dd90dc602b75bb3cba0db098bca8c3f4d76f96fc20e5
```

The dump was restored into a temporary database and then removed. Source and
restored databases both contained:

- 135 schema migrations
- 91 public tables

The local libpq 18 client adds `SET transaction_timeout = 0`, which PostgreSQL
16 does not support. The verified portable dump removes only that session
directive before restore. Application DDL and data are unchanged.

## Migration

Railway deployment `c3e71a88-61b3-4377-a918-64bb2b33ddcf` ran:

```sh
/bin/sh -lc 'POSTGRES_STATEMENT_TIMEOUT=600s bundle exec rails db:chatwoot_prepare'
```

The direct command without `/bin/sh -lc` failed before Rails started because
Railway treated the environment assignment as an executable. No Pipeline
migration was present after those failed attempts.

The successful deployment increased `schema_migrations` from 135 to 147. All
12 expected Pipeline migration versions were present exactly once.

## Smoke checks

Deployment `19a3565b-e7f0-465b-803a-01fe9777cb63` verified:

- S3-compatible upload, download, and delete
- creation of a synthetic account, API inbox, contact, and conversation
- creation and linking of a Pipeline, stage, item, and conversation link
- Pipeline state did not change Chatwoot conversation status
- all synthetic database records rolled back

The final database contains zero accounts, contacts, conversations, messages,
pipelines, and pipeline items.

The first smoke attempt exposed unstable Valkey authentication. Reusing
`${{secret(32)}}` through nested references generated different passwords.
The fix was to generate one stable secret, write it once through stdin, and
write the same private Redis URL through stdin to Valkey, Web, and Worker.
Password hashes were verified equal without exposing values.

## Health evidence

- Web deployment: `bb55b246-a955-469a-bc5f-b9c9bc5ce56d`
- Worker deployment: `71ca0c33-09b2-454e-93f0-a1c1e9ac50b6`
- Valkey deployment: `6ac92df7-7bc0-4f0e-9da4-40dec0b904d1`
- Web URL: `https://nexo-chatwoot-web-staging.up.railway.app`
- Web `/health`: HTTP 200 with `{"status":"woot"}`
- Worker logs: Rails booted, Sidekiq connected to isolated Valkey, and
  `sidekiq-alive` registered successfully
- Bucket: `962dfe27-7de4-47e1-ad11-0e3b32a0c540`

Railway also requires a shell wrapper around Web's `$PORT` expression:

```sh
/bin/sh -lc 'bundle exec rails server -p "$PORT" -b 0.0.0.0'
```

## Image rollback and roll-forward

Rollback image:

```text
ghcr.io/railwayapp-templates/chatwoot:Community@sha256:cdab29d860f4966e32dcac0997099857813a7d7100a43db1d414c2c3199106e8
```

Rollback deployments:

- Web: `9f455763-96d3-49e0-b5ac-4f20055aea86`
- Worker: `ec8d5c6d-c81f-46a6-acc4-ce8c81523360`

Both succeeded and Web remained healthy. Web and Worker were then rolled
forward to:

```text
ghcr.io/eliseoci/chatwoot-pipelines:v4.14.2-nexo.0@sha256:8576d9d3a9535a59fc729ea6c9394ab7a3bd70de9a1f8d3eac947a3daaa86d30
```

## Database rollback policy

Pipeline migrations are additive except where automation columns are replaced
by normalized action tables. Use this decision rule:

1. Before customer writes: stop Web and Worker, restore the verified backup,
   then deploy the prior image digest.
2. After customer writes: do not run destructive down migrations. Keep the
   schema and deploy a forward fix.
3. If an additive migration fails partially, inspect `schema_migrations` and
   database objects before retrying `db:chatwoot_prepare`.
4. Never restore this staging backup into production.
