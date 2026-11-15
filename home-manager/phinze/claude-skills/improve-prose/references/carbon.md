# Running the Carbon revision

## When to use it

Send Carbon the first draft of prose meant for human readers: PR and issue
bodies, code comments, docs, plans, and research notes. Send the first draft
rather than a polished one, because a careful draft gains little from a second
pass and Carbon tends to reshuffle it.

Skip Carbon if you are a Gemini model yourself. Also skip it for chat replies,
text of a sentence or two, text Paul wrote or has already revised, and quoted or
attributed words.

The draft leaves the machine for Google's API. Use it freely for public
repositories and Paul's own notes, and ask before sending prose from a private
work repository.

## The call

Resolve `scripts/carbon` relative to the skill's `SKILL.md`. Pass only the draft
and the facts, since the script already sends the skill's rubric, the Voice
section of Paul's global instructions, and samples of his own writing:

```bash
"$carbon" draft.md --facts facts.md > revised.md
```

Put what is true in `facts.md`, independent of the draft's wording: the diff
summary, commit messages, test results, decisions, and open caveats. Add
`--brief "..."` for instructions specific to one edit.

For code comments, pass the whole source file with `--code`. Carbon edits only
the comments, and the script exits 2 if anything outside a comment changed. If
it exits 2, discard the output instead of patching it.

A call usually takes seconds. For a long or tangled draft, pass
`--thinking medium`. That can take a few minutes, so start it in the background
when there is other work to do.

The script reads `GEMINI_API_KEY`, falling back to `op://cli/gemini/credential`
in 1Password (which can raise a 1Password prompt on Paul's Mac).
