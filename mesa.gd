extends "res://camera.gd"
## Mesa: aplicar estado, desfazer/refazer, salvar e abrir.


func apply_state(data: Dictionary) -> void:
	clear_selection()
	walking.clear()
	walk_speed.clear()
	hovered = null
	for p in pieces.get_children():
		pieces.remove_child(p)
		p.queue_free()
	for d in data.get("pecas", []):
		add_piece(str(d.nome), Color.html(str(d.cor)), Vector3(d.x, d.y, d.z), str(d.get("perso", "")), str(d.get("var", "")), float(d.get("giro", 0.0)))
	visual.clear_props()
	for o in data.get("objetos", []):
		visual.add_prop(str(o.tipo), Vector3(o.x, o.y, o.z))


func table_dict() -> Dictionary:
	var d := state_dict()
	d.cenario = scenario_path
	d.planos = jog.shots_dict()
	d.clima = visual.clima
	return d


func undo() -> void:
	if undo_stack.is_empty():
		show_msg("Nada pra desfazer")
		return
	redo_stack.push_back(state_dict())
	apply_state(undo_stack.pop_back())


func redo() -> void:
	if redo_stack.is_empty():
		show_msg("Nada pra refazer")
		return
	undo_stack.push_back(state_dict())
	apply_state(redo_stack.pop_back())


func save_table(path: String) -> void:
	if not path.ends_with(".json"):
		path += ".json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		show_msg("Não consegui salvar em " + path)
		return
	f.store_string(JSON.stringify(table_dict(), "\t", true, true))
	show_msg("Mesa salva: " + path.get_file())


func load_table(path: String) -> void:
	if not FileAccess.file_exists(path):
		show_msg("Arquivo de mesa não encontrado: " + path)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary):
		show_msg("Arquivo de mesa inválido")
		return
	var cen: String = data.get("cenario", "")
	if cen != "" and cen != scenario_path:
		await load_scenario(cen)
	apply_state(data)
	set_clima(data.get("clima", visual.clima))
	undo_stack.clear()
	redo_stack.clear()
	jog.load_shots(data.get("planos", {}))
	refresh_shot_btns()
	show_msg("Mesa aberta: " + path.get_file())
