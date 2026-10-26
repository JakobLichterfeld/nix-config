{ ... }:
{
  programs.fastfetch = {
    enable = true;
    # Configuration written to ~/.config/fastfetch/config.jsonc
    settings = {
      logo.padding.right = 3; # gap between logo and info
      display.freq.ndigits = 1; # CPU speed shorthand, e.g. 3.5 GHz
      modules = [
        "title"
        "separator"
        "os"
        "host"
        {
          type = "kernel";
          format = "{release}";
        }
        "uptime"
        "packages"
        "terminal"
        {
          type = "shell";
          format = "{pretty-name}";
        }
        {
          type = "cpu";
          # fastfetch cannot read bios_limit; without it neofetch falls back to scaling_max_freq,
          # then cpuinfo_max_freq, while freq-max reads them in reverse order (same value unless capped)
          format = "{name} @ {freq-max}";
        }
        "memory"
      ];
    };
  };
}
