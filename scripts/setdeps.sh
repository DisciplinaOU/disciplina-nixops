#!/usr/bin/env bash

#
# Usage: ./setdeps.sh <prefix> <postfix> -d <deployment> <path/to/deployment.nix>
#
# This script sets the path to the Disciplina source that will be used in a
# deployment. For example, to obtain the source from GitHub:
#
# $ ./setdeps.sh 'https://github.com/DisciplinaOU/' '/archive/master.tar.gz'
#
# (any other branch name or a tag can be used in place of `master`).

################################################################################
################################################################################


prefix="$1"
postfix="$2"

nixops modify \
  -Icustodial-wallet-api="https://github.com/DisciplinaOU/custodial-wallet-api/archive/prebuilt.tar.gz" \
  -Idisciplina="${prefix}disciplina/archive/watches.tar.gz" \
  -Idisciplina-nixops="${prefix}disciplina-nixops/archive/watches.tar.gz" \
  -Idisciplina-validatorcv="${prefix}disciplina-validatorcv/archive/master.tar.gz" \
  -Idisciplina-educator-spa="https://github.com/DisciplinaOU/disciplina-educator-spa/archive/1.0.0-web3.tar.gz" \
  "${@:3}"
