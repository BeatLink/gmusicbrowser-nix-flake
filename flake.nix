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

                    deps = with pkgs.perlPackages; [
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
                in
                {
                    gmusicbrowser = pkgs.perlPackages.buildPerlPackage rec {
                        pname = "gmusicbrowser";
                        version = "unstable-2022-03-02";

                        src = pkgs.fetchFromGitHub {
                            owner = "squentin";
                            repo = "gmusicbrowser";
                            rev = "73089de1a70f537dc790056a50802617ab0a1725";
                            sha256 = "sha256-i0EZOUxxx1rCa0pKEGzcUDoYNG0al/+bujtkOtWzSAM=";
                        };

                        postInstall = ''
                            find $out -type f -name "*.pod" -delete
                        '';

                        dontConfigure = true;
                        doCheck = false;
                        makeFlags = [ "prefix=$(out)" ];
                        outputs = [ "out" ];

                        preFixup = ''
                            gappsWrapperArgs+=(--prefix PERL5LIB : "${pkgs.perlPackages.makePerlPath deps}")
                        '';

                        buildInputs = [
                            pkgs.gst_all_1.gstreamer
                            pkgs.gst_all_1.gst-plugins-base
                            pkgs.gst_all_1.gst-plugins-good
                            pkgs.gst_all_1.gst-plugins-bad
                            pkgs.gst_all_1.gst-plugins-ugly
                            pkgs.gst_all_1.gst-libav
                        ]
                        ++ deps;

                        nativeBuildInputs = [
                            pkgs.gettext
                            pkgs.multimarkdown
                            pkgs.wrapGAppsHook
                        ];

                        meta = with pkgs.lib; {
                            homepage = "https://github.com/squentin/gmusicbrowser";
                            description = "jukebox for large collections of music";
                            license = licenses.gpl3;
                            platforms = platforms.linux;
                        };
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
