# TODO: add AWS ALB to NixOps and use that instead

env: domain: zone: params@{ config, lib, name, nodes, pkgs, resources, ... }:

let
  keys = config.awskeys;
  uris = {
    # faucet = "faucet.${domain}";
    # explorer = "explorer.${domain}";
    educator = "educator.${domain}";
    multi-educator = "multi-educator.${domain}";
    # witness = "witness.${domain}";
    validator = "validator.${domain}";
    auth = "auth.${domain}";
  };
  common = import ./common.nix "" "" params;
  cat = path: ''"$(cat "${path}")"'';
in
{
  deployment.route53.hostName = lib.mkForce "witness.${domain}";

  deployment.ec2.securityGroupIds = map (x: resources.ec2SecurityGroups."cluster-${x}-sg".name ) (
    [ "http-public" ]
  );

  deployment.ec2.subnetId = lib.mkForce resources.vpcSubnets."${zone}-subnet";
  deployment.ec2.elasticIPv4 = resources.elasticIPs.balancer-eip;

  boot.kernel.sysctl = {
    "net.core.somaxconn" = 4096;
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.nginx = {
    enable = true;

    appendConfig = ''
      worker_processes auto;
    '';
    eventsConfig = ''
      worker_connections 16384;
    '';
    commonHttpConfig = ''
      access_log syslog:server=unix:/dev/log,tag=nginx,severity=info combined;
    '';

    upstreams.educator = {
      servers."educator:4040" = {};
      extraConfig = "keepalive 32;";
    };

    upstreams.multi-educator = {
      servers."multi-educator:4040" = {};
      extraConfig = "keepalive 32;";
    };

    upstreams.auth = {
      servers."localhost:8000" = {};
      extraConfig = "keepalive 32;";
    };

    virtualHosts= {
      "${uris.educator}".locations."/".proxyPass = "http://educator";
      "${uris.multi-educator}".locations = {
        "/api".proxyPass = "http://multi-educator";
        "/" = {
          root = pkgs.disciplina-educator-spa.override {
            aaaUrl = "//${uris.auth}";
            educatorUrl = "//${uris.multi-educator}";
          };
          tryFiles = "$uri /index.html";
        };
      };

      "${uris.auth}".locations."/".proxyPass = "http://auth";

      "${uris.validator}" = {
        locations = {
	  "/api".proxyPass = "http://multi-educator";
          "/".root = pkgs.disciplina-validatorcv.override { witnessUrl = "//${uris.multi-educator}"; };
        };
        default = true;
      };
    };
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql;
  };

  systemd.services.custodial-wallet = {
    description = "Custodial wallet service";

    after = [ "network.target" "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];

    # We're going to run it on port 8000 in production
    environment = {
      PORT = "8000";
      DB_URL = "postgresql://disciplina@/disciplina?host=/tmp";
      DB_DIALECT = "postgres";
      JWT_SECRET_PATH = ../../secret.pem;   # SHOULD BE PUT MANUALLY ON DEPLOYER BEFORE DEPLOYMENT
      NETCORE_API = "";
      EMAIL_FROM = "test@stablewatch.io";
      EMAIL_NAME = "Stable Watches";
      FRONTEND_BASEURL = "https://multi-educator.watches.disciplina.io";
      ETH_PROVIDER_URL = "https://sepolia.infura.io/v3/${builtins.readFile keys.infura-key}";
      CERTGEN_API_URL  = "http://multi-educator:4040/api/educator/v1";
      DISCIPLINA_CONTRACT = "0xd25dB49fa9f9b27Ffe7B016395CEC704Ca650a8F";
      WALLET_SECRET = "wallet123123123";
      BTC_NETWORK="testnet";
      WETH_NATIVE_CONTRACT = "0xc778417E063141139Fce010982780140Aa0cD5Ab";
      UNISWAP_ROUTER_CONTRACT = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
      UNISWAP_V2_EXCHANGE_ADDRESS = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
      ETH_CHAIN_ID = "11155111";
      LIQUIDITY_ADDRESS = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
      LIQUIDITY_PRIVATE_KEY = "adasdasdsa";
    };
    serviceConfig = {
      ExecStartPre = common.postgres-pre-start;
      ExecStart = "${pkgs.nodejs-16_x}/bin/node ${pkgs.custodial-wallet-api}";
      # For security reasons we'll run this process as a special 'nodejs' user
      User = "disciplina";
      Restart = "always";
    };
  };

  users.extraUsers = {
    disciplina = {
      extraGroups = [ "keys" ];
      isSystemUser = true;
    };
  };
}
