let
  Goofeus = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJeW872aIf7gEz8mS6MOLOaheMNpJghqVppQlUYSqq4x";
  GoofyDesky = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMq/zGCOmrHUwNRwjDsj8Sw0PDbnMd3Ck7H/ZKsHKPkM goofy@GoofyDesky";
  GoofyDeskyRoot = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEYYvebtw5TAg8ZbaL0CTRmq2buYXyUDAYFbAaGAYKJO root@GoofyDesky";
  GoofyEnvy = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHcf8d+U2aI4zO/axcvK97qP1FG9cfwp5CCUuKZEYRu5 goofy@GoofyEnvy";
  Droid = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBhBPZ6RstKIkG1on6ny8fRJ3oOSvgqMPK+y8RNn8gX";
in
{
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
}
