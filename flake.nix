{
  outputs =
    {
      self,
      nixpkgs,
      nixpkgsUnstable,
      flake-utils,
      pre-commit-hooks,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        pkgsUnstable = nixpkgsUnstable.legacyPackages.${system};
      in
      {
        checks = {
          pre-commit-check = pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              air-fmt = {
                enable = true;
                entry = "${pkgs.air-formatter}/bin/air format";
                files = ".*\.[rR]$";
              };
            };
          };
        };

        devShells.default = pkgs.mkShell {
          inherit (self.checks.${system}.pre-commit-check) shellHook;
          env.R_LIBS_USER = "./.Rlib";
          buildInputs = [
            pkgs.bashInteractive
            self.checks.${system}.pre-commit-check.enabledPackages
          ];
          packages =
            with pkgs;
            [
              R
              radian
              (julia.withPackages [
                "CSV"
                "Convex"
                "DataFrames"
                "GeometryTypes"
                "Polyhedra"
                "SCS"
              ])
              quarto
            ]
            ++ (with pkgsUnstable; [
              air-formatter
            ])
            ++ (with pkgs.rPackages; [
              languageserver
              dotenv
              targets
              visNetwork
              tarchetypes
              qs2
              crew
              testthat
              withr
              yaml

              psych
              ggplot2
              future
              survival
              data_table
              RANN
              here
              Hmisc
              dotenv
              compositions
              cowplot
              rms
              mice
              MASS
              MCMCpack
              truncnorm
              # (pkgs.rPackages.buildRPackage {
              #   name = "lmtp";
              #   src = pkgs.fetchFromGitHub {
              #     owner = "BeaudanBrown";
              #     repo = "lmtp";
              #     rev = "009086e20ab24d104ceade38a1c3866e7d39a7a4";
              #     sha256 = "sha256-oirKPa16t1gwwhA7S/ERpbKTrWkjaAkDJyqJH0BIATs=";
              #   };
              #   propagatedBuildInputs = with pkgs.rPackages; [
              #     (pkgs.rPackages.buildRPackage {
              #       name = "mlr3superlearner";
              #       src = pkgs.fetchFromGitHub {
              #         owner = "nt-williams";
              #         repo = "mlr3superlearner";
              #         rev = "e56a4cbc29e6858ec045fdaf3423de6a3e43a330";
              #         sha256 = "sha256-N+1WvLnwq1Z6cZmf3w8zeX3Qha1NLbdOpm2u3YcK4Lg=";
              #       };
              #       propagatedBuildInputs = with pkgs.rPackages; [
              #         checkmate
              #         lgr
              #         mlr3
              #         data_table
              #         purrr
              #         cli
              #         glmnet
              #         mlr3learners
              #       ];
              #     })
              #     SuperLearner
              #     generics
              #     origami
              #     progressr
              #     isotone
              #     (pkgs.rPackages.buildRPackage {
              #       name = "ife";
              #       src = pkgs.fetchFromGitHub {
              #         owner = "nt-williams";
              #         repo = "ife";
              #         rev = "4281a41ce25fdedc529552310bf15a0e1605a8b2";
              #         sha256 = "sha256-+cLsdGu8jpNHQ0UZJuP2A+jb2WNMnE5Vq9qz6Z1tZrk=";
              #       };
              #       propagatedBuildInputs = with pkgs.rPackages; [
              #         cli
              #         generics
              #         S7
              #       ];
              #     })
              #   ];
              # })
              (pkgs.rPackages.buildRPackage {
                name = "lmtp";
                src = pkgs.fetchFromGitHub {
                  owner = "BeaudanBrown";
                  repo = "lmtp";
                  rev = "2a107de96906af9c42c38b7bd301ad17a3e684b4";
                  sha256 = "sha256-O8NHAjl95nssX//y+UgjghxF5Bqnv4eQR3l5FbVNv/I=";
                };
                propagatedBuildInputs = with pkgs.rPackages; [
                  SuperLearner
                  generics
                  origami
                  progressr
                  isotone
                  cli
                  R6
                  checkmate
                  ife
                  lifecycle
                ];
              })
            ]);
        };
      }
    );

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgsUnstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    pre-commit-hooks.url = "github:cachix/git-hooks.nix";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
  };
}
