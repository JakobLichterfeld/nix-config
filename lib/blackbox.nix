{ lib }:
{
  mkHttpTarget = name: hostOrAddress: {
    target = hostOrAddress;
    module = "http_2xx";
    labels = {
      probe = "http";
      environment = "prod";
      service = name;
    };
  };

  mkIcmpTarget = name: host: {
    target = host;
    module = "icmp";
    labels = {
      probe = "icmp";
      environment = "prod";
      service = name;
    };
  };

  mkTcpTarget = name: hostOrAddress: {
    target = hostOrAddress;
    module = "tcp_connect";
    labels = {
      probe = "tcp";
      environment = "prod";
      service = name;
    };
  };
}
