{
  inputs,
  config,
  pkgs,
  lib,
  machinesSensitiveVars,
  ...
}:
{
  system.stateVersion = "22.11";
  system.autoUpgrade = {
    enable = false;
    flake = "/etc/nixos\\?submodules=1";
    flags = [
      "--update-input"
      "nixpkgs"
      "-L" # print build logs
    ];
    dates = "Sat *-*-* 06:00:00";
    randomizedDelaySec = "45min";
    allowReboot = false;
  };

  imports = [
    ./filesystems
    ./nix
  ];

  time.timeZone = "Europe/Berlin";

  console.keyMap = "de";

  users.users = {
    root = {
      hashedPasswordFile = config.age.secrets.hashedUserPassword.path;
    };
  };
  services.openssh = {
    enable = lib.mkDefault true;
    settings = {
      PasswordAuthentication = lib.mkDefault false;
      LoginGraceTime = 0;
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

  networking.firewall.allowedTCPPorts = [
    machinesSensitiveVars.MainServer.sshPort
  ];

  programs.git.enable = true;
  programs.mosh.enable = true;
  programs.htop.enable = true;
  # programs.neovim = {
  #   enable = true;
  #   viAlias = true;
  #   vimAlias = true;
  #   defaultEditor = true;
  # };

  email = {
    enable = true;
    fromAddress = machinesSensitiveVars.Mail.fromAddress;
    toAddress = machinesSensitiveVars.Mail.toAddress;
    smtpServer = machinesSensitiveVars.Mail.smtpServer;
    smtpUsername = machinesSensitiveVars.Mail.smtpUsername;
    smtpPasswordPath = config.age.secrets.smtpPassword.path;
  };

  security = {
    doas.enable = lib.mkDefault false;
    sudo = {
      enable = lib.mkDefault true;
      wheelNeedsPassword = lib.mkDefault false;
    };
  };

  # homelab.motd.enable = true;

  # Firmware updates
  # to search for available updates, run `fwupdmgr refresh` and `sudo fwupdmgr get-updates`
  services.fwupd.enable = true;

  environment.systemPackages = with pkgs; [
    wget
    iperf3
    eza # A modern, maintained replacement for ls
    fastfetch
    tmux
    rsync
    iotop
    ncdu
    nmap
    jq
    ripgrep
    sqlite
    inputs.agenix.packages."${system}".default
    lm_sensors
    jc
    moreutils
    lsof
    fatrace
    git-crypt
    gnupg
    bfg-repo-cleaner
  ];

}
