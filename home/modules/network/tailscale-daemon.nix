{ lib, pkgs, ... }:
let
  brewCandidatePaths = [
    "/opt/homebrew/bin/brew"
    "/usr/local/bin/brew"
  ];

  tailscaleCandidatePaths = [
    "/opt/homebrew/bin/tailscale"
    "/usr/local/bin/tailscale"
  ];

  installScript = ''
    for candidate in ${lib.concatStringsSep " " tailscaleCandidatePaths}; do
      if [ -x "$candidate" ]; then
        exit 0
      fi
    done

    BREW=""
    for candidate in ${lib.concatStringsSep " " brewCandidatePaths}; do
      if [ -x "$candidate" ]; then
        BREW="$candidate"
        break
      fi
    done

    if [ -z "$BREW" ]; then
      echo "[tailscale] ERROR: Homebrew is required to install tailscale on macOS." >&2
      echo "[tailscale]        Install brew first: https://brew.sh" >&2
      exit 1
    fi

    if "$BREW" list --formula tailscale >/dev/null 2>&1; then
      echo "[tailscale] formula installed but symlink missing, relinking..."
      "$BREW" link --overwrite tailscale
    else
      echo "[tailscale] CLI not found, installing via Homebrew..."
      "$BREW" install tailscale
    fi

    echo ""
    echo "[tailscale] To start the daemon and join the tailnet:"
    echo "[tailscale]   sudo brew services start tailscale"
    echo "[tailscale]   sudo tailscale up"
    echo ""
    echo "[tailscale] A browser will open to authenticate. Use the same Tailscale"
    echo "[tailscale] account as your other devices in the tailnet."
  '';
in
{
  home.activation.installTailscaleDaemon = lib.mkIf pkgs.stdenv.isDarwin (
    lib.hm.dag.entryAfter [ "writeBoundary" ] installScript
  );
}
