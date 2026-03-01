# Tooling

## Available CLI Tools

The following non-standard commands are available globally:

- `jq` — JSON processing and transformation. Prefer over python for JSON.
- `yq` — YAML/TOML/XML processing (mikefarah/yq, Go version). Use for
  YAML/TOML the way you'd use jq for JSON.
- `python3` — stdlib-only interpreter (no pip). Use for data processing when
  jq/yq aren't sufficient. Do not attempt to pip install anything.
- `rg` (ripgrep) — fast recursive text search. Use instead of grep.
- `ast-grep` — structural code search using tree-sitter AST patterns.
- `gh` — GitHub CLI for PRs, issues, repos. Use instead of WebFetch for GitHub.
- `fzf` — fuzzy finder.

## ast-grep for Structural Search

When searching for code patterns — function definitions, type declarations,
imports, call sites, struct fields — prefer `ast-grep` over text-based search:

    ast-grep --lang <lang> -p '<pattern>'

ast-grep uses tree-sitter to match AST structure rather than raw text, making
it more accurate for queries like:

- Find function definitions: `ast-grep --lang python -p 'def $FUNC($$$ARGS)'`
- Find type declarations: `ast-grep --lang typescript -p 'type $NAME = $$$'`
- Find imports: `ast-grep --lang javascript -p 'import $$$FROM from "$MOD"'`

Use `$NAME` for single-node wildcards and `$$$NAME` for variadic (multi-node)
wildcards.

Fall back to Grep for:
- Literal string/comment search
- Regex patterns across file contents
- Languages ast-grep doesn't support

## Data Processing Preferences

For structured data, prefer purpose-built tools over general-purpose scripting:

1. **JSON** → `jq`
2. **YAML/TOML** → `yq`
3. **Tabular/complex transforms** → `python3` (stdlib: json, csv, re, pathlib,
   collections, itertools, etc.)
4. **Line-oriented text** → shell builtins, `awk`, `sed`
