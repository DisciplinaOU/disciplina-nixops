{ region ? "eu-west-2", domain ? "see-readme.disciplina.site", env ? "staging" }:
{
  network.description = "Disciplina cluster";

  defaults = { resources, lib, name, ... }: {
    imports = [ ../modules ];

    deployment.targetEnv = "ec2";
    deployment.ec2 = with resources; {
      inherit region;
      associatePublicIpAddress = lib.mkDefault true;
      ebsInitialRootDiskSize = lib.mkDefault 30;
      elasticIPv4 = if (env == "production") then elasticIPs."${name}-ip" else "";
      instanceType = lib.mkDefault "t2.medium";
      keyPair = ec2KeyPairs.cluster-key;
      securityGroupIds = [ ec2SecurityGroups.cluster-ssh-public-sg.name ];
      subnetId = lib.mkForce vpcSubnets.cluster-subnet;
    };

    deployment.route53 = lib.optionalAttrs (env != "production") {
      usePublicDNSName = true;
      hostname = "${name}.${domain}";
    };

    nixpkgs.pkgs = import ../pkgs.nix;

    services.nginx = {
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
    };

    services.sshguard.enable = true;

    networking.firewall.allowedTCPPorts = [ 22 ];

    dscp.keydir = env;
    dscp.keys = {
      committee-secret = { user = "disciplina"; services = [ "disciplina-witness" ]; shared = false; };
      faucet-key = { user = "disciplina"; services = [ "disciplina-faucet" ]; shared = false; };
    };
  };

  resources = import ./cluster-resources.nix { inherit region env domain; };

  witness-load-balancer = import ./cluster/witness-load-balancer.nix env domain;

  witness0 = import ./cluster/witness.nix env 0;
  witness1 = import ./cluster/witness.nix env 1;
  witness2 = import ./cluster/witness.nix env 2;
  witness3 = import ./cluster/witness.nix env 3;

  educator = import ./cluster/educator.nix env 4;
}
