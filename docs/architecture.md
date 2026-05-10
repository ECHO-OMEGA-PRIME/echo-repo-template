# Architecture

> <<ONE_LINE_DESCRIPTION>>

This document is the spec, not the code. When the diagrams drift from `main`,
the diagrams are wrong — fix them in the same PR.

## C4 — Context

Who talks to <<PROJECT_NAME>> and what flows in/out.

```mermaid
flowchart LR
  user[User / API client]
  ext[(External services)]
  proj[<<PROJECT_NAME>>]

  user -->|<<verb>>| proj
  proj -->|<<verb>>| ext
  ext -->|<<verb>>| proj
```

## C4 — Container

The runtime processes inside <<PROJECT_NAME>>.

```mermaid
flowchart TB
  subgraph proj [<<PROJECT_NAME>>]
    api[API surface]
    worker[Worker]
    db[(Postgres)]
  end

  api --> worker
  worker --> db
  api --> db
```

## Key sequences

### <<flow_name>>

```mermaid
sequenceDiagram
  participant U as User
  participant A as API
  participant W as Worker
  participant D as DB

  U->>A: <<request>>
  A->>D: lookup
  A->>W: enqueue job
  W->>D: write result
  A-->>U: ack
```

## Data model

```mermaid
erDiagram
  EXAMPLE ||--o{ EXAMPLE_ITEM : contains
  EXAMPLE {
    uuid id PK
    text name
    timestamptz created_at
  }
  EXAMPLE_ITEM {
    uuid id PK
    uuid example_id FK
    text payload
  }
```

## Conventions

See [`mermaid_conventions.md`](mermaid_conventions.md) (BP-5.2) for theme
tokens and which diagram type to use when.
