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
    "infrastructure/ssh-hosts"
  ];

  secretsAsEnvironmentVariables = {
    "credentials/glab-token" = "GITLAB_TOKEN";
    "credentials/jira-api-token" = "JIRA_API_TOKEN";
  };

  secretFileExists = name: builtins.pathExists (../../../secrets/${name}.age);

  environmentVariableSecretNames = builtins.filter secretFileExists (
    builtins.attrNames secretsAsEnvironmentVariables
  );

  allSecretNames =
    (builtins.filter secretFileExists secretsWithoutEnvironmentVariables)
    ++ environmentVariableSecretNames;

  allSecrets = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = makeSecret name;
    }) allSecretNames
  );

  sourceSecretsPath = "${secretsDirectory}/source-secrets.sh";

  generateSourceSecretsLine =
    name:
    let
      environmentVariableName = secretsAsEnvironmentVariables.${name};
      secretPath = "${secretsDirectory}/${builtins.baseNameOf name}";
    in
    ''echo "export ${environmentVariableName}=\"\$(cat '${secretPath}')\"" >> "${sourceSecretsPath}"'';

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
    + ''

      echo "[agenix] generating source-secrets.sh..."
      rm -f "${sourceSecretsPath}"
      touch "${sourceSecretsPath}"
      chmod 0600 "${sourceSecretsPath}"
    ''
    + lib.concatMapStringsSep "\n" generateSourceSecretsLine environmentVariableSecretNames
    + ''

      chmod 0400 "${sourceSecretsPath}"
    ''
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
