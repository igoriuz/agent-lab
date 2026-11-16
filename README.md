# agent-lab

**Status: discontinued (November 2026).** Kept as a reference, not maintained.
The documentation is in German; this page is the English entry point. The full
original concept is in [README.de.md](README.de.md).

agent-lab was a personal workshop for running coding agents from several
providers side by side on a home server (a Proxmox mini-PC), measuring them on
the same tasks, and reaching them from the phone through a Telegram bot. The
guiding idea: harnesses get replaced every few months, so the valuable parts
(skills, memory, evals, the record of what worked) should be plain Markdown and
JSON in Git, with one thin adapter per harness.

## What is worth a look

**An eval ladder with hidden acceptance tests** ([evals/](evals/)). A small
TypeScript project (subscriptions, paywall, receipt checks) and tasks in four
sizes. The acceptance test of each task is copied into the project only after
the agent has finished, so the agent cannot optimise against it. A run counts
as a success only if the hidden test passes, no existing test breaks and the
type check is green.

| Level | Task | What it tests |
|---|---|---|
| S | enforce a constant nobody enforces | inferring intent from code |
| M | a feature across several files, with tests | real work |
| L | a refactoring that must keep behaviour | care |
| S′ | the same task as S, with an interface contract in the text | what a specification is worth |

Findings from September 2026, three runs per level (details in
[evals/README.md](evals/README.md), raw data in [evals/rohdaten/](evals/rohdaten/)):

- Cheap "flash" models through Hermes Agent: qwen3.7-flash 8/9,
  glm-5.3-flash 7/9, deepseek-v4-flash 6/9. Almost every failure was on S, the
  only level without an interface contract.
- With the contract (S′), GLM and DeepSeek went from 1/3 to 3/3, and were
  cheaper and faster per success. Write the contract first; the retry loop is
  only the safety net.
- The same ladder cost about $3.33 with grok-4.6 and $0.08 with glm-5.3-flash
  through OpenRouter.
- With the same model, Hermes Agent used 1.8 to 2.9 times fewer input tokens
  than oh-my-pi.

**A harness adapter contract** ([adapters/](adapters/)): `install.sh` brings
skills and memory to where a harness expects them, `run.sh` runs one task and
prints a fixed JSON result. Adapters exist for Claude Code, oh-my-pi, OpenCode
and Hermes Agent. A harness comparison is in
[evals/harness-vergleich.md](evals/harness-vergleich.md).

**A Telegram allowlist** ([bridge/](bridge/)): a pure function that checks
sender *and* chat on every update type that carries a sender, including
`callback_query` (approval buttons), and drops strangers silently. Tested
without network: `python3 bridge/test_allowlist.py`.

**A Hermes Agent write-up** ([orchestrator/hermes.md](orchestrator/hermes.md)):
running Hermes as the runtime with an SSH worker container, the `/goal` loop
(its judge fails open: never run it without a gate and a turn budget), and the
update traps found on the way.

## Why it stopped

The measuring part worked; the orchestration on top was barely used day to
day. From October 2026 every role ran through Claude Code, tiered by model and
effort ([config/models.yaml](config/models.yaml)), and the self-built back
channel lost to off-the-shelf tools.

## Layout

```
adapters/      one adapter per harness, see adapters/README.md
bin/           setup, eval runner, Proxmox and Telegram helpers
bridge/        Telegram allowlist and its tests
config/        model roles and the project manifest schema
evals/         test project, task ladder, results, raw data
orchestrator/  orchestrator draft and the Hermes Agent write-up
skills/        empty in the public version
```

Secrets are never in the repo: copy [.env.example](.env.example) to `.env`.

## License

MIT, see [LICENSE](LICENSE).
