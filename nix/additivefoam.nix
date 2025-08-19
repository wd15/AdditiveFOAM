{
  stdenv,
  openfoam,
  src,
  version
}:
stdenv.mkDerivation rec {
  pname = "additivefoam";
  inherit version;
  inherit src;

  sourceRoot = ".";

  buildInputs = [
    openfoam
  ];
        
  buildPhase = ''
    runHook preBuild

    mkdir -p builduser/.OpenFOAM
    mkdir -p builduser/OpenFOAM
    export HOME=$(pwd)/builduser
    export USER=builduser

    source ${openfoam.outPath}/opt/OpenFOAM-12/etc/bashrc || true

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

  doCheck = true;

  checkPhase = ''

    cd $HOME
    mkdir -p app
    cp -r ${src}/tutorials/AMB2018-02-B/* app/
    chmod u+w -R app
    cd app
    ./Allrun

  '';
  
}
