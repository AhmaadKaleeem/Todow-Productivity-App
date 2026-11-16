---
name: hedgehog-adopt
description: Use once, at the start of bringing Hedgehog's discipline to an existing repo whose code Hedgehog didn't build — "adopt this repo", "add Hedgehog here", "I want scope/verify enforcement on my changes to this existing codebase". Invoked by the `planner` agent as Phase 0's fourth outcome, in place of any bootstrap skill. Reads the repo read-only, proposes a linear-chain `.hedgehog/core.yaml` whose `verify` commands are the repo's own, and writes only `.hedgehog/` — never touches working code. Also invoked again, briefly, whenever new change-work enters play on an already-adopted repo.
---

# Hedgehog Adopt

Brings Hedgehog's discipline to a repo that already exists, without
bootstrapping a workspace. On every other core, bootstrap generates or
copies a workspace before any build step runs. Here there is nothing to
generate — the workspace already exists, built by whoever wrote this
repo — so this skill replaces bootstrap entirely rather than extending
it. It writes `.hedgehog/` and nothing else, ever.

## What this is, precisely

Hedgehog on an existing repo is a **permanent discipline for how change
lands**, not an authority over what exists. The build graph covers new
work only. Pre-existing code is context to read and respect, never a node
in the graph — no task is ever created to "build" something that's
already there, and no artifact record, commit, or task ever claims
Hedgehog wrote code it didn't. `adoption.md`'s "Repo shape" section (Step
4) is a separate thing: a dated, prose snapshot of what Step 1 observed,
refreshable by re-running this skill — never build-graph state, never
authoritative past the date it was read, and never a substitute for
reading the actual code.

This is what makes adoption safe to run on a real, live codebase:

- **The build graph never models pre-existing architecture.** Module
  boundaries, conventions, and shape live in `adoption.md`'s prose as a
  dated read, not as `core.yaml` state or task history — nothing about
  the existing repo is ever treated as something Hedgehog built or
  verified.
- **No completion backfill.** It never fabricates commits to make
  `hedgehog db rebuild` believe pre-existing files were built by
  Hedgehog. `rebuild.mjs` marks a task complete only when a real commit's
  subject matches its `commit_message` — inventing that history would be
  fiction in the permanent record, so this skill doesn't.
- **No stack migration.** The repo's language, tooling, and conventions
  are already decided. This skill never proposes moving them toward any
  shipped core's stack — not Nx, not Drizzle, not anything else Hedgehog
  is opinionated about elsewhere. Every `verify` command it writes is one
  of the repo's own commands, confirmed with the user, never invented.
- **No legacy-code review.** `reviewer`, once this core is running,
  judges only the unit under change — never findings against pre-existing
  code nothing asked it to look at.
- **No generators.** Nothing here scaffolds files the way a shipped
  core's bootstrap does. This skill's only output is `.hedgehog/`.

