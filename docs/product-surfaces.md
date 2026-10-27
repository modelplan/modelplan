# ModelPlan product surfaces

ModelPlan has three entry points: the Mac App, the plugins, and the Skill. They use the same published recommendations and the same CLI data engine. Choose the entry point that fits where you want help; installing every surface is optional.

## Mac App: a dashboard for people

The Mac App presents your models, efforts, quota windows, reset times, and local activity in a dashboard. It sits alongside your coding agents. Its Settings is the home for installing the Claude Code and Codex plugins, so people can add automatic in-agent help from the dashboard. Plugin installation still requires a supported installer integration; the App must not invent a CLI command that does not exist.

New visual work belongs in the App and the website. The Codex plugin's existing panel remains available with its current features, but its visual feature set is frozen.

## Plugins: automatic help inside an agent

The Claude Code and Codex plugins bundle both the ModelPlan Skill and a pinned, checksum-checked CLI. They provide automatic hints inside the agent as well as explicit commands. Automatic hints default to on and can be turned off in setup. Turning them off silences the prompt hook; slash commands and the Codex panel remain usable.

Claude Code's status line is an optional display for model, effort, quota, and reset information. It is optional. In the current release it is the only source of the CLI's Claude Code quota snapshot; automatic Claude Code detection is coming. Without that snapshot Claude quota stays unknown, while public advice and other sources still work. Do not present the planned reader as already shipped.

## Skill: bring ModelPlan to any coding agent

The Skill works in any coding agent with Skill support, a shell, and anonymous HTTPS. It can answer model and effort questions from public data without an installed CLI.

When someone first asks about their own quota and the CLI is missing, the Skill asks once: “Install the ModelPlan CLI? It is checksum-checked and installs into ~/.local/bin.” It runs its pinned installer only after a yes. After a no, it does not ask again. Model and effort questions alone do not trigger an installation prompt.

The older `scripts/quota.py` helper remains available during the transition to CLI auto-detection, but is deprecated. It must not be presented as the long-term quota engine or as a reason to configure a status line.

## CLI: the shared data engine

The CLI ships with the App and plugins and is the quota upgrade for the standalone Skill. It reads published results, verifies and caches them, detects supported signed-in tools, and keeps personal readings on the user's machine. Clients display published verdicts rather than ranking models themselves.

Installing the CLI directly is an **Advanced** option for terminal users and integrations. It is not a fourth primary entry point. Installers verify release checksums and do not silently edit shell profiles or PATH.

## How the surfaces fit together

The adoption ladder is **Skill → Skill + CLI → plugin**: start with answers on demand, add local quota awareness, then add automatic in-agent help. The App sits alongside this ladder as the human-facing dashboard; it is not a required step. No surface switches the user's model or effort, and personal quota data is never uploaded.
