## See NIX.md for help getting started with Nix

{
  description = "An open-source CFD code for additive manufacturing built on OpenFOAM.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    # nixpkgs.url = "github:nixos/nixpkgs?ref=25.05;
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
      additivefoam = callPackage ./nix/additivefoam.nix {
        openfoam = openfoam;
        src = self;
        version = self.shortRev or self.dirtyShortRev;
      };
      exaca = inputs.exaca.packages.${system}.default;
    };
    
    packages = rec {
      default = additivefoam;
        
      inherit (derivations) additivefoam openfoam exaca;
    };

    devShells = with derivations; rec {
      default = additivefoamDev;

      additivefoamDev = config.pkgs.mkShell rec {
        name = "additivefoam-dev";

        packages = with config.pkgs; [
          openfoam
          additivefoam
          exaca
        ];

        shellHook = ''
          source ${openfoam.outPath}/opt/OpenFOAM-12/etc/bashrc
          export FOAM_USER_APPBIN=${additivefoam.outPath}/bin
          export FOAM_USER_LIBBIN=${additivefoam.outPath}/lib
        '';
      };

    };

});
}
