let
  macbook_personal_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICpNZt8hGVbToPSE0nqVFXsGSM3Zae2tAH/lmVN5rD1x";
  macbook_work_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFjXqZMBU/AfIw4V6blTH46DZJbW2IJeO7rk75u/1Fhm";
  all_keys = [
    macbook_personal_key
    macbook_work_key
  ];
in
{
  "credentials/obsidian-headless-auth-token.age".publicKeys = all_keys;
  "credentials/obsidian-headless-sync-config.age".publicKeys = all_keys;
  "credentials/glab-token.age".publicKeys = all_keys;
  "credentials/jira-api-token.age".publicKeys = all_keys;
}