What *does* transfer from the rest of Hedgehog, unweakened: scope as a
hard boundary on every task, no self-certification (only `hedgehog
verify`'s exit code moves state and commits), the dependency graph and
its leases and safe parallelism, small per-layer context loops, and
`reviewer`/`debt`/`friction` as real channels. On an existing codebase
scope enforcement is worth *more* than on a fresh one: blast radius is
the primary risk on code you didn't write, and bounding it is the one
thing a generic agent setup doesn't give you.

## When this runs

`planner`'s Phase 0 outcome 4, "An existing repo, ongoing adoption",
routes here, detected at its Workflow step 2 before Phase 0's matching
runs. The question isn't which core fits new work, it's that no new
workspace is being built at all. Skip
`hedgehog-planning-intake`'s BMAD shelf entirely: BMAD elicits product
drivers (persistence, deployment target, integration surface) that are
already settled facts of a repo that already exists, not open decisions
to interview for.

Two entry shapes:

- **First run** — nothing under `.hedgehog/` yet. Run every step below
  through Confirm & Lock, then add the first intent(s).
- **Later run** — `.hedgehog/core.yaml` already exists and was written by
  this skill (its own record — see Step 5). New change-work entered play.
  Skip straight to "Adding change-work" below; every earlier step is
  already-locked state, except `adoption.md`'s "Repo shape" section, which
  that same later run may refresh on request (see Step 4).

## Step 1 — read the repo, read-only

Before proposing anything, read enough of the repo to answer:

- **Layout.** Where source lives, where tests live, whether there's a
  monorepo structure (workspaces, packages) or a single package.
- **Package manager and toolchain.** `package.json`/`pnpm-lock.yaml`/
  `yarn.lock` (which one), `Cargo.toml`, `pyproject.toml`, `go.mod`,
  whatever the repo's own manifest is.
- **Existing commands.** `package.json` `scripts` (test, lint, typecheck,
  build), a `Makefile`, CI config (`.github/workflows/*.yml`,
  `.gitlab-ci.yml`) — CI config is often the most trustworthy source,
  since it's what the repo's own maintainers already run as their bar for
  "this change is good."
- **Natural seams.** Places where a change plausibly needs to move in a
  fixed order — a schema or migration before the code that reads it, a
  shared type or contract before its consumers, a public API before an
  internal one. Not every repo has these; a repo with no natural
  ordering constraint gets a single-layer chain (see Step 3). When a
  workspace manifest declares structure — `pnpm-workspace.yaml`,
  `Cargo.toml`'s `[workspace]` table, `go.work`, or equivalent — read it
  directly for the package list and which packages depend on which; that's
  evidence for a seam candidate, not a seam itself (see Step 3). Absent a
  manifest, fall back to reading the repo directly.
- **Shape.** Module or package boundaries, key entry points, and code
  conventions actually observed — naming patterns, error-handling idiom,
  where tests live relative to source. Note only what's actually visible
  in the files read for the other bullets above; skip this bullet outright
  if the repo is too small or too inconsistent to show a real pattern.
  This becomes `adoption.md`'s "Repo shape" section (Step 4) — calibration
  for how new code gets written, not an architecture model.

  **Also observe the repo's `pattern`**, from the same evidence, never a
  separate read: a workspace manifest's declared package graph (already
  opened above for seam candidates) is the strongest available signal —
  a one-way dependency direction toward a package nothing depends
  outward from is `hexagonal`; a graph that's just sequential, ordered
  stages with no domain/adapter shape is `layered`. **`none` unless the
  structure makes it unambiguous** — the bar is a declared package
  graph or an equally direct signal, not a directory named `domain` or a
  vibe. When in doubt, `none`: it costs nothing, checks nothing, and is
  honest. Never a recommendation — this records what the repo's
  structure already is, never what it should become, the same stance
  the rest of this step takes. `vertical-slice` is not a candidate here
  regardless of what's observed — this core's chain never carries
  `{module}` (Step 3), so that value has nothing to attach to; a
  module-per-package repo still reads as `hexagonal`, `layered`, or
  `none` from this evidence, same as any other.

This step is entirely read-only. Never write, edit, or run anything that
mutates the working tree here — no `npm install`, no formatter, nothing.

## Step 2 — propose the verify commands, confirm with the user

Candidate commands come only from what Step 1 actually found — never
invented, never assumed from convention ("this looks like it should have
a lint script"). Show the candidates and their source (`package.json`
script name, Makefile target, CI job step) and get explicit confirmation
before writing anything.

This is the highest-leverage step in the whole skill and the one place a
mistake is silent rather than loud: a `verify` command that doesn't
actually check what it claims to (a script that's a no-op, a lint config
so lenient it never fails, a test command that runs zero tests) still
exits 0, so `hedgehog verify` commits work that was never actually
checked. It looks like success. Read what a candidate command actually
does — not just its name — before proposing it: a `"test": "echo
ok"` placeholder script is a real thing real repos have.

