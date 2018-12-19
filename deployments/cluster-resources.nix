{ region ? "eu-west-2", domain, ... }:
let
  lib = import ./lib.nix;
  inherit (lib) withVPC sg dns;
in
  {
    resources = {
      ec2KeyPairs.cluster-keypair = { inherit region; };

      witness-load-balancer-eip = { inherit region; vpc = true; };

      vpcSubnets.deployer-subnet = publicSubnet "shared-vpc" "${region}a" "10.1.40.0/24";
      vpcSubnets.a-subnet = lib.publicSubnet "shared-vpc" "${region}a" "10.1.41.0/24";
      vpcSubnets.b-subnet = lib.publicSubnet "shared-vpc" "${region}b" "10.1.42.0/24";
      vpcSubnets.c-subnet = lib.publicSubnet "shared-vpc" "${region}c" "10.1.43.0/24";

      vpcRouteTableAssociations = with lib.rta; {
        a-assoc = associate "a-subnet" "route-table";
        b-assoc = associate "b-subnet" "route-table";
        c-assoc = associate "c-subnet" "route-table";
      };

      ec2SecurityGroups = with sg "shared-vpc"; {
        cluster-http-public-sg     = public [ 80 443 ];
        cluster-ssh-private-sg     = private [ 22 ];
        cluster-ssh-public-sg      = public [ 22 ];
        cluster-witness-public-sg  = public [ 4010 4011 ];
        cluster-witness-private-sg = private [ 4010 4011 ];
        cluster-witness-api-public-sg   = public [ 4030 ];
        cluster-witness-api-private-sg  = private [ 4030 ];
        cluster-educator-api-private-sg = private [ 4040 ];
      };

      route53RecordSets = with dns domain; {
        rs-faucet   = cname "faucet.${domain}"   "witness.${domain}";
        rs-explorer = cname "explorer.${domain}" "witness.${domain}";
        rs-educator = cname "educator.${domain}" "witness.${domain}";
      };

    };
  }
