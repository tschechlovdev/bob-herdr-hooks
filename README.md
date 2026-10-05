# bob-herdr-hooks

These hooks report [IBM Bob Shell](https://www.npmjs.com/package/bobshell) state to [herdr](https://github.com/herdrdev/herdr). They follow herdr's [add-herdr-support](https://herdr.dev/docs/add-herdr-support/) contract, so they work with stock herdr and need no herdr changes.

Once installed, a herdr pane running `bob` shows the `bob` agent as `working` or `idle`. After a herdr restart, the pane reopens the same task with `bob --resume <task-id>`.

## Requirements

- herdr 0.9.2 or later. Earlier versions reject the resume command, and the script then falls back to a plain state report.
- Bob Shell, with global settings at `~/.bob/settings/settings.json`
- `python3`

## Install

```sh
python3 install.py              # add the hooks to ~/.bob/settings/settings.json
python3 install.py --uninstall  # remove them again
```

The installer registers `herdr-bob.sh` by absolute path, so keep this folder where it is or re-run the installer after moving it. It keeps all other settings. Running it again replaces its own entries instead of adding duplicates.

## Event mapping

| Bob hook | Reported to herdr |
|---|---|
| `SessionStart` | `idle` + task ID + `bob --resume <task-id>` |
| `UserPromptSubmit`, `PreToolUse` | `working` |
| `Stop` | `idle` |

Outside herdr the script does nothing. It never writes to stdout, because Bob adds hook stdout to the model context. It always exits 0.

## Known limitations

- **No `blocked` state.** Bob has no permission-request hook, so herdr cannot see approval prompts from hooks alone. Screen detection is needed for that. A herdr fork with native Bob detection handles it.
- **The agent appears after the first prompt.** Bob fires `SessionStart` when the task is created at the first prompt, not when the TUI launches.
- **No exit hook.** herdr clears the agent once the pane returns to the shell prompt.

## Debugging

Set `HERDR_BOB_DEBUG_LOG` to append each hook event to a file:

```sh
HERDR_BOB_DEBUG_LOG=/tmp/bob-hooks.log bob
```

Each line records the event name, task ID and `SessionStart` source.
