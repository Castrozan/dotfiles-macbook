{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  secretsDirectory = "${config.home.homeDirectory}/.secrets";

  identityKeyPath = "${config.home.homeDirectory}/.ssh/id_ed25519";

  makeSecret = name: {
    file = ../../../secrets/${name}.age;
    path = "${secretsDirectory}/${builtins.baseNameOf name}";
  };

  secretsWithoutEnvironmentVariables = [
    "credentials/obsidian-headless-auth-token"
    "credentials/obsidian-headless-sync-config"
  ];

  secretFileExists = name: builtins.pathExists (../../../secrets/${name}.age);

  allSecretNames = builtins.filter secretFileExists secretsWithoutEnvironmentVariables;

  allSecrets = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = makeSecret name;
    }) allSecretNames
  );

  decryptAllSecretsScript = pkgs.writeShellScript "decrypt-agenix-secrets" (
    ''
      set -euo pipefail
      mkdir -p "${secretsDirectory}"
    ''
    + lib.concatMapStringsSep "\n" (
      name:
      let
        secret = allSecrets.${name};
      in
      ''
        echo "[agenix] decrypting ${name}..."
        rm -f "${secret.path}"
        ${lib.getExe pkgs.age} -d -i "${identityKeyPath}" -o "${secret.path}" "${secret.file}"
        chmod 0400 "${secret.path}"
      ''
    ) allSecretNames
  );
in
{
  imports = [ inputs.agenix.homeManagerModules.default ];

  age = {
    identityPaths = [ identityKeyPath ];
    secrets = allSecrets;
  };

  home.activation.agenix = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    run ${decryptAllSecretsScript}
  '';
}
