self: super: {
  bors-ng = self.beamPackages.mixRelease rec {
    pname = "bors-ng";

    src = self.fetchFromGitHub {
      owner = "bors-ng";

      repo = "bors-ng";

      rev = "2d5e98c76f43825ec8040fa862bb75d896dca482";

      hash = "sha256-AYb/XvKaLyvUHiGJv/5Bo/EDNjdnypsas1iOouNIf80=";

      # This is the real `package-lock.json`.  The one at the top-level of the
      # project is fairly useless.  We have to copy it to the top level for
      # `fetchNpmDeps` and `npmConfigHook` to work.
      postFetch =
        ''
        cp "$out/assets/package-lock.json" "$out/package-lock.json"
        '';
    };

    version = "0.1.5";

    nativeBuildInputs = [
      self.nodePackages.npm
      self.nodePackages.webpack-cli
      self.npmHooks.npmConfigHook
      self.npmHooks.npmInstallHook
    ];

    npmDeps = (self.fetchNpmDeps {
      inherit src;

      hash = "sha256-h1Mb3wb++WseCJdLqmMxlwzz83CW0yBHny6knccrIwk=";
    }).overrideAttrs (old: {
      # TODO: Upstream this fix into Nixpkgs
      preBuild = (old.preBuild or "") +
        ''
        mkdir $out
        '';
    });

    npmInstallFlags = "--prefix=assets --legacy-peer-deps";

    patches = [ ./user-agent.patch ];

    preInstall =
      let
        phoenix = self.fetchFromGitHub {
          owner = "phoenixframework";
          repo = "phoenix";
          rev = "v1.5.8";
          hash = "sha256-KNDOLHSi0t+oyw/P4NfuUmvI3muz5kb/yKwv482JcdM=";
        };

        phoenix_html = self.fetchFromGitHub {
          owner = "phoenixframework";
          repo = "phoenix_html";
          rev = "v3.3.0";
          hash = "sha256-GbNF/LlZJMaHGtlEc0a3Y1JvWyhcRZ2BZyid7oqwecc=";
        };
      in
        ''
        mkdir --parents deps
        ln --symbolic ${phoenix} deps/phoenix
        ln --symbolic ${phoenix_html} deps/phoenix_html
        (cd assets; webpack-cli)
        mix phx.digest --no-deps-check
        '';

    postInstall =
      ''
      wrapProgram $out/bin/bors --set RELEASE_COOKIE '0'
      '';

    mixNixDeps = import ./deps.nix {
      inherit (self) lib beamPackages;

      overrides = bself: bsuper: {
        cowboy = bsuper.cowboy.overrideAttrs (old: {
          IS_DEP = 1;
        });

        distillery = self.beamPackages.buildMix {
          name = "distillery";

          version = "0.0.0";

          src = self.fetchFromGitHub {
            owner = "bors-ng";

            repo = "distillery";

            rev = "8ba8cb437e10e873152f1c44f13c5181752ba142";

            hash = "sha256-yxReIajBoalidyE27xw26s1jMemDiSOMVnXO+zGSS+4=";
          };

          beamDeps = [
            bself.artificery
          ];
        };

        glob = self.beamPackages.buildRebar3 {
          name = "glob";

          version = "1.0.0";

          src = self.fetchFromGitHub {
            owner = "bors-ng";

            repo = "glob";

            rev = "7befe06698027e814cd654d5e2c52817749050bb";

            hash = "sha256-T/eWK1DWKwVkwjtc3pnrsb37eUVD80eypB7dVS0vEBA=";
          };

          beamDeps = [ ];
        };
      };
    };
  };
}
