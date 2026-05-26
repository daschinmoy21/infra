{
  description = "DevOps assignment — GCP + Terraform + Python/TS quickstart workers";

  inputs = {
    nixpkgs.url = "github:NixOS/Nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config = {allowUnfree = true;};
    };

    # Construct an emulated Ubuntu/Debian style file layout structure for your dev shell
    fhsEnv = pkgs. buildFHSEnv {
      name = "dev-fhs-shell";

      # Core system libraries required by the iii engine binary and underlying workers
      targetPkgs = pkgs:
        with pkgs; [
          # Upstream binary linking dependencies
          libcap_ng
          stdenv.cc.cc.lib
          zlib
          openssl
          glibc

          # Cloud & Automation Core
          google-cloud-sdk
          terraform
          terraform-ls

          # Modern Runtimes
          uv
          python314
          nodejs_24
          typescript
          typescript-language-server
          bun

          # Fetching utilities needed for standard scripts
          curl
          jq
          git
          cacert
        ];

      # Drop into a native standard shell environment upon activation
      runScript = "$SHELL";
    };
  in {
    # Directly binds the FHS environment container straight to your standard shell
    devShells.${system}.default = fhsEnv.env;
  };
}
