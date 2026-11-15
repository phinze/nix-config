# Previewing on the Mac

Dev servers here run on foxtrotbase, and Paul's browser is on the Mac. Nothing
is forwarded on its own: bankshot's auto-forward is off.

When you start a server Paul will want to open (a UI to look at, an API a Mac
app will call), run it under `bankshot wrap -- <cmd>` so its port shows up at
`localhost:PORT` on the Mac and goes away when the command exits. Then tell
Paul the URL; nothing else tells him the forward exists.

Your own checks (curl, tests, agent-browser) reach the server on foxtrotbase's
localhost and don't need a forward.

If the server is already running, use `bankshot forward PORT`, and
`bankshot unforward PORT` when you're done with it. `bankshot list` shows
what's forwarded.
