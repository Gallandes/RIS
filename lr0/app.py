import os
import redis
from flask import Flask

app = Flask(__name__)
db = redis.Redis(host=os.environ.get("REDIS_HOST", "redis"), port=6379)

@app.route("/")
def index():
    hits = db.incr("hits")
    return f"Привет из Цифрового города! Страницу открывали {hits} раз.\n"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
