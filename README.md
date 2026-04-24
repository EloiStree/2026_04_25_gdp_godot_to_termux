
# 2026_04_25_godot_gdp_to_termux

Try to establish communication between Godot and Termux to use Git on the Quest 3 / phone.

See: [https://chatgpt.com/share/69eab722-94d8-83eb-928e-9daa4f1c4bc4](https://chatgpt.com/share/69eab722-94d8-83eb-928e-9daa4f1c4bc4)

Install from termux python and flask
````
pkg update -y
pkg install python -y
pip install flask -y
nano server.py
```

Python Flask server code to run command on the device:
``` python
from flask import Flask, request
import subprocess

app = Flask(__name__)

@app.route("/run", methods=["POST"])
def run():
    cmd = request.json.get("cmd")

    if not cmd:
        return {"error": "no command provided"}, 400

    try:
        result = subprocess.check_output(
            cmd,
            shell=True,
            stderr=subprocess.STDOUT,
            text=True
        )
        return {"output": result}
    except subprocess.CalledProcessError as e:
        return {"output": e.output, "error": True}, 500


app.run(host="127.0.0.1", port=5050)
```

Launch Server
```
python server.py
```

`http://127.0.0.1:5050/run`


Node to run command:
```gdscript
extends Node

var http := HTTPRequest.new()

func _ready():
    add_child(http)

    var url = "http://127.0.0.1:5050/run"

    var body = {
        "cmd": "git"
    }

    var json = JSON.stringify(body)
    var headers = ["Content-Type: application/json"]

    http.request(url, headers, HTTPClient.METHOD_POST, json)
    http.request_completed.connect(_on_done)

func _on_done(result, response_code, headers, body):
    print("Response:", body.get_string_from_utf8())


```











