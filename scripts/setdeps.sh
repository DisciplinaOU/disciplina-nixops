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
	-Idisciplina="${prefix}disciplina${postfix}" \
	-Idisciplina-explorer-frontend="${prefix}disciplina-explorer-frontend${postfix}" \
	-Idisciplina-faucet-frontend="${prefix}disciplina-faucet-frontend${postfix}" \
	-Idisciplina-nixops="${prefix}disciplina-nixops${postfix}" \
	-Idisciplina-validatorcv="${prefix}disciplina-validatorcv${postfix}" \
	-Idisciplina-educator-spa="${prefix}disciplina-educator-spa${postfix}" \
	"${@:3}"
