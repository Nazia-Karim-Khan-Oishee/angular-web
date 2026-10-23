FROM node:22.22.3-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build


FROM nginx:stable-alpine
LABEL org.opencontainers.image.source="https://github.com/Nazia-Karim-Khan-Oishee/angular-web"
RUN rm -rf /usr/share/nginx/html/*
COPY --from=build /app/dist/webapp/browser /usr/share/nginx/html
EXPOSE 80
