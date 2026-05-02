{
  config,
  lib,
  pkgs,
  ...
}:
let
  sshHostsSecretExists = builtins.pathExists ../../../secrets/infrastructure/ssh-hosts.age;

  sshHostsDecryptedPath = "${config.home.homeDirectory}/.secrets/ssh-hosts";

  dellg15HostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICC9JN3f6UmPSmDUSfoSH+0tzQc66LEWLn9A+/b4xJCg";

  inboundAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDXjYtc1kccaHnEeCnLfn5jB+3K8ULqIIsFoq+4pc+fX zanoni@dellg15"
  ];

  authorizedKeysScript = pkgs.writeShellScript "ensure-inbound-authorized-keys" ''
    set -euo pipefail
    SSH_DIR="$HOME/.ssh"
    AUTHORIZED="$SSH_DIR/authorized_keys"

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    touch "$AUTHORIZED"
    chmod 600 "$AUTHORIZED"

    ${lib.concatMapStringsSep "\n" (key: ''
      if ! grep -qxF ${lib.escapeShellArg key} "$AUTHORIZED"; then
        printf '%s\n' ${lib.escapeShellArg key} >> "$AUTHORIZED"
      fi
    '') inboundAuthorizedKeys}
  '';

  generateScript = pkgs.writeShellScript "generate-private-ssh-config" ''
    set -euo pipefail
    HOSTS="${sshHostsDecryptedPath}"
    SSH_DIR="$HOME/.ssh"
    CONFIG_DIR="$SSH_DIR/config.d"
    PRIVATE_HOSTS="$CONFIG_DIR/private-hosts"
    KNOWN_HOSTS_PRIVATE="$SSH_DIR/known_hosts_private"

    mkdir -p "$CONFIG_DIR"

    if [ ! -f "$HOSTS" ]; then
      rm -f "$PRIVATE_HOSTS" "$KNOWN_HOSTS_PRIVATE"
      exit 0
    fi

    declare -A hosts
    while IFS='=' read -r key value; do
      [ -n "$key" ] && hosts["$key"]="$value"
    done < "$HOSTS"

    {
      if [ -n "''${hosts[dellg15]:-}" ]; then
        printf 'Host dellg15\n'
        printf '    HostName %s\n' "''${hosts[dellg15]}"
        printf '    User zanoni\n'
        printf '    IdentityFile ~/.ssh/id_ed25519_dellg15\n\n'
      fi
    } > "$PRIVATE_HOSTS"

    {
      if [ -n "''${hosts[dellg15]:-}" ]; then
        printf '%s ${dellg15HostKey}\n' "''${hosts[dellg15]}"
      fi
    } > "$KNOWN_HOSTS_PRIVATE"

    if [ -s "$KNOWN_HOSTS_PRIVATE" ]; then
      touch "$SSH_DIR/known_hosts"
      cat "$KNOWN_HOSTS_PRIVATE" >> "$SSH_DIR/known_hosts"
      sort -u "$SSH_DIR/known_hosts" -o "$SSH_DIR/known_hosts"
    fi
  '';
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = lib.mkIf sshHostsSecretExists [ "~/.ssh/config.d/*" ];

    matchBlocks = {
      "*" = { };

      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/id_rsa";
      };
      "git.coates.io" = {
        hostname = "git.coates.io";
        user = "git";
        identityFile = "~/.ssh/id_ed25519_coates";
      };
    };
  };

  home.activation.generatePrivateSshConfig = lib.mkIf sshHostsSecretExists (
    lib.hm.dag.entryAfter [ "agenix" ] ''
      run ${generateScript}
    ''
  );

  home.activation.ensureInboundAuthorizedKeys = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${authorizedKeysScript}
  '';
}
