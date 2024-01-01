{ inputs, config, pkgs, lib, ... }:
{
  system.stateVersion = "23.11";

  networking.useDHCP = false;
  networking.networkmanager.enable = false;
  nixpkgs = {
    overlays = [
        inputs.nur.overlay
    ];
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };


  users.users = {
    root = {
      initialHashedPassword = config.age.secrets.hashedUserPassword.path;
      openssh.authorizedKeys.keys = [ "sshKey_placeholder" ];
    };
  };
  services.openssh = {
    enable = lib.mkDefault true;
    settings = {
    PasswordAuthentication = lib.mkDefault false;
    PermitRootLogin = "no";
    };
    ports = [ inputs.machines.MainServer.sshPort ];
    hostKeys = [
      {
        path = "/persist/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
      {
        path = "/persist/ssh/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
    ];
  };

  nix.settings.experimental-features = lib.mkDefault [ "nix-command" "flakes" ];

  programs.git.enable = true;
  programs.mosh.enable = true;
  programs.htop.enable = true;

  security = {
    doas.enable = lib.mkDefault false;
    sudo = {
      enable = lib.mkDefault true;
      wheelNeedsPassword = lib.mkDefault true;
    };
  };

  networking.firewall.allowPing = true;

  system.autoUpgrade.enable = true;

  environment.systemPackages = with pkgs; [
    wget
    iperf3
    exa
    neofetch
    (python311.withPackages(ps: with ps; [ pip ]))
    tmux
    rsync
    iotop
    ncdu
    nmap
    jq
    ripgrep
    inputs.agenix.packages."${system}".default
    lm_sensors
    jc
    moreutils
  ];
}
