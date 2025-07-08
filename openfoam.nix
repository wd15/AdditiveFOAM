{
  stdenv,
  bash,
  m4,
  flex,
  bison,
  fftw,
  gnumake,
  mpi,
  scotch,
  boost,
  cgal,
  zlib,
  fetchFromGitHub,
  lib,
  trilinos-mpi,
  nix-update-script,
  version_ ? "12"
}:
stdenv.mkDerivation rec {
  pname = "openfoam-org";
  version = version_;
  hash = if version == "12" then
    "sha256-++WRLffDiFeYo5Fv3zBjgmV+PqwYTTtuvqjx4iKF5RI="
         else
           "sha256-1vcBZELsThlfSJeW3iFm8sTh+uOgKKEYU0g+XlxczdA=";
  src = fetchFromGitHub {
    owner = "OpenFOAM";
    repo = "OpenFOAM-12";
    rev = "refs/tags/version-${version}";
    hash = hash; #"sha256-1vcBZELsThlfSJeW3iFm8sTh+uOgKKEYU0g+XlxczdA="; #sha256-++WRLffDiFeYo5Fv3zBjgmV+PqwYTTtuvqjx4iKF555=";

  };
  meta = with lib; {
    description = "Open source computational fluid dynamics toolkit";
    homepage = "https://github.com/OpenFOAM/OpenFOAM-12";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ gusgibbon ];
    platforms = with platforms; [ "x86_64-linux" ];
  };
  passthru.updateScript = nix-update-script { };
  nativeBuildInputs = [
    gnumake
    bash
    m4
    flex
    bison
  ];
  buildInputs = [
    fftw
    mpi.dev
    scotch
    boost
    cgal
    zlib
    trilinos-mpi
  ];
  sourceRoot = ".";
  patchPhase = ''
    runHook prePatch

    mkdir -p builduser/OpenFOAM
    mkdir -p builduser/.OpenFOAM
    export HOME=$(pwd)/builduser
    mv source builduser/OpenFOAM/OpenFOAM-12
    mkdir -p builduser/OpenFOAM/OpenFOAM-12/paraviewout

    echo "hello1"
    ls $HOME/OpenFOAM/OpenFOAM-12/wmake

    set +e
    for f in \
        $HOME/OpenFOAM/OpenFOAM-12/wmake/scripts/* \
        $HOME/OpenFOAM/OpenFOAM-12/wmake/*
    do
      substituteInPlace $f --replace-quiet /bin/bash ${bash}/bin/bash
      #substituteInPlace $f --replace-fail /bin/bash ${bash}/bin/bash
    done
    set -e

    echo "hello2"
    rm $HOME/OpenFOAM/OpenFOAM-12/etc/config.sh/bash_completion
    touch $HOME/OpenFOAM/OpenFOAM-12/etc/config.sh/bash_completion

    echo "hello3"
    echo "set +e" | cat $HOME/OpenFOAM/OpenFOAM-12/etc/bashrc > tmp
    rm $HOME/OpenFOAM/OpenFOAM-12/etc/bashrc
    mv tmp $HOME/OpenFOAM/OpenFOAM-12/etc/bashrc

    echo "hello4"
    echo "set +e" | cat $HOME/OpenFOAM/OpenFOAM-12/Allwmake > tmp
    rm $HOME/OpenFOAM/OpenFOAM-12/Allwmake
    mv tmp $HOME/OpenFOAM/OpenFOAM-12/Allwmake

    alias wmRefresh="placeholder"
    chmod +x $HOME/OpenFOAM/OpenFOAM-12/Allwmake
    chmod +x $HOME/OpenFOAM/OpenFOAM-12/applications/utilities/postProcessing/graphics/PVReaders/Allwmake
    touch $HOME/.OpenFOAM/prefs.sh

    runHook postPatch
  '';
  configurePhase = ''
    runHook preConfigure

    echo "export ZOLTAN_TYPE=system" >> $HOME/.OpenFOAM/prefs.sh
    echo "export SCOTCH_TYPE=system" >> $HOME/.OpenFOAM/prefs.sh

    runHook postConfigure
  '';
  buildPhase = ''
    runHook preBuild

    cd $HOME/OpenFOAM/OpenFOAM-12
    source ./etc/bashrc
    ./Allwmake -j $NIX_BUILD_CORES -q

    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/OpenFOAM-12

    cp -r bin $out/opt/OpenFOAM-12
    cp -r platforms $out/opt/OpenFOAM-12
    cp -r etc $out/opt/OpenFOAM-12
    cp -r applications $out/opt/OpenFOAM-12
    cp -r src $out/opt/OpenFOAM-12
    cp -r doc $out/opt/OpenFOAM-12
    cp -r tutorials $out/opt/OpenFOAM-12

    runHook postInstall
  '';
}
