#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash jq nixops

set -euo pipefail

# Used to select secrets from secretsmanager
deployer_env="production"

# Deployer will receive domain name "deployer.$deployer_domain"
deployer_domain="example.net.disciplina.io"

deployment_repo="https://github.com/DisciplinaOU/disciplina-nixops"
NIXOPS_DEPLOYMENT="deployer"
AWS_SHARED_CREDENTIALS_FILE="$HOME/.aws/credentials"

# Do not change this. Use a different credential file if necessary.
AWS_ACCESS_KEY_ID="default"
nixops_home="/var/lib/nixops"

[ -f "$AWS_SHARED_CREDENTIALS_FILE" ] || {
  echo "* No AWS credentials file. Creating it..."
  mkdir -p "$(dirname "$AWS_SHARED_CREDENTIALS_FILE")"
  cat > "$AWS_SHARED_CREDENTIALS_FILE" <<-EOM
	[default]
	aws_access_key_id=...
	aws_secret_access_key=...
	EOM
  echo "** Put your credentials into $AWS_SHARED_CREDENTIALS_FILE"
  exit
}

if ! nixops info >/dev/null 2>&1; then
  echo "* Creating the deployment..."
  nixops create deployments/deployer.nix
  nixops set-args --argstr env bootstrap
  nixops set-args --argstr domain "$deployer_domain"
else
  echo "! You already have a deployment called '$NIXOPS_DEPLOYMENT'."
  read -p "!! Press Enter to proceed with redeploying it..."
fi

echo "* Deploying..."
nixops deploy

echo "* Moving everything to the deployer..."
state=$(nixops export)
cmd=""
cmd+="cd '$nixops_home' && "
cmd+="sudo -u nixops git clone '$deployment_repo' disciplina-nixops && "
cmd+="nixops import -d '$NIXOPS_DEPLOYMENT' && "
cmd+="nixops modify disciplina-nixops/deployments/deployer.nix && "
cmd+="nixops set-args --argstr env '$deployer_env'"
echo "$state" | nixops ssh deployer "$cmd"

public_ip=$(echo "$state" | jq -r '.[].resources["deployer"].publicDnsName')
echo "* All done."

echo "SSH into the new deployer at $public_ip"
