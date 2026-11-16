<!-- hedgehog:bootstrap-only start -->
<!--
  Hedgehog project CLAUDE.md template.

  This file is copied into a consuming project's repo root at install
  time, with the core-section marker below filled in from this
  project's chosen core's own CLAUDE.core.<name>.md (src/templates/).
  Placeholders wrapped in {{ }} are filled in once, at planning intake,
  by the `planner` agent (or by hand). Everything outside the
  placeholders is a constant of the Hedgehog discipline and should be
  left as-is.

  Delete this comment block after the placeholders are filled in.
-->
<!-- hedgehog:bootstrap-only end -->

# {{PROJECT_NAME}}

{{PROJECT_SUMMARY — 2–4 sentences the `planner` writes at planning
intake: what this project is, who it's for, and what it does. State
current intent, not history. Keep it tight — the full product narrative
lives in this core's own planning-intake output and the build graph, not
here.}}

This project is built with **Hedgehog**: a one-step-at-a-time build
discipline. The rules below aren't project preferences — they're how the
build stays mechanically correct. Follow them exactly.

<!-- hedgehog:bootstrap-only start -->
## First message in a fresh install

If `{{PROJECT_SUMMARY}}` above is still an unfilled placeholder, this is a
brand-new install and nothing has been built yet. Open with something
short and warm — 🦔 plus one line asking what the user wants to build —
then follow `planner` in this thread, not as a subagent dispatch —
Phase 0's BMAD elicitation is a live, multi-turn conversation the user
needs a direct channel for. Read `planner.md` fresh off disk (this
install just wrote it, in this session — don't rely on a prior read or
prior-project memory of what it says) and run it here through Confirm &
Lock and the `bootstrap` handoff. This same rule holds at every later
handoff to a newly-installed agent or skill in this session: read its
file, don't assume its content.

The build continues in this session — nothing here needs a restart. Hosts
differ in whether they pick up agents written mid-session, so prefer
reading an agent's file from `.claude/agents/` and following it inline;
each one is self-contained, and that path works everywhere. Reading also
avoids the quiet failure of dispatch by name, where `planner` or
`reviewer` resolves to the user's own unrelated global agent and runs a
different discipline with no symptom. If a dispatch does error with a
list of available agents that omits Hedgehog's, that is the same case —
read the file and carry on.

Don't re-explain the discipline or summarize this file; the greeting is
one line, not a tour. Skip this entirely once the placeholder is filled
in — every later session starts with `hedgehog status`, not a greeting.
<!-- hedgehog:bootstrap-only end -->

## How to work here

The build is a loop of small, gated, committed steps. You never hold the
whole plan in context — the plan lives in the structure:

- **The build graph** (`.hedgehog/hedgehog.db`) is the live source of
  truth for what's next. Query it via `hedgehog status`/`hedgehog ready`
  at the start of every session — never re-derive state from prose.
- **The commit log** is the record of what's built and why. Conventional
  commits are how progress is read, not a conversation summary.
- **The architecture is fixed and opinionated for this project's core**
  — the same on every Hedgehog project running that core. Where a piece
  lives, what it may depend on, the build order: all of it is inferable
  from this file and the skills *without reading a line of code*. You
  don't discover the patterns; you already know them.
- **The codebase carries the project-specific instances** — what's
  actually been built, what a given piece's shape is, what's already
  wired. That, you re-read from the code when you need it, rather than
  remembering it.

Because state lives in those places and not in the conversation, a fresh
context loses nothing: the architecture is known a priori, and the
project's specifics are re-read on demand. The `hedgehog-orchestrating`
skill (see **Running the build** below) is what uses that.

**Use only the skills and agents this repo provides**, including its
vendored BMAD shelf — never a general-purpose build-tool skill pack
(e.g. "superpowers") or another project's agent set. Hedgehog's
enforcement (scope boundaries, no self-certification, the commit-gated
loop) is what a generic skill pack has no notion of, and running one
alongside Hedgehog's own skills produces work that bypasses the very
discipline this file describes.

**Build through the loop, including when the work looks too small to need
it.** A task that seems like a quick edit is not a reason to skip the
graph, the step sequence, or the gate — scope grows, and the shortcut is
what turns a small change into debt the next step has to work around.
Don't propose going around the discipline to save a step, and don't treat
a user's impatience as license to: say what the loop's next step is and
take it. Where a rule genuinely conflicts with what the user is asking
for, name the conflict and let them decide — never resolve it by quietly
taking the faster path.

<!-- hedgehog:core-section start -->

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

<!-- hedgehog:core-section end -->

## Running the build

The build graph is the source of truth for what's next — never re-derive
build state from prose. The `hedgehog-orchestrating` skill owns the claim →
dispatch → verify cycle, the intent check, debt and decision recording, the
context boundaries to clear at, and the post-build handoff. Read it at the
start of every session and follow it.

## Delegating on this host

The agents in `.claude/agents/` are registered automatically — delegate to
one by name (`backend-eng`, `reviewer`, and so on) and it runs in its own
context with its own tool grant. The skills in `.claude/skills/` are
available the same way; invoke one by name rather than reimplementing what
it describes.

Clear context with `/clear` at the unit boundaries the
`hedgehog-orchestrating` skill states.
