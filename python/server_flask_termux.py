from flask import Flask, request
import subprocess

app = Flask(__name__)

@app.route("/run", methods=["POST"])
def run():
    cmd = request.json.get("cmd")

    if not cmd:
        return {"error": "no command provided"}, 400

    print(f"\n[COMMAND RECEIVED] {cmd}")

    try:
        result = subprocess.check_output(
            cmd,
            shell=True,
            stderr=subprocess.STDOUT,
            text=True
        )

        print("[OUTPUT]")
        print(result)

        return {"output": result}

    except subprocess.CalledProcessError as e:
        print("[ERROR OUTPUT]")
        print(e.output)

        return {"output": e.output, "error": True}, 500


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5050)

