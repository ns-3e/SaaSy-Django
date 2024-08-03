#!/bin/bash

read -p "Enter project name: " PROJECT_NAME
read -p "Enter database user: " DB_USER
read -p "Enter database password: " DB_PASSWORD

DB_NAME=$PROJECT_NAME

# Create Django project
django-admin startproject $PROJECT_NAME

# Change directory
cd $PROJECT_NAME || exit

# Create Python virtual environment
python -m venv venv

# Create requirements.txt file
echo "Django>=4.0,<5.0" > requirements.txt
echo "gunicorn" >> requirements.txt
echo "psycopg2-binary" >> requirements.txt

# Generate Docker files
cat <<EOL > Dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt

COPY . .

CMD ["gunicorn", "$PROJECT_NAME.wsgi:application", "--bind", "0.0.0.0:8000"]
EOL

cat <<EOL > docker-compose.yml
version: '3.8'

services:
  db:
    image: postgres:13
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: $DB_NAME
      POSTGRES_USER: $DB_USER
      POSTGRES_PASSWORD: $DB_PASSWORD

  web:
    build: .
    command: gunicorn $PROJECT_NAME.wsgi:application --bind 0.0.0.0:8000
    volumes:
      - .:/app
    ports:
      - "8000:8000"
    depends_on:
      - db

volumes:
  postgres_data:
EOL

# Create Django apps
apps=("accounts" "billing" "products" "analytics" "support" "notifications" "admin" "content" "integrations" "security" "settings" "onboarding" "custom_features")

for app in "${apps[@]}"; do
    django-admin startapp $app
done

# Create static and templates directories
mkdir -p $PROJECT_NAME/static/css
mkdir -p $PROJECT_NAME/static/js
mkdir -p $PROJECT_NAME/static/images
mkdir -p $PROJECT_NAME/templates

# Add Bootstrap CSS and JS to static folder
curl -o $PROJECT_NAME/static/css/bootstrap.min.css https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/css/bootstrap.min.css
curl -o $PROJECT_NAME/static/js/bootstrap.min.js https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/js/bootstrap.min.js

# Basic view and template for each app
for app in "${apps[@]}"; do
    mkdir -p $PROJECT_NAME/$app/templates/$app

    cat <<EOL > $PROJECT_NAME/$app/views.py
from django.shortcuts import render

def home(request):
    return render(request, '$app/home.html')

EOL

    cat <<EOL > $PROJECT_NAME/$app/templates/$app/home.html
{% extends "base.html" %}

{% block title %}${app^}{% endblock %}

{% block content %}
<h2>Welcome to the ${app^} app!</h2>
{% endblock %}
EOL

    cat <<EOL > $PROJECT_NAME/$app/urls.py
from django.urls import path
from . import views

app_name = '$app'
urlpatterns = [
    path('', views.home, name='home'),
]
EOL
done

# Update the main urls.py file to include the apps
cat <<EOL > $PROJECT_NAME/urls.py
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
EOL

for app in "${apps[@]}"; do
    echo "    path('$app/', include('$app.urls'))," >> $PROJECT_NAME/urls.py
done

cat <<EOL >> $PROJECT_NAME/urls.py
]
EOL

# Update settings.py to include the templates and static directories
SETTINGS_FILE="$PROJECT_NAME/settings.py"
sed -i "/TEMPLATES = \[/a \ \ \ \ 'DIRS': [os.path.join(BASE_DIR, 'templates')]," $SETTINGS_FILE
sed -i "/STATIC_URL = '\/static\/'/a \ \ \ \ STATICFILES_DIRS = [os.path.join(BASE_DIR, 'static')]" $SETTINGS_FILE

# Update base.html to include Bootstrap
cat <<EOL > $PROJECT_NAME/templates/base.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}My SaaS Platform{% endblock %}</title>
    <link rel="stylesheet" href="{% static 'css/bootstrap.min.css' %}">
</head>
<body>
    <header>
        <nav class="navbar navbar-expand-lg navbar-light bg-light">
            <a class="navbar-brand" href="#">My SaaS Platform</a>
            <div class="collapse navbar-collapse">
                <ul class="navbar-nav">
                    <li class="nav-item"><a class="nav-link" href="/">Home</a></li>
                </ul>
            </div>
        </nav>
    </header>
    <main class="container mt-4">
        {% block content %}
        {% endblock %}
    </main>
    <footer class="bg-light py-3 mt-4">
        <div class="container text-center">
            <p>&copy; 2024 My SaaS Platform</p>
        </div>
    </footer>
    <script src="{% static 'js/bootstrap.min.js' %}"></script>
</body>
</html>
EOL

# Create commands.md
cat <<EOL > commands.md
# Commands for $PROJECT_NAME

## Setting up the environment
\`\`\`
source venv/bin/activate
\`\`\`

## Starting Docker
\`\`\`
docker-compose up
\`\`\`

## Database Details
- **Database Name**: $DB_NAME
- **Database User**: $DB_USER
- **Database Password**: $DB_PASSWORD

## Other commands
- To build Docker images: \`docker-compose build\`
- To stop Docker: \`docker-compose down\`
\`\`\`
EOL

echo "Project setup complete!"