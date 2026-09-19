# Text execution boundary (2.5)

The supported default is **render → review → use your chosen client**. This is
an optional dotfiles module, not an unattended agent platform. It does not need
another account, model subscription, context collector or background service.

## What changed

`render`, snippets, exports and the coding-agent terminal menu still work.
`run`/`prompt` require `--provider NAME` for **each invocation**; optional
`--fallback NAME,NAME` authorizes only those additional recipients, in that
order. Prompt frontmatter, `providers.default`, cached health and saved logins
are not authorization. Missing/invalid flags refuse before selection capture.

```bash
printf 'text to review' | ~/.config/ai-router/ai-router.sh render summarize
# Only after reviewing your own text-only adapter and its actual recipient:
printf 'text to send' | ~/.config/ai-router/ai-router.sh run summarize --provider my-text-api
```

There is currently **no enabled, pre-verified stock text adapter**. Codex,
Claude, Gemini, Kimi and Junie text adapters are quarantined, as is the old
Ollama wrapper. They refuse without starting the underlying client. Installing
or authenticating those clients does not remove the gate. The coding-agent
menu is independent and intentionally does not promise text-only isolation.
Old GUI execution gestures lack recipient selection and therefore refuse;
plain prompt-render hotkeys remain available. This is a compatibility change,
not an installation error. Do not work around it by restoring a default chain.

Why this conservative boundary:

- A read-only coding-agent sandbox can still read and use tools. Codex documents
  read-only execution separately from user config and MCP behavior; it is not
  a no-tools text interface. See [Codex non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode).
- Claude documents separate bare-mode, tools and MCP controls, including managed
  policy caveats. Those version/policy combinations have not been integration
  tested here. See [Claude CLI reference](https://code.claude.com/docs/en/cli-reference).
- An Ollama installation can use cloud models or a non-default host. A name or
  client-side environment flag does not establish a running server's local-only
  boundary. See [Ollama FAQ](https://docs.ollama.com/faq).

Reintroduce an adapter only for an actual need, with version-scoped evidence for
input handling, tools/MCP/hooks/project discovery, recipient/locality, session
retention and cancellation. Unsupported versions must refuse, not retry in a
wider permission mode. No new API integration or credentials are required by
this remediation.

## What the runner enforces

- Non-empty, selected input. Failed selection does not fall back to clipboard;
  use `--from clipboard` to choose it explicitly. Text requests do not collect
  the frontmost app, window title or a second clipboard context. Render-only
  retains its existing local context behavior for review.
- Adapters run in a private, disposable neutral directory. Prompt input goes
  through stdin, not argv; router input/context environment copies are removed.
- Capability probing and execution share a finite deadline (60 seconds by
  default, configurable from greater than zero to 3600 seconds). Input and
  stdout each have a 4 MiB limit. Diagnostic probes also have deadlines.
- Each probe/execution owns a new process group. On timeout, handled signal or
  completion, ordinary descendants are terminated, escalating TERM to KILL.
  A fallback starts only after completion is confirmed. Cancellation or an
  uncertain cleanup stops the chain. SIGTERM to the router shell is forwarded
  to its supervisor; foreground Ctrl-C and SIGHUP are covered too.
- Failed stdout and all provider stderr are discarded, not regex-redacted into
  logs or copied over the clipboard. Error records contain router-generated
  status metadata. Legacy raw-debug switches no longer enable raw retention.
  New runtime files use a restrictive umask. Successful output still goes to
  `cache/last-output.md`, and to the clipboard if the prompt requests it.

Status codes: `64` invalid request, `65` size limit, `66` no input/prompt,
`69` unavailable, `71` timeout, `75` cleanup unconfirmed, `78` unsupported text
contract; handled signals use `128 + signal`. Other adapter failures keep their
nonzero code, without their raw payload.

## What this does not enforce

Custom adapters are **trusted local executable code**, not sandboxed plugins.
They must implement `--text-contract` and return exactly `text-v1` after review;
copying the template alone refuses. That marker is an assertion, not proof.
The router cannot verify a script's honesty, constrain all inherited environment
variables, stop a daemon that deliberately leaves its process group, or guarantee
cleanup after SIGKILL, power loss or a killed supervisor. It cannot retract a
request already received remotely or guarantee cloud billing stops. Neutral cwd
alone does not block user config, HOME reads, MCP or hooks in a custom client.

Existing raw logs, cached selection/output and third-party client histories are
not bulk-cleaned by this change (existing log rotation still applies). Review
and remove them separately; do not submit them
as diagnostic attachments. `privacy.log_events: false` stops router event logs,
not output caching or external-client retention. Concurrent invocations still
share the last-output/selection metadata views; this is not a multi-job queue.

## Acceptance

Run this from the repository:

```bash
bash tests/run-all.sh home/.config/ai-router/tests/run.sh tests/smoke/ai_router_cli_smoke.sh
```

Fake
adapters cover explicit-only fallback, refusal, timeouts, output bounds,
descendant cleanup (including delayed writes), top-level TERM/INT/HUP and
non-retention of unrecognizable private failure text. No real provider request,
remote cancellation, permission dialog or cloud billing is tested.
