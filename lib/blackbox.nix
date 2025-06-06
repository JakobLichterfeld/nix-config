{ lib }:
let
  mkTargetBase = module: probe: name: hostOrAddress: scope: severity: {
    target = hostOrAddress;
    module = module;
    labels = {
      probe = probe;
      environment = "prod";
      service = name;
      scope = scope;
      severity = severity;
    };
  };
in
{
  mkHttpTarget =
    name: hostOrAddress: scope:
    mkTargetBase "http_2xx" "http" name hostOrAddress scope "warning";

  mkHttpTargetCritical =
    name: hostOrAddress: scope:
    mkTargetBase "http_2xx" "http" name hostOrAddress scope "critical";

  mkIcmpTarget =
    name: host: scope:
    mkTargetBase "icmp" "icmp" name host scope "warning";

  mkIcmpTargetCritical =
    name: host: scope:
    mkTargetBase "icmp" "icmp" name host scope "critical";

  mkTcpTarget =
    name: hostOrAddress: scope:
    mkTargetBase "tcp_connect" "tcp" name hostOrAddress scope "warning";

  mkTcpTargetCritical =
    name: hostOrAddress: scope:
    mkTargetBase "tcp_connect" "tcp" name hostOrAddress scope "critical";
}
