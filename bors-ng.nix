{ config, lib, pkgs, ... }:

let
  cfg = config.services.bors-ng;

in
  { options.services.bors-ng = {
      enable = lib.mkEnableOption "bors-ng";

      publicHost = lib.mkOption {
        description = ''
          The hostname that will be used to access bors-ng.
        '';

        example = "bors-app.herokuapp.com";

        type = lib.types.str;
      };

      port = lib.mkOption {
        description = ''
          The port for the bors-ng service to listen on.
        '';

        default = 4000;

        type = lib.types.int;
      };

      databaseURL = lib.mkOption {
        description = ''
          The PostgreSQL URL.
        '';

        default = "postgresql:///bors_ng?user=bors-ng";

        type = lib.types.str;
      };

      secretKeyBaseFile = lib.mkOption {
        description = ''
          Path to a file containing the secret key base for bors-ng.
          This key must be at least 64 bytes long.
        '';

        type = lib.types.either lib.types.path lib.types.str;
      };

      github = lib.mkOption {
        description = "GitHub Integration options";

        type = lib.types.submodule {
          options = {
            clientID = lib.mkOption {
              description = "GitHub OAuth Client ID.";

              type = lib.types.str;
            };

            clientSecretFile = lib.mkOption {
              description =
                "Path to a file containing the GitHub OAuth client secret.";

              type = lib.types.either lib.types.path lib.types.str;
            };

            integrationID = lib.mkOption {
              description = "Integration ID of the app registered in GitHub.";

              type = lib.types.int;
            };

            integrationPEMFile = lib.mkOption {
              description = ''
                Path to a file in PEM format containing the integration secret
                key of the app registered in GitHub.
              '';

              type = lib.types.either lib.types.path lib.types.str;
            };

            webhookSecretFile = lib.mkOption {
              description = ''
                Path to a file containing the GitHub webhook secret.
              '';

              type = lib.types.either lib.types.path lib.types.str;
            };
          };
        };
      };
    };

    config = lib.mkIf cfg.enable {
      nixpkgs.overlays = [ (import ./overlay.nix) ];

      users.users.bors-ng = {
        description = "bors-ng User";

        isSystemUser = true;

        group = "bors-ng";

        home = "/var/lib/bors-ng";

        createHome = true;
      };

      users.groups.bors-ng = { };

      systemd.services.bors-ng = {
        description = "A merge bot for GitHub pull requests";

        wantedBy = [ "multi-user.target" ];

        environment = {
          DATABASE_AUTO_MIGRATE = "true";

          DATABASE_URL = cfg.databaseURL;

          DATABASE_USE_SSL = "false";

          GITHUB_CLIENT_ID = cfg.github.clientID;

          GITHUB_INTEGRATION_ID = toString cfg.github.integrationID;

          PORT = toString cfg.port;

          PUBLIC_HOST = cfg.publicHost;
        };

        path = [ pkgs.bors-ng ];

        script = ''
          export SECRET_KEY_BASE="$(< ${cfg.secretKeyBaseFile})"
          export GITHUB_CLIENT_SECRET="$(< ${cfg.github.clientSecretFile})"
          export GITHUB_INTEGRATION_PEM="$(base64 -w0 ${cfg.github.integrationPEMFile})"
          export GITHUB_WEBHOOK_SECRET="$(< ${cfg.github.webhookSecretFile})"

          bors eval 'BorsNG.Database.Migrate.run_standalone()'
          bors start
        '';

        serviceConfig = {
          User = "bors-ng";

          Group = "bors-ng";

          Restart = "on-failure";
        };
      };
    };
  }
