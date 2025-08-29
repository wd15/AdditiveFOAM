## See NIX.md for help getting started with Nix

{
  description = "An open-source CFD code for additive manufacturing built on OpenFOAM.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    utils.url   = "github:numtide/flake-utils";
    exaca.url   = "github:wd15/ExaCA/nix?dir=envs/nix";
  };

  outputs = inputs @ { self, utils, ... }: utils.lib.eachDefaultSystem (system: rec {
    config = rec {
      pkgs = import inputs.nixpkgs {
        inherit system;        
        config.cudaSupport = true;
        config.allowUnfree = true;
      };
    };

    lib = with config; {
      callPackage = set: pkgs.lib.callPackageWith (pkgs // set);
    };

    derivations = with config; rec {
      callPackage = lib.callPackage {};

      openfoam = callPackage ./nix/openfoam.nix { scotch = scotch; };
      scotch = callPackage ./nix/scotch.nix { };
      exaca = inputs.exaca.packages.${system}.default;

      additivefoam =
        let
          args = { exaca = exaca; openfoam = openfoam; };
        in
          {
            devel = callPackage ./nix/additivefoam.nix ({
              src = self;
              version = self.shortRev or self.dirtyShortRev;
            } // args);
            
            stable = callPackage ./nix/additivefoam.nix (rec {
              src = pkgs.fetchFromGitHub {
                owner = "ORNL";
                repo = "AdditiveFOAM";
                rev = "${version}";
                hash = "sha256-P7deK129ZiIvxYhP9AjxTX7PNDURF84jEcsIP1DRxPg=";
              };
              version = "1.1.0";
            } // args);
          };
      
    };
    
    packages = rec {
      default = additivefoam.devel;
      stable = additivefoam.stable;
        
      inherit (derivations) additivefoam openfoam exaca;
    };

    devShells = with derivations; rec {
      
      openfoam-env = config.pkgs.mkShell {
        name = "openfoam-env";
      
        packages = [
          openfoam
          exaca
        ];

        shellHook = ''
          source ${derivations.openfoam.outPath}/opt/OpenFOAM-12/etc/bashrc
        '';
      };

      default = openfoam-env.overrideAttrs (old: {
        name = "additivefoam-env";

        nativeBuildInputs = [
          additivefoam.devel
        ] ++ old.nativeBuildInputs;

      });

      stable = openfoam-env.overrideAttrs (old: {
        name = "additivefoam-stable-env";

        nativeBuildInputs = [
          additivefoam.stable
        ] ++ old.nativeBuildInputs;

      });
      
      devel = default.overrideAttrs (old: {
        name = "additivefoam-dev";

        nativeBuildInputs =
          old.nativeBuildInputs ++
          pkgs.lib.optionals (pkgs.stdenv.hostPlatform.isLinus) [
            gdb
            cntr
          ] ++ additivefoam.devel.buildInputs
          ++ additivefoam.devel.default.nativeBuildInputs
          ++ additivefoam.devel.propagatedBuildInputs;

        LOCALE_ARCHIVE = pkgs.lib.optional (pkgs.stdenv.hostPlatform.isLinux) (
          "${pkgs.glibcLocales}/lib/locale/locale-archive"
        );

      });
      
    };

  });
}
