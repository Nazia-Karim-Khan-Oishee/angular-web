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
          // IDEA IN ONE LINE: take the built website files out of the Docker image,
          // then use Cloudflare's upload tool (wrangler) to publish them to Cloudflare Pages.
          // The Cloudflare token and account id above let wrangler log in without a password prompt.
          // Jenkins talks to the host's Docker, so files are moved with `docker cp` instead of volume mounts.
          sh '''
            # STEP 1: get the website files out of the image we just built.
            # The image already contains the finished site (HTML, JS, CSS) inside nginx's html folder.
            # We start from an empty "site" folder on the Jenkins side.
            rm -rf site
            # Make a stopped container from the image (we do not run it, we only need to open it up).
            docker create --name "$SITE_CTR" "$IMAGE:$IMAGE_TAG"
            # Copy the site files from inside that container into the "site" folder.
            docker cp "$SITE_CTR":/usr/share/nginx/html site

            # STEP 2: prepare a small helper container that has Node.js, so it can run wrangler.
            # It receives the Cloudflare token and account id as environment variables.
            # When started, it will do two things:
            #   a) create the Cloudflare Pages project "angular-web" (ignored if it already exists)
            #   b) upload the /site folder to that project, which makes the new version live
            docker create --name "$DEPLOY_CTR" \
              -e CLOUDFLARE_API_TOKEN -e CLOUDFLARE_ACCOUNT_ID \
              node:22-alpine sh -c "
                npx -y wrangler@4 pages project create $PAGES_PROJECT --production-branch=$PAGES_BRANCH > /dev/null 2>&1 || true
                npx -y wrangler@4 pages deploy /site --project-name=$PAGES_PROJECT --branch=$PAGES_BRANCH --commit-hash=$IMAGE_TAG --commit-dirty=true
              "
            # STEP 3: hand the site files to the helper container...
            docker cp site "$DEPLOY_CTR":/site
            # STEP 4: ...and start it. This runs wrangler, uploads the files to Cloudflare,
            # and the site is live at https://angular-web.pages.dev (the -a shows its output in the Jenkins log).
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
