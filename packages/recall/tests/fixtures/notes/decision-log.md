# Decision log

A running log of decisions on Project Alpha.

## Database choice

Chose Postgres over MongoDB. Reason: query patterns are relational and we
want strong constraints on referential integrity.

## Rollout strategy

Use feature flags. We launch behind a percentage rollout starting at 5%,
ramping over two weeks if error rates stay flat.

## Auth

OIDC via the central identity provider, no in-house password storage.
