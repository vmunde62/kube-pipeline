properties([parameters([choice(choices: 'cluster1\ncluster2\ncluster3', description: 'Choose the cluster', name: 'clusterName'), choice(choices: 'ns1\nns2\nns3', description: 'Choose the namespace', name: 'nameSpace')])])


pipeline {
    agent any
    stages {
        stage('Git Checkout') {
            steps {
                checkout([$class: 'GitSCM', branches: [[name: '*/master']], extensions: [], userRemoteConfigs: [[url: 'https://github.com/vmunde62/kube-pipeline.git']]])
            }
        }
        stage('Setting variables') {
            steps {
                script {
                    env.valuesYaml = sh( script: "scripts/set_valuesYaml.sh", returnStdout: true).trim()
                    env.vaultToken = sh( script: "cat /etc/vault/token", returnStdout: true ).trim()
                    env.vaultServer = sh( script: "cat webapp-helm/$valuesYaml | grep vaultServer | cut -d ' ' -f 4", returnStdout: true ).trim()
                    env.policyName = sh( script: "cat webapp-helm/$valuesYaml | grep policyName | cut -d ' ' -f 4", returnStdout: true ).trim()
                    env.vaultRole = sh( script: "cat webapp-helm/$valuesYaml | grep vaultRole | cut -d ' ' -f 4", returnStdout: true ).trim()
                }
                sh """
                    sed -i "s+$vaultRole+${params.clusterName}-${params.nameSpace}-role+g" webapp-helm/$valuesYaml
                    """     
            }
        }
        stage('CSI Deploy') {
            steps {
                sh """
                    kubectl config use-context ${params.clusterName}
                    kubectl create namespace ${params.nameSpace} || true
                    kubectl config set-context --current --namespace ${params.nameSpace}
                    kubectl create sa default || true
                    helm install vault-${params.nameSpace} vault_helm -n ${params.nameSpace} || true
                    helm install csi-${params.nameSpace} csi_helm -n ${params.nameSpace} || true
                    """
            }
        }
        stage('Vault Authentication') {
            steps {
                script {
                    env.TOKEN_REVIEW_JWT = sh( script: "scripts/vault_helm_secret.sh", returnStdout: true).trim()
                    env.KUBE_CA_CERT= sh( script: "scripts/kube_ca_cert.sh", returnStdout: true).trim()
                    env.KUBE_HOST= sh( script: "scripts/kube_host.sh", returnStdout: true).trim()
                }
                sh """
                    vault login -address=$vaultServer $vaultToken
                    vault auth enable -address=$vaultServer --path=${params.clusterName} kubernetes || true

                    vault write -address=$vaultServer auth/${params.clusterName}/config \
                    token_reviewer_jwt="$TOKEN_REVIEW_JWT" \
                    kubernetes_host="$KUBE_HOST" \
                    kubernetes_ca_cert="$KUBE_CA_CERT" \
                    issuer="https://kubernetes.default.svc.cluster.local"

                    echo -e "path \\"secret/data/keypair\\" {\\n  capabilities = [\\"read\\"]\\n}" > policy.hcl
                    vault policy write -address=$vaultServer $policyName policy.hcl

                    vault write -address=$vaultServer auth/${params.clusterName}/role/${params.clusterName}-${params.nameSpace}-role \
                    bound_service_account_names=default \
                    bound_service_account_namespaces=${params.nameSpace} \
                    policies=$policyName \
                    ttl=24h
                """
            }
        }
        stage('Helm Deploy') {
            steps {
                sh """
                    helm upgrade --install webapp webapp-helm --values webapp-helm/$valuesYaml || true
                """
            } 
        }
    }
}