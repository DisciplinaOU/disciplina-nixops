{ region
, vpcCidr ? null }:

##
# Helper functions for AWS resource declaration.
#
# Many work like a DSL. For example:
#     route53RecordSets = with dns "foo.serokell.review"; {
#        rs-faucet    = cname "faucet.${domain}"   "witness.${domain}";
#     };
rec {
  optionalCall = x: y: if builtins.isFunction x then x y else x;

  # Associate with a given VPC by name. No longer as useful as it used to be.
  withVPC = vpc: resource: { resources, lib, ... }@arg:
    (optionalCall resource (arg // { vpc = vpc; })) // {
      inherit region;
      vpcId = resources.vpc."${vpc}" or vpc;
  };

  # Declare a public subnet
  publicSubnet = vpc: zone: cidrBlock: withVPC vpc {
    inherit cidrBlock zone;
    mapPublicIpOnLaunch = true;
  };

  # DSL to declare Security Groups.
  sg = vpc: {

    # Declare an SG that accepts connections from anywhere
    public = ports: (withVPC vpc {
      rules = map (x: { toPort = x; fromPort = x; sourceIp = "0.0.0.0/0"; }) ports;
    });

    # Declare an SG that only accepts connections from within the given VPC
    # (broken because VPC sharing)
    private = ports: (withVPC vpc {
      rules = map (x: { toPort = x; fromPort = x; sourceIp = vpcCidr; }) ports;
    });

    # Declare an SG that only accepts connections from the given subnet
    fromSubnet = subnet: ports: withVPC vpc ({ resources, lib, vpc, ... }: {
      rules = map (x: {
        toPort = x;
        fromPort = x;
        sourceIp = resources.vpcSubnets.${subnet}.cidrBlock;
      }) ports;
    });
  };

  # Declare an Internet Gateway Route Table Association
  igwroute = table: gateway: { resources, ... }: {
    inherit region;
    routeTableId = resources.vpcRouteTables."${table}" or table;
    destinationCidrBlock = "0.0.0.0/0";
    gatewayId = resources.vpcInternetGateways.${gateway};
  };

  # Associate a given subnet with a given route table
  rta.associate = subnet: table: { resources, ... }: {
    inherit region;
    subnetId = resources.vpcSubnets.${subnet};
    routeTableId = resources.vpcRouteTables."${table}" or table;
  };

  # DSL to declare DNS records
  dns = domain: rec {
    lib = (import ../pkgs.nix).lib;
    lastN = count: list: lib.drop (lib.length list - count) list;
    domainToZone = d: ((lib.concatStringsSep "." (lastN 2 (lib.splitString "." d))) + ".");
    zone = domainToZone domain;

    # Declare a cname record
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
