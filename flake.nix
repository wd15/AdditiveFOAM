## See NIX.md for help getting started with Nix

{
  description = "An open-source CFD code for additive manufacturing built on OpenFOAM.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    utils.url   = "github:numtide/flake-utils";
    exaca.url   = "github:wd15/ExaCA?ref=nix";
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
      exaca = inputs.exaca.packages.${system}.stable;

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
      default = additivefoamEnv;
      dev = additivefoamDev;
      
      additivefoamEnv = (
        let
          default = self.outputs.packages.${system}.default;
        in
          config.pkgs.mkShell rec {
            name = "additivefoam-env";
            
            packages = with config.pkgs; [
              openfoam
              default
              exaca
            ];

            shellHook = ''
              source ${openfoam.outPath}/opt/OpenFOAM-12/etc/bashrc
              export ADDITIVE_FOAM_INST_DIR=${default.outPath}
              export FOAM_USER_APPBIN=$ADDITIVE_FOAM_INST_DIR/bin
              export FOAM_USER_LIBBIN=$ADDITIVE_FOAM_INST_DIR/lib
              export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$FOAM_USER_LIBBIN
            '';
          }
      );

      additivefoamDev = (
        let
          default = self.outputs.packages.${system}.default;
          pkgs = config.pkgs;
        in
          config.pkgs.mkShell rec {
            name = "additivefoam-dev";
            
            packages = with config.pkgs; [
              openfoam
              exaca
            ]  ++ pkgs.lib.optionals (pkgs.stdenv.hostPlatform.isLinux) [
              gdb
              cntr
            ] ++ default.buildInputs
              ++ default.nativeBuildInputs
              ++ default.propagatedBuildInputs;

            LOCALE_ARCHIVE = pkgs.lib.optional (pkgs.stdenv.hostPlatform.isLinux) (
              "${pkgs.glibcLocales}/lib/locale/locale-archive"
            );
            shellHook = ''
              source ${openfoam.outPath}/opt/OpenFOAM-12/etc/bashrc
            '';
          }
      );


      
    };



    
  });
}
