{
  description = "Minimal crane flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    crane.url = "github:ipetkov/crane";

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    rust-overlay,
    crane,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [(import rust-overlay)];
      };
      inherit (pkgs) lib;

      # rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
      rustToolchain = pkgs.pkgsBuildHost.rust-bin.nightly.latest.default.override {
        targets = ["thumbv6m-none-eabi"];
      };

      craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

      commonArgs = {
        src = lib.cleanSourceWith {
          src = ./.;
          filter = path: type: (craneLib.filterCargoSources path type) || (builtins.baseNameOf path == "memory.x");
        };
        cargoExtraArgs = "-p application-test --target thumbv6m-none-eabi";
        doCheck = false;
        buildInputs = with pkgs; [
          flip-link
        ];
      };

      # Build artifacts
      cargoArtifacts = craneLib.buildDepsOnly (commonArgs
        // {
          extraDummyScript = ''
            cp -a ${./memory.x} $out/memory.x
            rm -rf $out/**/src/bin/crane-dummy-*
          '';
        });

      firmware = craneLib.buildPackage (commonArgs
        // {
          inherit cargoArtifacts;
        });
    in {
      packages = {
        inherit firmware;
      };
      devShells.default = craneLib.devShell {
        inputsFrom = [self.packages.${system}.firmware];
        buildInputs = with pkgs; [
          rust-analyzer
          probe-rs-tools # Flashing and debugging
          elf2uf2-rs # Converts ELF files to UF2 for the Pico
          picotool # For Pico operations
        ];
      };
    });
}
