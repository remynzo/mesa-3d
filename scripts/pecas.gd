extends "res://scripts/cenario.gd"
## Peças e personagens: criar, selecionar, arrastar, mandar andar.


func add_piece(nome: String, color: Color, pos: Vector3, perso := "", varia := "", giro := 0.0) -> Node3D:
	if not personagens.has(perso):
		perso = ""
	var p := StaticBody3D.new()
	p.collision_layer = LAYER_PIECE
	p.collision_mask = 0
	p.position = pos
	p.set_meta("nome", nome)
	p.set_meta("cor", color.to_html(false))
	p.set_meta("perso", perso)
	# Visual sobe e desce (pulinho, passos) e gira pra onde o personagem olha, sem mexer na posição real
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.rotation.y = giro
	p.add_child(visual)
	var mi := MeshInstance3D.new()
	mi.name = "Corpo"
	mi.mesh = piece_mesh
	mi.material_override = material_for(color)
	mi.position.y = 0.5
	visual.add_child(mi)
	var outline := MeshInstance3D.new()
	outline.name = "Contorno"
	outline.mesh = piece_mesh
	outline.material_override = outline_mat
	outline.position.y = 0.5
	outline.layers = VIS_MASTER
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outline.visible = false
	visual.add_child(outline)
	var cs := CollisionShape3D.new()
	cs.shape = piece_shape
	cs.position.y = 0.5
	p.add_child(cs)
	var lb := Label3D.new()
	lb.text = nome
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.position.y = 1.45
	# mesmo tamanho na tela de perto ou de longe, e sempre visível pro mestre (atravessa árvore e parede)
	lb.fixed_size = true
	lb.pixel_size = 0.0007
	lb.font_size = 48
	lb.font = Tema.fonte_forte
	lb.outline_size = 14
	lb.outline_modulate = Color(0, 0, 0, 0.85)
	lb.no_depth_test = true
	lb.render_priority = 10
	lb.layers = VIS_MASTER
	visual.add_child(lb)
	if perso != "":
		# miniatura de papel: imagem em pé
		mi.position.y = 0
		outline.position.y = 0
		outline.scale = Vector3.ONE * 1.04
		cs.shape = standee_shape
		cs.position.y = TOKEN_ALTURA / 2
		lb.position.y = TOKEN_ALTURA + 0.25
		set_variation(p, varia)
	var ring := MeshInstance3D.new()
	ring.name = "Anel"
	ring.mesh = ring_mesh
	ring.material_override = ring_mat
	ring.position.y = 0.04
	ring.visible = false
	ring.layers = VIS_MASTER
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(ring)
	pieces.add_child(p)
	return p


# Cada imagem é uma variação; "x_costas" são as costas de "x", e "costas" vale pras que não têm.


func load_characters() -> void:
	var root := ProjectSettings.globalize_path("res://personagens")
	if not DirAccess.dir_exists_absolute(root):
		return   # sem personagens: as peças viram fichas simples
	for nome in DirAccess.get_directories_at(root):
		var files := {}
		for f in DirAccess.get_files_at(root.path_join(nome)):
			if f.get_extension().to_lower() in ["png", "webp", "jpg", "jpeg"]:
				files[f.get_basename()] = root.path_join(nome).path_join(f)
		var keys := files.keys()
		keys.sort()
		var vars := {}
		for k: String in keys:
			if k == "costas" or k.ends_with("_costas"):
				continue
			var front := load_tex(files[k])
			var back: String = files.get(k + "_costas", files.get("costas", ""))
			vars[k] = [front, load_tex(back) if back != "" else front]
		if not vars.is_empty():
			personagens[nome] = vars


# ponytail: carrega todas as imagens na abertura; carregar sob demanda se tiver dezenas de personagens
func load_tex(path: String) -> Texture2D:
	if token_cache.has(path):
		return token_cache[path]
	var img := Image.load_from_file(path)
	if img.get_height() > 1024:
		img.resize(img.get_width() * 1024 / img.get_height(), 1024, Image.INTERPOLATE_LANCZOS)
	img.generate_mipmaps()
	token_cache[path] = ImageTexture.create_from_image(img)
	return token_cache[path]


