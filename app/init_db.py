"""Create database tables at deploy time (not during Gunicorn worker import)."""
from app import app, db


def main():
    with app.app_context():
        db.create_all()


if __name__ == "__main__":
    main()
