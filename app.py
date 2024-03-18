from flask import Flask, request, redirect
from flask.templating import render_template
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
import os

basedir = os.path.abspath(os.path.dirname(__file__))

app = Flask(__name__)
app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///" + os.path.join(basedir, "users.db")

db = SQLAlchemy(app)

migrate = Migrate(app, db)

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(30), unique=False, nullable=False)
    email = db.Column(db.String(50), unique=True, nullable=False)

    def _repr__(self):
        return "<User {}>".format(self.name)

@app.route("/login", methods=["POST", "GET"])
def login():
    if request.method == "POST":
        name = request.form.get("name")
        email = request.form.get("email")

        if name is not None and email is not None:
            u = User(name=name, email=email)
            db.session.add(u)
            db.session.commit()
            return redirect("/")
    return render_template("login.html")



@app.route("/")
def index():
    users = User.query.all()
    return render_template("index.html", users=users)



if __name__ == "__main__":
    app.run(debug=True)