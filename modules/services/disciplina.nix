{ config, lib, pkgs, ... }: with lib;

let
  cfg = config.services.disciplina;

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

    args = mkOption {
      type = types.attrs;
      default = {};
      description = ''
        Set of arguments passed to witness CLI
      '';
    };

    keyFiles = mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        list of files from /run/keys to copy to /tmp
      '';
    };
  };

  config = mkIf cfg.enable {

    systemd.services."disciplina-${cfg.type}" = let
      cfgfile = "${stateDir}/config.yaml";
      stateDir = "/var/lib/disciplina-${cfg.type}";
      keyServices = map (x: "${x}-key.service") cfg.keyFiles;
      keyScript = concatMapStringsSep "\n" (x: "cp /run/keys/${x} /tmp/${x}; chmod 444 /tmp/${x}") cfg.keyFiles;
      preStartScript = pkgs.writeScript "disciplina-${cfg.type}-prestart.sh" ''
        #!${pkgs.bash}/bin/bash -e
        ${keyScript}
      '';
    in
      rec {
      after = [ "network.target" ] ++ keyServices;
      requires = after;
      wantedBy = [ "multi-user.target" ];

      environment.HOME = stateDir;

      script = ''
        exec ${pkgs.disciplina}/bin/dscp-${cfg.type} ${attrsToFlags cfg.args}
      '';

      serviceConfig = {
        DynamicUser = true;
        StateDirectory = "disciplina-${cfg.type}";
        WorkingDirectory = stateDir;
        ExecStartPre = "!${preStartScript}";
      };
    };
  };
}
