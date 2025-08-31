{ self', pkgs, lib, ...}:

{
  devShells = with self'.packages; rec {
    default = pkgs.mkShell {
      name = "additivefoam-env";

      packages = [
        openfoam
        exaca
        self'.packages.default
      ];

      shellHook = ''
        source ${openfoam.outPath}/opt/OpenFOAM-12/etc/bashrc\
      '';                    
      
    };


    devel = pkgs.mkShell {
      name = "additivefoam-dev";

      packages = [
        openfoam
        exaca
      ];

      inputsFrom = [
        self'.packages.default
      ];

      shellHook = ''
        source ${openfoam.outPath}/opt/OpenFOAM-12/etc/bashrc\
      '';      

      LOCALE_ARCHIVE = pkgs.lib.optional (pkgs.stdenv.hostPlatform.isLinux) (
        "${pkgs.glibcLocales}/lib/locale/locale-archive"
      );
    };
  };
}
