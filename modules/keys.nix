{ lib, config, deploymentName, ...}: with lib; {
  options.dscp = {
    keydir = mkOption {
      type = types.nullOr types.string;
    };

    keys = mkOption {
      type = types.loaOf (types.submodule (
        { name, config, ... }:
        {
          options = {
            user = mkOption { type = types.nullOr types.string; default = null; };
            keyname = mkOption {
              type = types.string;
              default = name;
            };
            extension = mkOption {
              type = types.string;
              default = "key";
            };
            shared = mkOption {
              type = types.bool; default = true;
            };
            services = mkOption {
              type = types.listOf types.string;
              default = [];
              example = [ "nginx" ];
            };
            __toString = mkOption {
              default = self: "/run/keys/${name}";
              readOnly = true;
            };
          };
        }));
      default = {};
    };
  };

  config =
    let toPath = value: with value; ../keys + "/${lib.optionalString (!shared) (config.dscp.keydir + "/")}/${keyname}.${extension}";
    in
      mkIf (config.dscp.keydir != null) {
        assertions = lib.mapAttrsToList (name: value: {
          assertion = builtins.pathExists (toPath value);
          message = "key ${toPath value} doesn't exist";
        }) config.dscp.keys;

        deployment.keys = (lib.mapAttrs (name: value: {
          keyFile = toPath value;
          user = mkIf (value.user != null) value.user;
        }) config.dscp.keys);

        systemd.services = lib.mkMerge (lib.mapAttrsToList (name: { services, ...}@val: lib.genAttrs services (service: rec {
          requires = [ "${name}-key.service" ];
          after = requires;
          restartTriggers = [ (toString val) ];
        })) config.dscp.keys);
      };
}
