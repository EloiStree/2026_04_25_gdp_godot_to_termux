class_name TermuxBridge
extends Node


class TermuxCallback:
	extends RefCounted

	var request_id: int = -1
	var status: String = "pending"
	var result: Dictionary = {}

	func _init(id: int = -1) -> void:
		request_id = id
		status = "initialized"

	func set_started() -> void:
		status = "running"

	func set_done(success: bool, data: Dictionary) -> void:
		status = "done" if success else "error"
		result = data


# ✔️ Signals
signal on_command_sent(cmd: String, request_id: int)
signal on_command_output(request_id: int, success: bool, text: String)

signal on_command_sent_as_string(text: String)
signal on_command_output_as_string(text: String)


var http: HTTPRequest
@export var web_server_ip: String = "http://127.0.0.1:5050"

var _callbacks: Dictionary = {}
var _next_id: int = 0


func _ready() -> void:
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)


func run_command(cmd: String, callback: TermuxCallback) -> int:
	var request_id := _next_id
	_next_id += 1

	callback.request_id = request_id
	callback.set_started()
	_callbacks[request_id] = callback

	var url := "%s/run" % web_server_ip

	var body := {
		"cmd": cmd,
		"id": request_id
	}

	var json_body := JSON.stringify(body)
	var headers := PackedStringArray(["Content-Type: application/json"])

	var err := http.request(url, headers, HTTPClient.METHOD_POST, json_body)

	if err != OK:
		_callbacks.erase(request_id)
		callback.set_done(false, {"error": "request_failed_to_start", "code": err})
		return -1

	_emit_sent(cmd, request_id)
	return request_id


func run_command_no_callback(cmd: String) -> int:
	return run_command(cmd, TermuxCallback.new())


func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var text := body.get_string_from_utf8()

	var data: Dictionary = _try_parse_json(text)

	var success := response_code >= 200 and response_code < 300

	# Try to resolve request id safely
	var request_id: int = data.get("id", -1)
	on_command_output.emit(request_id, success, text)
	on_command_output_as_string.emit(text)
	

	# Fallback: match unknown response to first pending callback if id missing
	var callback: TermuxCallback = null

	if request_id != -1 and _callbacks.has(request_id):
		callback = _callbacks[request_id]
		_callbacks.erase(request_id)
	elif _callbacks.size() > 0:
		# fallback safety net
		var first_key :int= _callbacks.keys()[0]
		callback = _callbacks[first_key]
		_callbacks.erase(first_key)

	if callback:
		callback.set_done(success, data)


func _try_parse_json(text: String) -> Dictionary:
	var json := JSON.new()
	var err := json.parse(text)

	if err == OK:
		return json.data as Dictionary

	return {
		"raw": text,
		"parse_error": true
	}


func _emit_sent(cmd: String, request_id: int) -> void:
	on_command_sent.emit(cmd, request_id)
	on_command_sent_as_string.emit(cmd)
