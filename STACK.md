# STACK.md — running a project locally and as a dev preview (canonical)

Every project, whatever its technology (Node API, Next.js/Payload, SilverStripe,
WordPress), has one script at its root, `./stack.sh`, with the same commands. Agents,
the dev preview on the agent server and people use only this script; nobody starts
dev servers or containers by hand.

## The contract

```
./stack.sh start      # start everything; idempotent; returns when healthy (or fails)
./stack.sh stop       # stop everything; keeps data volumes
./stack.sh restart    # stop + start (used after dev moves)
./stack.sh status     # exit 0 only when healthy; prints what runs where
./stack.sh url        # prints the URL to open, e.g. http://127.0.0.1:3500/
./stack.sh logs       # recent logs of the app and services
```

Rules:

1. **Ports come from the port registry.** Each project owns a 20-port block in
   `factory-ops` (`registers/PORTS.md`). The script takes the block from
   `STACK_BASE_PORT` (default: the project's block) and uses fixed offsets:
   `.0` app, `.1` API/backend, `.2` database, `.3` extra database, `.4` search,
   `.5/.6` mail SMTP/UI, `.7-.9` extras. It never picks a port on its own.
2. **Loopback only.** Everything binds to `127.0.0.1`, never `0.0.0.0`. In compose
   files publish ports as `"127.0.0.1:${DB_PORT}:5432"`. The owner reaches a preview
   through an SSH tunnel; nothing is reachable from the network.
3. **Containers run in the agent's own (rootless) Docker** on the agent server, or the
   owner's Docker locally. Compose project name `<project>-<instance>`
   (`STACK_INSTANCE`, default `local`; the dev preview uses `preview`), so instances
   never share containers or volumes.
   On the agent server `STACK_INSTANCE` and `STACK_BASE_PORT` are always set (the
   agents' test ports, instance `agent`); the defaults are for the owner's laptop only.
   Compose services do not use `restart: always` or `unless-stopped`, so nothing comes
   back by itself after `stop` or after its workspace is gone.
4. **Development secrets only, outside the repository.** On first start the script
   writes random values to `~/.local/state/stack/<project>-<instance>.env`, outside the
   working tree, so `factory-check` never flags them and they can never be committed.
   They never include client data, production credentials or the project's model key.
5. **Stop means everything.** The app runs in its own process group; `stop` ends the
   whole group (watchers included) and the compose services, keeping data volumes.
6. **Healthy means usable.** `start` waits for the app's health URL and fails with the
   last log lines if it does not come up. The health URL proves the app can do its job,
   not only that the process answers. It returns 200 only when all of these hold, and
   otherwise 503, with a short JSON body naming each check and its result (no secrets):
   - **its own database**: the script passes `STACK_INSTANCE` to the app; the app
     records the instance name in its database on first start and health fails when
     the database it reached belongs to another instance (a stray container on the
     same port then shows up at once instead of silently serving the wrong data);
   - **migrations**: every migration in the code has been applied;
   - **data**: a real query against the database succeeds (not only a connection);
   - **services**: every service the app needs (extra database, search, mail, an
     external API it cannot work without) answers.
   Checks stay cheap (well under a second); the preview watchdog calls it every two
   minutes.
7. **No interactive prompts**, so the preview service can run it unattended.

## Where it runs

| Where | Who starts it | Instance |
| --- | --- | --- |
| Owner's laptop | the owner, with `./stack.sh` (or the project's `.ps1` on Windows) | `local` |
| Agent server, dev preview | the preview service, on demand when the owner opens it | `preview` |
| Agent server, task workspace | nobody: agents run tests and gates there, not the stack; test databases use the project's test ports (`$FACTORY_TEST_PORTS`, the second half of its block) | `agent` |

The dev preview shows the latest `dev` and runs only while the owner uses it. The owner
opens it with `factory-preview <PROJECT>` on the laptop: that starts the stack on the
agent server if needed and opens an SSH tunnel to the project's ports. While it is
open, a push to `dev` (by `finish-work`) is picked up within about two minutes and the
stack restarts. Two hours after the tunnel closes the preview service runs
`./stack.sh stop` (data volumes kept); the next open starts it again.

## Template

`templates/stack.sh` implements the contract; a project fills in its compose file,
its app command, its health path and its `prepare` step (installing dependencies,
migrations, seed data).
