
    echo "🐳 Fetching Docker Nectar..."
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker $USER
    echo "✅ Docker installed. (Logout/Login later to use without sudo)"