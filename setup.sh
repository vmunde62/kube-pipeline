#!/bin/sh


# Checking Prerequisites and installing if not found.
echo 'Checking Prerequisites..'
if ! command -v docker > /dev/null; then
    echo 'Installing Docker..'
    sudo apt-get remove docker docker-engine docker.io containerd runc -y 
    sudo apt-get update 
    sudo apt-get install ca-certificates curl gnupg lsb-release -y
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg 
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
    sudo groupadd docker
    sudo usermod -aG docker $USER 
fi
if ! command -v minikube > /dev/null; then
    echo 'Installing minikube..'
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
    sudo dpkg -i minikube_latest_amd64.deb 
fi
if ! command -v kubectl > /dev/null; then
    echo 'Installing kubectl'
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl -y
    sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update
    sudo apt-get install -y kubectl
fi
if ! command -v helm > /dev/null; then
    echo 'Installing helm'
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    sudo apt-get install apt-transport-https --yes
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get update
    sudo apt-get install helm -y
fi
if ! command -v vault > /dev/null; then
    echo 'Installing vault'
    sudo apt update && sudo apt install -y gpg 
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install -y vault
fi
if ! which jenkins > /dev/null; then
    echo 'Installing jenkins'
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo tee \
      /usr/share/keyrings/jenkins-keyring.asc > /dev/null
    echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
      https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
      /etc/apt/sources.list.d/jenkins.list > /dev/null
    sudo apt-get update
    sudo apt-get install openjdk-11-jre -y
    sudo apt-get install jenkins -y
fi


# Creating minikube clusters

echo 'Creating minikube clusters'
for cluster in cluster1 cluster2 cluster3; do
    if ! minikube profile list | grep $cluster | grep Running > /dev/null; then
        echo "Creating $cluster"
        minikube start --profile $cluster
    fi
done


# Starting Vault server
vaultdir=/etc/vault.d/vault.hcl
vaultSecretPath=keypair
crtName=tls.crt
keyName=tls.key
password=hello123

if test -f $vaultdir; then
    echo 'Clearing Default configuration'
    sudo systemctl stop vault
    sudo rm /usr/lib/systemd/system/vault.service
    sudo rm -R /etc/vault.d
    sudo rm -R /opt/vault
    sudo systemctl daemon-reload
fi
if ! test -f vault/vault_keys; then
    echo 'Setting vault server'
    sudo mkdir /etc/vault
    sudo cp vault/vault.hcl /etc
    sudo cp vault/vault.service /usr/lib/systemd/system
    sudo cp vault/vaultunseal.service /usr/lib/systemd/system
    sudo systemctl daemon-reload
    sudo systemctl start vault.service
    #sudo systemctl enable vault.service
    sleep 10
    sudo vault operator init -address='http://0.0.0.0:8200' -key-shares=4 -key-threshold=2 | head -6 > vault/vault_keys
    KEY1=$(cat vault/vault_keys | head -1 | cut -d " " -f 4)
    KEY2=$(cat vault/vault_keys | head -2 | tail -1 | cut -d " " -f 4)
    TOKEN=$(cat vault/vault_keys | tail -1 | cut -d " " -f 4)

    sudo cat > vault/unseal.sh <<EOF
#!/bin/bash

sleep 5
vault operator unseal $KEY1
sleep 2
vault operator unseal $KEY2
EOF

    sudo chmod u+x vault/unseal.sh
    sudo cp vault/unseal.sh /etc/vault
    sudo echo $TOKEN > vault/token
    sudo cp vault/token /etc/vault
    sleep 2
    sudo systemctl start vaultunseal.service
    #sudo systemctl enable vaultunseal.service
    sleep 10
    vault login -address='http://0.0.0.0:8200' $TOKEN
    vault secrets enable -path=secret -address='http://0.0.0.0:8200' kv-v2
    vault kv put -address='http://0.0.0.0:8200' secret/$vaultSecretPath $crtName="$(cat vault/ca.crt)" $keyName="$(cat vault/ca.key)" jkspass="$password"
fi


# configuring jenkins

if ! test -f /var/lib/jenkins/.kube/config; then
    echo 'Configuring jenkins'
    sudo systemctl stop jenkins
    sudo cp -R ~/.kube /var/lib/jenkins
    sudo cp -R ~/.minikube /var/lib/jenkins
    sudo sed -i "s+/home/$USER+/var/lib/jenkins+g" /var/lib/jenkins/.kube/config
    sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube
    sudo chown -R jenkins:jenkins /var/lib/jenkins/.minikube
    sudo systemctl start jenkins
fi


