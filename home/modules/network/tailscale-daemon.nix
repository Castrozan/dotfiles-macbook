{ lib, pkgs, ... }:
let
  brewCandidatePaths = [
    "/opt/homebrew/bin/brew"
    "/usr/local/bin/brew"
  ];

  installScript = ''
    if command -v tailscale >/dev/null 2>&1; then
      exit 0
    fi

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

    echo "[tailscale] CLI not found, installing via Homebrew..."
    "$BREW" install tailscale

    echo ""
    echo "[tailscale] Install complete. To start the daemon and join the tailnet:"
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
