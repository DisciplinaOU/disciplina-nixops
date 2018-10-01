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
  # buildSystems: needed so it doesn't build the vm's etc.
  buildSystems = nixops: recurseIntoAttrs (lib.mapAttrs
    (name: node: node.config.system.build.toplevel)
    nixops.nodes);
in

{
  disciplina-cluster = buildSystems (evalNixOps ./deployments/cluster.nix);
  disciplina-deployer = buildSystems (evalNixOps ./deployments/deployer.nix);
}
