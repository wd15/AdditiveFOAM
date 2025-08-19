## See NIX.md for help getting started with Nix

{
  description = "An exascale-capable cellular automaton for nucleation and grain growth";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    # nixpkgs.url = "github:nixos/nixpkgs?ref=25.05;
    utils.url   = "github:numtide/flake-utils";
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

      openfoam = callPackage ./openfoam.nix { scotch = scotch; };
      scotch = callPackage ./scotch.nix { };      

      additivefoam = with config; pkgs.stdenv.mkDerivation rec {
        pname = "additivefoam";
        version = "dev";

        sourceRoot = ".";
        src = self;

        dontUseCmakeConfigure = true;

        buildInputs = [
          derivations.openfoam
          pkgs.openmpi
        ];
        
        propagatedBuildInputs = [
          pkgs.openmpi
          derivations.openfoam
        ];


        buildPhase = ''
          runHook preBuild

          mkdir -p builduser/.OpenFOAM
          mkdir -p builduser/OpenFOAM
          export HOME=$(pwd)/builduser
          export USER=builduser

          source ${derivations.openfoam.outPath}/opt/OpenFOAM-12/etc/bashrc || true

          cd source/applications/solvers/additiveFoam/movingHeatSource
          wmake libso

          cd ..
          wmake

          runHook postBuild
        '';

        installPhase = ''
        runHook preInstall

        mkdir -p $out

        cp -r $FOAM_USER_APPBIN $out
        cp -r $FOAM_USER_LIBBIN $out

        runHook postInstall
        '';

      
      };

    };
    
    packages = rec {
      default = additivefoam;
        
      inherit (derivations) additivefoam openfoam;
    };

    devShells = with config; rec {
      default = additivefoamDev;

      additivefoamDev = pkgs.mkShell rec {
        name = "additivefoam-dev";

        packages = with pkgs; [
          derivations.openfoam
          derivations.additivefoam
          cmake
          clang-tools
        ] ++ pkgs.lib.optionals (pkgs.stdenv.hostPlatform.isLinux) [
          gdb
          cntr
        ] ++ derivations.openfoam.nativeBuildInputs
          ++ derivations.openfoam.propagatedBuildInputs;

        shellHook = ''
          source ${derivations.openfoam.outPath}/opt/OpenFOAM-12/etc/bashrc
          export FOAM_USER_APPBIN=${derivations.additivefoam.outPath}/bin
          export FOAM_USER_LIBBIN=${derivations.additivefoam.outPath}/lib
        '';

      };

    };

});
}
