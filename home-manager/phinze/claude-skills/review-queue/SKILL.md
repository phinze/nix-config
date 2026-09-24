---
name: review-queue
description: Coordinate a whole batch of pending PR reviews from one session. Triage everything awaiting the user's review, handle the tiny ones inline, pitch review rigs for the rest, and keep a status board until the queue is empty. Use when asked to get through the review queue, work through open reviews, coordinate a pile of reviews, or act as a coordinator session for reviews.
---

# Review Queue

**One session holds the queue. Each substantial review happens in its own rig.**

This skill is the coordinator. It doesn't review deeply; `review-pr` does that
inside a review rig. The coordinator's job is to decide where the user's
attention goes, get the rigs ready before they're needed, and notice when a
PR's state changes out from under a review the user already posted.

## 1. Pull the queue

Fetch what's waiting, then enrich each PR. Keep the raw JSON in the scratchpad
so later passes can slice it without re-fetching.

    gh search prs --review-requested=@me --state=open \
      --json repository,number,title,author,createdAt,updatedAt,isDraft,url --limit 100

    gh pr view <n> -R <owner/repo> --json additions,deletions,changedFiles,\
    reviews,statusCheckRollup,mergeable,assignees,headRefOid,body

`reviewRequests` is often empty even for PRs the search returned, because the
request went to a team. Trust the search, not that field.

Alongside it, run `rig ls` to find review rigs that already exist (`pr-<n>`
ids) and any ticket or project rigs the PRs touch. A PR whose rig is already
working is in progress, not new work.

## 2. Triage

Show one table, smallest to largest, with an attention level per PR:

- **quick**: a handful of lines, one or two files. Read the diff right here.
- **light**: small and self-contained, or UI that mostly needs a look.
- **medium**: wide but shallow, or needs the user's taste (branding, UX copy).
- **heavy**: real logic change, migrations, anything that needs call-chain
  tracing.

Under the table, list the cross-links you found, since those are what the
user can't see from GitHub alone: an existing rig for the PR, a project rig
whose area it touches, a Linear ticket that already covers a concern the diff
raises. Linear search is cheap; when a diff makes you think "we should have a
ticket for this," look before proposing one.

Then propose an order. The default is quick wins first to clear the queue,
then the heaviest while the user is fresh, then the rest. Treat that as a
suggestion, not a rule.

## 3. Handle the quick ones inline

A quick PR doesn't need a rig. Read the diff, check the one or two things it
could get wrong, and draft the review in chat. Respect the `review-pr`
assignee mutex: if someone other than the user holds the PR, say so before
reviewing.

The usual draft-before-posting rule applies. A bare approval can go out as
soon as the user says so; anything with prose gets shown first. If a comment
promises a follow-up ("I'll note it on MIR-123"), that follow-up is part of
what the user is approving, so name it in the draft.

## 4. Pitch the rigs

    rig review <pr-url> < /dev/null

Outside a terminal, `rig review` prepares the tmux session and prints
`session ready ... attach manually` without switching the user's client. So
it's safe to pitch several in parallel from the coordinator. Each rig's agent
starts `/review-pr` on its own.

Afterward, report the set of rigs and the suggested order. Don't send the user
into a rig; they choose when to switch.

## 5. Keep the board

When the user checks in, refresh and redraw one board:

    gh pr view <n> -R <repo> --json state,reviewDecision,reviews,headRefOid,commits,updatedAt
    gh search prs --review-requested=@me --state=open   # new arrivals, and what's left
    rig ls                                               # rig state per pr-<n>

Per PR, show where it stands (approved / changes requested / merged / not yet
reviewed), which rig it has, and what happens next and whose move it is.

**Check whether the head moved after the user's review.** Compare the user's
latest review `submittedAt` with the last commit, or keep the `headRefOid` you
saw at review time. An approval that predates a new push still counts on
GitHub. If the push changed behavior or UI, say what changed so the user can
decide whether to look again before it merges. Replies from the author to bot
comments explain the push quickly.

If a review rig went idle, its agent probably finished a pass and is waiting
on the user. Say so. If a rig's PR has merged but the rig is still around,
flag it for teardown.

Don't declare the queue done just because every rig is idle. Done means every
PR in the queue has a posted review from the user. Check GitHub, not the rigs.

## 6. Wind down

Parking and tearing down mean different things, so pick the word carefully.
**Park** a rig that's waiting on someone else: it stays on disk and comes back
with `rig wake`. **Tear down** (`rig down`) a rig that's finished, with nothing
left to wait for.

For review rigs, what the user posted decides it. An approval finishes the
rig, so it's ready to tear down. A changes request means waiting on the
author's push, so it stays parked for the re-review. Tear rigs down only when
the user asks. `rig down` tears down whichever rig contains the cwd, so run it
from inside the target's basedir:

    cd ~/workspaces/<review-rig-basedir> && rig down < /dev/null

Never run it from the coordinator's own basedir.

The coordinator follows the same rule. Once every PR in the queue has a posted
review from the user, it's done: say it's ready to tear down, and stop.
Re-reviews come back through their parked rigs and the next queue pass, so
there's no reason to hold the coordinator open for them.
