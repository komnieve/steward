# Project Alpha

Alpha is a green-field experiment in distributed task scheduling. It is not
yet load-bearing for any customer-facing feature.

## Goals

- Validate the queue model under realistic burst load.
- Settle the API surface before integrating with the production scheduler.
- Produce a runbook that another engineer can follow without me in the room.

## Status

Architecture doc landed. First end-to-end test passes locally. Production
readiness still pending: monitoring, alerting, and the on-call runbook.
