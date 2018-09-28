{ config, lib, pkgs, ... }: with lib;

let
  cfg = config.services.disciplina-witness;

  attrsToFlags = set:
    let
      render = name: value:
        "--" + name + (optionalString (isString value) (" " + value));

      renderList = name: value:
        if isList value
        then map (render name) value
        else [ (render name value) ];
    in
    concatStringsSep " " (concatLists (mapAttrsToList renderList set));
in

{
  options.services.disciplina-witness = {
    enable = mkEnableOption "Disciplina witness";

    args = mkOption {
      type = types.attrs;
      default = {};
    };

    configFiles = mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        List of file paths (as strings) to merge and pass to witness node
      '';
    };
  };

  config = mkIf cfg.enable {

    systemd.services.disciplina-witness = let
      cfgfile = "${stateDir}/config.yaml";
      stateDir = "/var/lib/disciplina-witness";
    in
      {
      after = [ "network.target" ];
      requires = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        ${pkgs.yq}/bin/yq -s '.[0] * .[1]' ${lib.concatStringsSep " " cfg.configFiles} >| ${cfgfile}
        chmod 444 ${cfgfile}

        cp /run/keys/witness-keyfile-pass /tmp/witness-keyfile-pass
        chmod 444 /tmp/witness-keyfile-pass
      '';

      environment.HOME = stateDir;

      serviceConfig = {
        ExecStart = "${pkgs.disciplina}/bin/dscp-witness --config ${cfgfile} ${attrsToFlags cfg.args}";
        PermissionsStartOnly = "true";
        DynamicUser = "true";
        StateDirectory = "disciplina-witness";
        WorkingDirectory = stateDir;
      };
    };
  };
}
