---
name: hedgehog-authored-loop
description: Use for every unit of change-work on an adopted core (`.hedgehog/core.yaml` present, written by `hedgehog-adopt`) — building one layer per claimed packet, gated by `hedgehog verify` and committed one layer at a time. Triggers on "next step", "what's next", "build this", or the start of any work session on an adopted repo. Adds this core's linear-chain, Correction Protocol and per-change Stop Condition deltas to `hedgehog-orchestrating`.
---

# Hedgehog Authored Loop

The operating loop for a repo Hedgehog was adopted onto: `hedgehog
claim` reserves the packet(s) for ready layers, `layer-eng` builds each,
`hedgehog verify` gates and commits it. The build graph
(`.hedgehog/hedgehog.db`) is the live list — query it via `hedgehog
status`/`hedgehog ready`, never re-derive state from prose.

`hedgehog-orchestrating` owns the core-neutral loop: the cycle, the
Test-depth and review rule, the Friction log, the Correction Protocol and
its Post-build entry, the Stop Condition, and the Graph exits. This skill
names the agent that builds each layer and adds what is specific to an
adopted core.

## Where this core's shape lives

Two files carry the layer sequence, and both are locked:
**`.hedgehog/core.yaml`** is the design authority, always a linear chain
(no module axis); **`.hedgehog/adoption.md`** is the rationale: the
repo's own commands and their source, why the layers are ordered the way
they are, and what was deliberately left unmodeled (see `hedgehog-adopt`'s
"No global Stop Condition" and "Coverage is partial" — both apply here
and are not repeated below).

`.hedgehog/core.yaml` is what the compiler and every command below
actually read. Read `adoption.md` at the start of a session to know what
this adopted repo's discipline is — `layer-eng` reads it before writing
any layer. `adoption.md`'s "Repo shape" section is a dated snapshot, not
a live model — treat it as calibration for how new code should look, and
read the actual files it describes when precision matters more than a
snapshot can offer.

### core.yaml vs. the packet

`hedgehog plan` **copies** each layer's scope globs, verify command and
commit message onto every task row when it compiles. From that moment
the row — which is what the packet shows — is what `hedgehog claim` hands
out and what `hedgehog verify` gates against. `core.yaml` is no longer
consulted for a task that already exists.

So an edit to `core.yaml` after `plan` has run does **not** reach
already-compiled tasks, and re-running `hedgehog plan` won't apply it
either: compiling an intent flips it to `active`, and `plan` only reads
`proposed`/`planned` intents, so it reports "0 intent(s) compiled" and
changes nothing.

If the packet and `core.yaml` disagree, the packet is what your work will
actually be judged by. Reconcile, don't pick a winner:

1. `hedgehog status` prints a **DRIFT** section: every task whose
   compiled fields no longer match `core.yaml`, field by field, with
   `core.yaml`'s value against the task's.
2. `hedgehog plan --recompile` rewrites those fields from the current
   `core.yaml` on tasks nothing has acted on yet (`proposed`, `planned`,
   `ready`), and refuses `building`, `verifying`, `complete` and
   `blocked` tasks, naming each and why. `--dry-run` previews it;
   `--include-blocked` opts in the blocked ones (their working-tree work
   was done against the old scope, so check it after);  `--strict` exits
   non-zero when drift remains.
3. Drift `--recompile` won't touch — a task already built or committed, a
   layer dropped from `core.yaml`, a changed `depends_on` — is a
   Correction Protocol case (below), not a field rewrite.

Never patch a task row in SQLite by hand to work around this. The DB is
derived and gitignored; `hedgehog db rebuild` re-derives every task from
`core.yaml` and the committed intents, so a hand-patched row silently
disappears on the next rebuild or fresh clone.

## Linear chain only

An adopted core is always a linear chain: one pass total, one task per
layer, no `module` dimension, no `{module}` anywhere in `core.yaml`. Each
batch of change-work walks the same fixed sequence `hedgehog-adopt`
locked at adoption time. `hedgehog claim --count N` naturally returns at
most one task at a time — there's no fan-out to gain from a linear chain,
so concurrent execution buys nothing here.

## The Loop

Run the cycle in `hedgehog-orchestrating`'s "The cycle". On this core:

- **Dispatch** each packet to a `layer-eng` subagent, with the reminder
  to read `.hedgehog/adoption.md` for what its layer owns. Build the
  packet inline only on the conditions "The cycle" step 2 lists.
- **Intent and debt.** "What the packet carries forward" applies as
  written. A "KNOWN LIMITATION" comment in a source file is not a debt
  mechanism: the inheriting task's packet is assembled from the graph,
  and nothing reads that comment.

## Intra-layer conventions

An adopted repo's stack is whatever it already was before adoption, so
the conventions inside a layer come from two places: the repo's own
existing idioms (its error-handling style, its naming), and whatever the
earlier layers already established on disk for this change. Read before
writing, and stay consistent with what's there.

Two hold regardless of stack:

- **A layer owns one artifact, reached through the interface the
  rationale file named** (or, on an adopted core, the seam it named). The
  layer below is consumed through that interface, not reached around —
  the boundary is what makes the layer independently verifiable.
- **Each layer's tests live inside that layer's scope** and run under its
  own `verify` command. Test depth follows `hedgehog-orchestrating`'s
  "Test-depth and review rule".

## Friction log

`hedgehog-orchestrating`'s "Friction log" applies.

## Correction Protocol

`hedgehog-orchestrating`'s "Correction Protocol" and its "Post-build
entry" apply, including "Narrow out-of-scope fix". There is no build to
be "post" on an adopted core (see "Stop Condition" below), so a
structural correction on already-`complete` tasks is fixed forward in new
commits.

When the correction is to the **layer sequence itself**, `.hedgehog/
core.yaml` and `adoption.md` are locked outside that path: stop, say what
the design got wrong, and hand to `hedgehog-adopt`. After it changes
`core.yaml`, run `hedgehog plan --recompile` (see "core.yaml vs. the
packet" above); tasks it refuses are fixed forward through the protocol.

## Layer Transition Checks

Use the `reviewer` agent at the last layer of a batch of change-work. It
checks what the mechanical gate can't: whether the layer boundary
`adoption.md` described actually held, and whether the interfaces between
layers stayed the ones that were designed.

## Rules

- **A wrong layer gets fixed at its source** through the Correction
  Protocol, not a downstream workaround.
- **The layer's own `verify` command gates every commit.** Never weaken
  it to clear a gate.
- **Scope is the boundary.** A layer writes inside its ALLOWED SCOPE and
  nowhere else; a change that needs to land elsewhere is a correction,
  not a wider write.
- **`.hedgehog/core.yaml` and `adoption.md` are locked** (except
  `adoption.md`'s "Repo shape" section, refreshable via `hedgehog-adopt`).
  Changing anything else is a `hedgehog-adopt` re-run.

## Stop Condition

**No global Stop Condition.** Adoption is the permanent way change lands
on the repo, not a build that finishes, so `hedgehog-orchestrating`'s
completion handoff does not apply. See `hedgehog-adopt`'s "No global Stop
Condition". Its "Managing context" applies per change: run `hedgehog
boundary` before `/clear`, and open the next session on `hedgehog
boundary --handoff`.

**New change-work** goes to `hedgehog-adopt`'s "Adding the first (or
next) change-work", not a re-entry pass: there is no BMAD archive here to
read as context. Changing the **layer sequence itself** is the
Correction Protocol case above.
