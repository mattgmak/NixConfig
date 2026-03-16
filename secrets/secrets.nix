let
  Goofeus = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID3GH7QU/uGwkpB22Wxx/GFCVSO+/59zFr8M+WfNpufE";
  GoofyDesky = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMq/zGCOmrHUwNRwjDsj8Sw0PDbnMd3Ck7H/ZKsHKPkM goofy@GoofyDesky";
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
}
