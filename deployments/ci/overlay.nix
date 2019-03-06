final: previous: let
  ci-dummy = final.callPackage ({runCommandNoCC, ...}:runCommandNoCC "dscp-ci-dummy" {} "touch $out") {};
in {
  disciplina = ci-dummy;
  disciplina-config = ci-dummy;
  disciplina-data = ci-dummy;
  pdf-generator-xelatex = ci-dummy;
  disciplina-explorer-frontend = ci-dummy;
  disciplina-faucet-frontend = ci-dummy;
  disciplina-validatorcv = ci-dummy;
  disciplina-educator-spa = ci-dummy;
}
