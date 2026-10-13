{
  flake.sshKeys = {
    Goofeus = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJeW872aIf7gEz8mS6MOLOaheMNpJghqVppQlUYSqq4x";
    GoofyDesky = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMq/zGCOmrHUwNRwjDsj8Sw0PDbnMd3Ck7H/ZKsHKPkM goofy@GoofyDesky";
    GoofyDeskyRoot = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEYYvebtw5TAg8ZbaL0CTRmq2buYXyUDAYFbAaGAYKJO root@GoofyDesky";
    GoofyEnvy = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHcf8d+U2aI4zO/axcvK97qP1FG9cfwp5CCUuKZEYRu5 goofy@GoofyEnvy";
    Droid = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINKuInd6TqSlVSu3qottOYYODNbdVC07mfEs7Idbo20u";
    MacMini = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILvHr70WhwFy98okSEV2hpsiUMZwqVuME+T97Gd6SGvP mattgmak@Matthews-Mac-mini.local";
    # Passphrase-less identity for agent@Goofeus, decrypts API secrets headlessly.
    AgentAge = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC5KIsxMM9XNnktIidlFgdgLjkAM7hTETiVy5dBYtcgq agent@Goofeus";
  };
}
