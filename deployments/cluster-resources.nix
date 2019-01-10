{ region ? "eu-central-1"
, domain
, vpcId ? null
, vpcCidr ? null
, routeTableId ? null
, ... }:
let
  lib = import ./lib.nix { inherit region vpcCidr; };
  inherit (lib) withVPC sg dns publicSubnet;
in
  {
    resources = {
      ec2KeyPairs.cluster-keypair = { inherit region; };

      elasticIPs.balancer-eip = { inherit region; vpc = true; };

      vpcSubnets.a-subnet = publicSubnet vpcId "${region}a" "10.1.41.0/24";
      vpcSubnets.b-subnet = publicSubnet vpcId "${region}b" "10.1.42.0/24";
      vpcSubnets.c-subnet = publicSubnet vpcId "${region}c" "10.1.43.0/24";

      vpcRouteTableAssociations = with lib.rta; {
        a-assoc = associate "a-subnet" routeTableId;
        b-assoc = associate "b-subnet" routeTableId;
        c-assoc = associate "c-subnet" routeTableId;
      };

      ec2SecurityGroups = with sg vpcId; {
        cluster-http-public-sg          = public  [ 80 443 ];
        cluster-ssh-private-sg          = private [ 22 ];
        cluster-ssh-public-sg           = public  [ 22 ];
        cluster-witness-public-sg       = public  [ 4010 4011 ];
        cluster-witness-private-sg      = private [ 4010 4011 ];
        cluster-witness-api-public-sg   = public  [ 4030 ];
        cluster-witness-api-private-sg  = private [ 4030 ];
        cluster-educator-api-private-sg = private [ 4040 ];
        # ssh-from-deployer-sg            = fromSubnet "deployer-subnet" [ 22 ];
      };

      route53RecordSets = with dns domain; {
        rs-faucet    = cname "faucet.${domain}"   "witness.${domain}";
        rs-explorer  = cname "explorer.${domain}" "witness.${domain}";
        rs-educator  = cname "educator.${domain}" "witness.${domain}";
        rs-validator = cname "validator.${domain}" "witness.${domain}";
      };

    };
  }
