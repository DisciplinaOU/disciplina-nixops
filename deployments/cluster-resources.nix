{ region ? "eu-west-2", domain, ... }:

{
  resources = {
    vpc.cluster-vpc = {
      inherit region;
      enableDnsSupport = true;
      enableDnsHostnames = true;
      cidrBlock = "10.0.0.0/16";
    };

    vpcSubnets.cluster-subnet = withVPC "cluster-vpc" {
      cidrBlock = "10.0.44.0/24";
      mapPublicIpOnLaunch = true;
    };

    ec2SecurityGroups = with srk-lib.sg "cluster-vpc"; {
      cluster-http-public-sg     = public [ 80 443 ];
      cluster-ssh-private-sg     = private [ 22 ];
      cluster-ssh-public-sg      = public [ 22 ];
      cluster-witness-public-sg  = public [ 4010 4011 ];
      cluster-witness-private-sg = private [ 4010 4011 ];
      cluster-witness-api-public-sg   = public [ 4030 ];
      cluster-witness-api-private-sg  = private [ 4030 ];
      cluster-educator-api-private-sg = private [ 4040 ];
    };

    route53RecordSets = with srk-lib.dns [ "${domain}." ] {
      rs-faucet   = cname "faucet.${domain}"   "witness.${domain}";
      rs-explorer = cname "explorer.${domain}" "witness.${domain}";
      rs-educator = cname "educator.${domain}" "witness.${domain}";
    };
  };
}
