# Nexo Pipelines Architecture

## Product boundary

Pipelines structure the business workflow that surrounds customer
conversations. They do not replace Chatwoot conversations or reinterpret
conversation status.

```text
Conversation state
  open / pending / resolved / snoozed

Pipeline business state
  new / qualified / proposal / won
  triaged / investigating / completed
  screening / interview / hired
```

The state machines are independent. Resolving a conversation must never infer
that a Pipeline Item was won, lost, hired, rejected, paid, or completed.

## Core aggregate

A Pipeline Item is the first-class workflow record.

```text
Account
└── Pipeline
    ├── Pipeline Stage
    └── Pipeline Item
        ├── Primary Contact
        ├── Optional Company
        ├── Owner and Team
        ├── Linked Conversations
        ├── Activities and Next Action
        ├── Custom Field Values
        ├── Stage Transitions
        ├── Automation Runs
        └── Audit Timeline
```

A conversation may trigger item creation, but it is not the item. One item may
link multiple conversations. A contact may also have multiple legitimate items
when the business objectives are different.

## Deep modules

### Pipeline Definition

Owns templates, pipelines, ordered stages, terminal outcomes, field
definitions, stage requirements, archive rules, and configuration validation.

### Pipeline Item Lifecycle

Owns item creation, account consistency, conversation linking, active-item
deduplication, explicit parallel items, stage transitions, ownership,
activities, archive behavior, and audit events.

The intended stable entry point for conversation intake is conceptually:

```text
Pipelines::Items::FindOrCreateForConversation.call(...)
```

Callers provide context. The lifecycle module owns matching and idempotency.
Chatwoot's asynchronous `conversation_created` event is consumed by a
Pipelines listener, which schedules a dedicated intake job. The lifecycle
service locks the contact before matching active items so duplicate or
concurrent delivery cannot create parallel records accidentally. Explicit
operator intent uses the same service with deduplication bypassed.

### Pipeline Attention

Calculates inspectable reasons an item needs action, including overdue
activities, missing next action, stalled stage, unread linked conversation,
handoff, and failed automation.

### Pipeline Automation

Owns trigger matching, condition evaluation, action execution, idempotency,
Sidekiq orchestration, retries, approval gates, and run history.

Rules contain ordered `PipelineAutomationAction` records rather than one
opaque action payload. Every rule execution creates one
`PipelineAutomationRun`, while every action creates one
`PipelineAutomationActionRun`. Successful action runs are terminal and are not
replayed when a later action fails. Failed actions can be retried without
duplicating completed database work.

Stage-entry execution uses Sidekiq through
`Pipelines::Automations::StageEntryJob`. Execution errors use polynomial
backoff with at most five job attempts. The final failed run remains visible in
the item timeline and contributes `failed_automation` to the attention view.

Outbound pipeline webhooks:

- are configured only by account administrators;
- use `SafeFetch` URL protections;
- carry an account-scoped payload;
- are signed with `X-Chatwoot-Timestamp` and `X-Chatwoot-Signature`;
- use a stable `X-Chatwoot-Delivery` value derived from the action run so
  receivers can deduplicate a successful delivery whose acknowledgement was
  interrupted.

Customer-facing message actions are intentionally absent. Adding one requires
a separate approval capability rather than another action enum value.

### Pipeline Authorization

Maps existing account users, teams, and role capabilities to pipeline actions.
It must not create a second user directory or weaken account isolation.

### Pipeline API and Events

Exposes account-scoped APIs and lifecycle events. Events support real-time UI,
the audit timeline, outbound webhooks, and automation triggers.

### Pipeline Workspace

Owns Kanban, list, attention, item drawer, filtering, sorting, saved views,
accessible movement, optimistic updates, and localized presentation.

### Conversation Integration

Adds a thin Pipeline section to the existing conversation sidebar. It delegates
creation, linking, transitions, assignment, and activities to the domain
interfaces above.

### Pipeline Reporting

Reads lifecycle data for stage counts, stage aging, outcomes, activities,
source/channel attribution, and workload. It does not own transactional state.

## Expected code ownership

Most Pipelines implementation belongs in isolated paths:

```text
app/models/pipeline*.rb
app/models/pipelines/
app/services/pipelines/
app/jobs/pipelines/
app/listeners/pipelines/
app/policies/pipeline*.rb
app/controllers/api/v1/accounts/pipeline*.rb
app/views/api/v1/accounts/pipelines/
app/views/api/v1/models/_pipeline*.jbuilder
app/javascript/dashboard/api/pipeline*.js
app/javascript/dashboard/routes/dashboard/settings/pipelines/
app/javascript/dashboard/routes/dashboard/pipelines/
app/javascript/dashboard/store/modules/pipelines/
config/locales/pipelines/
db/migrate/*pipeline*
spec/**/pipeline*
spec/**/pipelines/
```

Names may evolve as implementation proceeds, but ownership must remain
recognizable and removable. Deleting the module should remove Pipelines without
breaking message delivery.

## Allowed thin integration points

Pipelines may require small changes to shared Chatwoot surfaces:

- account associations;
- contact and conversation associations;
- account-scoped API routes;
- dashboard route registration and navigation;
- conversation sidebar composition;
- event constants and event dispatch;
- webhook event registration;
- localization registration;
- Community Edition Docker and CI release metadata.

Shared edits must delegate to Pipelines domain interfaces. Business rules do not
belong in shared controllers, conversation callbacks, navigation components, or
channel adapters.

## Forbidden coupling

Pipelines must not:

- modify channel message delivery;
- make a Pipeline Item a subtype of Conversation;
- add business stages to the conversation status enum;
- use Chatwoot labels as the Pipeline database;
- delete or mutate conversations when an item is archived;
- infer terminal outcomes from conversation resolution;
- import Enterprise implementation code;
- require PostgreSQL or Valkey to run inside the application container.

## Data invariants

- Every record is account-scoped.
- A Pipeline owns an ordered set of Pipeline Stages.
- A terminal Pipeline Stage must declare an explicit outcome key; an active
  stage must not declare one.
- Pipeline Item, stage, contact, company, owner, team, and linked conversations
  must belong to the same account.
- `PipelineItemConversation` is the current-link join record. It never copies or
  owns conversation status, assignment, labels, messages, or channel state.
- A linked conversation must belong to the Pipeline Item's primary contact.
- Conversation link and unlink operations emit immutable `PipelineItemEvent`
  audit records before the transaction commits.
- Destroying a Pipeline Item removes only its join and audit records; it never
  deletes a Chatwoot conversation.
- An item stage belongs to the item's pipeline.
- Stage transitions are append-only audit records.
- Automatic conversation intake is idempotent.
- The default deduplication candidate is an active item with the same account,
  contact, and pipeline.
- Explicit operator intent may create a parallel item.
- Terminal outcome is explicit Pipeline state.
- User-facing copy uses translation keys and locale-aware formatting.

## Testing seams

Behavior should be verified at stable boundaries:

- definition and template behavior;
- lifecycle and deduplication services;
- transition validation and audit output;
- authorization policies;
- request contracts;
- automation execution and retries;
- lifecycle events and webhooks;
- board, list, attention, drawer, and sidebar behavior;
- Community Edition startup without `enterprise/`;
- Web and Worker startup from the same image.
