{ config, vars, ... }:
{
# grafana configuration
  services.prometheus = {
    enable = true;
    port = 9001;
    scrapeConfigs = [
      {
        job_name = "MainServer";
        static_configs = [{
          targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
        }];
      }
    ];
    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd"  ];
        port = 9002;
      };
    };
  };
}

