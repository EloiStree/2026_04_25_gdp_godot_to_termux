extends Node

@export var bridge: TermuxBridge


func _ready() -> void:
	add_child(bridge)

	bridge.on_command_sent.connect(_on_sent)
	bridge.on_command_output.connect(_on_output)
	bridge.on_command_sent_as_string.connect(_on_sent_str)
	bridge.on_command_output_as_string.connect(_on_output_str)

	await get_tree().create_timer(1).timeout

	await _sync_all_submodules()


# -------------------------
# MAIN SYNC FLOW
# -------------------------

func _sync_all_submodules() -> void:
	var root := ProjectSettings.globalize_path("res://")
	var gitmodules_path := root + ".gitmodules"

	if not FileAccess.file_exists(gitmodules_path):
		print("[INFO] No .gitmodules found")
		return

	var file := FileAccess.open(gitmodules_path, FileAccess.READ)
	var content := file.get_as_text()
	file.close()

	var paths: Array[String] = []

	for line in content.split("\n"):
		line = line.strip_edges()
		if line.begins_with("path = "):
			paths.append(line.replace("path = ", "").strip_edges())

	for rel_path in paths:
		var abs_path := root.path_join(rel_path)

		print("\n============================")
		print("Syncing:", abs_path)
		print("============================")

		await _sync_repo(abs_path)


# -------------------------
# PER REPO FLOW
# -------------------------

func _sync_repo(path: String) -> void:
	var cb := bridge.TermuxCallback.new()

	# 1. status
	bridge.run_command("cd \"%s\" && git status --porcelain" % path, cb)
	await get_tree().create_timer(0.5).timeout

	# 2. add
	bridge.run_command("cd \"%s\" && git add ." % path, cb)
	await get_tree().create_timer(0.5).timeout

	# 3. commit (safe: only if changes exist)
	bridge.run_command(
		"cd \"%s\" && git diff --cached --quiet || git commit -m \"auto sync\"" % path,
		cb
	)
	await get_tree().create_timer(0.5).timeout

	# 4. pull (rebase recommended)
	bridge.run_command("cd \"%s\" && git pull" % path, cb)
	await get_tree().create_timer(1.0).timeout

	# 5. push
	bridge.run_command("cd \"%s\" && git push" % path, cb)
	await get_tree().create_timer(1.0).timeout


# -------------------------
# SIGNALS
# -------------------------

func _on_sent(cmd: String, request_id: int) -> void:
	print("[SENT]", request_id, cmd)


func _on_output(request_id: int, success: bool, text: String) -> void:
	print("[OUTPUT]", request_id, success)
	print(text)


func _on_sent_str(text: String) -> void:
	print("[SENT STRING]", text)


func _on_output_str(text: String) -> void:
	print("[OUTPUT STRING]")
	print(text)
