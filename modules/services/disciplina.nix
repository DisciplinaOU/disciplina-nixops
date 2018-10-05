{ config, lib, pkgs, ... }: with lib;

let
  cfg = config.services.disciplina;

  attrsToFlags = set:
    let
      render = name: value: "--" + name + (optionalString (isString value) (" " + value));
      renderList = name: value: map (render name) (lib.toList value);
    in
    concatStringsSep " " (concatLists (mapAttrsToList renderList set));

  stateDir = "/var/lib/disciplina-${cfg.type}";
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

    args = mkOption {
      type = types.attrs;
      default = {};
      description = ''
        Set of arguments passed to witness CLI
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
      after = [ "network.target" ];
      requires = after;
      wantedBy = [ "multi-user.target" ];

      path = with pkgs; [ curl ];

      script = ''
        exec ${pkgs.disciplina}/bin/dscp-${cfg.type} ${attrsToFlags cfg.args}
      '';

      serviceConfig = {
        User = "disciplina";
        WorkingDirectory = stateDir;
        StateDirectory = "disciplina-${cfg.type}";
      };
    };
  };
}
