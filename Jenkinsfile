pipeline {
  agent any
  options { timestamps(); timeout(time: 15, unit: 'MINUTES') }
  environment { REGISTRY = 'localhost:5000'; IMAGE = 'capstone-app' }
  stages {
    stage('Checkout') { steps { checkout scm } }
    stage('Test') {
      steps {
        sh '''
          python3 -m venv .venv
          .venv/bin/pip install -q -r requirements.txt
          mkdir -p reports
          .venv/bin/python -m pytest -q --junitxml=reports/junit.xml
        '''
      }
      post { always { junit 'reports/junit.xml' } }
    }
    stage('Build image') {
      steps { sh 'docker build -t $REGISTRY/$IMAGE:$BUILD_NUMBER --build-arg APP_VERSION=$BUILD_NUMBER .' }
    }
    stage('Scan image') {
      // --exit-code 0 only reports. Change to 1 to FAIL the build on CRITICAL findings.
      steps { sh 'docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image --severity CRITICAL --exit-code 0 $REGISTRY/$IMAGE:$BUILD_NUMBER' }
    }
    stage('Approval') {
      steps { timeout(time: 10, unit: 'MINUTES') { input message: 'Publish this build to the registry?' } }
    }
    stage('Publish') { steps { sh 'docker push $REGISTRY/$IMAGE:$BUILD_NUMBER' } }
  }
  post { failure { echo 'capstone-app: build FAILED - open Console Output and Test Result' } }
}
