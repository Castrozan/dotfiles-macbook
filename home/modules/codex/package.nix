{ pkgs, ... }:
let
  fetchPrebuiltBinary = import ../../../lib/fetch-prebuilt-binary.nix { inherit pkgs; };

  version = "0.128.0";

  platformBinaryHashBySystem = {
    "x86_64-linux" = {
      platform = "x86_64-unknown-linux-gnu";
      sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
    "aarch64-darwin" = {
      platform = "aarch64-apple-darwin";
      sha256 = "sha256-8GggLoqJjCQMjAaEAbzNMLp7VvYfX/zRSD1UXUeq89U=";
    };
  };

  currentSystem = platformBinaryHashBySystem.${pkgs.stdenv.hostPlatform.system};

  codexUnwrapped = fetchPrebuiltBinary {
    pname = "codex";
    inherit version;
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-${currentSystem.platform}.tar.gz";
    inherit (currentSystem) sha256;
    binaryName = "codex";
    archiveBinaryPath = "codex-${currentSystem.platform}";
  };

  codex = pkgs.symlinkJoin {
    name = "codex-${version}";
    paths = [
      (pkgs.writeShellScriptBin "codex" ''
        export NPM_CONFIG_PREFIX="/nonexistent"
        exec ${codexUnwrapped}/bin/codex \
          --model "gpt-5.4" \
          --sandbox "danger-full-access" \
          --ask-for-approval "never" \
          --no-alt-screen \
          "$@"
      '')
    ];
    meta.priority = 4;
  };
in
{
  home.packages = [ codex ];
  home.file.".local/bin/codex".source = "${codex}/bin/codex";
}