If the repo has no test command at all, say so plainly rather than
inventing one. A layer's `verify` can be a typecheck or lint alone if
that's genuinely all the repo has — an honest, weaker gate beats a
fabricated test command that doesn't exist.

## Step 3 — propose the layer chain

**Linear chain, no `{module}` anywhere.** Change order is not
construction order — there's no "schema before service" here, because
nothing is being constructed. The chain expresses, for a given batch of
change-work, which seam moves first and what has to be re-verified after.
A repo with no natural seam (Step 1 found none) gets the degenerate case:
one layer, scope `["**"]`, verify the repo's full check. A repo with a
real seam (e.g. a shared package other packages depend on) gets that
seam as an earlier layer, `depends_on` chaining the rest after it — the
same pattern `landing-page`'s brief → feeling → tokens → sequence →
artifact chain already establishes for a linear, no-module-axis core
(the `@skyf0xx/hedgehog-core-landing-page` package's `workspace/core.yaml`).
When Step 1 found a
workspace manifest, its declared packages and dependency direction are
candidate seams, shown to the user with the manifest as their source —
same as Step 2's verify-command candidates, confirmed before anything is
written, never assumed straight into the chain.

Linear chain is not a simplification made for this skill's convenience —
it's what sidesteps the loader's module-axis uniformity rule: a core
where any layer's scope carries `{module}` requires every
non-`exclusive`/non-`once` layer to carry one too, which fights any repo
not laid out module-per-directory.
Never introduce `{module}` here.

**Always end with a `join`-style tail layer**: `scope: ["**"]`,
`exclusive: true`, verify the repo's full check (typecheck + test,
whatever Step 2 confirmed covers the whole repo) — the cross-cutting
safety net, the same pattern `full-stack-app`'s own `join` layer
establishes. This is what catches a change that passed its own narrow
layer's verify but broke something the narrower verify command couldn't
see.

Each layer's `commit` uses the repo's own conventional-commit style if it
has one (read a handful of recent commit subjects to tell), or standard
Conventional Commits otherwise.

**Write Step 1's observed `pattern` onto the generated `core.yaml`.**
`vertical-slice` never applies here — this chain never carries
`{module}` (above), and `vertical-slice` requires a module axis by
construction, so that value is simply unreachable on this core.

A linear, no-branching chain — which is the only shape this step ever
produces — conformance-checks clean under both `layered` and
`hexagonal` alike (confirmed directly against `validateCore`: a strict
sequence trivially satisfies hexagonal's direction check too, since
there is nothing to branch). `validateCore` will not catch a wrong
choice between the two here, so it is not the backstop — Step 1's
"unambiguous evidence" bar is. Declare only what the evidence actually
showed (`hexagonal` needs the specific domain/adapter package-graph
signal, not just "the layers happen to be in a line"; a plain
sequential dependency short of that is `layered`, or `none` if even
that is not clean). **The chain is not to be reshaped to satisfy a
declaration** — if Step 1's evidence for a value doesn't hold once the
actual chain is in front of you, downgrade the declaration (toward
`layered`, then `none`) and say why in `adoption.md`'s rationale rather
than forcing it. The chain expresses change order; the pattern
describes the repo — where they'd disagree, the chain wins and the
declaration yields.

## Step 4 — write `.hedgehog/adoption.md`

The rationale, same stance as `core-design.md` on an authored core: what
the repo's own commands are and their source, why the layers are ordered
the way they are (or why there's only one, for a repo with no natural
seam), and what was deliberately left out (stack migration, legacy
review — name these explicitly so a later reader doesn't wonder whether
they were forgotten). No nested YAML-shaped content — this file is
prose, `core.yaml` is the only file the engine parses.

