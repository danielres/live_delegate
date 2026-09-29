{
  pkgs,
  lib,
  config,
  ...
}:

{
  packages =
    with pkgs;
    [
      beam27Packages.elixir-ls
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      inotify-tools
      libnotify
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      terminal-notifier
      darwin.apple_sdk.frameworks.CoreFoundation
      darwin.apple_sdk.frameworks.CoreServices
    ];

  dotenv.disableHint = true;

  languages.elixir = {
    enable = true;
  };

  # needed by elixir-ls:
  languages.erlang = {
    enable = true;
  };

  process.manager.implementation = "overmind";

  # enable iex history
  env =
    {
      ERL_AFLAGS = "-kernel shell_history enabled";
    }
    // lib.optionalAttrs pkgs.stdenv.isLinux {
      PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH = lib.getExe pkgs.chromium;
    };
  #
  # env.REDIS_URL = config.secretspec.secrets.REDIS_URL;
}
