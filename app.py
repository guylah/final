from flask import Flask, request, redirect, session
from flask.templating import render_template
import pymysql.cursors
import mysql.connector
import rottentomatoes as rt
from imdb import Cinemagoer


app = Flask(__name__)
app.secret_key = "ilikemovies"

def create_conn():
    conn = mysql.connector.connect(
        host="movie-db.cf8oq4agi34u.us-east-1.rds.amazonaws.com",
        user="admin",
        password="oogg8888",
        database="movie_db"
    )
    return conn

conn = create_conn()

with conn.cursor() as cursor:
    sql = """
    CREATE TABLE IF NOT EXISTS user_watchlist (
        username VARCHAR(255) PRIMARY KEY,
        watchlist TEXT NULL
    )
    """
    cursor.execute(sql)
    conn.commit()


class User:
    username = None
    watchlist = None

    def __init__(self, username, watchlist=None):
        self.username = username
        self.watchlist = watchlist if watchlist else "" 

    def add_to_watchlist(self, movie_name):
        if self.watchlist:
            self.watchlist += "," + movie_name
        else:
            self.watchlist = movie_name

def get_tomato_score(movie_name: str):
    return rt.Movie(movie_name).weighted_score

def get_imdb_score(movie_name: str):
    cg = Cinemagoer()
    movie = cg.search_movie(movie_name)[0]
    cg.update(movie, info=["main"])
    return movie.data.get("rating")

def average_score(movie_name: str):
    scores = [get_imdb_score(movie_name), get_tomato_score(movie_name) / 10]
    return round(sum(scores) / len(scores), 2)

@app.route("/", methods=["GET", "POST"])
def index():
    return render_template("search.html")

@app.route("/search", methods=["POST"])
def search():
    movie_name = request.form.get("movie_name")
    if movie_name:
        return redirect(f"/movie/{movie_name}")
    else:
        return redirect("/")

@app.route("/movie/<movie_name>", methods=["GET", "POST"])
def movie(movie_name):
    if request.method == "POST":
        username = session.get('username')
        if not username:
            return redirect("/login")
        
        if username:
             with conn.cursor() as cursor:
                cursor.execute("SELECT watchlist FROM user_watchlist WHERE username = %s", (username,))
                user = cursor.fetchone()

                if user:
                    watchlist = user[0]
                    watchlist += "," + movie_name if watchlist else movie_name
                    cursor.execute("UPDATE user_watchlist SET watchlist = %s WHERE username = %s", (watchlist, username))
                    conn.commit()
        return redirect(f"/{username}/watchlist")

    imdb_score = get_imdb_score(movie_name)
    tomato_score = get_tomato_score(movie_name)
    avg_score = average_score(movie_name)

    return render_template("movie.html", movie_name=movie_name, imdb_score=imdb_score, tomato_score=tomato_score, avg_score=avg_score)

@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form.get("username")
        if username:
            session['username'] = username

            with conn.cursor() as cursor:
                cursor.execute("SELECT COUNT(*) FROM user_watchlist WHERE username = %s", (username,))
                user_exists = cursor.fetchone()[0]

                if not user_exists:
                    cursor.execute("INSERT INTO user_watchlist (username, watchlist) VALUES (%s, %s)", (username, ""))
                    conn.commit()

            return redirect("/")
    return render_template("login.html")

@app.route("/<username>/watchlist")
def watchlist(username):
     with conn.cursor() as cursor:
        cursor.execute("SELECT watchlist FROM user_watchlist WHERE username = %s", (username,))
        user = cursor.fetchone()
        watchlist = user[0].split(",") if user else []
     return render_template("watchlist.html", username=username, watchlist=watchlist)

if __name__ == "__main__":
    app.run(debug=True)