{ config, lib, pkgs, ... }: with lib;

let
  cfg = config.services.disciplina;
  mkConfig = configAttrs: pkgs.writeText "disciplina-config.yaml" (builtins.toJSON configAttrs);
  stateDir = "/var/lib/disciplina-${cfg.type}";
  attrsToFlags = set:
    let
      render = name: value: "--" + name + (optionalString (isString value) (" " + value));
      renderList = name: value: map (render name) (lib.toList value);
    in
    concatStringsSep " " (concatLists (mapAttrsToList renderList set));

in

{
  options.services.disciplina = {
    enable = mkEnableOption "Disciplina witness";

    type = mkOption {
      type = types.enum [ "witness" "faucet" "educator" ];
      default = "witness";
      description = ''
        The type of node to spawn. Sets the systemd unit name to
        `disciplina-<type>`, state dir to `/var/lib/disciplina-<type>`, and
        runs `dscp-<type>`.
      '';
    };

    upstreamConfigFile = mkOption {
      type = types.package;
      default = pkgs.disciplina-config;
      description = ''
        Upstream config file passed as first --config option to service.
      '';
    };

    config = mkOption {
      type = types.attrs;
      default = {};
      description = ''
        Options written to the config.yaml file passed to the service.
      '';
    };

    args = mkOption {
      type = types.attrs;
      default = {};
      description = ''
        Set of arguments passed to witness CLI
      '';
    };

    requires = mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        Systemd services that this one depends on.
        Will be added to Requires in After in the systemd unit.
      '';
    };

    serviceConfig = mkOption {
      default = {};
      type = types.attrs;
      description = ''
        Systemd serviceConfig.
      '';
    };

  };

  config = mkIf cfg.enable {

    users.users.disciplina = {
      home = stateDir;
      extraGroups = [ "keys" ];
      createHome = true;
      isSystemUser = true;
    };

    systemd.services."disciplina-${cfg.type}" = rec {
      inherit (cfg) requires;
      after = [ "network.target" ] ++ requires;
      wantedBy = [ "multi-user.target" ];

      path = with pkgs; [ curl ];

      script = ''
        set -euxo pipefail
        exec ${pkgs.disciplina}/bin/dscp-${cfg.type} --config ${cfg.upstreamConfigFile} --config ${mkConfig cfg.config} ${attrsToFlags cfg.args}
      '';

      serviceConfig = {
        User = "disciplina";
        WorkingDirectory = stateDir;
        StateDirectory = "disciplina-${cfg.type}";
      } // cfg.serviceConfig;
    };
  };
}
