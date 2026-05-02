{ lib, pkgs, ... }:
let
  installScript = ''
    if command -v tailscale >/dev/null 2>&1; then
      exit 0
    fi

    echo "[tailscale] CLI not found, installing via Homebrew..."

    if ! command -v brew >/dev/null 2>&1; then
      echo "[tailscale] ERROR: Homebrew is required to install tailscale on macOS." >&2
      echo "[tailscale]        Install brew first: https://brew.sh" >&2
      exit 1
    fi

    brew install tailscale

    echo ""
    echo "[tailscale] Install complete. To start the daemon and join the tailnet:"
    echo "[tailscale]   sudo brew services start tailscale"
    echo "[tailscale]   sudo tailscale up"
    echo ""
    echo "[tailscale] A browser will open to authenticate. Use the same Tailscale account"
    echo "[tailscale] as your other devices (castro.lucas290@gmail.com)."
  '';
in
{
  home.activation.installTailscaleDaemon = lib.mkIf pkgs.stdenv.isDarwin (
    lib.hm.dag.entryAfter [ "writeBoundary" ] installScript
  );
}
