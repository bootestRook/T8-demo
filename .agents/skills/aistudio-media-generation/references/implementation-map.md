# Implementation Map

## Purpose

Use this reference when the target API accepts a generation request but media does not come back immediately.

## Execution model

Most media APIs follow one of these patterns:

- synchronous generation
- accepted task plus polling
- accepted task plus webhook or background completion

If the generation response does not include final media URLs, assume polling is required until the target service proves otherwise.

## Polling flow

1. Read the first generate response carefully.
2. Extract `taskId`, provider task id, or status token.
3. Call the task status route until the status becomes complete, failed, or cancelled.
4. Stop polling on timeout and report the last known status.

Use script flags when the task route is non-standard:

- `--task-path-template`
- `--task-query`
- `--provider` when the status endpoint expects provider as a query param

## Status expectations

Common terminal states:

- `success`
- `completed`
- `failed`
- `cancelled`

Common non-terminal states:

- `pending`
- `queued`
- `processing`
- `running`

## Failure patterns

Request fails early:

- schema mismatch
- auth failure
- provider not registered

Task is accepted but never completes:

- missing `taskId`
- polling the wrong route
- provider status is non-terminal but the client stops too early
- provider returns an unsupported intermediate status

Task completes externally but UI never updates:

- polling response shape differs from generate response shape
- client only reads one URL field name
- business-layer writeback is separate from media completion

## Discovery checklist

Search for:

```bash
rg -n "queue|poll|processor|worker|taskId|history|status|provider factory" .
```
