{ pkgs, ... }:
{
  home.packages = with pkgs; [
    fastfetch
  ];
  xdg.configFile = {
    "fastfetch/config.conf" = {
      source = ./config.conf;
    };
  };
}
