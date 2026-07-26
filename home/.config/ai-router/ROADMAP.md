# AI Workflow Router Roadmap

What is planned next, in rough priority order. The design rules behind these, and
the history of what has already been decided, are in
`docs/tools/ai-router/design-notes.md`.

- **Template upgrade.** Rendering is plain string replacement. Add default values
  and simple conditionals - enough for prompts that need optional context without
  pulling in a template engine.
- **Generate the snippet exports at install time.** `exports/*.json` are build
  artifacts that are currently committed and diffed by a smoke test, so editing a
  snippet without re-exporting fails CI. Generating them during install removes
  the trap.
- **More runtime context, under strict privacy limits.** Browser URL, repository
  path and active file are the useful ones. Each must be independently optional,
  never logged in full, and kept off the direct hotkey path if it is slow.
- **A retrieval surface better than the Hammerspoon chooser.** Raycast snippet
  import first, since the export already exists. A dedicated app only if the data
  model proves itself there.
- **Context-aware ranking.** `state/usage.json` already records what gets used;
  ranking by frontmost app or project would make the palette useful without
  typing.

Not planned, on purpose:

- No provider execution on the default `CapsLock + letter` gesture.
- No auto-replacement of selected text.
- No growth of the Hammerspoon chooser into a Raycast replacement.
