# Based on https://gist.github.com/guillermofbriceno/abef9f1357329778897ea8dbac17b9db

{
    description = "Flake for gmusicbrowser with NixOS and Home Manager modules";

    inputs = {
        nixpkgs = {
            url = "github:NixOS/nixpkgs/nixos-unstable";
        };
        home-manager = {
            url = "github:nix-community/home-manager";
            inputs.nixpkgs.follows = "nixpkgs";
        };
    };
    outputs =
        {
            self,
            nixpkgs,
            home-manager,
        }:
        let
            forAllSystems = nixpkgs.lib.genAttrs [
                "x86_64-linux"
                "aarch64-linux"
            ];
        in
        {
            packages = forAllSystems (
                system:
                let
                    pkgs = import nixpkgs { inherit system; };

                    perlDeps = with pkgs.perlPackages; [
                        Gtk3
                        Gtk3ImageView
                        Gtk3SimpleList
                        Cairo
                        CairoGObject
                        Glib
                        GlibObjectIntrospection
                        NetDBus
                        XMLTwig
                        XMLParser
                        HTMLParser
                        Pango
                        LocaleGettext
                    ];

                    gstreamerDeps = [
                        pkgs.gst_all_1.gstreamer
                        pkgs.gst_all_1.gst-plugins-base
                        pkgs.gst_all_1.gst-plugins-good
                        pkgs.gst_all_1.gst-plugins-bad
                        pkgs.gst_all_1.gst-plugins-ugly
                        pkgs.gst_all_1.gst-libav
                    ];

                    otherDeps = [
                        pkgs.mediainfo
                        pkgs.mpv
                    ];

                in
                {
                    gmusicbrowser = pkgs.perlPackages.buildPerlPackage rec {

                        pname = "gmusicbrowser";

                        version = "75c410d0dd71f116082aecd3b52af725f670521a";

                        src = pkgs.fetchFromGitHub {
                            owner = "squentin";
                            repo = "gmusicbrowser";
                            rev = "75c410d0dd71f116082aecd3b52af725f670521a";
                            sha256 = "sha256-nZ1/hRrzem5RTeXcGeogvn5PrZoz/U03ZEVPWeYn1Eo=";
                        };

                        meta = with pkgs.lib; {
                            homepage = "https://github.com/squentin/gmusicbrowser";
                            description = "jukebox for large collections of music";
                            license = licenses.gpl3;
                            platforms = platforms.linux;
                        };

                        preBuild = ''
                            substituteInPlace generic_metadata_reader_gstreamer.pm --replace "system('env','perl',__FILE__)" "system('${pkgs.perl}/bin/perl', __FILE__)"
                            substituteInPlace generic_metadata_reader_gstreamer.pm --replace "my @cmd_and_args= ('env','perl',__FILE__,$uri)" "my @cmd_and_args= ('${pkgs.perl}/bin/perl',__FILE__,$uri)"
                        '';

                        buildInputs = gstreamerDeps ++ perlDeps ++ otherDeps;

                        nativeBuildInputs = [
                            pkgs.makeWrapper
                            pkgs.gettext
                            pkgs.multimarkdown
                            pkgs.wrapGAppsHook
                            pkgs.perl
                            pkgs.gobject-introspection
                        ];

                        dontConfigure = true;

                        doCheck = false;

                        makeFlags = [ "prefix=$(out)" ];

                        outputs = [ "out" ];

                        postInstall = ''
                            find $out -type f -name "*.pod" -delete
                        '';

                        postFixup =
                            let
                                perlLibs = with pkgs.perlPackages; makePerlPath perlDeps;
                                gstPlugins = pkgs.lib.makeLibraryPath gstreamerDeps;
                                binaries = pkgs.lib.makeBinPath otherDeps;
                            in
                            ''
                                wrapProgram $out/bin/gmusicbrowser \
                                    --set PERL5LIB "${perlLibs}" \
                                    --set GST_PLUGIN_SYSTEM_PATH "${gstPlugins}" \
                                    --prefix PATH : ${binaries}
                            '';
                    };
                }
            );

            # Default package/app
            defaultPackage = forAllSystems (system: self.packages.${system}.gmusicbrowser);

            apps = forAllSystems (system: {
                gmusicbrowser = {
                    type = "app";
                    program = "${self.packages.${system}.gmusicbrowser}/bin/gmusicbrowser";
                };
                default = self.apps.${system}.gmusicbrowser;
            });

            # NixOS module
            nixosModules.gmusicbrowser =
                {
                    config,
                    lib,
                    pkgs,
                    ...
                }:
                with lib;
                {
                    options.programs.gmusicbrowser.enable = mkEnableOption "gmusicbrowser music player";
                    config = mkIf config.programs.gmusicbrowser.enable {
                        environment.systemPackages = [ self.packages.${pkgs.system}.gmusicbrowser ];
                    };
                };
            nixosModules.default = self.nixosModules.gmusicbrowser;

            # Home Manager module
            homeManagerModules.gmusicbrowser =
                {
                    config,
                    lib,
                    pkgs,
                    ...
                }:
                with lib;
                {
                    options.programs.gmusicbrowser.enable = mkEnableOption "gmusicbrowser music player";
                    config = mkIf config.programs.gmusicbrowser.enable {
                        home.packages = [ self.packages.${pkgs.system}.gmusicbrowser ];
                    };
                };
            homeManagerModules.default = self.homeManagerModules.gmusicbrowser;
        };
}
