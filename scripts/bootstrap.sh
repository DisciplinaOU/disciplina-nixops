#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash jq nixops

set -euo pipefail

deployment_repo="https://github.com/DisciplinaOU/disciplina-nixops"
nixops_home="/var/lib/nixops"

export AWS_ACCESS_KEY_ID="default"
export NIXOPS_DEPLOYMENT="deployer"
export DISCIPLINA_ENV="bootstrap"

[ -f "$HOME/.aws/credentials" ] || {
  echo "* No AWS credentials file. Creating it..."
  mkdir -p "$HOME/.aws"
  cat > "$HOME/.aws/credentials" <<-EOM
	[default]
	aws_access_key_id=...
	aws_secret_access_key=...
	EOM
  echo '** Put your credentials into $HOME/.aws/credentials'
  exit
}

if ! nixops info >/dev/null 2>&1; then
  echo "* Creating the deployment..."
  nixops create deployments/deployer.nix
else
  echo "! You already have a deployment called '$NIXOPS_DEPLOYMENT'."
  read -p "!! Press Enter to proceed with redeploying it..."
fi

echo "* Deploying..."
nixops deploy

echo "* Moving everything to the deployer..."
json=$(nixops export)
cmd=""
cmd+="mkdir -p '$nixops_home' && "
cmd+="cd '$nixops_home' && "
cmd+="git clone '$deployment_repo' && "
cmd+="chown -R nixops:nixops . && "
cmd+="sudo -u nixops nixops import -d '$NIXOPS_DEPLOYMENT' && "
cmd+="sudo -u nixops nixops modify ./disciplina-nixops/deployments/deployer.nix"
echo "$json" | nixops ssh disciplina-deployer "$cmd"

public_ip=$(echo "$json" | jq -r '.[].resources["disciplina-deployer"].publicDnsName')
echo "* All done."

echo "SSH into the new deployer at $public_ip"
