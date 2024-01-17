{ config, vars, machinesSensitiveVars, ... }:
let
  directories = [
    "${vars.serviceConfigRoot}/traefik"
  ];
  files = [
    "${vars.serviceConfigRoot}/traefik/acme.json"
  ];
in
{
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  age.secrets.dnsApiCredentials.file = ../../secrets/dnsApiCredentials.age; # content is: dnschallengeProvider=<token>

  systemd.tmpfiles.rules =  map (x: "d ${x} 0775 share share - -") directories ++ map (x: "f ${x} 0600 share share - -") files;

  virtualisation.oci-containers = {
    containers = {
      traefik = {
        image = "traefik";
        autoStart = true;
        cmd = [
          # able to route other containers
          "--api.insecure=true"
          "--providers.docker=true"
          "--providers.docker.exposedbydefault=false"
          # letsencrypt
          "--certificatesresolvers.letsencrypt.acme.dnschallenge=true"
          "--certificatesresolvers.letsencrypt.acme.dnschallenge.delaybeforecheck=20"
          "--certificatesresolvers.letsencrypt.acme.dnschallenge.provider=${machinesSensitiveVars.MainServer.dnschallengeProvider}"
          "--certificatesresolvers.letsencrypt.acme.email=${machinesSensitiveVars.MainServer.letsencryptEmail}"
          "--certificatesresolvers.letsencrypt.acme.storage=acme.json"
          # http
          "--entrypoints.web.address=:80"
          "--entrypoints.web.http.redirections.entrypoint.to=websecure"
          "--entrypoints.web.http.redirections.entrypoint.scheme=https"
          # https
          "--entrypoints.websecure.address=:443"
          #"--entrypoints.websecure.asDefault=true"
          "--entrypoints.websecure.http.tls=true"
          "--entrypoints.websecure.http.tls.certResolver=letsencrypt"
          "--entrypoints.websecure.http.tls.domains[0].main=${machinesSensitiveVars.MainServer.domainNameTail}"
          "--entrypoints.websecure.http.tls.domains[0].sans=*.${machinesSensitiveVars.MainServer.domainNameTail}"

        ];
        extraOptions = [
          # Config for traefik
          "-l=traefik.enable=true"
          "-l=traefik.http.routers.traefik.rule=Host(`proxy.${machinesSensitiveVars.MainServer.domainNameTail}`)"
          "-l=traefik.http.services.traefik.loadbalancer.server.port=8080"
          # Config for homepage
          "-l=homepage.group=Services"
          "-l=homepage.name=Traefik"
          "-l=homepage.icon=traefik.svg"
          "-l=homepage.href=https://traefik.${machinesSensitiveVars.MainServer.domainNameTail}"
          "-l=homepage.description=Reverse proxy"
        ];
        ports = [
          "443:443"
          "80:80"
        ];
        environmentFiles = [
          config.age.secrets.dnsApiCredentials.path
        ];
        volumes = [
          "/var/run/podman/podman.sock:/var/run/docker.sock:ro"
          "${vars.serviceConfigRoot}/traefik/acme.json:/acme.json"
        ];
      };
    };
  };
}
