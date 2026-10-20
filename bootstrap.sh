#!/bin/bash
# usage: bootstrap.sh ROLE REG_IP CLOUD OWNER TOKEN     (runs once, as root, from user-data)
set -euo pipefail
ROLE="$1"; REG_IP="$2"; CLOUD="$3"; OWNER="$4"; TOKEN="$5"
exec >> /var/log/capstone-bootstrap.log 2>&1
set -x
export DEBIAN_FRONTEND=noninteractive
echo "$ROLE" > /etc/capstone-role
apt-get update -y
apt-get install -y ansible-core
DOCKER=false
if [ "$ROLE" = "ci" ]; then DOCKER=true; fi
ansible-playbook -c local -i localhost, -e install_docker=$DOCKER /opt/capstone/ansible/baseline.yml
if [ "$CLOUD" = "aws" ]; then apt-get install -y awscli || snap install aws-cli --classic; fi

if [ "$ROLE" = "ci" ]; then
  cd /opt/capstone
  docker run -d --name registry --restart=always -p 5000:5000 -v registrydata:/var/lib/registry registry:2
  sleep 5
  for v in 1.0 2.0; do
    docker build -t "localhost:5000/capstone-app:$v" --build-arg "APP_VERSION=$v" .
    docker push "localhost:5000/capstone-app:$v"
  done
  apt-get install -y openjdk-21-jre fontconfig
  install -d -m 0755 /etc/apt/keyrings
  curl -fsSL -o /etc/apt/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
  echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list
  apt-get update -y
  apt-get install -y jenkins
  usermod -aG docker jenkins
  mkdir -p /etc/systemd/system/jenkins.service.d
  printf '[Service]\nEnvironment="JAVA_OPTS=-Djava.awt.headless=true -Xmx512m"\n' > /etc/systemd/system/jenkins.service.d/override.conf
  systemctl daemon-reload
  systemctl enable jenkins
  systemctl restart jenkins
fi

if [ "$ROLE" = "k8s" ]; then
  mkdir -p /etc/rancher/k3s
  cat > /etc/rancher/k3s/registries.yaml <<REG_EOF
mirrors:
  "$REG_IP:5000":
    endpoint:
      - "http://$REG_IP:5000"
REG_EOF
  sed -i "s/REGISTRY_IP/$REG_IP/; s/OWNER_ID/$OWNER/; s/TOKEN_VALUE/$TOKEN/" /opt/capstone/k8s/deployment.yaml
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable traefik" sh -
  for i in $(seq 1 60); do k3s kubectl get nodes 2>/dev/null | grep -q ' Ready' && break; sleep 5; done
fi
touch /var/lib/capstone-ready
