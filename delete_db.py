from app import db, User  # Assuming your models are defined in app.py
from app import app
with app.app_context():
    # Delete user by email
    test_email_1 = "test@mail"
    test_email_2 = ""

    user1 = User.query.filter_by(email=test_email_1).first()
    user2 = User.query.filter_by(email=test_email_2).first()

    if user1:
        db.session.delete(user1)
    if user2:
        db.session.delete(user2)

    db.session.commit()