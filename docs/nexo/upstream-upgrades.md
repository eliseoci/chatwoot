# Upstream Chatwoot Upgrade Procedure

Nexo releases follow stable Chatwoot tags. Upstream upgrades are deliberate
compatibility exercises, not automatic merges from `develop`.

## Before starting

1. Confirm the target version is the latest stable release on the official
   Chatwoot GitHub releases page.
2. Read upstream release notes and migration notes.
3. Record the current Nexo image tag, digest, source commit, `VERSION_CW`, and
   `VERSION_NEXO`.
4. Confirm the current database backup and restore procedure.
5. Create a temporary upgrade branch from the current Nexo release line.

## Fetch and integrate

```bash
git fetch upstream --tags
git tag --verify v<target> || true
git checkout -b upgrade/chatwoot-v<target>
git merge v<target>^{}
```

If the upstream tag is unsigned, verification means comparing the fetched tag
and commit with the official release page. Do not invent signature assurance.

Do not force-push a released Nexo tag. If integration requires corrections,
publish a new Nexo release number.

## Mandatory conflict audit

Inspect these shared hotspots even if Git reports no textual conflict:

| Hotspot | Why |
| --- | --- |
| `config/routes.rb` | Account-scoped Pipeline APIs are registered here. |
| `app/models/account.rb` | Owns account-scoped associations and deletion behavior. |
| `app/models/contact.rb` | Owns primary-contact relationships. |
| `app/models/conversation.rb` | Owns linked-conversation relationships only. |
| Dashboard route registration | Registers the first-class Pipelines workspace. |
| Dashboard navigation | Exposes Pipelines without replacing Conversations. |
| Conversation sidebar | Hosts the thin Pipeline context integration. |
| Event configuration | Supports real-time updates and automation triggers. |
| Webhook registration | Publishes supported Pipeline lifecycle events. |
| Locale registration | Ensures all Pipeline copy remains translatable. |
| `Gemfile`, lockfiles, Node config | May affect tests, jobs, and image compilation. |
| Docker files and entrypoints | Must keep Web/Worker process compatibility. |
| Database schema and migrations | Must remain forward-compatible. |

Also search the upstream Enterprise overlay for corresponding extension files.
The purpose is compatibility awareness only: do not copy, modify, or depend on
Enterprise implementation code.

## Required validation

Run validation without a local production build:

```bash
script/nexo/validate_distribution_guardrails.sh
bash -n script/nexo/validate_distribution_guardrails.sh
```

Then run the focused Pipelines backend and frontend checks introduced by each
implementation slice. CI owns production container builds.

The Community Edition validation must remove `enterprise/` before the backend
test and image-build jobs, matching upstream CE behavior.

## Staging rehearsal

Before a release can reach production:

1. Create a recoverable staging database backup.
2. Run the release migration command exactly once.
3. Start Web and Worker from the same pinned image digest.
4. Verify PostgreSQL, Valkey, object storage, Web, Worker, and queue health.
5. Exercise core Chatwoot conversation behavior without customer delivery.
6. Exercise automatic Pipeline intake, linking, transitions, activities,
   attention, automation, authorization, reporting, and localization.
7. Rehearse application rollback.
8. Document whether each database migration supports rollback or requires a
   forward fix.

## Release record

Each upgrade record must contain:

- previous and target Chatwoot versions;
- previous and target Nexo versions;
- upstream and Nexo commit SHAs;
- image tag and digest;
- conflicts and resolutions;
- database migrations;
- test and staging evidence;
- known risks;
- rollback or forward-fix instructions;
- explicit production approval.
