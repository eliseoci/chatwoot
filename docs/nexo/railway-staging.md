# Railway staging topology

This runbook defines the provisioned and verified staging deployment for Nexo
Chatwoot Pipelines. It is an operational contract, not a Railway multi-service
configuration schema. Production mutation is explicitly forbidden.

## Confirmed target

| Resource | Value |
| --- | --- |
| Project | `93404cd1-0fc9-4a0f-9319-722685cc81f0` |
| Environment | `27ca71ff-726f-4f76-8117-506bc5a62ca4` (`staging`) |
| Image | `ghcr.io/eliseoci/chatwoot-pipelines:v4.14.2-nexo.0@sha256:8576d9d3a9535a59fc729ea6c9394ab7a3bd70de9a1f8d3eac947a3daaa86d30` |
| Web | `ce724e5a-2231-4732-a19f-bf6654a0d6bd` |
| Worker | `96da393f-2a16-4cf9-93ac-bb48d0926456` |
| PostgreSQL | `b89dbdad-1346-47b3-984a-2ab37d14f693` |
| Valkey | `9be11a8b-66e2-4867-8050-878ea3fdfa49` |
| Bucket | `962dfe27-7de4-47e1-ad11-0e3b32a0c540` |

Before any mutation, verify `railway whoami --json`, read the environment
configuration, and confirm both IDs. Never infer the target from a locally
linked Railway directory when a dashboard URL was supplied.

## Service topology

| Service | Source | Command | Health | Persistence |
| --- | --- | --- | --- | --- |
| Chatwoot Web | Immutable Nexo image | `/bin/sh -lc 'bundle exec rails server -p "$PORT" -b 0.0.0.0'` | Railway HTTP `/health` | None |
| Chatwoot Worker | Same immutable Nexo image | `bundle exec sidekiq -C config/sidekiq.yml` | Process status plus Sidekiq operational probe | None |
| Postgres | `pgvector/pgvector:pg16` | Image default | `pg_isready` | `/var/lib/postgresql/data` |
| Valkey | `valkey/valkey:8-alpine` | Image default | Authenticated `valkey-cli ping` | `/data` |
| Uploads | Railway S3-compatible bucket | N/A | Synthetic upload/read/delete | Bucket |

Web and Worker are separate Railway services. They use the same image digest
but different process commands. Neither application service gets a persistent
volume; attachments belong in the bucket.

The Worker deliberately has no fake HTTP health endpoint. Verify that its
deployment is running and execute:

```sh
bundle exec rails runner "require 'sidekiq/api'; exit(Sidekiq::ProcessSet.new.size.positive? ? 0 : 1)"
```

## Release migration

Run exactly once after the database is reachable and before starting or
replacing Web and Worker:

```sh
POSTGRES_STATEMENT_TIMEOUT=600s bundle exec rails db:chatwoot_prepare
```

Railway does not expand leading environment assignments in direct start
commands. The one-shot Railway command must therefore be:

```sh
/bin/sh -lc 'POSTGRES_STATEMENT_TIMEOUT=600s bundle exec rails db:chatwoot_prepare'
```

Do not put either command in every replica's startup command.

## Variable wiring

Apply the variables in
`config/nexo/railway_staging_contract.json` to both application services. Use
Railway service references and generated secrets; never copy credentials into
the repository or this runbook.

Required groups are:

- Rails runtime: `RAILS_ENV`, `NODE_ENV`, `RAILS_LOG_TO_STDOUT`,
  `SECRET_KEY_BASE`
- PostgreSQL: `DATABASE_URL=${{Postgres.DATABASE_URL}}`
- Valkey: one stable password generated once, written via stdin, and embedded
  into the private `REDIS_URL` for Web and Worker. Do not use
  `${{secret(...)}}` in multiple nested references because Railway evaluates
  each context independently.
- Active Storage: `ACTIVE_STORAGE_SERVICE=s3_compatible` and the Railway
  bucket's endpoint, region, bucket name, access key, and secret key
- Staging safety: `ENABLE_ACCOUNT_SIGNUP=false`

Do not configure production domains, SMTP, provider webhooks, WhatsApp,
Instagram, or customer credentials in the initial staging deployment.

## Provisioning order

1. Verify the authenticated Railway identity and the confirmed project and
   environment IDs.
2. Read the existing environment configuration and inventory services,
   volumes, domains, and variables.
3. Preserve the existing Postgres 16 staging instance and its volume.
4. Create staging-only `nexo-valkey` pinned to `valkey/valkey:8-alpine` with
   `/data`. Do not mutate the shared legacy Valkey service.
5. Create the Railway bucket in `iad`.
6. Create staging-only Chatwoot Web from the immutable Nexo image without an
   application volume and configure `/health`.
7. Create staging-only Chatwoot Worker from the same immutable image without a
   domain or volume.
8. Configure shared variable references and generated secrets with deploys
   skipped until the complete configuration is ready.
9. Run the release migration once.
10. Deploy Worker and Web, then verify all health checks and smoke tests.
11. Record resulting service, bucket, deployment, and domain IDs in the Linear
    issue.

## Safety and rollback

- Use fresh or synthetic staging data for the first rehearsal.
- Never reference production service IDs or production secrets.
- Keep customer channels, outbound email, and production webhooks disabled.
- Do not start the Worker before the migration succeeds.
- Keep the previous Chatwoot image digest and a database backup reference
  before replacement.
- Roll back by restoring the prior image digest and database backup as a
  coordinated operation. NEXO-159 owns the full migration and rollback
  rehearsal.

## References

- [Railway Config as Code](https://docs.railway.com/config-as-code/reference)
- [Railway health checks](https://docs.railway.com/deployments/healthchecks)
- [Railway private registries](https://docs.railway.com/builds/private-registries)
- [Railway variables](https://docs.railway.com/variables/reference)
- [Railway templates](https://docs.railway.com/templates/create)
- [Railway Docker Compose guide](https://docs.railway.com/guides/docker-compose)
