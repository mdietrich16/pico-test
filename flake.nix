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

      rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;

      craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

      commonArgs = {
        src = craneLib.cleanCargoSource ./.;
        doCheck = false;
      };

      desktopCargoArtifacts = craneLib.buildDepsOnly commonArgs;

      embeddedArgs =
        commonArgs
        // {
          src = lib.cleanSourceWith {
            src = ./.;
            filter = path: type: (craneLib.filterCargoSources path type) || (builtins.baseNameOf path == "memory.x");
          };
          cargoExtraArgs = "--target thumbv6m-none-eabi";
          buildInputs = with pkgs; [
            flip-link
          ];
        };

      # Build artifacts
      embeddedCargoArtifacts = craneLib.buildDepsOnly (embeddedArgs
        // {
          extraDummyScript = ''
            cp -a ${./memory.x} $out/memory.x
            (shopt -s globstar; rm -rf $out/**/src/bin/crane-dummy-*)
          '';
        });

      embedded = craneLib.buildPackage (embeddedArgs // {cargoArtifacts = embeddedCargoArtifacts;});
      desktop = craneLib.buildPackage (commonArgs // {cargoArtifacts = desktopCargoArtifacts;});
    in {
      packages = {
        inherit embedded desktop;
      };
      devShells.default = craneLib.devShell {
        inputsFrom = [self.packages.${system}.embedded self.packages.${system}.desktop];
        buildInputs = with pkgs; [
          rust-analyzer
          probe-rs-tools # Flashing and debugging
          elf2uf2-rs # Converts ELF files to UF2 for the Pico
          picotool # For Pico operations
        ];
      };
    });
}
