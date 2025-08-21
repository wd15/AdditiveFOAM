{
  stdenv,
  openfoam,
  openmpi,
  exaca,
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
    openmpi
  ];

  propagatedBuildInputs = [
    exaca
    openmpi
  ];
  
  buildPhase = ''
    runHook preBuild

    mkdir -p builduser/.OpenFOAM
    mkdir -p builduser/OpenFOAM
    export HOME=$(pwd)/builduser
    export USER=builduser

    source ${openfoam.outPath}/opt/OpenFOAM-12/etc/bashrc || true

    APPS_DIR=$(pwd)/source/applications/solvers/additiveFoam

    cd $APPS_DIR/movingHeatSource
    wmake libso

    cd $APPS_DIR/functionObjects/ExaCA
    wmake libso

    cd $APPS_DIR
    wmake

    runHook postBuild
  '';

  installPhase = ''
  runHook preInstall

  mkdir -p $out

  cp -r $FOAM_USER_APPBIN $out
  cp -r $FOAM_USER_LIBBIN $out

  cp -r ${src}/applications $out/
  cp -r ${src}/tutorials $out/

  runHook postInstall
  '';

  doCheck = true;

  checkPhase = ''

    cd $HOME
    mkdir -p app
    cp -r ${src}/tutorials/AMB2018-02-B/* app/
    chmod u+w -R app
    cd app

    # broken in parallel?
    substituteInPlace $HOME/app/Allrun --replace-fail "runParallel" "runApplication"
    substituteInPlace $HOME/app/Allrun --replace-fail "~/install/exaca/bin/ExaCA" "ExaCA"

    ./Allrun -withExaCA

    test -e ExaCA/Output.vtk

  '';
  
}
