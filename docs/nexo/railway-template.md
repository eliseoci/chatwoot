# Deploy and Host Nexo Chatwoot Pipelines with Railway

Deploy the Nexo Chatwoot Community Edition fork with first-class Pipelines:
configurable workflow stages, Kanban and list views, linked conversations,
activities, ownership, attention signals, automations, permissions, and
reporting foundations.

[Deploy Nexo Chatwoot Pipelines](https://railway.com/deploy/nexo-chatwoot-pipelines)

## About Hosting Nexo Chatwoot Pipelines

Nexo Chatwoot Pipelines is a multi-service Rails deployment. Railway runs Web
and Sidekiq Worker as separate stateless services, provisions PostgreSQL and
Valkey with persistent volumes, creates S3-compatible object storage, generates
installation-specific secrets, runs the database migration as a Web
pre-deploy release hook, and exposes only the Web service publicly.

## Why Deploy Nexo Chatwoot Pipelines on Railway?

Railway provisions and connects the complete stack from one template while
preserving the service boundaries required for safe scaling, backups, upgrades,
and rollback. Web and Worker use one immutable image, stateful services remain
independent, internal traffic uses private networking, and migrations block a
bad Web release before it replaces the healthy deployment.

## Common Use Cases

- Manage sales leads and opportunities beside their Chatwoot conversations.
- Operate support escalation, onboarding, recruitment, collections, or real
  estate workflows.
- Give agencies a reusable, isolated deployment for each client.
- Self-host the Nexo Chatwoot Community Edition fork with upgrade controls.
- Evaluate Pipelines in a non-production environment before customer rollout.

## Dependencies for Nexo Chatwoot Pipelines Hosting

- Nexo Chatwoot Community Edition image for Web and Worker
- PostgreSQL 16 with `pgvector`
- Valkey 8
- Railway S3-compatible object storage
- Railway private networking and generated service variables

### Deployment Dependencies

- [Nexo Chatwoot source](https://github.com/eliseoci/chatwoot)
- [Chatwoot upstream](https://github.com/chatwoot/chatwoot)
- [Railway pre-deploy commands](https://docs.railway.com/deployments/pre-deploy-command)
- [Railway variables](https://docs.railway.com/variables)
- [Railway storage buckets](https://docs.railway.com/storage-buckets)

## What the template creates

| Resource | Configuration |
| --- | --- |
| `nexo-chatwoot-web` | Immutable Nexo Chatwoot image, `/health` check, public Railway domain |
| `nexo-chatwoot-worker` | Same immutable image running Sidekiq |
| `Postgres` | `pgvector/pgvector:pg16` with a persistent volume |
| `nexo-valkey` | `valkey/valkey:8-alpine` with authentication and a persistent volume |
| `nexo-chatwoot-uploads` | Railway S3-compatible object-storage bucket |

Web and Worker are stateless and do not share a filesystem. PostgreSQL,
Valkey, and uploads remain independent persistent resources.

The template is pinned to:

```text
ghcr.io/eliseoci/chatwoot-pipelines:v4.14.2-nexo.0@sha256:8576d9d3a9535a59fc729ea6c9394ab7a3bd70de9a1f8d3eac947a3daaa86d30
```

Do not replace the digest with `latest`, `Community`, or a branch tag.

## Deployment behavior

Railway generates independent PostgreSQL, Valkey, and Rails secrets for each
installation. Application services use private service references rather than
public database or cache endpoints.

Before each Web release starts, Railway runs this pre-deploy command once:

```sh
/bin/sh -lc 'POSTGRES_STATEMENT_TIMEOUT=600s bundle exec rails db:chatwoot_prepare'
```

This is the release migration hook. It is not part of the Web or Worker start
command and is not executed by every replica. If it fails, Railway does not
replace the running Web deployment.

The Worker references the Web service URL, so Railway waits for the migrated,
healthy Web release before starting Sidekiq.

### Railway CLI caveat

Use the Railway dashboard one-click deploy URL for the full template contract:

```text
https://railway.com/deploy/nexo-chatwoot-pipelines
```

As of Railway CLI `5.13.0`, `railway deploy --template` is not a reliable
smoke path for this template. The CLI fetches the published serialized config,
hydrates service variables, and then reserializes only a reduced service model
before calling `templateDeployV2`. That drops V2-only fields required here,
including the Railway Bucket, Web `preDeployCommand`, restart policy, and
other deployment metadata.

For automation, either deploy from the dashboard or call `templateDeployV2`
with the published `serializedConfig` preserved. When using the API directly,
hydrate each service variable's `defaultValue` into `value` before deployment
without removing `buckets`, `volumeMounts`, or Web `preDeployCommand`.

## First activation

1. Deploy the template.
2. Wait until PostgreSQL, Valkey, Web, and Worker report `Success`.
3. Open the generated Web domain and confirm `/health` returns:

   ```json
   {"status":"woot"}
   ```

4. Create the first Chatwoot account through the Rails console or temporarily
   enable account signup for controlled onboarding.
5. Keep SMTP, WhatsApp, Instagram, email inboxes, webhooks, and other customer
   delivery credentials unset until the installation has passed its smoke
   checks.
6. Configure the required channels only after ownership, routing, permissions,
   and human handoff behavior are reviewed.

`ENABLE_ACCOUNT_SIGNUP` defaults to `false`. The template does not include
customer channel credentials or outbound email configuration.

## Required smoke checks

Before connecting customers:

- Web `/health` returns HTTP 200.
- Worker logs show Rails boot and a registered `sidekiq-alive` process.
- The database contains all expected schema migrations.
- Valkey responds to an authenticated `PING`.
- A synthetic object can be uploaded, read, and deleted from the bucket.
- A synthetic contact, conversation, Pipeline item, stage transition, and
  message can be created without sending customer traffic.
- Synthetic data is deleted or rolled back.

## Published template verification

Canonical template:

- Template ID: `b506e365-4d5f-42d4-97ce-e66dba3404ff`
- Template code: `nexo-chatwoot-pipelines`
- Deploy URL: <https://railway.com/deploy/nexo-chatwoot-pipelines>

Template source project:

- Project ID: `f501f9bf-f945-456c-84eb-bf3e183622a1`
- Environment ID: `1f31560b-937a-4dac-8cab-2b7b52454859`
- Health: `https://nexo-chatwoot-web-template.up.railway.app/health`

Smoke deployment used the full published serialized config through
`templateDeployV2` and verified:

- Web, Worker, PostgreSQL, and Valkey deployed successfully.
- Web `/health` returned `{"status":"woot"}`.
- Web deployment manifest preserved the pre-deploy migration command.
- Railway Bucket `nexo-chatwoot-uploads` was created.
- Bucket upload/read/delete succeeded with a synthetic object.
- Worker booted Rails, registered `sidekiq-alive`, connected to Valkey, and
  performed scheduled jobs.

Smoke project evidence is recorded in
`config/nexo/railway_template_contract.json` and validated by
`script/nexo/validate_railway_template_contract.rb`.

## Backups

Before every upgrade:

1. Create a PostgreSQL backup.
2. Restore that backup into a temporary database and verify schema and row
   counts.
3. Record the current application image tag and digest.
4. Record the current Web and Worker deployment IDs.
5. Confirm the bucket retention and recovery requirements for attachments.

Database backups and object storage are separate concerns. A PostgreSQL backup
does not include uploaded files.

## Upgrade

1. Read the Nexo release notes and upstream Chatwoot migration notes.
2. Rehearse the upgrade in an isolated Railway environment.
3. Replace both Web and Worker with the same new immutable image digest.
4. Deploy Web first. Its pre-deploy hook runs the database migration once.
5. Confirm Web health, then confirm Worker health and queue activity.
6. Run conversation, Pipeline, Valkey, and storage smoke checks.
7. Promote only after the backup restore and rollback path are verified.

Never mix Web and Worker versions.

## Rollback

Application rollback and database rollback are separate decisions:

- If the new image is compatible with the migrated schema, restore the prior
  image digest for both Web and Worker.
- If a migration is destructive or incompatible, restore the verified
  PostgreSQL backup and the prior image digest as one coordinated operation.
- If a migration cannot safely roll back, use a forward fix rather than
  forcing a database downgrade.

Do not treat a successful Railway deployment rollback as proof that the
database schema was rolled back.

## Security and operations

- PostgreSQL and Valkey use private networking and persistent volumes.
- Web is the only service with a public HTTP domain.
- Secrets are generated by Railway and are not stored in this repository.
- Web and Worker use the same generated `SECRET_KEY_BASE`.
- The Valkey URL uses the same generated password as the Valkey server.
- Customer delivery remains disabled until credentials are explicitly added.
- Production changes require a verified backup, staging rehearsal, and
  explicit human approval.

## Source and license

Nexo Chatwoot Pipelines is based on Chatwoot Community Edition. Nexo modules
live outside `enterprise/` and the distribution image excludes Chatwoot
Enterprise implementation code.

- [Nexo Chatwoot source](https://github.com/eliseoci/chatwoot)
- [Chatwoot upstream](https://github.com/chatwoot/chatwoot)
- License boundary: see `LICENSE` and `docs/nexo/distribution.md`
