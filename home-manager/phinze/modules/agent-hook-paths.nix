{ config, lib, ... }:
{
  options.phinze.agentHooks.sophonCommand = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    description = ''
      sophon's hook command with the binary resolved through the user profile
      rather than a bare store path.

      Agent harnesses read their hook config once at session start and hold it
      for the life of the session. A store path pins the binary that existed at
      switch time; when nix-config-sync bumps an input and the old generation
      rolls off the profile, a GC can delete that path out from under a session
      that is still running. The hook then fails with exit 127 (command not
      found) on its next event. A profile path re-resolves on every invocation.
    '';
  };

  # Upstream owns the flag construction; we rewrite only the binary location,
  # so a change to sophon's hook interface still flows through.
  config.phinze.agentHooks.sophonCommand =
    lib.replaceStrings [ "${config.services.sophon.package}" ] [ config.home.profileDirectory ]
      config.services.sophon.hookCommand;
}
