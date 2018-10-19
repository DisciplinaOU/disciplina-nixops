{ config, lib, pkgs, ... }: with lib;

let
  cfg = config.services.educator_aaa;
  keys = config.dscp.keys;
  package = pkgs.educator_aaa;
  stateDirName = "educator_aaa";
  stateDir = "/var/lib/${stateDirName}";
in

{
  options.services.educator_aaa = {
    enable = mkEnableOption "Educator AAA";

    virtualHost = mkOption {
      default = "educator_aaa";
      type = types.nullOr types.string;
    };

    port = mkOption {
      type = types.int;
    };
  };

  config = mkIf cfg.enable {
    users.users.educator_aaa = {
      home = "/var/lib/${stateDir}";
      createHome = true;
      isSystemUser = true;
    };

    services.postgresql = {
      enable = true;
      package = pkgs.postgresql100;
      initialScript = pkgs.writeText "educator_aaa.psql" ''
        CREATE ROLE "educator_aaa" LOGIN PASSWORD 'educator_aaa';
        CREATE DATABASE "educator_aaa" OWNER 'educator_aaa';
      '';
    };

    services.nginx.virtualHosts = mkIf (cfg.virtualHost != null) {
      ${cfg.virtualHost}.locations."/".proxyPass =
        "http://localhost:${toString cfg.port}";
    };

    dscp.keys = {
      # Contains AWS bucket keys and secret key base
      educator_aaa = {
        user = "educator_aaa";
        services = [ "educator_aaa" ];
        shared = false;
        extension = "env";
      };
    };

    systemd.services."educator_aaa" = rec {
      after = [ "network.target" "postgresql.service" ];
      requires = after;
      wantedBy = [ "multi-user.target" ];

      environment = {
        MIX_ENV = "prod";
        RELEASE_MUTABLE_DIR = "/var/lib/${stateDir}";
        PORT = toString cfg.port;
        DATABASE_URL = "postgres://educator_aaa:educator_aaa@localhost/educator_aaa";
      };

      script = ''
        exec ${package}/bin/educator_aaa foreground
      '';

      serviceConfig = {
        EnvironmentFile = toString keys.educator_aaa;
        User = "educator_aaa";
        WorkingDirectory = "/var/lib/${stateDir}";
        StateDirectory = stateDir;
      };
    };
  };
}
