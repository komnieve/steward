# Practice Layer

Steward assumes you hold work as practice. The Practice Layer is how that assumption
becomes code the agent can use.

See [`SPEC.md`](SPEC.md) for the interface definition and authoring guide.

See [`templates/`](templates/) for the seven components shipped in this repo.

See [`examples/`](examples/) for fully-written example Practice Layers you can fork.

---

## If you're setting up Steward

`./scripts/setup` asks you which Practice Layer components you want installed. Your
answers render templates from `templates/` into `$STEWARD_HOME/practice/`, where you edit
them to fit you.

## If you're authoring a Practice Layer

Fork `templates/`. Rewrite in your voice. Publish as a separate repo or contribute back
as an entry in `examples/`.

## If you're trying to understand what this is for

Read [`SPEC.md`](SPEC.md) top-to-bottom. It defines what a Practice Layer must do, what
it must not do, and why.
