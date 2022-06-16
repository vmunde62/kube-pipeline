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
                    sleep(10)
                    helm install csi csi_helm -n ns1 || true
                    sleep(10)
                    """
            }
        }
    }
}