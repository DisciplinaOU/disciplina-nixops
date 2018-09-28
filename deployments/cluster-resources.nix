{ region, env }:

let mkIP =
  { resources, lib, ... }:
  {
    inherit region;
    vpc = true;
  };
  zone = "${region}a";

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

  elasticIPs = if (env == "production") then
    {
      builder-ip = mkIP;
      witness1-ip = mkIP;
      witness2-ip = mkIP;
      witness3-ip = mkIP;
    } else {};

  ec2SecurityGroups.cluster-http-public-sg =
    { resources, lib, ... }:
    {
      inherit region;
      vpcId = resources.vpc.cluster-vpc;
      rules = [
        # HTTP(S)
        { fromPort =  80; toPort =  80; sourceIp = "0.0.0.0/0"; }
        { fromPort = 443; toPort = 443; sourceIp = "0.0.0.0/0"; }
      ];
    };

  ec2SecurityGroups.cluster-ssh-private-sg =
    { resources, lib, ... }:
    {
      inherit region;
      vpcId = resources.vpc.cluster-vpc;
      rules = [
        # SSH
        { fromPort =    22; toPort =    22; sourceIp = vpc.cluster-vpc.cidrBlock; }
      ];
    };

  ec2SecurityGroups.cluster-ssh-public-sg =
    { resources, lib, ... }:
    {
      inherit region;
      vpcId = resources.vpc.cluster-vpc;
      rules = [
        # SSH
        { fromPort =    22; toPort =    22; sourceIp = "0.0.0.0/0"; }
      ];
    };

  ec2SecurityGroups.cluster-witness-public-sg =
    { resources, lib, ... }:
    {
      inherit region;
      vpcId = resources.vpc.cluster-vpc;
      rules = [
        # Disciplina witness
        { fromPort =  4010; toPort =  4011; sourceIp = "0.0.0.0/0"; }
      ];
    };

  ec2SecurityGroups.cluster-witness-private-sg =
    { resources, lib, ... }:
    {
      inherit region;
      vpcId = resources.vpc.cluster-vpc;
      rules = [
        # Disciplina witness ZMQ
        { fromPort =  4010; toPort =  4011; sourceIp = vpc.cluster-vpc.cidrBlock; }
      ];
    };

  ec2SecurityGroups.cluster-witness-api-public-sg =
    { resources, lib, ... }:
    {
      inherit region;
      vpcId = resources.vpc.cluster-vpc;
      rules = [
        # Disciplina witness HTTP API
        { fromPort =  4030; toPort =  4030; sourceIp = "0.0.0.0/0"; }
      ];
    };

  ec2SecurityGroups.cluster-witness-api-private-sg =
    { resources, lib, ... }:
    {
      inherit region;
      vpcId = resources.vpc.cluster-vpc;
      rules = [
        # Disciplina witness HTTP API
        { fromPort =  4030; toPort =  4030; sourceIp = vpc.cluster-vpc.cidrBlock; }
      ];
    };

  ec2SecurityGroups.cluster-telegraf-private-sg =
    { resources, lib, ... }:
    {
      inherit region;
      vpcId = resources.vpc.cluster-vpc;
      rules = [
        # Telegraf ingress port
        { fromPort =  8125; toPort =  8125; protocol = "udp"; sourceIp = vpc.cluster-vpc.cidrBlock; }
      ];
    };

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
}
