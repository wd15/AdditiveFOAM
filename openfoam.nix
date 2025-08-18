{
  stdenv,
  bash,
  m4,
  flex,
  bison,
  fftw,
  gnumake,
  scotch,
  boost,
  openmpi,
  cgal,
  zlib,
  fetchFromGitHub,
  lib,
  trilinos-mpi,
  mpich,
  nix-update-script,
  version_ ? "12",
  glibc,
  libbsd,
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
  nativeBuildInputs = buildInputs;

  buildInputs = [
    # gcc10
    gnumake
    bash
    m4
    bison
    fftw
    boost
    cgal
    zlib
    trilinos-mpi
    openmpi
    openmpi.dev
    # openmpi.dev
    # openmpi.out
#    mpi
    flex
    scotch
    scotch.dev
    glibc
    libbsd
#    mpich
  ];

  propagatedBuildInputs = [
    openmpi
    openmpi.dev
  ];
  sourceRoot = ".";
  patchPhase = ''
    runHook prePatch

    mkdir -p builduser/OpenFOAM
    mkdir -p builduser/.OpenFOAM
    export HOME=$(pwd)/builduser
    mv source builduser/OpenFOAM/OpenFOAM-12
    mkdir -p builduser/OpenFOAM/OpenFOAM-12/paraviewout

    set +e
    for f in \
        $HOME/OpenFOAM/OpenFOAM-12/wmake/scripts/* \
        $HOME/OpenFOAM/OpenFOAM-12/wmake/*
    do
      substituteInPlace $f --replace-quiet /bin/bash ${bash}/bin/bash
    done
    set -e

    rm $HOME/OpenFOAM/OpenFOAM-12/etc/config.sh/bash_completion
    touch $HOME/OpenFOAM/OpenFOAM-12/etc/config.sh/bash_completion

    echo "set +e" | cat $HOME/OpenFOAM/OpenFOAM-12/etc/bashrc > tmp
    rm $HOME/OpenFOAM/OpenFOAM-12/etc/bashrc
    mv tmp $HOME/OpenFOAM/OpenFOAM-12/etc/bashrc

    echo "set +e" | cat $HOME/OpenFOAM/OpenFOAM-12/Allwmake > tmp
    rm $HOME/OpenFOAM/OpenFOAM-12/Allwmake
    mv tmp $HOME/OpenFOAM/OpenFOAM-12/Allwmake

    alias wmRefresh="placeholder"
    chmod +x $HOME/OpenFOAM/OpenFOAM-12/Allwmake
    chmod +x $HOME/OpenFOAM/OpenFOAM-12/applications/utilities/postProcessing/graphics/PVReaders/Allwmake
    touch $HOME/.OpenFOAM/prefs.sh

    # only if version 10
    substituteInPlace $HOME/OpenFOAM/OpenFOAM-12/etc/bashrc --replace-fail "export WM_PROJECT_VERSION=dev" "export WM_PROJECT_VERSION=12"
    sed -i '47 i libDir=${openmpi.dev}/lib' $HOME/OpenFOAM/OpenFOAM-12/etc/config.sh/mpi
     # substituteInPlace $HOME/OpenFOAM/OpenFOAM-12/etc/config.sh/scotch --replace-fail "export SCOTCH_VERSION=scotch_6.0.9" "export SCOTCH_VERSION=scotch_6.1.3."
    sed -ie 's|SCOTCH_ARCH_PATH=.*$|SCOTCH_ARCH_PATH=${scotch.dev}|' $HOME/OpenFOAM/OpenFOAM-12/etc/config.sh/scotch

    set +e
    for f in \
        $HOME/OpenFOAM/OpenFOAM-12/src/parallel/decompose/*/Make/options
    do
      substituteInPlace $f --replace-quiet /usr/include/scotch ${scotch.dev}/include
      substituteInPlace $f --replace-quiet "\$(SCOTCH_ARCH_PATH)/lib" ${scotch.out}/lib
      # sed -i '/-lscotch/ a -L${scotch}/lib \\' $f
      # sed -i '/-lscotch/ a -L${scotch.dev}/lib \\' $f
      # sed -i '/-lscotch/ a -L${scotch.out}/lib \\' $f
    done
    set -e

    substituteInPlace $HOME/OpenFOAM/OpenFOAM-12/wmake/rules/General/mplibOPENMPI --replace-fail "\$(MPI_ARCH_PATH)/include" "${openmpi.dev}/include"
    substituteInPlace $HOME/OpenFOAM/OpenFOAM-12/wmake/rules/General/mplibOPENMPI --replace-fail "\$(MPI_ARCH_PATH)/lib" "${openmpi.out}/lib"

    ls $HOME/OpenFOAM/OpenFOAM-12/tutorials/mesh/snappyHexMesh/iglooWithFridges
    rm $HOME/OpenFOAM/OpenFOAM-12/tutorials/mesh/snappyHexMesh/iglooWithFridges

    runHook postPatch

  '';

  configurePhase = ''
    runHook preConfigure

    echo "export ZOLTAN_TYPE=system" >> $HOME/.OpenFOAM/prefs.sh
    echo "export SCOTCH_TYPE=system" >> $HOME/.OpenFOAM/prefs.sh

    # echo "export ZOLTAN_TYPE=none" >> $HOME/.OpenFOAM/prefs.sh
    # echo "export SCOTCH_TYPE=none" >> $HOME/.OpenFOAM/prefs.sh


    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    cd $HOME/OpenFOAM/OpenFOAM-12
    source ./etc/bashrc

    # only if version 10
#    echo "${scotch.dev}"

    # export LD_LIBRARY_PATH="${openmpi.dev}/lib:${openmpi}/lib:${openmpi.out}/lib:${flex}/lib:${scotch.dev}/lib:${libbsd}/lib''${LD_LIBRARY_PATH}"
    # export C_INCLUDE_PATH="${openmpi.dev}/include:${openmpi.out}/include:${flex}/include:${scotch.dev}/include''${C_INCLUDE_PATH}"
    # export CPLUS_INCLUDE_PATH="${openmpi.dev}/include:${openmpi.out}/include:${flex}/include:${scotch.dev}/include''${CPLUS_INCLUDE_PATH}"
    # export PATH="${openmpi.dev}/bin:${scotch}/bin''${PATH}"

    # export LD_LIBRARY_PATH="${flex}/lib:${scotch.dev}/lib:${libbsd}/lib''${LD_LIBRARY_PATH}"
    # export C_INCLUDE_PATH="${flex}/include:${scotch.dev}/include''${C_INCLUDE_PATH}"
    # export CPLUS_INCLUDE_PATH="${flex}/include:${scotch.dev}/include''${CPLUS_INCLUDE_PATH}"
    # export PATH="${scotch}/bin''${PATH}"

    export LD_LIBRARY_PATH="${flex}/lib:${libbsd}/lib''${LD_LIBRARY_PATH}"
    export C_INCLUDE_PATH="${flex}/include''${C_INCLUDE_PATH}"
    export CPLUS_INCLUDE_PATH="${flex}/include''${CPLUS_INCLUDE_PATH}"


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
