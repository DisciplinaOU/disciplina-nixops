{ lib, config, pkgs, deploymentName, ...}: with lib; {
  options.awskeys = mkOption {
    type = types.loaOf (types.submodule (
      { name, config, ... }:
      {
        options = rec {
          destDir = mkOption {
            default = "/run/keys";
            type = types.path;
            description = ''
              When specified, this allows changing the destDir directory of the key
              file from its default value of <filename>/run/keys</filename>.

              This directory will be created, its permissions changed to
              <literal>0555</literal> and ownership to <literal>root:keys</literal>.
            '';
          };

          path = mkOption {
            type = types.path;
            default = "${config.destDir}/${name}";
            internal = true;
            description = ''
              Path to the destination of the file, a shortcut to
              <literal>destDir</literal> + / + <literal>name</literal>

              Example: For key named <literal>foo</literal>,
              this option would have the value <literal>/run/keys/foo</literal>.
            '';
          };

          user = mkOption {
            default = "root";
            type = types.str;
            description = ''
              The user which will be the owner of the key file.
            '';
          };

          group = mkOption {
            default = "root";
            type = types.str;
            description = ''
              The group that will be set for the key file.
            '';
          };

          permissions = mkOption {
            default = "0440";
            type = types.str;
            description = ''
              The default permissions to set for the key file, needs to be in the
              format accepted by <citerefentry><refentrytitle>chmod</refentrytitle>
              <manvolnum>1</manvolnum></citerefentry>.
            '';
          };

          region = mkOption {
            type = types.str;
            description = ''
              The AWS region.
            '';
          };

          services = mkOption {
            type = types.listOf types.string;
            default = [];
            example = [ "nginx" ];
          };

          secretId = mkOption {
            type = types.str;
            description = ''
              The secret name.
            '';
          };

          key = mkOption {
            # This option deliberately has no default, using an entire blob
            # rather than a specific secret should be deliberate.
            type = types.nullOr types.str;
            description = ''
              The key in the json secret, or null for the entire blob.
            '';
          };

          __toString = mkOption {
            default = self: self.path;
            readOnly = true;
          };
        };
      }));
    default = {};
  };

  config = {
    systemd.services = lib.mkMerge ([ (flip mapAttrs' config.awskeys (name: keyCfg:
    nameValuePair "${name}-key" rec {
      requires = [ "network.target" ];
      after = requires;
      path = with pkgs; [ awscli jq ];

      serviceConfig.Type = "oneshot";
      script = ''
        set -euo pipefail
        mkdir -p /run/keys
        chown root:root /run/keys
        chmod 0555 /run/keys
        touch ${keyCfg.path}
        chown ${keyCfg.user}:${keyCfg.group} ${keyCfg.path}
        chmod ${keyCfg.permissions} ${keyCfg.path}

        aws secretsmanager get-secret-value \
          --secret-id ${keyCfg.secretId} --region ${keyCfg.region} \
          | jq -r .SecretString \
          ${lib.optionalString (keyCfg.key != null) "| jq -r .${keyCfg.key}"} \
          > ${keyCfg.path}
      '';
    })) ] ++ (lib.mapAttrsToList (name: { services, ...}@val: lib.genAttrs services (service: rec {
      requires = [ "${name}-key.service" ];
      after = requires;
      restartTriggers = [ (toString val) ];
    })) config.awskeys));
  };
}
