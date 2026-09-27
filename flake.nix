{
  description = "The OpenAgent Agent OS";
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-flake.url = "github:juspay/rust-flake";
  };
  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.rust-flake.flakeModules.default
        inputs.rust-flake.flakeModules.nixpkgs
      ];
      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin"];
      perSystem = {
        config,
        self',
        inputs',
        pkgs,
        system,
        lib,
        ...
      }: {
        rust-project.src = lib.sources.cleanSource ./.;
        rust-project.defaults.perCrate.crane.args.nativeBuildInputs = with pkgs; [
          clang
          perl
          pkg-config
        ];
        rust-project.defaults.perCrate.crane.args.buildInputs = with pkgs; [
          clang
          openssl
          perl
          pkg-config
        ];
        rust-project.crates.openagent-desktop.crane.args.nativeBuildInputs = with pkgs; [
          pkg-config
          wrapGAppsHook3
        ];
        rust-project.crates.openagent-desktop.crane.args.buildInputs = with pkgs; [
          atk
          glib
          gtk3
          libayatana-appindicator
          openssl
          pkg-config
          webkitgtk_4_1
        ];
        rust-project.crates.openagent-desktop.crane.args.preFixup = ''
          gappsWrapperArgs+=(
            --prefix LD_LIBRARY_PATH : "${pkgs.libayatana-appindicator}/lib"
          )
        '';

        packages.default = self'.packages.openagent-cli;
        apps = {
          openagent-cli = {
            program = "${self'.packages.openagent-cli}/bin/openagent";
            meta.description = "CLI tool for the OpenAgent Agent OS";
          };
          openagent-desktop = {
            program = "${self'.packages.openagent-desktop}/bin/openagent-desktop";
            meta.description = "Native desktop application for the OpenAgent Agent OS (Tauri 2.0)";
          };
          default = self'.apps.openagent-cli;
        };
      };
      flake = {
      };
    };
}
