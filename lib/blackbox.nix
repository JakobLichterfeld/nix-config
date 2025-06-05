{ lib }:
{
  mkHttpTarget = name: hostOrAddress: scope: {
    target = hostOrAddress;
    module = "http_2xx";
    labels = {
      probe = "http";
      environment = "prod";
      service = name;
    } // lib.optionalAttrs (scope != null) { scope = scope; };
  };

  mkIcmpTarget = name: host: scope: {
    target = host;
    module = "icmp";
    labels = {
      probe = "icmp";
      environment = "prod";
      service = name;
    } // lib.optionalAttrs (scope != null) { scope = scope; };
  };

  mkTcpTarget = name: hostOrAddress: scope: {
    target = hostOrAddress;
    module = "tcp_connect";
    labels = {
      probe = "tcp";
      environment = "prod";
      service = name;
    } // lib.optionalAttrs (scope != null) { scope = scope; };
  };
}
