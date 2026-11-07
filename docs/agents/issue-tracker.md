# Issue tracker: itsaplan

Issues and specs for this repo live in the itsaplan project **CUTCAP** (team Redstone, ref `redstone.CUTCAP`). Use the `mcp__itsaplan__*` tools for all operations. Issue identifiers look like `CUTCAP-42`.

## Resolving ids

- Column, type and label ids come from `get_project` with `projectKey: "CUTCAP"`. Never hard-code them; resolve them per session.
- Pick columns by `stateType` (`backlog`, `unstarted`, `started`, `completed`, `canceled`), never by name.
- Given `CUTCAP-42`, call `get_issue_by_number` (`projectKey: "CUTCAP"`, `sequenceNumber: 42`). Every other issue tool takes the internal numeric `id` from that result.

## Conventions

- **Create an issue**: `create_issue` with `projectKey`, `title`, markdown `description`, `columnId` of the `unstarted` column (or `backlog` for ideas), `typeId` (Feature / Bug / Task / Tech debt / Research) and `labelIds`.
- **Read an issue**: `get_issue_by_number`, or `get_issue` with the numeric id. Read `list_issue_activity` before commenting on a long-running issue.
- **List issues**: `list_issues` with field filters (`labelIds` as CSV, `columnId`, `typeId`, `parentId`); `search_issues` for text.
- **Sub-issues**: set `parentId` on `create_issue` / `update_issue`. Only one level: a subtask cannot have subtasks.
- **Blocking**: `link_issues` with `kind: "blocked_by"` (or `"blocks"`) between numeric ids. A ticket is unblocked when every blocker sits in a `completed` or `canceled` column.
- **Comment**: `add_comment`; answer an existing comment with `replyToId`.
- **Apply / remove labels**: `update_issue` with `labelIds`, which **replaces** the whole set, so read the current labels first and send the merged list.
- **State**: move to a `started` column when work begins and to `completed` / `canceled` when it ends. Never leave an issue in `started` after stopping.
- **Close**: post the explanation with `add_comment`, then `update_issue` into the `completed` (done) or `canceled` (won't do) column.
- Commit messages for issue work stay Conventional Commits; reference the issue in the body (`Refs: CUTCAP-42`).

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature requests; `/triage` reads this flag.)_

## When a skill says "publish to the issue tracker"

Create an itsaplan issue in CUTCAP as above. A spec is a `Feature` issue whose description is the full spec markdown.

## When a skill says "fetch the relevant ticket"

Read it as in **Read an issue** above.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single issue with **child** issues as tickets.

- **Map**: one issue labelled `wayfinder:map` (create the label with `create_label` if missing), holding the Notes / Decisions-so-far / Fog body.
- **Child ticket**: a subtask of the map (`parentId` = map id), labelled `wayfinder:<type>` (`research` / `prototype` / `grilling` / `task`). Once claimed, it is assigned to the driving dev.
- **Blocking**: see **Blocking** under Conventions.
- **Frontier query**: `list_issues` with `parentId` = map id, keep those not in `completed` / `canceled` columns, drop any with an open blocker or an assignee; first in map order wins.
- **Claim**: `update_issue` with `assigneeUserId` (from `get_current_user`), the session's first write.
- **Resolve**: `add_comment` with the answer, move the ticket to the `completed` column, then append a context pointer (gist + link) to the map's Decisions-so-far.
