#!/usr/bin/env bash

#
# Usage: ./bootstrap.sh
#
# This script bootstraps a deployer-host, which can be used to build and deploy
# Disciplina clusters. Important: bootstrapping does not create a full deployer,
# rather the simplest one capable of deploying itself.

set -euo pipefail

################################################################################


# Used to select secrets from AWS Secrets Manager
deployer_env="production"

# Deployer will receive domain name "deployer.$deployer_domain"
deployer_domain="net.disciplina.io"

# Credentials used for bootstrapping
aws_credentials_file="$HOME/.aws/credentials"

deployment_repo="https://github.com/DisciplinaOU/disciplina-nixops"


################################################################################
################################################################################


# Do not change this. Use a different credential file if necessary.
export AWS_ACCESS_KEY_ID="default"
export AWS_SHARED_CREDENTIALS_FILE="$aws_credentials_file"

[ -f "$AWS_SHARED_CREDENTIALS_FILE" ] || {
  echo "* No AWS credentials file. Creating it..."
  mkdir -p "$(dirname "$AWS_SHARED_CREDENTIALS_FILE")"
  cat > "$AWS_SHARED_CREDENTIALS_FILE" <<-EOM
	[default]
	aws_access_key_id=...
	aws_secret_access_key=...
	EOM
  echo "** Put your credentials into $AWS_SHARED_CREDENTIALS_FILE and rerun the script"
  exit
}


export NIXOPS_DEPLOYMENT="deployer"

if ! nixops info >/dev/null 2>&1; then
  echo "* Creating the deployment..."
  nixops create deployments/deployer.nix
  nixops set-args --argstr env "bootstrap"
  nixops set-args --argstr domain "$deployer_domain"
else
  echo "! You already have a deployment called '$NIXOPS_DEPLOYMENT'."
  read -p "!! Press Enter to proceed with redeploying it..."
fi

echo "* Deploying..."
nixops deploy

echo "* Moving everything to the deployer..."
nixops_home="/var/lib/nixops"
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
