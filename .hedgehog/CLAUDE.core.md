## This project's core: adopted (brownfield)

<!-- hedgehog:bootstrap-only start -->
Hedgehog was adopted onto this repo's existing codebase by
`hedgehog-adopt` rather than building a workspace from scratch.
<!-- hedgehog:bootstrap-only end -->
The build graph here covers **new change only**, and no task, commit, or
artifact record in it is ever fabricated for code Hedgehog didn't
touch — that's absolute. Pre-existing code is context to read and
respect, never a node in the build graph.

- **`.hedgehog/core.yaml`** — a linear chain of change-order layers (no
  module axis), each `verify` command drawn from this repo's own
  test/lint/typecheck commands, confirmed at adoption time. `hedgehog
  plan` compiles the build graph from it.
- **`.hedgehog/adoption.md`** — the rationale: what the repo's own
  commands are, why the layers are ordered the way they are, what
  `hedgehog-adopt` deliberately chose not to do (stack migration, legacy
  review), and a "Repo shape" section — module boundaries, entry points,
  and conventions observed, dated to when it was read. That section is a
  snapshot, refreshable by re-running `hedgehog-adopt`, never build-graph
  state and never treated as current past its date.

Read `adoption.md` to know what each layer covers and why, and to get
your bearings in this repo's shape before writing new code — then confirm
against the actual files, since the snapshot ages and the code doesn't
wait for a refresh. There is no `core-design.md` on this core —
`hedgehog-adopt` never designs a stack or proposes converting this repo
toward one; it only wraps the commands and seams already here.

**Coverage is partial, always.** `hedgehog status` and `hedgehog boundary`
describe the state of work under discipline, not the state of this repo.
A file with no entry under `hedgehog why` was never touched by Hedgehog —
that's expected on an adopted repo, not a bug.

**The packet is what actually runs**, same as any other core: `hedgehog
plan` copies each layer's scope globs, verify command, and commit message
onto the task row at compile time, and the packet is gated against that
row, not against a live re-read of `core.yaml`. See `hedgehog-authored-
loop`'s "core.yaml vs. the packet" for the drift/reconcile mechanics —
they apply here unchanged.

### The skills — invoke these, don't improvise

- **`hedgehog-authored-loop`** — every unit of change: `hedgehog claim`
  reserves the packet for one ready layer (`hedgehog next` previews it
  read-only, without reserving), `layer-eng` builds it, `hedgehog
  verify` gates and commits it. Also holds the Correction Protocol and
  this core's Stop Condition (per-change here, not whole-graph — see
  below).
- **`hedgehog-adopt`** — run again whenever new change-work enters play:
  sizes the request (a large or ambiguous one gets a short clarifying
  pass first), adds one or more intents for the change (goal, outcome,
  which seam it touches), and runs `hedgehog plan`. Never re-proposes the
  layer chain — that was fixed at adoption time. Can also refresh
  `adoption.md`'s "Repo shape" section on request, but only that section.

### The agents — delegate the judgment calls

`layer-eng` builds one layer per `hedgehog claim`ed packet, working from
the packet's ALLOWED SCOPE; it reports the work done and never commits
it. See `hedgehog-authored-loop` for the claim/dispatch/verify sequencing,
and `hedgehog-adopt` for how `planner`, `reviewer`, and `tweaker` route
work onto this core — that's the source, not restated here.

## The constants (do not deviate)

### Stack: not Hedgehog's to choose

This repo's language, package manager, and tooling are whatever they
already were before adoption. Hedgehog never proposes converting them
toward a shipped core's stack — not even as a suggestion. Every `verify`
command in `.hedgehog/core.yaml` is one of this repo's own commands.

### Layout

```text
.hedgehog/
  hedgehog.db      the build graph — intents, compiled tasks, verifications, committed to git
  core.yaml        the change-order layer chain, scope, verification, commit messages — locked
  adoption.md      the rationale behind core.yaml, this repo's own commands, and a dated repo-shape snapshot — locked except that snapshot
```

### Core rules

- **Change-scoped only.** No task ever describes pre-existing code as
  work to do. A file with no artifact record was never built by
  Hedgehog — `hedgehog why` says so plainly rather than erroring.
- **One layer, one commit**, in the exact message `.hedgehog/core.yaml`
  names for that layer.
- **Scope is the boundary**, more load-bearing here than on a greenfield
  core: on an unfamiliar codebase, blast radius is the primary risk, and
  scope enforcement is the only mechanism that bounds it.
- **The layer's own `verify` command — this repo's own command — gates
  every commit.** Never weaken it to clear a gate.
- **No global Stop Condition.** Adoption has no terminal state: it is the
  permanent way change lands on this repo from here on, not a project
  that finishes. "Done" is per-change (`hedgehog boundary` on the current
  intent), never whole-graph.
- **Fix wrong layers at the source** via the Correction Protocol — never
  a downstream workaround.
- **The layer chain itself is locked.** A layer in the wrong place or a
  missing seam is a `hedgehog-adopt` re-run (adding a layer, never
  reshaping history), not a quiet edit to `core.yaml`.
