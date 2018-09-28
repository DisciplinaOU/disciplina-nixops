{ pkgs ? import ./pkgs.nix }: with pkgs;

let
  nixops = callPackage ./pkgs/nixops {};

  evalMachineInfo = import "${nixops}/share/nix/nixops/eval-machine-info.nix";

  evalNixOps = deployment: evalMachineInfo {
    deploymentName = "eval";

    nixpkgs = path;
    system = system;

    args = {};
    uuid = "000-000-000-000";

    networkExprs = [ deployment ];
  };
in

{
  disciplina-cluster = evalNixOps ./deployments/cluster.nix;
  disciplina-deployer = evalNixOps ./deployments/deployer.nix;
}
