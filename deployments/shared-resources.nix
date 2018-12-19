{ region ? "eu-west-2", ... }:
let
  lib = import ./lib.nix;
  inherit (lib) withVPC publicSubnet rta igwroute sg;
in
{
  resources = {
    vpc.shared-vpc = {
      inherit region;
      enableDnsSupport = true;
      enableDnsHostnames = true;
      cidrBlock = "10.1.0.0/16";
    };

    ec2KeyPairs.deployer-keypair = { inherit region; };
    vpcInternetGateways.igw    = withVPC "shared-vpc" {};
    vpcRouteTables.route-table = withVPC "shared-vpc" {};
    vpcRoutes.igw-route = igwroute "route-table" "igw";

    vpcRouteTableAssociations = with rta; {
      deployer-assoc = associate "deployer-subnet" "route-table";
    };

    ec2SecurityGroups = with sg "shared-vpc"; {
      http-public-sg        = public [ 80 443 ];
      ssh-public-sg         = public [ 22 ];
      witness-public-sg     = public [ 4010 4011 ];
      witness-api-public-sg = public [ 4030 ];
      ssh-from-deployer-sg  = fromSubnet "deployer-subnet" [ 22 ];
    };
  };
}
