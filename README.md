Primary Disciplina deployment specification.

To set up this repo, run:

```sh
nix-shell
git crypt unlock
cat .gitconfig >> .git/config
```

## Darwin builder

[nix-darwin][] profile for macOS builder. Runs Buildkite to build macOS apps on
CI for QA team.

### Provisioning

Darwin builder is the hardest of all three to provision because there's no
[NixOps][] support and [nix-darwin][] provides relatively little control when
compared to NixOS.

1. Sign up for [MacStadium][] and rent a server.

2. Copy `keys/buildkite-token` to the newly provisioned server:
```sh
scp keys/buildkite-token administrator@1.2.3.4
```

3. SSH to the server (default password is in the MacStadium ticket):
```sh
ssh administrator@1.2.3.4
```

4. Install [Nix][]:
```sh
curl https://nixos.org/nix/install | sh
```

5. Install [nix-darwin][]:
```sh
nix-build https://github.com/LnL7/nix-darwin/archive/master.tar.gz -A installer
result/bin/darwin-installer
```

6. Set up our Nix channels:
```sh
nix-channel --add https://github.com/serokell/nixpkgs/archive/master.tar.gz nixpkgs
nix-channel --add https://github.com/serokell/nix-darwin/archive/master.tar.gz darwin
nix-channel --add https://github.com/DisciplinaOU/disciplina-nixops/archive/master.tar.gz disciplina-nixops
nix-channel --update
```

7. Update `~/.nixpkgs/darwin-configuration.nix` to the effect of:
```nix
{
  imports = [
    <disciplina-nixops/deployments/darwin-builder.nix>
  ];

  # sysctl -n hw.ncpu
  nix.buildCores = 4;
  nix.maxJobs = 4;

  system.stateVersion = 3;
}
```

8. Rebuild:
```sh
darwin-rebuild switch
```

9. Update `state/darwin-builder.ssh` (in this repo) with the new IP.

[MacStadium]: https://www.macstadium.com
[Nix]: https://nixos.org/nix
[NixOps]: https://nixos.org/nixops
[nix-darwin]: https://github.com/LnL7/nix-darwin

## Deployer

Singleton entity that is used to provision clusters in one-to-many
relationship. Runs Buildkite to CD clusters on each GitHub push, and to build
Flatpak bundles, LaTeX documents and HTML documentation as part of CI pipeline.

### Provisioning

```sh
nix-shell --argstr accessKeyId production --run 'nixops deploy -d deployer -s state/deployer.nixops'
```

## Cluster

Actual Disciplina cluster. Work in progress.
