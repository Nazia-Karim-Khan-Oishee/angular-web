pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '10'))
  }

  triggers {
    githubPush()
  }

  environment {
    IMAGE         = 'ghcr.io/nazia-karim-khan-oishee/angular-web'
    PAGES_PROJECT = 'angular-web'
    PAGES_BRANCH  = 'main'
    SITE_CTR      = "angular-web-site-${env.BUILD_NUMBER}"
    DEPLOY_CTR    = "angular-web-deploy-${env.BUILD_NUMBER}"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        script {
          env.IMAGE_TAG = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
        }
        echo "Building commit ${env.IMAGE_TAG}"
      }
    }

    stage('Build app image') {
      steps {
        sh 'docker build -t "$IMAGE:$IMAGE_TAG" -t "$IMAGE:latest" .'
      }
    }

    stage('Push to GHCR') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'ghcr', usernameVariable: 'GHCR_USER', passwordVariable: 'GHCR_TOKEN')]) {
          sh '''
            echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin
            docker push "$IMAGE:$IMAGE_TAG"
            docker push "$IMAGE:latest"
          '''
        }
      }
    }

    stage('Deploy to Cloudflare Pages') {
      steps {
        withCredentials([
          string(credentialsId: 'cloudflare-api-token', variable: 'CLOUDFLARE_API_TOKEN'),
          string(credentialsId: 'cloudflare-account-id', variable: 'CLOUDFLARE_ACCOUNT_ID')
        ]) {
          // Jenkins talks to the host's Docker, so files are moved with `docker cp` instead of volume mounts.
          sh '''
            rm -rf site
            docker create --name "$SITE_CTR" "$IMAGE:$IMAGE_TAG"
            docker cp "$SITE_CTR":/usr/share/nginx/html site

            docker create --name "$DEPLOY_CTR" \
              -e CLOUDFLARE_API_TOKEN -e CLOUDFLARE_ACCOUNT_ID \
              node:22-alpine sh -c "
                npx -y wrangler@4 pages project create $PAGES_PROJECT --production-branch=$PAGES_BRANCH > /dev/null 2>&1 || true
                npx -y wrangler@4 pages deploy /site --project-name=$PAGES_PROJECT --branch=$PAGES_BRANCH --commit-hash=$IMAGE_TAG --commit-dirty=true
              "
            docker cp site "$DEPLOY_CTR":/site
            docker start -a "$DEPLOY_CTR"
          '''
        }
      }
    }
  }

  post {
    always {
      sh '''
        docker rm -f "$SITE_CTR" "$DEPLOY_CTR" > /dev/null 2>&1 || true
        docker logout ghcr.io > /dev/null 2>&1 || true
        rm -rf site
      '''
    }
    success {
      echo "Image: ${env.IMAGE}:${env.IMAGE_TAG}"
      echo "Site:  https://${env.PAGES_PROJECT}.pages.dev"
    }
  }
}
