# Runbook

Oncall, incidents, rollback. Skim this before paging anyone.

## Owners

- Primary: <<HANDLE_OR_NAME>>
- Backup:  <<HANDLE_OR_NAME>>
- Slack:   <<#channel>>

## Health checks

| Check | Where | Green |
| --- | --- | --- |
| Liveness | `<<URL>>/health` | HTTP 200 within 1s |
| <<dependency>> | <<URL>> | <<criterion>> |

## Common incidents

### <<incident_name>>

**Symptoms:** <<what the user / dashboard shows>>

**Diagnosis:**

1. <<step>>
2. <<step>>

**Mitigation:**

```bash
# <<minimal command sequence to restore service>>
```

**Rollback:**

```bash
# <<command sequence to roll back to previous version>>
```

## Deploys

- Production deploy: <<process>>
- Pre-deploy checklist: <<link or steps>>
- Post-deploy verification: <<URL or query>>

## Backups

- Where: <<bucket or DB snapshot location>>
- Retention: <<days>>
- Restore drill cadence: <<monthly | quarterly>>
