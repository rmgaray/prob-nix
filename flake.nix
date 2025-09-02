{
  description = "Wrapper for ProB (prebuilt binaries)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    ProB1150 = {
      flake = false;
      url = "https://stups.hhu-hosting.de/downloads/prob/tcltk/releases/1.15.0/ProB.linux64.tar.gz";
    };
    TkTable = {
      flake = false;
      url = "github:bohagan1/TkTable/tktable-2-12-0";
    };
  };

  outputs = { self, nixpkgs, flake-utils, ProB1150, TkTable }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages = {
        default = self.outputs.packages.${system}.prob;

        prob = pkgs.stdenv.mkDerivation {
          pname = "prob";
          version = "1.15.0";
          src = ProB1150;

          dontBuild = true;

          nativeBuildInputs = [
            pkgs.autoPatchelfHook
            pkgs.makeWrapper
          ];

          buildInputs = with pkgs; [
            stdenv.cc.cc.lib
            zlib
            libxml2
            gmp
            zeromq
            czmq
            z3
            tcl
            libuuid
            jre_headless
            tcl-8_5
            tk-8_5
          ];

          installPhase = ''
            mkdir -p $out
            cp -r * $out/

            # Wrap probcli so it finds Java
            makeWrapper $out/probcli $out/bin/probcli \
              --set JAVA_HOME ${pkgs.jre_headless} \
              --prefix PATH : ${pkgs.jre_headless}/bin \
              --set PROB_HOME $out \
              --prefix LD_LIBRARY_PATH : $out/lib

            
            # Create directory for Tcl/Tk inside the package
            # Unfortunately Tcl/Tk really expects all libraries to be placed
            # in a specific place with respect to each other.
            mkdir -p $out/lib/tcltk

            
            # Symlink Tcl/Tk libraries and scripts
            ln -s ${pkgs.tcl-8_5}/lib/libtcl8.5.so $out/lib/tcltk/libtcl8.5.so
            ln -s ${pkgs.tcl-8_5}/lib/tcl8.5 $out/lib/tcltk/tcl8.5

            ln -s ${pkgs.tk-8_5}/lib/libtk8.5.so $out/lib/tcltk/libtk8.5.so
            ln -s ${pkgs.tk-8_5}/lib/tk8.5 $out/lib/tcltk/tk8.5

            # Wrap prob so it finds Java and Tcl/Tk
            makeWrapper $out/prob $out/bin/prob \
              --set JAVA_HOME ${pkgs.jre_headless} \
              --prefix PATH : ${pkgs.jre_headless}/bin \
              --set PROB_HOME $out \
              --prefix LD_LIBRARY_PATH : $out/lib:$out/lib/tcltk \
              --set SP_TCL_DSO $out/lib/tcltk/libtcl8.5.so \
              --set SP_TK_DSO $out/lib/tcltk/libtk8.5.so \
              --set TCL_LIBRARY $out/lib/tcltk/tcl8.5 \
              --set TK_LIBRARY $out/lib/tcltk/tk8.5
          '';        
        };

        # Can't package tktable until development headers for tk
        # are added to nixpkgs.
        # 
        # tktable = pkgs.tcl.mkTclDerivation { 
        #   pname = "TkTable";
        #   version = "2.12.0";
        #   src = TkTable;

        #   # The mkTclDerivation does not do this for some reason
        #   configureFlags = [
        #     "--with-tk=${pkgs.tk-8_5}/lib"
        #     "--with-tkinclude=" # can't add the header here :(
        #   ];

        #   nativeBuildInputs = [ pkgs.makeWrapper ];
        #   buildInputs = [ pkgs.tcl-8_5 pkgs.tk-8_5 ];
        # };
      };
    });
}
