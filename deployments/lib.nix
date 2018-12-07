rec {
  optionalCall = x: y: if builtins.isFunction x then x y else x;
  withVPC = vpc: resource: { resources, lib, ... }@arg: (optionalCall resource (arg // { vpc = resources.vpc.${vpc}; })) // {
    inherit (resources.vpc.${vpc}) region;
    vpcId = resources.vpc.${vpc};
  };
  publicSubnet = vpc: zone: cidrBlock: withVPC vpc {
    inherit cidrBlock zone;
    mapPublicIpOnLaunch = true;
  };
  sg = vpc: {
    public = ports: (withVPC vpc {
      rules = map (x: { toPort = x; fromPort = x; sourceIp = "0.0.0.0/0"; }) ports;
    });
    private = ports: withVPC vpc ({ resources, lib, vpc, ... }: {
      rules = map (x: { toPort = x; fromPort = x; sourceIp = vpc.cidrBlock; }) ports;
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
    inherit (resources.vpcRouteTables.${table}) region;
    routeTableId = resources.vpcRouteTables.${table};
    destinationCidrBlock = "0.0.0.0/0";
    gatewayId = resources.vpcInternetGateways.${gateway};
  };
  rta.associate = subnet: table: { resources, ... }: {
    inherit (resources.vpcRouteTables.${table}) region;
    subnetId = resources.vpcSubnets.${subnet};
    routeTableId = resources.vpcRouteTables.${table};
  };
  # dns = zones: {
  #   lib = (import ../pkgs.nix).lib;
  #   lastN = count: list: lib.drop (lib.length list - count) list;
  #   domainToZone = d: ((lib.concatStringsSep "." (lastN 2 (lib.splitString "." d))) + ".");
  #   mkLBCname = d:
  #     { lib, nodes, ... }:
  #     {
  #       domainName = "${d}.${domain}.";
  #       recordValues = [ "witness.${domain}" ];
  #       recordType = "CNAME";
  #       zoneName = domainToZone domain;
  #     };
  # };
}
