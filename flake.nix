# Nix shell for running the incus-windows toolset on NixOS.
#
#   nix develop
#   sh build.sh 2022
#
# or without entering the shell:
#
#   nix develop -c sh build.sh 2022
#
# The shell provides every tool build.sh and tools/* call for, except
# incus itself: incus is a client/daemon pair, and config.sh selects the
# virtio driver pack from the client's version, so the client must match
# the local daemon. Take incus from the host system (on this fleet,
# profiles/incus-hypervisor.nix in the nixos-config flake provides it),
# not from this shell.
#
# nixpkgs is pinned to the same revision as the nixos-config fleet flake,
# so the shell's packages substitute from the fleet's binary cache.
{
  inputs.nixpkgs.url =
    "github:NixOS/nixpkgs/d482ef84049d9b7276b83a06e4e4d76983830097";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          coreutils-full # paste, od, mktemp, sha256sum, and the rest
          gnugrep
          gnused # pack.sh, mkmeta
          gawk # urls.txt and incus version parsing
          findutils # find, xargs
          gnutar # mkmeta, image export extraction
          xz
          curl
          python3 # tools/click.py, tools/rmnics.py (stdlib only)
          xorriso # ISO extraction and repacking
        ];

        # incus deliberately comes from the host, not from here; see the
        # file comment.
        shellHook = ''
          if ! command -v incus >/dev/null 2>&1; then
            echo "warning: incus is not on PATH; this host must provide" \
                 "the incus client and daemon" >&2
          fi
        '';
      };
    };
}
