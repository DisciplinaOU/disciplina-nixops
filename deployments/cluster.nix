{ region ? "eu-west-2", domain ? "see-readme.disciplina.site", env ? "staging"
, hostType ? "ec2", pkgs ? import ../pkgs.nix }:

{
  network.description = "Disciplina cluster";
  require = [ ./cluster-resources.nix ];

  defaults = { resources, lib, name, ... }: {
    imports = [ ../modules ];

    deployment.targetEnv = hostType;

    deployment.virtualbox = {
      headless = true;
      memorySize = 512;
      vcpu = 2;
    };

    deployment.ec2 = with resources; {
      inherit region;
      associatePublicIpAddress = lib.mkDefault true;
      ebsInitialRootDiskSize = lib.mkDefault 30;
      instanceType = lib.mkDefault "t2.medium";
      instanceProfile = "ReadDisciplinaSecrets";
      securityGroupIds = [ ec2SecurityGroups.cluster-ssh-public-sg.name ];
      subnetId = lib.mkForce vpcSubnets.cluster-subnet;
    };

    deployment.route53 = lib.optionalAttrs (env != "production") {
      usePublicDNSName = true;
      hostname = "${name}.${domain}";
    };

    system.nixos.tags = lib.optional (hostType == "virtualbox") "internal";

    nixpkgs.pkgs = pkgs;

    services.nginx = {
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
    };

    services.sshguard.enable = true;

    networking.firewall.allowedTCPPorts = [ 22 ];

    awskeys = {
      committee-secret = {
        services = [ "disciplina-witness" ];
        secretId = "${env}/disciplina/cluster";
        key = "committee-secret";
      };
      faucet-key = {
        services = [ "disciplina-faucet" ];
        secretId = "${env}/disciplina/cluster";
        key = "faucet-key";
      };
    };
    # aws secretsmanager get-secret-value --secret-id ${env}/disciplina/cluster | jq -r .SecretString
  };

  resources = pkgs.lib.optionalAttrs (hostType == "ec2")
    (import ./cluster-resources.nix { inherit region env domain; });

  balancer = import ./cluster/balancer.nix env domain;

  witness0 = import ./cluster/witness.nix 0;
  witness1 = import ./cluster/witness.nix 1;
  witness2 = import ./cluster/witness.nix 2;
  witness3 = import ./cluster/witness.nix 3;

  educator = import ./cluster/educator.nix;
}
