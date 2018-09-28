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

    systemd.services.disciplina-witness = {
      after = [ "network.target" ];
      requires = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        cat ${lib.concatStringsSep " " cfg.configFiles} |
          ${pkgs.yq}/bin/yq -n 'reduce [inputs][] as $item ({}; . * $item)' > /tmp/config.yaml

        chmod 444 /tmp/config.yaml
      '';

      serviceConfig = {
        ExecStart = "${pkgs.disciplina}/bin/dscp-witness --config /tmp/config.yaml ${attrsToFlags cfg.args}";
        PermissionsStartOnly = "true";
        DynamicUser = "true";
        StateDirectory = "disciplina-witness";
      };
    };
  };
}
