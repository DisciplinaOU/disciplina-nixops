#!/usr/bin/env bash

set -e

if [ -z "$IN_NIX_SHELL" ]; then
  echo >&2 "Please, run this script from inside nix-shell."
  exit 1
fi

deployment_repo="https://github.com/DisciplinaOU/disciplina-nixops"
nixops_home="/var/lib/nixops"
dname="dscp"


unset AWS_SHARED_CREDENTIALS_FILE

[ -f "$HOME/.aws/credentials" ] || {
  echo "* No AWS credentials file. Creating it..."
  mkdir -p "$HOME/.aws"
  cat > "$HOME/.aws/credentials" <<EOF
[default]
aws_access_key_id=...
aws_secret_access_key=...
EOF
  echo '** Put your credentials into $HOME/.aws/credentials'
  exit
}

if ! nixops info -d "$dname" >/dev/null 2>&1; then
  echo "* Creating the deployment..."
  nixops create deployments/deployer.nix -d "$dname"
  nixops set-args --argstr env production -d "$dname"
else
  echo "! You already have a deployment called '$dname'."
  read -p "!! Press Enter to proceed with redeploying it..."
fi

echo "* Deploying..."
nixops deploy -d "$dname"

echo "* Moving everything to the deployer..."
json=$(nixops export -d "$dname")
mkdir -p "$nixops_home"
cmd="git clone \"$deployment_repo\" \"$nixops_home\"/disciplina-nixops && chown -R nixops:nixops \"$nixops_home\" && sudo -u nixops nixops import && sudo -u nixops nixops modify \"$nixops_home\"/disciplina-nixops/deployments/deployer.nix"
echo "$json" | nixops ssh -d "$dname" disciplina-deployer -A "$cmd"

public_ip=$(echo "$json" | jq -r '.[].resources["disciplina-deployer"].publicDnsName')
echo "* All done."

echo "SSH into the new deployer at $public_ip"
