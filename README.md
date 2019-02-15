This repository contains the Nixops deployment specification for Disciplina.

# Bootstrapping

In order to bootstrap a deployer machine, you will need a machine running Linux
with the Nix package manager installed. If you already have one, you can skip
the following subsection.

## Launching a NixOS instance

1. Go to the [NixOS download page](https://nixos.org/nixos/download.html).
2. Use a “Launch” button to create an instance in the region of your choice.
3. Make sure it has at least 5 Gb of disk space and 3 Gb of RAM.
4. SSH into your new NixOS instance and install Git and vim (or your favourite
   editor): `nix-env -iA nixos.git nixos.vim`.


## Deploying a minimalistic deployer

Deploying clusters works through a deployer. The first step is therefore to
deploy a deployer. From it, several clusters can be easily deployed. The
deployer also serves as a CI agent.

1.  Log into any Linux machine with Nix installed.
2.  Clone `https://github.com/DisciplinaOU/disciplina-nixops` and `cd` into it.
3.  Commit your SSH public key into `deployments/ssh-keys.nix` in the
    `disciplina-nixops` repository and add yourself to the `wheel` group in
    `deployments/deployer.nix`.
4.  Put your aws credentials in `~/.aws/credentials` in the following format:

        [default]
        aws_access_key_id=...
        aws_secret_access_key=...

5.  Review `scripts/bootstrap.sh` and modify the variables if needed.
6.  Enter `nix-shell`. This may take several minutes without any output
    as nixpkgs is being fetched.
7.  Run `./scripts/bootstrap.sh`.
8.  If you were using a temporary instance for bootstrapping, at this point
    you can safely discard it.

## Finalising the deployer deployment

1.  SSH into the brand new deployer.
2.  Run `nixops deploy -d deployer` to finalise its deployment.
    This may again take several minutes as nixpkgs is being fetched.


# Deploying a cluster

1.  SSH into the deployer.
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
    4.  Set `domain` to the full domain name under which the records for
        the names of the machines should be created.
    5.  Set `dnsZone` to the name of an AWS DNS zone in which these records will be
        configured if it differs from `disciplina.io.`.

8.  Run `./scripts/setdeps.sh 'https://github.com/DisciplinaOU/'
    '/archive/master.tar.gz' deployments/cluster.nix` to set the versions of
    dependencies used. `master` can be replaced with other tags or branches that
    are available in all dependencies. In order to use different sources for
    different dependencies, you need to manually run `nixops modify` with a `-I`
    option for each dependency.
9.  Run `./scripts/resources.sh deployer <name>` to give the cluster access to the
    VPC and routing table of the deployer.
10. Run `./scripts/deploy.sh <name>` to deploy the cluster.

## Managing secrets

Secrets are stored in aws secretsmanager. The set of secrets that should be used
can be selected by setting the `env` variable using `set-args`, as mentioned
above. For example, when `env` is set to `production`, the cluster uses the
secret called `production/disciplina/cluster`. Note, that as a special case,
when `env` is set to `production`, DNS will be disabled. The following secrets
are used:

- `<env>/disciplina/cluster` is used by the cluster. It should be a JSON object
  containing the following keys: `CommitteeSecret` and `FaucetKey`.
- `<env>/disciplina/buildkite` is used by the buildkite agent. It should be a
  JSON object containing the following keys: `AgentToken`, `APIAccessToken` and
  `CachixSigningKey`.

## Setting up continuous delivery

Continuous Delivery is conceptually the same as continuous integration: a
pipeline is triggered on BuildKite, which makes the associated BK agent run some
commands. The same agent runs both CI and CD for disciplina, and it runs on the
deployer.

An agent associates itself with a BK project by providing it with a secret token.

The deployment pipeline can be found here: https://buildkite.com/disciplina/disciplina-deploy

When this particular pipeline is triggered, it will check out the associated Git
repository, import `.buildkite/deploy.yml` and run the steps defined therein.

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

## Provisioning

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


--------------------------------------------------------------------------------


# Terminology

* A `deployment` is an entry in a nixops state file.
* A `cluster` is the set of resources created by running nixops for a given
  deployment.
* A `deployer` is the singleton entity that is used to provision clusters in
  one-to-many relationship.
  Runs Buildkite to CD clusters on each GitHub push, and to build Flatpak bundles,
  LaTeX documents and HTML documentation as part of CI pipeline.



[MacStadium]: https://www.macstadium.com
[Nix]: https://nixos.org/nix
[NixOps]: https://nixos.org/nixops
[nix-darwin]: https://github.com/LnL7/nix-darwin
