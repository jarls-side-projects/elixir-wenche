{
  pkgs,
  mixEnv,
  beamPackages,
}: let
  basePackages = with pkgs; [
    elixir
    hex
    mix2nix
  ];

  inputs = with pkgs;
    basePackages
    ++ lib.optionals stdenv.isLinux [inotify-tools]
    ++ lib.optionals stdenv.isDarwin
    (with darwin.apple_sdk.frameworks; [CoreFoundation CoreServices]);

  hooks = ''
    mkdir -p .nix-mix .nix-hex
    export MIX_HOME=$PWD/.nix-mix
    export HEX_HOME=$PWD/.nix-mix
    export PATH=$MIX_HOME/bin:$HEX_HOME/bin:$PATH

    export MIX_ENV=${mixEnv}

    export LANG=en_US.UTF-8
    export ELIXIR_ERL_OPTIONS="+fnu"
    export ERL_AFLAGS="-kernel shell_history enabled"
  '';
in
  pkgs.mkShell {
    buildInputs = inputs;
    shellHook = hooks;
  }
