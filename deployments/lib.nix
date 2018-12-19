{ region
, vpcCidr }:

rec {
  optionalCall = x: y: if builtins.isFunction x then x y else x;
  withVPC = vpc: resource: { resources, lib, ... }@arg:
    (optionalCall resource (arg // { vpc = vpc; })) // {
      inherit region;
      vpcId = vpc;
  };
  publicSubnet = vpc: zone: cidrBlock: withVPC vpc {
    inherit cidrBlock zone;
    mapPublicIpOnLaunch = true;
  };
  sg = vpc: {
    public = ports: (withVPC vpc {
      rules = map (x: { toPort = x; fromPort = x; sourceIp = "0.0.0.0/0"; }) ports;
    });
    private = ports: (withVPC vpc {
      rules = map (x: { toPort = x; fromPort = x; sourceIp = vpcCidr; }) ports;
    });
    fromSubnet = subnet: ports: withVPC vpc ({ resources, lib, vpc, ... }: {
      rules = map (x: {
        toPort = x;
        fromPort = x;
        sourceIp = resources.vpcSubnets.${subnet}.cidrBlock;
      }) ports;
    });
  };
  igwroute = table: gateway: { resources, ... }: {
    inherit region;
    routeTableId = table;
    destinationCidrBlock = "0.0.0.0/0";
    gatewayId = resources.vpcInternetGateways.${gateway};
  };

  rta.associate = subnet: table: { resources, ... }: {
    inherit region;
    subnetId = resources.vpcSubnets.${subnet};
    routeTableId = table;
  };

  dns = domain: rec {
    lib = (import ../pkgs.nix).lib;
    lastN = count: list: lib.drop (lib.length list - count) list;
    domainToZone = d: ((lib.concatStringsSep "." (lastN 2 (lib.splitString "." d))) + ".");
    zone = domainToZone domain;
    cname = from: to:
      { lib, nodes, ... }:
      {
        domainName = "${from}.";
        recordValues = [ to ];
        recordType = "CNAME";
        zoneName = zone;
      };
  };
}
