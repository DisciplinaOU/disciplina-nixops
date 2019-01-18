{ pkgs ? import ./pkgs.nix }: with pkgs;

let
  evalMachineInfo = import "${nixops}/share/nix/nixops/eval-machine-info.nix";

  evalNixOps = deployment: evalMachineInfo {
    deploymentName = "eval";

    nixpkgs = path;
    system = system;

    args = {
      domain = "cd.invalid";
      clusterIndex = "";
      env = "ci";
    };

    uuid = "000-000-000-000";

  networkExprs = [ deployment ./deployments/ci/shim.nix ];
  };
  # buildSystems: needed so it doesn't build the vm's etc.
  buildSystems = nixops: recurseIntoAttrs (lib.mapAttrs
    (name: node: node.config.system.build.toplevel)
    nixops.nodes);
  # make sure not to build disciplina
  shimmedPkgs = pkgs.extend (import ./deployments/ci/overlay.nix);
  customPackages = lib.getAttrs (builtins.attrNames (import ./pkgs {} {})) shimmedPkgs;
in
customPackages // {
  disciplina-cluster = buildSystems (evalNixOps ./deployments/cluster.nix);
  disciplina-deployer = buildSystems (evalNixOps ./deployments/deployer.nix);
}