Add a **"Repo shape, as of adoption"** section from Step 1's Shape
bullet: module/package boundaries, entry points, and conventions
observed, headed with the date and git ref it was read at. Label it
plainly as a snapshot — what the repo looked like when read, not a
live model — and say how to refresh it: re-run this skill (see "Adding
the first (or next) change-work" below), never a hand edit.

Include the observed `pattern` in this same section, stated as a fact
with its evidence, never a suggestion — *"No enforced dependency
direction observed (`pattern: none`) — `packages/` declares no
dependency graph and imports run both ways between `core/` and
`api/`."*, not *"this repo would benefit from…"*. If Step 3 downgraded
the declared value from what Step 1 first noted (say, `hexagonal`'s
evidence didn't fully hold once the actual chain was in view), say that
here too, in the same factual register: what was observed, and why the
declared `core.yaml` value ended up more conservative. This section is
the one part of `adoption.md` a later run may refresh — the pattern
observation refreshes with it, for the same reason the rest of the
section does: a repo's shape changes as it's built on.

Only this section is refreshable. Everything else in `adoption.md` — the
commands, the layer rationale, what was left out — is locked the same as
`core.yaml`, written once at Step 5 and changed only by the Correction
Protocol path described there.

## Step 5 — Confirm & Lock

🔒 Show, in full:

- The commands Step 2 confirmed and where each came from.
- The layer chain in order: what each owns, its scope globs, its verify
  command, its commit message.
- The tail `join` layer explicitly, and what it catches that the earlier
  layers don't.
- The observed `pattern`, framed as an observation, not a judgment —
  *"Observed architecture: none — this repo has no enforced dependency
  direction. Hedgehog records this as a fact about the repo; it does
  not change it."* When the declared value is `layered` or `hexagonal`,
  state the evidence in the same line rather than the bare word.
- Plainly, in these words or equivalent: *"This adds Hedgehog's
  discipline to how change lands on this repo from here forward. It
  never touches your existing code and never converts your stack — only
  new work goes through this build graph, and coverage will always be
  partial by design. `adoption.md` will also hold a dated snapshot of
  this repo's shape, refreshable on request — never build-graph state,
  never treated as current past the date it was read."*

Wait for explicit go-ahead. On confirmation, write `.hedgehog/core.yaml`
(format enforced by `hedgehog core check`; field reference:
https://github.com/skyf0xx/hedgehog/blob/master/AUTHORING-CORES.md) and `.hedgehog/adoption.md`.
Verify the file before showing it back:

```bash
hedgehog core check .hedgehog/core.yaml
```

It exits 1 on a file that does not load and prints lint warnings
otherwise; `hedgehog core show` prints the layers as resolved.

Nothing else gets written at adoption time beyond the instructions-file
Hedgehog section and the adopted-core record below. No working code, no
`package.json` edits, no formatter run, no root `CLAUDE.md` project
placeholders — `{{PROJECT_NAME}}`/`{{PROJECT_SUMMARY}}` describe a
project Hedgehog is building, and adoption isn't building one, so leave
them alone.

Record the adoption once, right here at first adoption:
`npx @skyf0xx/hedgehog core record-adopted` (or the locally installed
`hedgehog` binary). It fetches the `adopted` package, lands `layer-eng`
and every skill this manifest names, keeps a local copy of
`CLAUDE.core.md` at `.hedgehog/CLAUDE.core.md`, and merges that section
into every host's existing instructions file (a hand-written root
`CLAUDE.md` included), never creating one that is absent: adoption only
extends the instructions file a repo already has. It marks the project's
core record `adopted` so `hedgehog update` refreshes this core's own
agents and skills instead of silently deleting them (adoption's `init`
names no core). Idempotent, and a later "Adding the first (or next)
change-work" pass has no need to re-run it.

## Adding the first (or next) change-work

`tweaker`, keyed off `hedgehog-daily`, is what routes a request here in
the first place: that gate reads `.hedgehog/core.yaml` and sends anything
that reaches more than one layer or introduces something that doesn't yet
exist to this section, while a same-layer edit to something already
there stops at its own tweak exit and never reaches this skill at all. A
request already past that gate is change-work by `hedgehog-daily`'s own
condition — this section's fast-path/elicitation bar is a second,
narrower decision made only once that's settled: not whether the work is
big enough to enter the graph, but whether the intent can be written now
or needs a clarifying pass first. Size against that bar before adding an
intent instead of a feel for "big" or "small." The fast path — straight
to `hedgehog intent add` below — applies only when **all** of these hold:

- The ask names its own acceptance condition — you can state what "done"
  looks like without guessing.
- It fits inside one layer of the locked chain — no new seam, no work
  spanning more than one layer's scope.
- The `verify` command that would prove it is already one of this
  repo's own, already sitting in `.hedgehog/core.yaml` — nothing new to
  wire up.
- It touches no security, auth, migration, or data-loss surface.

Failing even one of these gets `hedgehog-adopt-elicit` first — a short,
targeted clarifying pass on what's in scope, what's explicitly out, and
any constraints the user already knows — not `hedgehog-planning-intake`'s
BMAD shelf (that shelf's product-driver questions don't fit a change to a
repo that already exists, whatever the change's size). Fold the answers
directly into the intent's own `--goal`/`--outcome` text; nothing new
gets archived or locked.

**Security-sensitive work never takes the fast path**, however small or
well-scoped it looks: anything touching auth, permissions, migrations, or
data deletion goes through elicitation unconditionally.

**State which path was taken, and why, in one line, before proceeding**
— e.g. "fast path: single-layer log-format fix, verify is the repo's
existing lint command" or "elicitation: touches the auth session table."
The cost of getting this call wrong is asymmetric: routing a small change
through elicitation is friction the user notices immediately, while
routing a large one straight to `intent add` produces an under-specified
intent whose cost surfaces layers later — stating the call out loud
makes a wrong one visible immediately instead of at the next layer.

*The bar above and the requirement to state the call out loud are
adapted from [twilson63/lfg](https://github.com/twilson63/lfg)'s
"Triage: when to use the full loop" (MIT-licensed) — stated thresholds
beat a vibe, and declaring the path taken catches a wrong call early.
The rest of `lfg` (HTML progress pages, canvas diagrams, LLM-as-judge
scoring) is deliberately not carried over: the build graph, `hedgehog
verify`'s exit code, and the task packet already cover that ground.*

Once `core.yaml` is locked and any elicitation above is done, add intents
the same way any other core does — `hedgehog intent add --id <id> --goal
<goal> --outcome <outcome>`, one per distinct unit of change, each `id`
naming the change rather than a domain module (`fix-auth-timeout`,
`add-rate-limiting`, not a table or screen name — there's no module axis
here). Then `hedgehog plan` compiles it through the locked chain. This is
the same shape whether it's the first intent on a freshly adopted repo or
the fifth one three months later — adoption has no first-run-only intent
step the way planning intake does; every entry is the same mechanical
add, sized as above.

An adoption re-run can also refresh `adoption.md`'s "Repo shape" section
on request — when the user or `planner` flags that the repo's changed
enough since the last read to be worth re-scanning. Re-run Step 1's Shape
bullet and Step 4's write for that section only; the commands, layer
chain, and rest of `adoption.md` stay locked and untouched.

Commit this as `chore(planning): adopt` (first run, alongside the
Confirm & Lock commit) or `chore(planning): adopt change` (every later
run adding new change-work) — distinguishable from `hedgehog-planning-
intake`'s own `chore(planning): intake`/`extend scope` messages, since no
BMAD archive backs either of these.

From here, hand off to `hedgehog-authored-loop` — this core's
`core.yaml` is shaped exactly like an authored core's, so the same loop
skill runs it unmodified: `hedgehog claim` reserves the packet, `layer-
eng` builds it, `hedgehog verify` gates and commits it. That skill's
"Module axis" section always reads as linear chain here; its Correction
Protocol and Stop Condition apply as written, with one addition — see
"No global Stop Condition" below.

## `hedgehog why` on pre-existing code

A file this skill's chain never touched has no `artifacts` row, because
Hedgehog never built it — `hedgehog why <path>` already says so plainly
(`(no artifact recorded for this path)`) rather than erroring or
returning something misleading. That's the correct, expected answer for
almost every file in a freshly adopted repo. It is not a bug to route
around and not something this skill tries to backfill.

## No global Stop Condition

Every other core's Stop Condition fires once the whole graph is
`complete` — the project is done. Adoption has no such moment: it is the
permanent way change lands on this repo from here on, not a build that
finishes. Read `hedgehog-authored-loop`'s Stop Condition as **per-change,
never whole-graph**: `hedgehog boundary` still answers "is now a safe
moment to clear context" for the change currently in flight, and that
check is exactly as useful here as anywhere else. What doesn't apply is
treating "every task complete" as a project-level milestone worth a
handoff ceremony — there's always a next change, and the next one is
just another `hedgehog-adopt` intent add away.

## Coverage is partial — say so

`hedgehog status` and `hedgehog boundary` describe the state of work
under discipline, never the state of the repo as a whole. On an adopted
repo this matters more than it does elsewhere: a fresh Hedgehog project's
graph and its repo are the same size by construction, but an adopted
repo's graph only ever covers what's passed through it since adoption.
Never let a status summary imply broader authority than that — if asked
"is this repo fully covered," the honest answer is always "no, only the
changes that went through Hedgehog since adoption are," not a count that
could be misread as a percentage of the whole.

## Constraints

- **Never touch working code, at adoption time or ever, as this skill.**
  The only writes this skill makes are `.hedgehog/core.yaml`,
  `.hedgehog/adoption.md` (Step 4's rationale and its "Repo shape"
  section), the instructions-file Hedgehog section and the adopted-core
  record, both via `hedgehog core record-adopted` (first run only), and
  the build graph via `hedgehog intent add`/
  `hedgehog plan`.
  `hedgehog-adopt-elicit`'s clarifying pass writes nothing of its own —
  its output only ever becomes `--goal`/`--outcome` text on an
  `hedgehog intent add` call. Everything else — the actual change-work —
  is `layer-eng`'s job through `hedgehog-authored-loop`, gated the same
  as any other layer.
- **Never propose converting the repo's stack, structure, or conventions
  toward any shipped core's** — not Nx, not a particular ORM, not a
  particular framework. Not even phrased as a suggestion. This is the one
  headline pillar (opinionated stack + generators) that deliberately does
  not come along to a brownfield adoption — say so if asked, don't quietly
  work around it.
- **Never invent a `verify` command.** Every one comes from something
  Step 1 actually found in the repo and Step 2 actually confirmed with
  the user. A wrong `verify` command is the worst failure mode available
  — it looks like success while checking nothing.
- **Never create a task for pre-existing code.** The graph is
  change-scoped by construction; a task exists only for work an intent
  actually asked for.
- **No `{module}` anywhere in `core.yaml`.** Linear chain only — see Step
  3 for why.
- **Always end the chain with an `exclusive: true`, `scope: ["**"]` join
  layer.** This is the cross-cutting net that catches what a narrower
  layer's verify can't see.
- **`.hedgehog/core.yaml` is locked once written, and so is everything in
  `adoption.md` except its "Repo shape" section.** A layer chain that
  turns out wrong is a re-run of this skill to add or adjust a layer via
  a fresh Confirm & Lock, not a silent edit — and never touches tasks
  already compiled or completed (see `hedgehog-authored-loop`'s
  "core.yaml vs. the packet" for the drift/reconcile mechanics, which
  apply here unchanged). "Repo shape" is the one section a later run may
  regenerate on request (see "Adding the first (or next) change-work"),
  and even then only by re-running Step 1/4, never a hand edit.
