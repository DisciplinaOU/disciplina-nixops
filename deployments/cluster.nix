{ region ? "eu-west-2"
, env ? builtins.getEnv "DISCIPLINA_ENV"
, domain ? "see-readme.dscp.serokell.review"
, hostType ? "ec2"
, pkgs ? import ../pkgs.nix
, ...}:

{
  network.description = "Disciplina cluster ${domain}";

  require = pkgs.lib.optionals (hostType == "ec2")
    [ ./cluster-resources.nix ];

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
      keyPair = ec2KeyPairs.cluster-keypair;
      associatePublicIpAddress = lib.mkDefault true;
      ebsInitialRootDiskSize = lib.mkDefault 30;
      instanceType = lib.mkDefault "t2.medium";
      instanceProfile = "ReadDisciplinaSecrets";
      securityGroupIds = [ ec2SecurityGroups.cluster-ssh-public-sg.name ];
    };
    
    # limit access to amazon roles and keys to root
    networking.firewall.extraCommands = ''
      iptables -A OUTPUT -m owner -p tcp -d 169.254.169.254 ! --uid-owner root -j nixos-fw-log-refuse
    '';
    networking.firewall.extraStopCommands = ''
      iptables -D OUTPUT -m owner -p tcp -d 169.254.169.254 ! --uid-owner root -j nixos-fw-log-refuse || true
    '';

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

    dscp.keydir = toString env;
    dscp.keys = {
      committee-secret = { user = "disciplina"; services = [ "disciplina-witness" ]; shared = false; };
      faucet-key = { user = "disciplina"; services = [ "disciplina-faucet" ]; shared = false; };
    };

    # awskeys = {
    #   committee-secret = {
    #     services = [ "disciplina-witness" ];
    #     secretId = "${env}/disciplina/cluster";
    #     key = "committee-secret";
    #   };
    #   faucet-key = {
    #     services = [ "disciplina-faucet" ];
    #     secretId = "${env}/disciplina/cluster";
    #     key = "faucet-key";
    #   };
    # };
    # aws secretsmanager get-secret-value --secret-id ${env}/disciplina/cluster | jq -r .SecretString
  };

  balancer = import ./cluster/balancer.nix env domain "a";

  witness0 = import ./cluster/witness.nix 0 "a";
  witness1 = import ./cluster/witness.nix 1 "a";
  witness2 = import ./cluster/witness.nix 2 "b";
  witness3 = import ./cluster/witness.nix 3 "c";

  educator = import ./cluster/educator.nix "a";
}
