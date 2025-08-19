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

      openfoam = callPackage ./nix/openfoam.nix { scotch = scotch; };
      scotch = callPackage ./nix/scotch.nix { };      
      additivefoam = callPackage ./nix/additivefoam.nix {
        openfoam = openfoam;
        src = self;
        version = self.shortRev or self.dirtyShortRev;
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
        ];

        shellHook = ''
          source ${derivations.openfoam.outPath}/opt/OpenFOAM-12/etc/bashrc
          export FOAM_USER_APPBIN=${derivations.additivefoam.outPath}/bin
          export FOAM_USER_LIBBIN=${derivations.additivefoam.outPath}/lib
        '';

      };

    };

});
}
