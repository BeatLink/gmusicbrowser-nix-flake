# Based on https://gist.github.com/guillermofbriceno/abef9f1357329778897ea8dbac17b9db

{
    description = "Flake for gmusicbrowser with NixOS and Home Manager modules";

    inputs = {
        nixpkgs = {
            url = "github:NixOS/nixpkgs/nixos-unstable";
        };
    };
    outputs =
        {
            self,
            nixpkgs,
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

                    # GTK stock id -> freedesktop icon name, for the icons GTK 3 no longer
                    # resolves. Apply and OK are deliberately absent: modern themes carry no
                    # icon for them, and their buttons are labelled.
                    stockIconFallbacks =
                        let
                            map' = {
                                # Reaches a stock name in upstream's table, and the lookup is
                                # single-level, so it needs the real name directly.
                                "gmb-view-fullscreen" = "view-fullscreen";

                                "gtk-about" = "help-about";
                                "gtk-add" = "list-add";
                                "gtk-clear" = "edit-clear";
                                "gtk-close" = "window-close";
                                "gtk-copy" = "edit-copy";
                                "gtk-delete" = "edit-delete";
                                "gtk-edit" = "accessories-text-editor";
                                "gtk-fullscreen" = "view-fullscreen";
                                "gtk-go-back" = "go-previous";
                                "gtk-go-down" = "go-down";
                                "gtk-go-forward" = "go-next";
                                "gtk-go-up" = "go-up";
                                "gtk-goto-bottom" = "go-bottom";
                                "gtk-goto-top" = "go-top";
                                "gtk-index" = "help-contents";
                                "gtk-info" = "dialog-information";
                                "gtk-jump-to" = "go-jump";
                                "gtk-leave-fullscreen" = "view-restore";
                                "gtk-media-next" = "media-skip-forward";
                                "gtk-media-pause" = "media-playback-pause";
                                "gtk-media-play" = "media-playback-start";
                                "gtk-media-previous" = "media-skip-backward";
                                "gtk-media-stop" = "media-playback-stop";
                                "gtk-new" = "document-new";
                                "gtk-open" = "document-open";
                                "gtk-quit" = "application-exit";
                                "gtk-refresh" = "view-refresh";
                                "gtk-remove" = "list-remove";
                                "gtk-save" = "document-save";
                                "gtk-save-as" = "document-save-as";
                                "gtk-sort-ascending" = "view-sort-ascending";
                                "gtk-sort-descending" = "view-sort-descending";
                                "gtk-zoom-100" = "zoom-original";
                                "gtk-zoom-fit" = "zoom-fit-best";
                                "gtk-zoom-in" = "zoom-in";
                                "gtk-zoom-out" = "zoom-out";
                            };
                        in
                        nixpkgs.lib.concatStringsSep "\n" (
                            nixpkgs.lib.mapAttrsToList (stock: name: "\t'${stock}' => '${name}',") map'
                        );

                    otherDeps = [
                        pkgs.mediainfo
                        pkgs.mpv
                    ];

                in
                {
                    gmusicbrowser = pkgs.perlPackages.buildPerlPackage {

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

                            # gmusicbrowser asks the icon theme for GTK stock names, and its own
                            # set_from_stock override blanks the image when the lookup fails —
                            # so on a theme without the legacy gtk-* names every toolbar icon
                            # renders as empty space. %IconsFallbacks is the upstream hook for
                            # this: a fallback is registered only for names the theme lacks.
                            substituteInPlace gmusicbrowser.pl --replace \
                                "	#'gmb-media-skip-forward'=> 'media-skip-forward'," \
                                "	#'gmb-media-skip-forward'=> 'media-skip-forward',
${stockIconFallbacks}"
                        '';

                        buildInputs = gstreamerDeps ++ perlDeps ++ otherDeps;

                        nativeBuildInputs = [
                            pkgs.makeWrapper
                            pkgs.gettext
                            pkgs.multimarkdown
                            pkgs.wrapGAppsHook3
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
                        environment.systemPackages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.gmusicbrowser ];
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
                        home.packages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.gmusicbrowser ];
                    };
                };
            homeManagerModules.default = self.homeManagerModules.gmusicbrowser;
        };
}
