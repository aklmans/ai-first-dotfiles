# Your own agent skills

Skills you write live here, one directory each, and the `skills` module deploys
them to `~/.agents/skills/`.

`.agents/skills/` rather than `.claude/skills/` on purpose: SKILL.md is an open
format, and `.agents/skills/` is the path agents other than Claude Code look in
as well. One copy, read by whichever agent you happen to be using.

```
home/.agents/skills/
└── my-skill/
    ├── SKILL.md        # required
    ├── reference.md    # optional supporting files
    └── scripts/
```

`SKILL.md` starts with YAML frontmatter. `name` and `description` are what make
a skill findable — the description is how an agent decides whether this is the
skill for what you just asked:

```markdown
---
name: my-skill
description: What this does, and when it should be used.
---

The instructions themselves, as ordinary Markdown.
```

`./bootstrap/setup.sh skills` deploys these and checks each one has a `SKILL.md`
with both fields. `./bootstrap/setup.sh doctor skills` re-checks without writing
anything.

## This is the half you own

Skills written by other people are a different problem, and have a different
answer: list them in `manifests/skills/skills-default.txt` and run
`./bootstrap/skills.sh`, which hands the fetching to `npx skills`. Files here are
yours, tracked in this repository, and restored by `bootstrap/uninstall.sh` if
you remove the module — none of which is true of a skill you downloaded.
