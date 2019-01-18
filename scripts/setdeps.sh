#!/usr/bin/env bash

# Usage: setdeps.sh prefix postfix -d deployment

prefix="$1"
postfix="$2"

nixops modify \
	-Idisciplina="${prefix}disciplina${postfix}" \
	-Idisciplina-explorer-frontend="${prefix}disciplina-explorer-frontend${postfix}" \
	-Idisciplina-faucet-frontend="${prefix}disciplina-faucet-frontend${postfix}" \
	-Idisciplina-nixops="${prefix}disciplina-nixops${postfix}" \
	-Idisciplina-validatorcv="${prefix}disciplina-validatorcv${postfix}" \
	"${@:3}"
