{
  description = "DevOps assignment — GCP + Terraform + Python/TS quickstart workers";

  inputs = {
    nixpkgs.url = "github:NixOS/Nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forEachSupportedSystem = f:
      nixpkgs.lib.genAttrs supportedSystems (system:
        f {
          pkgs = import nixpkgs {
            inherit system;
            config = {allowUnfree = true;};
          };
        });
  in {
    devShells = forEachSupportedSystem ({pkgs}: {
      default = pkgs.mkShell {
        packages = with pkgs; [
          # GCP
          google-cloud-sdk

          # IaC
          terraform

          # Python worker (SLM inference) — deps managed by uv
          uv
          python314

          # TypeScript worker
          nodejs_24
          typescript
          typescript-language-server
          bun

          # Utilities
          curl
          jq
        ];

        shellHook = ''
          echo "GCP + Terraform + Python/TS dev environment loaded!"
        '';
      };
    });
  };
}
