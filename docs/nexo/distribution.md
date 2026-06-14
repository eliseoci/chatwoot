# Nexo Chatwoot Distribution

Nexo Chatwoot is an upgrade-safe distribution of Chatwoot Community Edition.
It adds Nexo-owned product modules while preserving Chatwoot's messaging,
channel, contact, and conversation behavior.

## Repository topology

The canonical remotes are:

```text
origin    https://github.com/eliseoci/chatwoot.git
upstream  https://github.com/chatwoot/chatwoot.git
```

`origin` contains Nexo release branches and tags. `upstream` is read-only and
is used to fetch stable Chatwoot releases.

## Release baseline

The first distribution baseline is Chatwoot `v4.14.2`, published on
June 10, 2026.

Nexo development branches start from the dereferenced commit of an official
stable upstream tag, never from the moving upstream `develop` branch.

## Versioning

`VERSION_CW` contains the upstream Chatwoot version.

`VERSION_NEXO` contains the complete Nexo distribution version:

```text
<chatwoot-version>-nexo.<release>
```

Examples:

```text
4.14.2-nexo.0
4.14.2-nexo.1
4.15.0-nexo.1
```

Release tags add the conventional `v` prefix:

```text
v4.14.2-nexo.1
```

The corresponding immutable container tag is:

```text
ghcr.io/eliseoci/chatwoot-pipelines:v4.14.2-nexo.1
```

Production and staging deployments must also record the registry digest. A
floating tag such as `latest`, `Community`, or a branch name is not a release
identifier.

## Branching

1. Fetch the official stable upstream tag.
2. Verify the tag in the Chatwoot GitHub releases page.
3. Create a Nexo release branch from the dereferenced stable tag.
4. Merge completed Nexo feature branches into that release branch.
5. Run the Community Edition, Nexo guardrail, and focused Pipelines checks.
6. Create a `v<chatwoot>-nexo.<release>` tag only after the release checks pass.

The initial feature branch is:

```text
codex/chatwoot-pipelines
```

## License boundary

The root Chatwoot license makes code outside `enterprise/` available under the
MIT Expat license. Code under `enterprise/` has a separate Chatwoot Enterprise
license.

Nexo Pipelines must:

- live outside `enterprise/`;
- not copy Enterprise implementation files;
- not import or reference `Enterprise::` implementation modules;
- not depend on an Enterprise-only controller, model, service, policy, route,
  component, or API;
- continue to work after the Community Edition image removes `enterprise/`.

The upstream Community Edition build already removes `enterprise/` and
`spec/enterprise`. Nexo CI adds a guardrail that rejects Nexo changes to that
tree and scans the Pipelines domain for Enterprise implementation references.

## Runtime topology

One Nexo application image is used by two stateless processes:

```text
Chatwoot Web     bundle exec rails s -p 3000 -b 0.0.0.0
Chatwoot Worker  bundle exec sidekiq -C config/sidekiq.yml
```

Stateful dependencies remain separate:

- PostgreSQL
- Valkey
- S3-compatible object storage

The distribution must never package PostgreSQL or Valkey inside the Chatwoot
application image.

## Production gate

Creating an image or a Railway staging topology does not authorize a production
change. Production requires:

1. a pinned image tag and digest;
2. a database backup and verified restore path;
3. a staging migration rehearsal;
4. Web and Worker health verification;
5. a documented rollback or forward-fix strategy;
6. explicit human approval immediately before mutation.
