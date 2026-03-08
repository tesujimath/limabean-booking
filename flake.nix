{
  description = "A development environment flake for limabean.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs:
    inputs.flake-utils.lib.eachDefaultSystem
      (system:
        let
          overlays = [ (import inputs.rust-overlay) ];
          pkgs = import inputs.nixpkgs {
            inherit system;
          };
          pkgs-with-rust-overlay = import inputs.nixpkgs {
            inherit system overlays;
          };
          # cargo-nightly based on https://github.com/oxalica/rust-overlay/issues/82
          nightly = pkgs-with-rust-overlay.rust-bin.selectLatestNightlyWith (t: t.default);
          cargo-nightly = pkgs.writeShellScriptBin "cargo-nightly" ''
            export RUSTC="${nightly}/bin/rustc";
            exec "${nightly}/bin/cargo" "$@"
          '';

          ci-packages = with pkgs; [
            bashInteractive
            coreutils
            diffutils

            cargo
          ] ++ (lib.optionals (builtins.match ".*-linux" system != null) [
            gcc
          ]) ++ (lib.optionals (builtins.match ".*-darwin" system != null) [
            clang
            libiconv
          ]);

          version = (builtins.fromTOML (builtins.readFile ./Cargo.toml)).package.version;
          limabean-booking =
            pkgs.rustPlatform.buildRustPackage
              {
                inherit version;

                pname = "limabean-booking";

                src = ./.;

                cargoDeps = pkgs.rustPlatform.importCargoLock {
                  lockFile = ./Cargo.lock;
                };

                meta = with pkgs.lib; {
                  description = "Generic Beancount booking algorithm in Rust";
                  homepage = "https://github.com/tesujimath/limabean-booking";
                  license = with licenses; [ asl20 mit ];
                  # maintainers = [ maintainers.tesujimath ];
                };
              };

        in
        with pkgs;
        {
          devShells.default = mkShell {
            nativeBuildInputs = [
              cargo-modules
              cargo-nightly
              cargo-udeps
              cargo-outdated
              cargo-edit
              clippy
              rustc
            ] ++ ci-packages;
          };

          packages.default = limabean-booking;
        }
      );
}
