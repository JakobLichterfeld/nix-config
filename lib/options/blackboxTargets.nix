{
  lib,
  description ? "List of blackbox probe targets.",
  defaultTargets ? [ ],
}:

lib.mkOption {
  type = lib.types.listOf (
    lib.types.submodule {
      options = {
        target = lib.mkOption {
          type = lib.types.str;
          description = "Target hostname or IP with optional port.";
        };
        module = lib.mkOption {
          type = lib.types.str;
          description = "Blackbox exporter module (e.g., http_2xx, icmp, tcp_connect, etc.).";
        };
        labels = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Labels to attach to the probe result.";
        };
      };
    }
  );
  description = description;
  default = defaultTargets;
}
