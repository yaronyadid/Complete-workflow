from flask import Flask

app = Flask(__name__)

@app.route("/")
def home():
    color = "#2b6cb0"  
    message = "Hello from my App!"  
    return f"""
    <html>
    <head>
      <title>My App</title>
    </head>
    <body style="background-color:{color}; color:white; text-align:center; font-family:Arial; padding-top:50px;">
      <h1>{message}</h1>
    </body>
    </html>
    """

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
