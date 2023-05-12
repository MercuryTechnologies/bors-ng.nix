{ config, lib, pkgs, ... }:

let
  secretsDirectory = config.virtualisation.sharedDirectories.secrets.target;

in

{ containers.bors-ng = {
    autoStart = true;

    bindMounts."/var/secrets".hostPath = "/var/secrets";

    forwardPorts = [ { hostPort = config.services.bors-ng.port; } ];

    config = {
      imports = [ ./bors-ng.nix ];

      # NOTE: This is to work around the `/var/secrets` 9p mount not being
      # readable to non-`root` users inside the container.
      security.sudo.extraRules =
        let
          permit = filename: {
            users = [ "bors-ng" ];
            commands = [
              { command =
                  "${pkgs.coreutils}/bin/cat ${secretsDirectory}/${filename}";

                options = [ "NOPASSWD" "SETENV" ];
              }
            ];
          };

        in
          map permit [
            "client-secret.txt"
            "private-key.pem"
            "secret-key-base.txt"
            "webhook-secret.txt"
          ];

      services = {
        bors-ng = {
          enable = true;

          publicHost = "bors-ng.example.com";

          secretKeyBaseFile = "<(/run/wrappers/bin/sudo ${pkgs.coreutils}/bin/cat ${secretsDirectory}/secret-key-base.txt)";

          github = {
            clientID = "Iv1.53ee025385b27c1a";

            clientSecretFile =
              "<(/run/wrappers/bin/sudo ${pkgs.coreutils}/bin/cat ${secretsDirectory}/client-secret.txt)";

            integrationID = 604707;

            integrationPEMFile =
              "<(/run/wrappers/bin/sudo ${pkgs.coreutils}/bin/cat ${secretsDirectory}/private-key.pem)";

            webhookSecretFile =
              "<(/run/wrappers/bin/sudo ${pkgs.coreutils}/bin/cat ${secretsDirectory}/webhook-secret.txt)";
          };
        };

        postgresql = {
          enable = true;

          ensureDatabases = [ "bors_ng" ];

          ensureUsers = [
            { name = "bors-ng";

              ensurePermissions."DATABASE 'bors_ng'" = "ALL PRIVILEGES";
            }
          ];

          authentication = ''
            host all all 127.0.0.1/32 trust
          '';
        };
      };

      system.stateVersion = "22.11";

      systemd.services.bors-ng = {
        after = [ "postgresql.service" ];

        requires = [ "postgresql.service" ];
      };
    };
  };

  services.getty.autologinUser = "root";

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  security.acme = {
    defaults.email = "webmaster@example.com";

    acceptTerms = true;
  };

  services.nginx = {
    recommendedProxySettings = true;

    recommendedTlsSettings = true;

    virtualHosts = {
      "${config.services.bors-ng.publicHost}" = {
        forceSSL = true;

        enableACME = false; # TODO: true

        locations."/" = {
          proxyPass =
            "http://localhost:${toString config.services.bors-ng.port}";
        };
      };
    };
  };

  system.stateVersion = "22.11";

  virtualisation.sharedDirectories = {
    secrets = {
      source = "$SECRETS";

      target = "/var/secrets";
    };
  };
}
