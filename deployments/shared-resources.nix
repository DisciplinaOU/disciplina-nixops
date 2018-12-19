{ region ? "eu-west-2"
, ... }:
let
  lib = import ./lib.nix { inherit region; };
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

    vpcSubnets.deployer-subnet = publicSubnet "shared-vpc" "${region}a" "10.1.40.0/24";
    vpcRouteTableAssociations = with rta; {
      deployer-assoc = associate "deployer-subnet" "route-table";
    };

    ec2SecurityGroups = with sg "shared-vpc"; {
      ssh-public-sg         = public [ 22 ];
    };
  };
}
