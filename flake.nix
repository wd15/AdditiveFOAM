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

    };

    additivefoam = with config; pkgs.stdenv.mkDerivation rec {
      pname = "additivefoam";
      version = "dev";

      src = self;

      CMAKE_TLS_VERIFY=0;
      
      nativeBuildInputs = [
        pkgs.cmake
        derivations.openfoam
      ];

      buildInputs = [
        derivations.openfoam
        pkgs.openmpi
      ];

      propagatedBuildInputs = [
        pkgs.openmpi
        derivations.openfoam
      ];

    };
      
    packages = rec {
      default = openfoam;

      inherit (derivations) openfoam;
    };

    devShells = with config; rec {
      default = additivefoamDev;

      additivefoamDev = pkgs.mkShell rec {
        name = "additivefoam-dev";

        packages = with pkgs; [
          derivations.openfoam
          cmake
        ] ++ self.outputs.packages.${system}.default.buildInputs
          ++ self.outputs.packages.${system}.default.nativeBuildInputs
          ++ self.outputs.packages.${system}.default.propagatedBuildInputs;
        
        shellHook = ''
          source ${derivations.openfoam.outPath}/opt/OpenFOAM-12/etc/bashrc
        '';
      };

    };

});
}