func set_variation(p: Node3D, varia: String) -> void:
	var perso: String = p.get_meta("perso")
	var vars: Dictionary = personagens[perso]
	if not vars.has(varia):
		varia = vars.keys()[0]
	p.set_meta("var", varia)
	var tex: Texture2D = vars[varia][0]
	var key := perso + "/" + varia
	if not token_cache.has(key):
		var q := QuadMesh.new()
		q.size = Vector2(TOKEN_ALTURA * tex.get_width() / tex.get_height(), TOKEN_ALTURA)
		q.center_offset = Vector3(0, TOKEN_ALTURA / 2, 0)
		var mats := []
		for outline in [false, true]:
			var m := ShaderMaterial.new()
			m.shader = TOKEN_SHADER
			m.set_shader_parameter("frente", tex)
			m.set_shader_parameter("costas", vars[varia][1])
			m.set_shader_parameter("contorno", outline)
			mats.append(m)
		token_cache[key] = [q, mats[0], mats[1]]
	var c: Array = token_cache[key]
	var corpo: MeshInstance3D = p.get_node("Visual/Corpo")
	var contorno: MeshInstance3D = p.get_node("Visual/Contorno")
	corpo.mesh = c[0]
	corpo.material_override = c[1]
	contorno.mesh = c[0]
	contorno.material_override = c[2]


func open_menu() -> void:
	var pos := get_viewport().get_mouse_position()
	var p := piece_at(pos)
	var alvos: Array = selected.keys() if p == null or selected.has(p) else [p]
	if p:
		alvos.erase(p)
		alvos.push_front(p)
	alvos = alvos.filter(func(x: Node3D) -> bool: return x.get_meta("perso") != "")
	if alvos.is_empty():
		show_msg("Passe o mouse em cima de um personagem e aperte B")
		return
	var perso: String = alvos[0].get_meta("perso")
	alvos = alvos.filter(func(x: Node3D) -> bool: return x.get_meta("perso") == perso)
	menu_before = state_dict()
	menu.abrir(self, alvos, personagens[perso], pos)


func menu_closed() -> void:
	if state_dict() != menu_before:
		push_undo(menu_before)


func face_camera(pos: Vector3) -> float:
	var d := camera.global_position - pos
	return atan2(-d.x, -d.z)


func set_selected(p: Node3D, on: bool) -> void:
	if on:
		selected[p] = true
	else:
		selected.erase(p)
	p.get_node("Anel").visible = on


func clear_selection() -> void:
	for p in selected.keys():
		set_selected(p, false)


func delete_selected() -> void:
	if selected.is_empty():
		return
	push_undo()
	for p in selected.keys():
		walking.erase(p)
		pieces.remove_child(p)
		p.queue_free()
	selected.clear()
	hovered = null


func set_hover(p: Node3D) -> void:
	if p == hovered:
		return
	if is_instance_valid(hovered):
		hovered.get_node("Visual/Contorno").visible = false
	hovered = p
	if p:
		p.get_node("Visual/Contorno").visible = true


# Discos no chão mostrando onde as peças vão parar (só o mestre vê).
func show_markers(points: Array[Vector3]) -> void:
	while markers.size() < points.size():
		var m := MeshInstance3D.new()
		m.mesh = marker_mesh
		m.material_override = marker_mat
		m.layers = VIS_MASTER
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		markers.append(m)
	for i in markers.size():
		markers[i].visible = i < points.size()
		if i < points.size():
			markers[i].position = points[i] + Vector3.UP * 0.03


func selection_center() -> Vector3:
	var center := Vector3.ZERO
	for p: Node3D in selected:
		center += p.position
	return center / selected.size()


# Manda as selecionadas andarem até o ponto, mantendo a formação.
func order_walk_to(point: Vector3) -> void:
	if selected.is_empty():
		return
	push_undo()
	var center := selection_center()
	for p: Node3D in selected:
		walking[p] = point + p.position - center


