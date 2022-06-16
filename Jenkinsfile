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
                sh 'echo hello'     
            }
        }
        stage('CSI Deploy') {
            steps {
                sh """
                    kubectl config use-context cluster1
                    kubectl create namespace ns1 || true
                    kubectl config set-context --current --namespace ns1
                    kubectl create sa default || true
                    helm install vault vault_helm -n ns1 || true
                    helm install csi csi_helm -n ns1 || true
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
                sh "echo $TOKEN_REVIEW_JWT"
                sh "echo $KUBE_HOST"
            }
        }
    }
}