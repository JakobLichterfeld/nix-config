{ ... }:
{
  age.secrets.dataIndexerJwt = {
    file = ./../../../../secrets/dataIndexerJwt.age; # content is the JWT secret used by the Data Indexer service
    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e dataIndexerJwt.age
  };

  age.secrets.deadmanPingEnvWslEnvDataIndexer = {
    file = ./../../../../secrets/deadmanPingEnvWslEnvDataIndexer.age; # content is the deadman ping env file, with PING_URL= according to modules/deadman-ping
    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e deadmanPingEnvWslEnvDataIndexer.age
  };

  age.secrets.hashedUserPassword = {
    file = ./../../../../secrets/hashedUserPassword.age; # content is result of: `mkpasswd -m sha-512`
    # cd secrets && EDITOR=nano nix --experimental-features 'nix-command flakes' run github:ryantm/agenix -- -e hashedUserPassword.age
  };
}
