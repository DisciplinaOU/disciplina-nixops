# Disciplina operations

## Darwin builder

[nix-darwin][] profile for macOS builder. Runs Buildkite to make CI provide
macOS apps on each pull request for QA team.

### Provisioning

Darwin builder is the hardest of all three to provision because there's no
[NixOps][] support and [nix-darwin][] provides relatively little control when
compared to NixOS.

1. Sign up for [MacStadium][] and rent a server.

2. Copy `keys/buildkite-token` to the newly provisioned server:
```sh
scp keys/buildkite-token administrator@darwin-builder
```

3. SSH to the server (default password is in the MacStadium ticket):
```sh
ssh administrator@darwin-builder
```

4. Generate Ed25519 SSH key (just pick defaults):
```sh
ssh-keygen -t ed25519
```

TODO: fork [nix-darwin][] and update buildkite-agent module to remove this step

5. Install [Nix][]:
```sh
curl https://nixos.org/nix/install | sh
```

6. Install [nix-darwin][]:
```sh
nix-build https://github.com/LnL7/nix-darwin/archive/master.tar.gz -A installer

```

7. Set up our Nix channels:
```sh
nix-channel --add https://github.com/serokell/nixpkgs/archive/master.tar.gz nixpkgs
nix-channel --add https://github.com/DisciplinaOU/disciplina-nixops/archive/master.tar.gz disciplina-nixops
nix-channel --update
```

8. Update `~/.nixpkgs/darwin-configuration.nix` to the effect of:
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

9. Rebuild:
```sh
darwin-rebuild switch
```

10. Update `state/darwin-builder.ssh` (in this repo) with the new IP.

[MacStadium]: https://www.macstadium.com
[Nix]: https://nixos.org/nix
[NixOps]: https://nixos.org/nixops
[nix-darwin]: https://github.com/LnL7/nix-darwin

## Deployer

Singleton entity that is used to provision cluster in one-to-many relationship.
Runs Buildkite to CD cluster on each GitHub push, and to make CI provide Flatpak
bundles and some other miscellaneous artifacts.

### Provisioning

```sh
nix-shell --argstr accessKeyId production --run 'nixops deploy -d deployer -s keys/deployer.nixops'
```

## Cluster

Actual Disciplina cluster. Work in progress.
