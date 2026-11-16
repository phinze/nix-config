# Previewing on the Mac

Dev servers here run on foxtrotbase, and Paul's browser is on the Mac. Nothing
is forwarded on its own.

When you start a server Paul will want to open (a UI to look at, an API a Mac
app will call), print its URL as `http://localhost:PORT/` on a line of its
own. Paul ⌘-clicks it in Rex, which forwards a port on the Mac to that port
here and opens it in his browser.

Your own checks (curl, tests, agent-browser) reach the server on foxtrotbase's
localhost and don't need a forward.

Don't run `rex forward open` for this: run here, it listens on foxtrotbase,
not on the Mac. Don't reach for `bankshot wrap` or `bankshot forward` either;
Paul keeps `wrap` for OAuth logins, not previews.
