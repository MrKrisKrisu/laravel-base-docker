# laravel-base-docker

> Prebuild webserver for laravel deployment with apache2

## Example usage

Add the following files to your laravel project and adapt the paths to your requirements and paths.

### Dockerfile

```dockerfile
FROM node:18-alpine as NodeBuildContainer
WORKDIR /app
COPY . /app
RUN npm i && npm run prod

FROM composer:2 as ComposerBuildContainer
WORKDIR /app
COPY . /app
RUN composer install --ignore-platform-reqs --no-interaction --no-dev --no-progress --no-suggest --optimize-autoloader

FROM ghcr.io/mrkriskrisu/laravel-base:latest
WORKDIR /var/www/html

COPY --chown=www-data:www-data . /var/www/html
COPY --from=NodeBuildContainer --chown=www-data:www-data /app/public/js /var/www/html/public/js
COPY --from=NodeBuildContainer --chown=www-data:www-data /app/public/fonts /var/www/html/public/fonts
COPY --from=NodeBuildContainer --chown=www-data:www-data /app/public/css /var/www/html/public/css
COPY --from=ComposerBuildContainer --chown=www-data:www-data /app/vendor /var/www/html/vendor

CMD ["/var/www/html/docker-entrypoint.sh"]

EXPOSE 80/tcp
```

### docker-entrypoint.sh

```bash
#!/bin/bash
set -e
role=${CONTAINER_ROLE:-app}

cd /var/www/html
wait-for-it "$DB_HOST:${DB_PORT:=3306}"
runuser -u www-data -- php artisan optimize
runuser -u www-data -- php artisan config:clear

if [ "$role" = "app" ]; then

    echo "Running as app..."
    if [ "$APP_ENV" = 'local' ]; then
        echo "Running as local environment."
        runuser -u www-data -- php artisan migrate --seed --force
    else
        echo "Running as productive environment."
        runuser -u www-data -- php artisan migrate --force
    fi

    apache2-foreground

elif [ "$role" = "queue" ]; then

    echo "Running the queue..."
    runuser -u www-data -- php artisan queue:work

elif [ "$role" = "scheduler" ]; then

    echo "Running as scheduler..."
    while true
    do
        runuser -u www-data -- php artisan schedule:run --verbose --no-interaction
        sleep 60
    done

else
    echo "Could not match the container role \"$role\""
    exit 1
fi
```

### docker-compose.yml

```yaml
version: "3.9"

services:
  scheduler:
    image: your-build-image
    container_name: laravel-scheduler
    restart: 'always'
    depends_on:
      - app
    networks:
      - internal
    env_file:
      - .env.app
    environment:
      CONTAINER_ROLE: scheduler

  queue:
    image: your-build-image
    container_name: laravel-queue
    restart: 'always'
    depends_on:
      - app
    networks:
      - internal
    env_file:
      - .env.app
    environment:
      CONTAINER_ROLE: queue

  app:
    image: your-build-image
    container_name: laravel-app
    restart: 'always'
    networks:
      - internal
    env_file:
      - .env.app
    environment:
      - CONTAINER_ROLE=app

  database:
    image: mariadb:latest
    container_name: laravel-db
    restart: 'always'
    volumes:
      - ./docker/database:/var/lib/mysql
    networks:
      - internal
    environment:
      - TZ=Europe/Berlin
    env_file:
      - .env.db

networks:
  internal:
    external: false
```