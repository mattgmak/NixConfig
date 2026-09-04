let
  Goofeus = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJeW872aIf7gEz8mS6MOLOaheMNpJghqVppQlUYSqq4x";
  GoofyDesky = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMq/zGCOmrHUwNRwjDsj8Sw0PDbnMd3Ck7H/ZKsHKPkM goofy@GoofyDesky";
  GoofyDeskyRoot = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEYYvebtw5TAg8ZbaL0CTRmq2buYXyUDAYFbAaGAYKJO root@GoofyDesky";
  GoofyEnvy = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHcf8d+U2aI4zO/axcvK97qP1FG9cfwp5CCUuKZEYRu5 goofy@GoofyEnvy";
  Droid = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBhBPZ6RstKIkG1on6ny8fRJ3oOSvgqMPK+y8RNn8gX";
  MacMini = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILvHr70WhwFy98okSEV2hpsiUMZwqVuME+T97Gd6SGvP mattgmak@Matthews-Mac-mini.local";
  # Agent user's dedicated age identity (generated 2026-09-04, passphrase-less ed25519).
  # Used by agent@Goofeus to decrypt cursor/github/cline/opencode API secrets headlessly.
  AgentAge = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC5KIsxMM9XNnktIidlFgdgLjkAM7hTETiVy5dBYtcgq agent@Goofeus";
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
    publicKeys = [
      Droid
      GoofyDesky
      GoofyEnvy
      Goofeus
      AgentAge
      MacMini
    ];
  };

  "mercury-ai-token.age" = {
    armor = true;
    publicKeys = [
      Droid
      GoofyDesky
      GoofyEnvy
      Goofeus
      AgentAge
      MacMini
    ];
  };

  "context7-api-key.age" = {
    armor = true;
    publicKeys = [
      Droid
      GoofyDesky
      GoofyEnvy
      Goofeus
      AgentAge
      MacMini
    ];
  };

  "github-mcp-token.age" = {
    armor = true;
    publicKeys = [
      Droid
      GoofyDesky
      GoofyEnvy
      Goofeus
      AgentAge
      MacMini
    ];
  };

  "cursor-api-key.age" = {
    armor = true;
    publicKeys = [
      Droid
      GoofyDesky
      GoofyEnvy
      Goofeus
      AgentAge
      MacMini
    ];
  };

  "cline-api-key.age" = {
    armor = true;
    publicKeys = [
      Droid
      GoofyDesky
      GoofyEnvy
      Goofeus
      AgentAge
      MacMini
    ];
  };

  "cursor-usage-session-token.age" = {
    armor = true;
    publicKeys = [
      Droid
      GoofyDesky
      GoofyEnvy
      Goofeus
      AgentAge
      MacMini
    ];
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
