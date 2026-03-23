{
  lib,
  pkgs,
  config,
  ...
}:
let
  nodejs = pkgs.nodejs_22;
  obsidianHeadlessVersion = "0.0.5";
  npmPrefixDirectory = "${config.home.homeDirectory}/.local/share/obsidian-headless-npm";
  vaultPath = "${config.home.homeDirectory}/vault";

  nodeGypBuildDependencies = lib.concatStringsSep ":" [
    "${nodejs}/bin"
    "${pkgs.python3}/bin"
    "${pkgs.gnumake}/bin"
  ];

  installObsidianHeadlessViaNpm = pkgs.writeShellScript "obsidian-headless-install" ''
    set -euo pipefail
    export PATH="${nodeGypBuildDependencies}:''${PATH:+:$PATH}"
    export NPM_CONFIG_PREFIX="${npmPrefixDirectory}"
    OB_BIN="${npmPrefixDirectory}/bin/ob"

    if [ -x "$OB_BIN" ]; then
      INSTALLED_VERSION="$("$OB_BIN" --version 2>/dev/null || echo "unknown")"
      if [ "$INSTALLED_VERSION" = "${obsidianHeadlessVersion}" ]; then
        exit 0
      fi
    fi

    ${nodejs}/bin/npm install -g "obsidian-headless@${obsidianHeadlessVersion}" \
      --prefix "${npmPrefixDirectory}" \
      --registry "https://registry.npmjs.org/"
  '';

  obsidianHeadlessWrapper = pkgs.writeShellScriptBin "ob" ''
    export PATH="${nodejs}/bin:''${PATH:+:$PATH}"
    export NPM_CONFIG_PREFIX="${npmPrefixDirectory}"
    exec "${npmPrefixDirectory}/bin/ob" "$@"
  '';

  obsidianHeadlessSyncScript = pkgs.writeShellScript "obsidian-headless-sync" ''
    export PATH="${nodejs}/bin:''${PATH:+:$PATH}"
    export NPM_CONFIG_PREFIX="${npmPrefixDirectory}"

    OB_BIN="${npmPrefixDirectory}/bin/ob"
    if [ ! -x "$OB_BIN" ]; then
      echo "obsidian-headless not installed. Run 'ob --version' to trigger install." >&2
      exit 1
    fi

    exec "$OB_BIN" sync --continuous --path "${vaultPath}"
  '';
in
{
  home = {
    packages = [
      obsidianHeadlessWrapper
    ];

    activation.installObsidianHeadlessViaNpm = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      run ${installObsidianHeadlessViaNpm}
    '';
  };

  launchd.agents.obsidian-headless-sync = {
    enable = true;
    config = {
      Label = "com.dotfiles.obsidian-headless-sync";
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${obsidianHeadlessSyncScript}"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/obsidian-headless-sync.log";
      StandardErrorPath = "/tmp/obsidian-headless-sync.log";
    };
  };
}
