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

    home = mkOption {
      type = types.path;
      default = /var/lib/disciplina-witness;
    };
  };

  config = mkIf cfg.enable {
    users.users.disciplina-witness = {
      createHome = true;
      home = toString cfg.home;
      isSystemUser = true;
    };

    systemd.services.disciplina-witness = {
      after = [ "network.target" ];
      requires = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.disciplina}/bin/dscp-witness ${attrsToFlags cfg.args}";
        User = "disciplina-witness";
      };
    };
  };
}
