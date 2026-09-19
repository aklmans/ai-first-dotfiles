# AI Workflow Router Roadmap

Feature growth is frozen. Keep local prompt rendering, reusable snippets/exports
and the explicit coding-agent terminal menu working. They do not require text
execution, extra subscriptions, another launcher or background context capture.

Router 2.5 gates each text request behind an explicit recipient and a reviewed
adapter. Stock text adapters are quarantined. The full contract is in
`docs/tools/ai-router/safety.md`; old routing defaults are metadata only.

Only reopen text execution for an actual workflow, one adapter at a time:

1. Verify explicit stdin and recipient/locality with supported client versions.
2. Verify no tools, MCP, hooks, project discovery or hidden retention. Unsupported
   versions refuse; a read-only coding-agent flag is insufficient.
3. Verify timeout/cancel/ordinary-descendant cleanup plus remote cancellation
   separately. Local process exit does not establish that billing stopped.
4. Add recipient/input preview to a GUI only if users need GUI execution. Until
   then modified-key run gestures refuse and plain render gestures remain.

Deferred, not promised: richer templating, generated-at-install exports,
context-aware ranking, extra providers and a replacement chooser. Do not expand
these just to increase feature count. Custom adapters remain trusted local code,
not sandboxed plugins, regardless of a text-contract marker.

Not planned: automatic text replacement, default-hotkey provider calls, ambient
project/clipboard collection for text requests or migration to an AI platform.
