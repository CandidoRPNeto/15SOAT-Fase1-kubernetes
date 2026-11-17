#!/usr/bin/env bash
# Registers a GitHub Actions self-hosted runner on THIS machine for one repo
# (ADR-014) and runs it as a systemd --user service. Labels: self-hosted, kind.
# Only the `deploy` job targets it, and only on push to the protected branch.
# Usage: scripts/setup-runner.sh CandidoRPNeto/15SOAT-Fase1-billing
set -euo pipefail
repo="${1:?usage: $0 <owner/repo>}"
version="${RUNNER_VERSION:-2.338.2}"
name="$(basename "$repo")"
dir="$HOME/actions-runners/$name"

mkdir -p "$dir" && cd "$dir"
if [[ ! -x ./config.sh ]]; then
  curl -fsSL -o runner.tgz "https://github.com/actions/runner/releases/download/v${version}/actions-runner-linux-x64-${version}.tar.gz"
  tar xzf runner.tgz && rm runner.tgz
fi

# Re-running only refreshes the systemd unit; config.sh refuses a configured dir.
if [[ ! -f .runner ]]; then
  token="$(gh api -X POST "repos/$repo/actions/runners/registration-token" --jq .token)"
  ./config.sh --unattended --replace --url "https://github.com/$repo" --token "$token" \
    --name "$(hostname)-$name" --labels kind --work _work
fi

unit="$HOME/.config/systemd/user/actions-runner-$name.service"
mkdir -p "$(dirname "$unit")"
cat > "$unit" <<UNIT
[Unit]
Description=GitHub Actions runner for $repo (kind deploys)
After=network-online.target docker.service

[Service]
WorkingDirectory=$dir
Environment=KUBECONFIG=$HOME/.kube/workshop-os-config
# systemd --user starts with a minimal PATH; kind/kubectl (e.g. linuxbrew)
# would be missing and deploy-kind.sh fails with "kind: command not found".
Environment=PATH=$PATH
ExecStart=$dir/run.sh
Restart=always

[Install]
WantedBy=default.target
UNIT
systemctl --user daemon-reload
systemctl --user enable "actions-runner-$name.service"
systemctl --user restart "actions-runner-$name.service"
echo "runner for $repo is $(systemctl --user is-active "actions-runner-$name.service")"
