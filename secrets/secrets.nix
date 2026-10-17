let
  keys = (import ../dendritic/ssh-keys.nix).flake.sshKeys;
  inherit (keys) AgentAge Droid Goofeus GoofyDesky GoofyDeskyRoot GoofyEnvy MacMini;
  piRecipients = [ Droid GoofyDesky GoofyEnvy Goofeus AgentAge MacMini ];
in
{
  # Encrypted private key for AgentAge (agent@Goofeus). Decryptable by Goofeus host
  # key (root) + GoofyDesky; placed owner=agent so HM age.identityPaths can use it.
  "agent-age-key.age" = {
    armor = true;
    publicKeys = [
      Goofeus
      GoofyDeskyRoot
    ];
  };
  "cloudflare-caddy.age" = {
    armor = true;
    publicKeys = [
      Goofeus
      GoofyDesky
    ];
  };

  "nextcloud-admin-pass.age" = {
    armor = true;
    publicKeys = [
      Goofeus
      GoofyDesky
    ];
  };

  "copyparty-goofy-pass.age" = {
    armor = true;
    publicKeys = [
      Goofeus
      GoofyDesky
      GoofyDeskyRoot
    ];
  };

  "glance-env.age" = {
    armor = true;
    publicKeys = [
      Goofeus
      GoofyDesky
    ];
  };

  "donetick-jwt.age" = {
    armor = true;
    publicKeys = [
      Goofeus
      GoofyDesky
    ];
  };

  "trek-env.age" = {
    armor = true;
    publicKeys = [
      Goofeus
      GoofyDesky
    ];
  };

  "trek-tailscale-auth.age" = {
    armor = true;
    publicKeys = [
      Goofeus
      GoofyDesky
    ];
  };

  "transmission-pia-vpn.age" = {
    armor = true;
    publicKeys = [
      Goofeus
      GoofyDesky
    ];
  };

  "radicale-htpasswd.age" = {
    armor = true;
    publicKeys = [
      Goofeus
      GoofyDesky
      GoofyEnvy
    ];
  };

  "restic-password.age" = {
    armor = true;
    publicKeys = [
      Goofeus
      GoofyDesky
    ];
  };

  "restic-b2-env.age" = {
    armor = true;
    publicKeys = [
      Goofeus
      GoofyDesky
    ];
  };

  "opencode-api-key.age" = {
    armor = true;
    publicKeys = piRecipients;
  };

  "openrouter-api-key.age" = {
    armor = true;
    publicKeys = piRecipients;
  };

  "mercury-ai-token.age" = {
    armor = true;
    publicKeys = piRecipients;
  };

  "context7-api-key.age" = {
    armor = true;
    publicKeys = piRecipients;
  };

  "github-mcp-token.age" = {
    armor = true;
    publicKeys = piRecipients;
  };

  "cursor-api-key.age" = {
    armor = true;
    publicKeys = piRecipients;
  };

  "cline-api-key.age" = {
    armor = true;
    publicKeys = piRecipients;
  };

  "cursor-usage-session-token.age" = {
    armor = true;
    publicKeys = piRecipients;
  };

  "deepseek-api-key.age" = {
    armor = true;
    publicKeys = piRecipients;
  };

  "commandcode-api-key.age" = {
    armor = true;
    publicKeys = piRecipients;
  };

  "nix-builder-goofydesky.age" = {
    armor = true;
    publicKeys = [
      GoofyDesky
      GoofyDeskyRoot
    ];
  };

  "nix-builder-goofeus.age" = {
    armor = true;
    publicKeys = [
      Goofeus
      GoofyDesky
    ];
  };
}
