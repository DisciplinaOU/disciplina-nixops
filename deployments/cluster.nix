{ region ? "eu-west-2", domain ? "see-readme.disciplina.site", env ? "staging" }:
{
  network.description = "Disciplina cluster";
  require = [ ./cluster-resources.nix ];

  defaults = { resources, lib, name, ... }: {
    imports = [ ../modules ];

    deployment.targetEnv = "ec2";
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

    networking.firewall.extraCommands = ''
      iptables -A OUTPUT -m owner -p tcp -d 169.254.169.254 ! --uid-owner root -j nixos-fw-log-refuse
    '';
    networking.firewall.extraStopCommands = ''
      iptables -D OUTPUT -m owner -p tcp -d 169.254.169.254 ! --uid-owner root -j nixos-fw-log-refuse
    '';

    nixpkgs.pkgs = import ../pkgs.nix;

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

  witness-load-balancer = import ./cluster/witness-load-balancer.nix env domain;

  witness0 = import ./cluster/witness.nix 0;
  witness1 = import ./cluster/witness.nix 1;
  witness2 = import ./cluster/witness.nix 2;
  witness3 = import ./cluster/witness.nix 3;

  educator = import ./cluster/educator.nix;
}
