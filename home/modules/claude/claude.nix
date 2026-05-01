{ pkgs, ... }:
let
  fetchPrebuiltBinary = import ../../../lib/fetch-prebuilt-binary.nix { inherit pkgs; };

  version = "2.1.126";

  bucket = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";

  platformBinaryHashBySystem = {
    "x86_64-linux" = {
      platform = "linux-x64";
      sha256 = "sha256-/OlpaNJ1Fh/2WkwZ/GQ078aXPZ9tNdw5kqK6BVPKwY4=";
    };
    "aarch64-darwin" = {
      platform = "darwin-arm64";
      sha256 = "sha256-h6HQUBjOrfwf5ha/wQJisFA/UZhvSvLcQtHthW7T97s=";
    };
  };

  currentSystem = platformBinaryHashBySystem.${pkgs.stdenv.hostPlatform.system};

  claude-code-unwrapped = fetchPrebuiltBinary {
    pname = "claude-code-unwrapped";
    inherit version;
    url = "${bucket}/${version}/${currentSystem.platform}/claude";
    inherit (currentSystem) sha256;
    binaryName = "claude";
  };

  claude-code = pkgs.writeShellScriptBin "claude" ''
    export NPM_CONFIG_PREFIX="/nonexistent"
    export DISABLE_AUTOUPDATER=1
    exec ${claude-code-unwrapped}/bin/claude "$@"
  '';
in
{
  home = {
    packages = [ claude-code ];
  };
}
