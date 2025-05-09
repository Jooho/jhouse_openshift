import os
from app import flask_app

if __name__ == "__main__":
    # Get port from environment variable or use default 9999
    port = int(os.environ.get("PORT", 9999))

    # Run the app with Gunicorn
    # Use 4 worker processes
    # Bind to all interfaces (0.0.0.0) instead of just localhost
    # Set timeout to 30 seconds
    os.system(f"gunicorn -w 4 -b 0.0.0.0:{port} --timeout 30 app:flask_app")
