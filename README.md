Primary Disciplina deployment specification.

To set up this repo, enter `nix-shell` and run:

```sh
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

2. Copy `keys/production/buildkite-token` to the newly provisioned server:
```sh
scp keys/production/buildkite-token administrator@1.2.3.4:~
```

3. SSH to the server (default password is in the MacStadium ticket):
```sh
ssh administrator@1.2.3.4
```

4. Activate passwordless `sudo`: https://apple.stackexchange.com/a/333055

5. Install [Nix][]:
```sh
curl https://nixos.org/nix/install | sh
```

6. Install [nix-darwin][]:
```sh
nix-build https://github.com/LnL7/nix-darwin/archive/master.tar.gz -A installer
result/bin/darwin-installer
```

7. Set up our Nix channels:
```sh
nix-channel --add https://github.com/serokell/nixpkgs/archive/master.tar.gz nixpkgs
nix-channel --add https://github.com/serokell/nix-darwin/archive/master.tar.gz darwin
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

Singleton entity that is used to provision clusters in one-to-many
relationship. Runs Buildkite to CD clusters on each GitHub push, and to build
Flatpak bundles, LaTeX documents and HTML documentation as part of CI pipeline.

### Provisioning

```sh
nix-shell --argstr env production --run 'nixops deploy -d deployer -s state/deployer.nixops'
```

## Cluster

Actual Disciplina cluster. WIP.

### Provisioning

Some terminology first:

* A `deployment` is an entry in a nixops state file.
* A `cluster` is the set of resources created by running nixops for a given
  deployment.

* A `production` cluster, is the one served at the official DNS name.
  Deployment access is restricted.
* A `staging` cluster exists at `*.dscp.serokell.review` and can be updated by
  most devs, QA, and ops with the `/deploy discplina@<ref> to staging` slack
  command (not implemented yet).
* A `testing` cluster belongs to a single dev/qa/ops, and should generally not
  be expected to be up or reliable, because chances are someone's working on
  it.

#### IMPORTANT

You need a patched version of nix. Upstream PR is currently pending. The correct
version is provided as part of the overlay used in this repo. To install it,
`cd` into repo base, and:

```sh
nix-env -f pkgs.nix -iA nix
```

#### Creating the deployment

To create a new testing deployment, run the following:

```sh
nixops create deployments/cluster.nix -d disciplina
nixops set-args --argstr domain yourname.dscp.serokell.review -d disciplina
nixops deploy -d disciplina
```

Where `-d disciplina` can be replaced by any name you like, such as
`discplina-testing` or `disciplina-kawaii`.

In order to create a local deployment using VMs, before `nixops deploy`, run:

```sh
nixops set-args --argstr hostType virtualbox -d disciplina
```

To push changes to the cluster, re-run the last command.

To clean up your cluster, which you should do when you're done with it to
conserve money, run this:

```sh
nixops destroy -d disciplina --confirm
```

#### Deploying to production

Do as above to create a deployment, skip the second step, and run this instead:

```sh
nixops set-args --argstr env production -d disciplina
nix-shell --argstr env production --run 'nixops deploy -d cluster -s state/cluster.nixops'
```

Re-run last command to push new changes.

### Overriding dependencies

These dependencies are handled on the NIX_PATH:

* disciplina
* disciplina-explorer-frontend
* disciplina-faucet-frontend

The default values for them are set in `shell.nix`, and point to the `master`
branch of their respective repositories on Github.

The easy way to provide an override is to modify the nixops deployment.

The basic premise is to provide it the option `-I name=path`, where `name` is
one of the above you wish to override, and where path is either a local path or
a URL (like the default values, which point at tarballs of git branches on github)

So, for example, for development you might want to point at a local git clone of
`disciplina`, so you can manually `git` around, try patches, etc.

Of course, you need to create a deployment first, as above. Then, modify the
deployment with a NIX_PATH override:

```sh
nixops modify -d disciplina -I disciplina=$HOME/path/to/disciplina deployments/cluster.nix
```

Please note that `modify` is not incremental. If you do the above, and then
this, it will remove the override. Each call to `modify` needs to include all
arguments, including `deployments/cluster.nix`.

```sh
nixops modify -d disciplina deployments/cluster.nix
```

#### Pointing at a github archive

Github provides archive URIs which export tarballs of any valid git ref. Use the
following format:

```
https://github.com/<owner>/<repo>/archive/<ref>.tar.gz
```

Where `ref` can be any valid ref, including branch names, tag names, commit refs.
