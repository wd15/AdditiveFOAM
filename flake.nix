## See NIX.md for help getting started with Nix

{
  description = "An exascale-capable cellular automaton for nucleation and grain growth";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
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

      openfoam = callPackage ./openfoam.nix {};

    };

    exaca = with config; pkgs.stdenv.mkDerivation rec {
      pname = "exaca";
      version = "dev";

      src = self;

      CMAKE_TLS_VERIFY=0;
      
      nativeBuildInputs = [
        pkgs.cmake
      ];

      buildInputs = [
        pkgs.kokkos
        pkgs.openmpi
      ];

      propagatedBuildInputs = [
        pkgs.openmpi
      ];

    };
      
    packages = rec {
      default = openfoam;

      inherit (derivations) openfoam;
    };

  });

}
