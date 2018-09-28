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
  };

  config = mkIf cfg.enable {

    systemd.services.disciplina-witness = {
      after = [ "network.target" ];
      requires = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        cp /run/keys/witness.yaml /tmp/witness.yaml
        chmod 444 /tmp/witness.yaml
      '';

      serviceConfig = {
        ExecStart = "${pkgs.disciplina}/bin/dscp-witness ${attrsToFlags cfg.args}";
        PermissionsStartOnly = "true";
        DynamicUser = "true";
        StateDirectory = "disciplina-witness";
      };
    };
  };
}