func walk(delta: float) -> void:
	for p: Node3D in walking.keys():
		var t: Vector3 = walking[p]
		var flat := Vector3(t.x - p.position.x, 0, t.z - p.position.z)
		var left := flat.length()
		# acelera na saída e freia no último metro
		var v := move_toward(float(walk_speed.get(p, 0.0)), WALK_SPEED * clampf(left / 1.2, 0.3, 1.0), 8.0 * delta)
		walk_speed[p] = v
		var visual: Node3D = p.get_node("Visual")
		if left <= v * delta:
			p.position = on_ground(Vector3(t.x, p.position.y, t.z))
			walking.erase(p)
			walk_speed.erase(p)
			visual.position.y = 0.0
		else:
			var np := p.position + flat / left * v * delta
			np.y = ground_at(np.x, np.z, p.position.y + 1.5)
			p.position = np
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-flat.x, -flat.z), 1.0 - exp(-10.0 * delta))
			visual.position.y = absf(sin(time * 9.0)) * 0.08   # passinhos
			# ponytail: linha reta, atravessa parede; NavigationRegion3D se precisar desviar


func start_drag(shift: bool) -> void:
	if not selected.has(press_piece):
		if not shift:
			clear_selection()
		set_selected(press_piece, true)
	push_undo()
	dragging = true
	grab_start = press_piece.position
	drag_start = {}
	for p: Node3D in selected:
		drag_start[p] = p.position
		walking.erase(p)
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(p.get_node("Visual"), "position:y", 0.6, 0.18)


func drag_to(pos: Vector2) -> void:
	var hit := mouse_hit(pos, LAYER_MAP)
	if hit.is_empty():
		return
	var h: Vector3 = hit.position
	var landing: Array[Vector3] = []
	for p: Node3D in drag_start:
		var o: Vector3 = drag_start[p] - grab_start
		var x := h.x + o.x
		var z := h.z + o.z
		var y := h.y if p == press_piece else ground_at(x, z, h.y + 1.5)
		p.position = Vector3(x, y, z)
		landing.append(on_ground(p.position))
	show_markers(landing)


func end_drag() -> void:
	for p: Node3D in drag_start:
		var tw := create_tween().set_parallel()
		tw.tween_property(p, "position", on_ground(p.position), 0.12).set_trans(Tween.TRANS_SINE)
		tw.tween_property(p.get_node("Visual"), "position:y", 0.0, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	drag_start = {}
	show_markers([])


# Botão direito segurado: linha do caminho e metros até o mouse.
func update_aim(pos: Vector2) -> void:
	var hit := mouse_hit(pos, LAYER_MAP)
	if hit.is_empty():
		return
	var to: Vector3 = hit.position
	var from := selection_center()
	var im: ImmediateMesh = aim_line.mesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var n := maxi(2, ceili(from.distance_to(to) / 0.5))
	for i in n + 1:
		var p := from.lerp(to, float(i) / n)
		im.surface_add_vertex(Vector3(p.x, ground_at(p.x, p.z, maxf(from.y, to.y) + 1.5) + 0.06, p.z))
	im.surface_end()
	aim_line.visible = true
	var landing: Array[Vector3] = []
	for p: Node3D in selected:
		landing.append(on_ground(to + p.position - from))
	show_markers(landing)
	aim_label.text = "%s m" % meters(Vector2(to.x - from.x, to.z - from.z).length())
	aim_label.position = pos + Vector2(18, 6)
	aim_label.visible = true


func end_aim() -> void:
	aiming = false
	aim_line.visible = false
	aim_label.visible = false
	show_markers([])


func meters(m: float) -> String:
	return ("%.1f" % m).replace(".", ",").trim_suffix(",0")


func end_rect(shift: bool) -> void:
	if not shift:
		clear_selection()
	if not rect.visible:
		return
	var r := Rect2(rect.position, rect.size)
	for p: Node3D in pieces.get_children():
		var top := p.global_position + Vector3.UP * 0.5
		if not camera.is_position_behind(top) and r.has_point(camera.unproject_position(top)):
			set_selected(p, true)
