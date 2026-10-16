# Code style

Write code for the next person reading it. Prefer a descriptive name and a short block over dense expressions.

- Swift values, properties and functions use lower camel case. Types and protocols use upper camel case, matching Apple's APIs. Keep established acronyms such as `ID` and `URL` readable.
- Expand function bodies, guards, branches and loops. Put one statement on each line. Wrap long argument lists rather than squeezing them together.
- Use four spaces in Swift and Python, and two in browser code. Separate logical steps with blank lines; use additional space for larger sections only when it helps scanning. Avoid randomly varying whitespace.
- Preserve persistence keys, Codable fields, localization keys, accessibility identifiers, framework requirements and third-party APIs when renaming local variables. Those names can be compatibility contracts.
- Keep standard Python snake case for Python APIs. Use descriptive camel case in Swift and JavaScript. Short mathematical coordinates such as `x` and `y` are appropriate when their meaning is clear.
- Comments explain a constraint, decision or unit. Do not add narration that merely repeats the next line.
- Do not reformat generated data, compiled frameworks or licensed artwork as application source.

## Repeatable formatting

The repository's `.swiftformat`, `.prettierrc.json` and `pyproject.toml` record the settings. SwiftFormat is restricted to formatting rules; it does not modernize APIs or rewrite application behavior.

```sh
swiftformat Finn tools Design/Presentation/Finn-Keynote-2026-10-16/production/source --config .swiftformat
black tools tests docs/validation Design/Presentation/Finn-Keynote-2026-10-16/production/source
prettier --write 'site/*.{html,css}' 'Design/Presentation/Finn-Keynote-2026-10-16/*.{html,js}'
```

Use `swiftformat --lint` or `black --check` to check without changing files. Run the existing tests when changing logic or names; a formatting check alone does not establish correctness.
