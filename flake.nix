{
  description = "T3 Code server and desktop app, repackaged from upstream release binaries";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    # Upstream publishes an arm64 server but no arm64 desktop build that we
    # could test; add a system here only together with its sources.json entry.
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    sources = builtins.fromJSON (builtins.readFile ./sources.json);

    overlay = final: _prev: {
      t3code-server = final.callPackage ./pkgs/server.nix {inherit sources;};
      t3code-desktop = final.callPackage ./pkgs/desktop.nix {inherit sources;};
    };
    packages = overlay pkgs pkgs;
  in {
    overlays.default = overlay;

    packages.${system} = packages // {default = packages.t3code-desktop;};

    # The update workflow gates every version bump on these.
    checks.${system} = packages;

    formatter.${system} = pkgs.alejandra;
  };
}
