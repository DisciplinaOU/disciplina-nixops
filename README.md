Primary Disciplina deployment specification.

To use this repo, enter `nix-shell`.

# Deploying

Deploying clusters works through a deployer. The first step is therefor to
deploy a deployer. From it, several clusters can be easily deployed. The
deployer also serves as a CI agent.

## Deploying a deployer

1.  Log into a machine with nix installed.
2.  Clone `https://github.com/DisciplinaOU/disciplina-nixops` and `cd` to it.
3.  Commit your SSH public key into `deployments/ssh-keys.nix` in the
    `disciplina-nixops` repository and add yourself to the `wheel` group in
    `deployments/deployer.nix`.
4.  Put your aws credentials in `~/.aws/credentials` in the following format:

        [default]
        aws_access_key_id=...
        aws_secret_access_key=...

5.  Check `scripts/bootstrap.sh` and modify variables if needed.
6.  Enter `nix-shell`. This may take several minutes as nixpkgs is being
    fetched.
7.  Run `scripts/bootstrap.sh`.
8.  SSH into the domain name printed by the script.
9.  Run `nixops deploy -d deployer` to finish deployment. This may again take
    several minutes as nixpkgs is being fetched.

## Deploying a cluster

1.  SSH to the deployer.
2.  `cd` to `/var/lib/nixops` where deployer-wide state should be kept.
3.  Create a directory for the cluster you want to deploy and `cd` to it.
4.  Clone `https://github.com/DisciplinaOU/disciplina-nixops` and `cd` to it.
5.  Run `export NIXOPS_DEPLOYMENT=<name>` to set the name of the cluster for this
    session or pass `-d <name>` to every `nixops` command.
6.  Create the cluster deployment entry with
    `nixops create deployments/cluster.nix`. After this, it will fail to
    evaluate until all necessary arguments have been set in the next three
    steps.
7.  Use `nixops set-args --argstr <key> <value>` to set the
    following variables:

    1.  Set `region` to the AWS region if it differs from `eu-central-1`.
    2.  Set `clusterIndex` to an integer between 1 and 25. Every cluster deployed
        from the same deployer should have a different cluster index.
    3.  Set `env` to `staging` or `production` depending on which set of secrets
        you want to use. If set to `production`, DNS will not be configured, so
        the next two steps can be skipped.
    4.  Set `domain` to the domain under which the domain names for the machines
        should be created.
    5.  Set `dnsZone` to the AWS DNS zone in which these domains can be
        configured if it differs from `disciplina.io.`.

8.  Run `scripts/setdeps.sh 'https://github.com/DisciplinaOU/'
    '/archive/master.tar.gz' deployments/cluster.nix` to set the versions of
    dependencies used. `master` can be replaced with other tags or branches that
    are available in all dependencies. In order to use different sources for
    different dependencies, you need to manually run `nixops modify` with a `-I`
    option for each dependency.
9.  Run `scripts/resources.sh deployer <name>` to give the cluster access to the
    VPC and routing table of the deployer.
10. Run `scripts/deploy.sh <name>` to deploy the cluster.

## Setting up continuous delivery

Continuous Delivery is conceptually the same as continuous integration: a
pipeline is triggered on BuildKite, which makes the associated BK agent run some
commands. The same agent runs both CI and CD for disciplina, and it runs on the
deployer.

An agent associates itself with a BK project by providing it with a secret token.

The deployment pipeline can be found here: https://buildkite.com/disciplina/disciplina-deploy

When this particular pipeline is triggered, it will check out the associated Git
repository, import `.buildkite/pipeline.deploy.yaml` and run the steps defined therein.

This repository should contain all things necessary for a deployment, one way or
another. Git submodules are one way.

These steps should include running `nixops` to deploy whatever it is you want to deploy.

In order to avoid running on build-only agents, this will only run on builders
with a tag `deploy=true`.

We have a Slack command `/deploy` that asks GitHub to trigger a deployment
event, which this BK pipeline is configured to respond to.

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

If you want to avoid hours of building, it's recommended that you set up our binary cache.
Instructions for this are on the [cachix page](https://disciplina.cachix.org).

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

To push changes to the cluster, re-run the last command.

When not actively working on your cluster, you should shut it down:

```sh
nixops stop -d disciplina --confirm
```

You can start it back up with:

```sh
nixops start -d disciplina --confirm
```

To clean up your cluster, which you should do when you're done with it:

```sh
nixops destroy -d disciplina --confirm
```

#### Deploying locally

You should only deploy to AWS if you have a good reason for it. You can deploy
to your local computer by spawning VirtualBox machines, which is much faster.

The entire cluster will need ~2Gb of RAM and 13Gb of HDD space once deployed and running.

##### Setup

You will need to install VirtualBox.

On NixOS, add the following to your `configuration.nix`:
```
  virtualisation.virtualbox.host.enable = true;
```

For other Linux distributions, it's probably in your repositories.

On other systems, visit the [VirtualBox
website](https://www.virtualbox.org/wiki/Downloads) to download and install.

##### Important!

From the nixops manual:
> Note that for this to work the vboxnet0 network has to exist - you can add it in
> the VirtualBox general settings under Networks - Host-only Networks if
> necessary.

##### Deployment

Replace `<name>` with what you want to call this deployment. For example,
`disciplina-vm` or `disciplina-local`. Use a unique name.

```sh
nixops create deployments/cluster.nix -d <name>
nixops set-args --argstr hostType virtualbox -d <name>
```

You can stop and start the cluster same as above. This will stop all VMs. You
will also need to start the deployment after rebooting your machine.

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
