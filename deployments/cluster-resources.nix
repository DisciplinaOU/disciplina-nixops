{ region, env, domain }:

let
  mkIP = { resources, lib, ... }: {
    inherit region;
    vpc = true;
  };

  mkSG = rules: { resources, lib, ... }: {
    inherit region rules;
    vpcId = resources.vpc.cluster-vpc;
  };

  zone = "${region}a";
  production = env == "production";

in rec {
  vpc.cluster-vpc = {
    inherit region;
    instanceTenancy = "default";
    enableDnsSupport = true;
    enableDnsHostnames = true;
    cidrBlock = "10.0.0.0/16";
  };

  vpcSubnets.cluster-subnet =
    { resources, lib, ... }:
    {
      inherit region zone;
      vpcId = resources.vpc.cluster-vpc;
      cidrBlock = "10.0.44.0/24";
      mapPublicIpOnLaunch = true;
    };

  elasticIPs = if production then
    {
      balancer-ip = mkIP;
      witness1-ip = mkIP;
      witness2-ip = mkIP;
      witness3-ip = mkIP;
      educator-ip = mkIP;
    } else {};

  ec2SecurityGroups.cluster-http-public-sg = mkSG [
    { fromPort =  80; toPort =  80; sourceIp = "0.0.0.0/0"; }
    { fromPort = 443; toPort = 443; sourceIp = "0.0.0.0/0"; }
  ];

  ec2SecurityGroups.cluster-ssh-private-sg = mkSG [
    { fromPort =    22; toPort =    22; sourceIp = vpc.cluster-vpc.cidrBlock; }
  ];

  ec2SecurityGroups.cluster-ssh-public-sg = mkSG [
    { fromPort =    22; toPort =    22; sourceIp = "0.0.0.0/0"; }
  ];

  ec2SecurityGroups.cluster-witness-public-sg = mkSG [
    { fromPort =  4010; toPort =  4011; sourceIp = "0.0.0.0/0"; }
  ];

  ec2SecurityGroups.cluster-witness-private-sg = mkSG [
    { fromPort =  4010; toPort =  4011; sourceIp = vpc.cluster-vpc.cidrBlock; }
  ];

  ec2SecurityGroups.cluster-witness-api-public-sg = mkSG [
    { fromPort =  4030; toPort =  4030; sourceIp = "0.0.0.0/0"; }
  ];

  ec2SecurityGroups.cluster-witness-api-private-sg = mkSG [
    { fromPort =  4030; toPort =  4030; sourceIp = vpc.cluster-vpc.cidrBlock; }
  ];

  ec2SecurityGroups.cluster-educator-api-private-sg = mkSG [
    { fromPort =  4040; toPort =  4040; sourceIp = vpc.cluster-vpc.cidrBlock; }
  ];

  vpcRouteTables.cluster-route-table =
    { resources, ... }:
    {
      inherit region;
      vpcId = resources.vpc.cluster-vpc;
    };

  vpcRouteTableAssociations.cluster-assoc =
    { resources, ... }:
    {
      inherit region;
      subnetId = resources.vpcSubnets.cluster-subnet;
      routeTableId = resources.vpcRouteTables.cluster-route-table;
    };

  vpcInternetGateways.cluster-igw =
    { resources, ... }:
    {
      inherit region;
      vpcId = resources.vpc.cluster-vpc;
    };

  vpcRoutes.cluster-route =
    { resources, ... }:
    {
      inherit region;
      routeTableId = resources.vpcRouteTables.cluster-route-table;
      destinationCidrBlock = "0.0.0.0/0";
      gatewayId = resources.vpcInternetGateways.cluster-igw;
    };

  ec2KeyPairs.cluster-key = {
    name = "cluster-kp";
    inherit region;
  };

  route53RecordSets = let
    lib = (import ../pkgs.nix).lib;
    lastN = count: list: lib.drop (lib.length list - count) list;
    domainToZone = d: ((lib.concatStringsSep "." (lastN 2 (lib.splitString "." d))) + ".");
    mkLBCname = d:
      { lib, nodes, ... }:
      {
        domainName = "${d}.${domain}.";
        recordValues = [ "witness.${domain}" ];
        recordType = "CNAME";
        zoneName = domainToZone domain;
      };
  in
    lib.optionalAttrs (!production) {
      rs-faucet = mkLBCname "faucet";
      rs-explorer = mkLBCname "explorer";
      rs-educator = mkLBCname "educator";
    };
}
