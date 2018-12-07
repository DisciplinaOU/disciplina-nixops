{ region ? "eu-west-2", ... }:

let lib = import ./lib.nix; inherit (lib) withVPC; in
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

    vpcSubnets.deployer-subnet = lib.publicSubnet "shared-vpc" "" "10.1.0.0/24";

    vpcRouteTableAssociations = with lib.rta; {
      deployer-assoc = associate "deployer-subnet" "route-table";
    };

    vpcRoutes.igw-route = lib.igwroute "route-table" "igw";

    ec2SecurityGroups = with lib.sg "shared-vpc"; {
      http-public-sg        = public [ 80 443 ];
      ssh-public-sg         = public [ 22 ];
      witness-public-sg     = public [ 4010 4011 ];
      witness-api-public-sg = public [ 4030 ];
      ssh-from-deployer-sg  = fromSubnet "deployer-subnet" [ 22 ];
    };

    # route53RecordSets = with srk-lib.dns [ "${domain}." ] {
    #   rs-faucet   = cname "faucet.${domain}"   "witness.${domain}";
    #   rs-explorer = cname "explorer.${domain}" "witness.${domain}";
    #   rs-educator = cname "educator.${domain}" "witness.${domain}";
    # };
  };
}
