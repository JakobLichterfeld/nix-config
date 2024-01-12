{ config, vars, pkgs, ... }:
let
directories = [
"${vars.serviceConfigRoot}/homepage"
"${vars.serviceConfigRoot}/homepage/config"
];

settingsFormat = pkgs.formats.yaml { };
homepageCustomCss = pkgs.writeTextFile {
  name = "custom.css";
  text = builtins.readFile ./custom.css;
};
homepageCustomJs = pkgs.writeTextFile {
  name = "custom.js";
  text = builtins.readFile ./custom.js;
};
homepageSettings = {
  bookmarks = pkgs.writeTextFile{
    name = "bookmarks.yaml";
    text = builtins.readFile ./bookmarks.yaml;
  };
  docker = settingsFormat.generate "docker.yaml" (import ./docker.nix);
  kubernetes =  pkgs.writeTextFile{
    name = "kubernetes.yaml";
    text = builtins.readFile ./kubernetes.yaml;
  };
  services = pkgs.writeTextFile {
    name = "services.yaml";
    text = builtins.readFile ./services.yaml;
  };
  settings = settingsFormat.generate "settings.yaml" (import ./settings.nix);
  widgets = pkgs.writeTextFile {
    name = "widgets.yaml";
    text = builtins.readFile ./widgets.yaml;
  };
};
in
{
  systemd.tmpfiles.rules = map (x: "d ${x} 0775 share share - -") directories;
  virtualisation.oci-containers = {
    containers = {
      homepage = {
        image = "ghcr.io/gethomepage/homepage:latest";
        autoStart = true;
        # extraOptions = [
        # "-l=traefik.enable=true"
        # "-l=traefik.http.routers.home.rule=Host(`${vars.domainName}`)"
        # "-l=traefik.http.services.home.loadbalancer.server.port=3000"
        # ];
        volumes = [
          "${vars.serviceConfigRoot}/homepage/config:/app/config"
          "${homepageSettings.bookmarks}:/app/config/bookmarks.yaml"
          "${homepageCustomCss}:/app/config/custom.css"
          "${homepageCustomJs}:/app/config/custom.js"
          "${homepageSettings.docker}:/app/config/docker.yaml"
          "${homepageSettings.kubernetes}:/app/config/kubernetes.yaml"
          "${homepageSettings.services}:/app/config/services.yaml"
          "${homepageSettings.settings}:/app/config/settings.yaml"
          "${homepageSettings.widgets}:/app/config/widgets.yaml"
          "/var/run/podman/podman.sock:/var/run/docker.sock:ro"
        ];
        ports = [
          "3080:3000"
        ];
        environment = {
          TZ = "Europe/Berlin";
        };
        # environmentFiles = [
        # ];
      };
    };
};
}
