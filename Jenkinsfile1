pipeline {
  agent any

  environment {
      DOCKER_REGISTRY = 'https://registry.hub.docker.com'
      DOCKER_CREDENTIALS = credentials('docker-hub-credentials')
  }
  
   stages {
    stage('remove old container') {
      steps {
        sh 'docker rm -f sum_cont'
      }
    }
    stage('building new image') {
      steps {
        sh 'docker build -t new_img .'
      }
    }
    stage('run containers') {
      steps {
        sh 'docker run -d --name new_cont new_img:latest & docker run -d -p 5000:5000 --name sum_cont -v db-vol:/var/lib/docker/volumes new_img:latest'
      }
    }
    stage('stop test container') {
      steps {
        sh 'docker stop new_cont'
        }
    }
    stage('remove test container') {
      steps {
        sh 'docker remove new_cont'
        }
    }
    stage('docker login') {
      steps {
        sh 'docker login -u "$DOCKER_CREDENTIALS_USR" -p "$DOCKER_CREDENTIALS_PSW"'
        }
    }
    stage('tag new image') {
      steps {
        sh 'docker tag new_img guylah/summary:latest'
        }
    }
    stage('push image to docker hub') {
      steps {
        sh 'docker push guylah/summary:latest'
        }
    }
        stage('kubectl apply') {
            steps {
                sh 'kubectl apply -f summary-deploy.yaml --validate=false'
            }
        }

        stage('delete old image') {
      steps {
        sh 'docker rmi new_img' 
        }
    }
  }
}
