{
    description = "Plank Reloaded";

    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    };

    outputs = { self, nixpkgs, ... }: let
        systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" ];
        forAllSystems = arch: nixpkgs.lib.genAttrs systems (system: arch system);
    in {
        packages = forAllSystems (system:
            let
                pkgs = import nixpkgs { inherit system; };
            in {


                ---

# https://gist.github.com/guillermofbriceno/abef9f1357329778897ea8dbac17b9db

{ lib
, perlPackages
, fetchFromGitHub
, gettext
, multimarkdown
, wrapGAppsHook
, gst_all_1
}:

let
  inherit (perlPackages) makePerlPath;
  deps = with perlPackages; [
    Gtk3 # fix: Can't locate Gtk3.pm in @INC
    Gtk3ImageView
    Gtk3SimpleList
    Cairo # fix: Can't locate Cairo.pm in @INC
    CairoGObject # fix: Can't locate Cairo/GObject.pm in @INC
    Glib # fix: Can't locate Glib.pm in @INC
    GlibObjectIntrospection # fix: 't locate Glib/Object/Introspection.pm in @INC
    NetDBus
    XMLTwig
    XMLParser
    HTMLParser
    Pango
    LocaleGettext
  ];
in

perlPackages.buildPerlPackage  {
  pname = "gmusicbrowser";
  version = "60d4b6f";
  src = fetchFromGitHub {
    owner = "squentin";
    repo = "gmusicbrowser";
    rev = "75c410d0dd71f116082aecd3b52af725f670521a";
    sha256 = "sha256-nZ1/hRrzem5RTeXcGeogvn5PrZoz/U03ZEVPWeYn1Eo=";
  };

  postInstall = ''
      find $out -type f -name "*.pod" -delete
  '';
  dontConfigure = true; # fix: Can't open perl script "Makefile.PL": No such file or directory
  doCheck = false; # fix: make: *** No rule to make target 'test'.  Stop.
  makeFlags = [
    "prefix=$(out)" # fix: mkdir: cannot create directory '/usr': Permission denied
  ];
  outputs = [ "out" ]; # fix: error: builder failed to produce output path for output 'devdoc'
  # fix: Can't locate Gtk3.pm in @INC
  preFixup = ''
    gappsWrapperArgs+=(--prefix PERL5LIB : "${makePerlPath deps}")
  '';
  buildInputs = [ 
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav
    deps
  ];

  nativeBuildInputs = [
    gettext # fix: msgmerge: command not found
    multimarkdown # fix: markdown: command not found
    wrapGAppsHook # fix? Typelib file for namespace 'Gtk', version '3.0' not found
  ];

  meta = with lib; {
    homepage = "https://github.com/squentin/gmusicbrowser";
    description = "jukebox for large collections of music";
    #maintainers = teams.gnome.members;
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}
                ---
                plank-reloaded = pkgs.stdenv.mkDerivation rec {

                    pname = "plank-reloaded";

                    version = "latest";

                    src = ./.;

                    nativeBuildInputs = [
                        pkgs.meson
                        pkgs.ninja
                        pkgs.pkg-config
                        pkgs.vala
                        pkgs.glib
                        pkgs.bamf
                        pkgs.wrapGAppsHook  # Added for GSettings support
                    ];

                    buildInputs = [
                        pkgs.gnome-settings-daemon
                        pkgs.dconf
                        pkgs.glib
                        pkgs.git
                        pkgs.gtk3
                        pkgs.gnome-menus
                        pkgs.libgee
                        pkgs.libwnck
                        pkgs.pango
                        pkgs.desktop-file-utils
                    ];

                    # Compile schemas in post-install phase
                    postInstall = ''
                        glib-compile-schemas $out/share/glib-2.0/schemas
                    '';

                    patches = [
                        ./nix-hide-in-pantheon.patch
                    ];

                    meta = with pkgs.lib; {
                        description = "A simple dock for X11 environments";
                        license = licenses.mit;
                        platforms = platforms.linux;
                    };
                };
                default = self.packages.${system}.plank-reloaded;
            });
        defaultPackage = forAllSystems (system: self.packages.${system}.plank-reloaded);
        defaultApp = forAllSystems (system: {
            type = "app";
            program = "${self.packages.${system}.plank-reloaded}/bin/plank";
        });
    };
}