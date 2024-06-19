{ inputs, config, pkgs, lib, machinesSensitiveVars, ... }:
{
  age.secrets.hashedUserPassword.file = ../../secrets/hashedUserPassword.age; # content is result of: `mkpasswd -m sha-512`

  system.stateVersion = "23.11";

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.optimise = {
    automatic = true;
    dates = ["weekly"];
  };

  system.autoUpgrade = {
    enable = true;
    flake = inputs.self.outPath;
    flags = [
      "--update-input"
    ];
    dates = "06:00";
    randomizedDelaySec = "45min";
  };

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
    ports = [ machinesSensitiveVars.MainServer.sshPort ];
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
  networking.firewall.allowedTCPPorts = [ machinesSensitiveVars.MainServer.sshPort ];

  nix.settings.experimental-features = lib.mkDefault [ "nix-command" "flakes" ];

  console.keyMap = "de";

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

  environment.systemPackages = with pkgs; [
    wget
    iperf3
    eza # A modern, maintained replacement for ls
    neofetch
    (python313.withPackages (ps: with ps; [ pip ]))
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
    git-crypt
    gnupg
    pinentry
  ];
}
