# Tooling

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
