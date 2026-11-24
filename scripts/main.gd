extends "res://scripts/testes.gd"
## Mesa 3D de RPG: cenário .glb, peças, névoa e configurações de qualidade.
## Testes: godot --path . -- --foto /caminho/teste.glb   |   -- --carga [cenario.glb] [--preset Baixo]
## Aqui: abertura, entrada do mouse/teclado e o laço de cada quadro. O resto está nos arquivos da corrente (veja base.gd).


func _ready() -> void:
	piece_mesh.top_radius = 0.42
	piece_mesh.bottom_radius = 0.5
	piece_mesh.height = 1.0
	piece_shape.radius = 0.5
	piece_shape.height = 1.0
	standee_shape.radius = 0.4
	standee_shape.height = TOKEN_ALTURA
	load_characters()
	ring_mesh.inner_radius = 0.55
	ring_mesh.outer_radius = 0.68
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1, 0.85, 0.2)
	# contorno: a mesma malha um pouco maior, só com as faces de trás
	outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	outline_mat.grow = true
	outline_mat.grow_amount = 0.05
	outline_mat.albedo_color = Color(1, 1, 1)
	marker_mesh.top_radius = 0.5
	marker_mesh.bottom_radius = 0.5
	marker_mesh.height = 0.02
	marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_mat.albedo_color = Color(1, 1, 1, 0.35)

	camera = Camera3D.new()
	camera.cull_mask = VIS_WORLD | VIS_MASTER
	add_child(camera)
	jog = Jogadores.new()
	add_child(jog)
	jog.setup(VIS_WORLD | VIS_PLAYER, VIS_MASTER)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	add_child(sun)
	visual = Visual.new()
	add_child(visual)
	visual.setup(self)

	scenario = Node3D.new()
	add_child(scenario)
	pieces = Node3D.new()
	add_child(pieces)

	grid = MeshInstance3D.new()
	grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grid.layers = VIS_MASTER
	grid.visible = false
	add_child(grid)
	aim_line = MeshInstance3D.new()
	aim_line.mesh = ImmediateMesh.new()
	aim_line.layers = VIS_MASTER
	aim_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aim_line.material_override = ring_mat
	add_child(aim_line)

	build_ui()
	load_config()
	set_mode(Mode.PIECES)
	get_window().files_dropped.connect(_on_files_dropped)

	var args := OS.get_cmdline_user_args()
	if "--foto" in args:
		run_photo_test(args)
	elif "--carga" in args:
		run_load_test(args)
	elif "--mesa" in args:
		if "--fotos" in args:
			run_table_photos(args)
		else:
			load_table(args[args.find("--mesa") + 1])
	else:   # aberto sem nada: mesa de exemplo (a capela) e, na primeira vez, a ajuda
		if FileAccess.file_exists(EXEMPLO):
			load_table(EXEMPLO)
		else:
			make_default_ground()
		help_panel.visible = not ajuda_vista


func _input(event) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
		set_mode(Mode.PIECES if mode == Mode.FLY else Mode.FLY)
		get_viewport().set_input_as_handled()
	elif mode == Mode.FLY and event is InputEventMouseMotion:
		yaw -= event.relative.x * 0.003
		pitch = clampf(pitch - event.relative.y * 0.003, -1.5, 1.5)
		camera.rotation = Vector3(pitch, yaw, 0)
	elif mode == Mode.FLY and event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			fly_speed *= 1.2
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			fly_speed /= 1.2
		get_viewport().set_input_as_handled()


func _unhandled_input(event) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.physical_keycode
		if key == KEY_ESCAPE:
			toggle_settings()
		elif key == KEY_DELETE and mode != Mode.FLY:
			delete_selected()
		elif key == KEY_Z and event.ctrl_pressed:
			redo() if event.shift_pressed else undo()
		elif key == KEY_Y and event.ctrl_pressed:
			redo()
		elif key == KEY_B and mode != Mode.FLY:
			open_menu()
		elif (key == KEY_Q or key == KEY_E) and mode != Mode.FLY and not selected.is_empty():
			push_undo()
			for p: Node3D in selected:
				p.get_node("Visual").rotation.y += PI / 4 * (1 if key == KEY_Q else -1)
		elif key == KEY_C and not event.ctrl_pressed:
			jog.go_to(camera.global_transform)
		elif key >= KEY_1 and key <= KEY_9:
			shot_key(key - KEY_0, event.ctrl_pressed)
		return
	if mode == Mode.FLY:
		return
	if event is InputEventMouseButton and event.pressed:
		get_viewport().gui_release_focus()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(event.position, event.button_index == MOUSE_BUTTON_WHEEL_UP)
			return
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			var hit := mouse_hit(event.position, LAYER_MAP)
			orbit_pivot = hit.position if not hit.is_empty() else cam_goal.origin - cam_goal.basis.z * 15.0
			return
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		if event.shift_pressed:
			pan(event.relative)
		else:
			orbit(event.relative)
		return
	match mode:
		Mode.PIECES:
			pieces_input(event)
		Mode.NEW:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				var hit := mouse_hit(event.position, LAYER_MAP)
				if not hit.is_empty():
					push_undo()
					var perso := perso_opt.get_item_text(perso_opt.selected) if perso_opt.selected > 0 else ""
					add_piece(name_edit.text if name_edit.text != "" else "Peça", color_btn.color, on_ground(hit.position), perso, "", face_camera(hit.position))
		Mode.SCENE:
			scene_input(event)


func prop_at(pos: Vector2) -> Node3D:
	var hit := mouse_hit(pos, LAYER_MAP | Visual.LAYER_PROP)
	if hit.is_empty() or hit.collider.get_parent() != visual.props:
		return null
	return hit.collider


func scene_input(event) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press_prop = prop_at(event.position)
			if press_prop:
				push_undo()
			else:
				var hit := mouse_hit(event.position, LAYER_MAP)
				if not hit.is_empty():
					var tipo: String = Visual.CATALOGO[prop_opt.selected]
					if tipo != "Impacto":
						push_undo()
					visual.add_prop(tipo, hit.position)
		else:
			press_prop = null
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var p := prop_at(event.position)
		if p:
			push_undo()
			visual.remove_prop(p)
	elif event is InputEventMouseMotion and press_prop and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var hit := mouse_hit(event.position, LAYER_MAP)
		if not hit.is_empty():
			press_prop.position = hit.position


func pieces_input(event) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press_pos = event.position
			press_piece = piece_at(event.position)
			rect_selecting = press_piece == null
			dragging = false
		else:
			if dragging:
				end_drag()
			elif rect_selecting and not (event.position.distance_to(press_pos) < 5 and toggle_door(event.position)):
				end_rect(event.shift_pressed)
			elif press_piece:
				if event.shift_pressed:
					set_selected(press_piece, not selected.has(press_piece))
				else:
					clear_selection()
					set_selected(press_piece, true)
			press_piece = null
			rect_selecting = false
			dragging = false
			rect.hide()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and not selected.is_empty():
			aiming = true
			update_aim(event.position)
		elif not event.pressed and aiming:
			end_aim()
			var hit := mouse_hit(event.position, LAYER_MAP)
			if not hit.is_empty():
				order_walk_to(hit.position)
	elif event is InputEventMouseMotion and aiming:
		update_aim(event.position)
	elif event is InputEventMouseMotion and event.button_mask == 0:
		set_hover(piece_at(event.position))
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if press_piece and not dragging and event.position.distance_to(press_pos) > 4:
			start_drag(event.shift_pressed)
		if dragging:
			drag_to(event.position)
		elif rect_selecting:
			rect.show()
			rect.position = press_pos.min(event.position)
			rect.size = (event.position - press_pos).abs()


# Atalho de print (Super+Shift+S) rouba o teclado no meio: o Shift desce aqui e o soltar vai pra outro
# programa, aí ele ficava "apertado pra sempre". Ao perder/ganhar o foco ou o mouse voltar, esquece as teclas.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT,
			NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_WM_MOUSE_ENTER]:
		for k in [KEY_W, KEY_S, KEY_A, KEY_D, KEY_SPACE, KEY_SHIFT, KEY_CTRL, KEY_META]:
			if Input.is_physical_key_pressed(k):
				var e := InputEventKey.new()
				e.physical_keycode = k
				e.keycode = k
				e.pressed = false
				Input.parse_input_event(e)


func _process(delta: float) -> void:
	if mode == Mode.FLY:
		var b := camera.global_transform.basis
		var dir := Vector3.ZERO
		if Input.is_physical_key_pressed(KEY_W): dir -= b.z
		if Input.is_physical_key_pressed(KEY_S): dir += b.z
		if Input.is_physical_key_pressed(KEY_A): dir -= b.x
		if Input.is_physical_key_pressed(KEY_D): dir += b.x
		if Input.is_physical_key_pressed(KEY_SPACE): dir += Vector3.UP
		if Input.is_physical_key_pressed(KEY_SHIFT): dir -= Vector3.UP
		if Input.is_physical_key_pressed(KEY_META):   # Super apertado = atalho do sistema, não voo
			dir = Vector3.ZERO
		var speed := fly_speed * (3.0 if Input.is_physical_key_pressed(KEY_CTRL) else 1.0)
		camera.position += dir.normalized() * speed * delta
		cam_goal = camera.global_transform
	elif cam_moving():
		var w := 1.0 - exp(-12.0 * delta)   # inércia: chega rápido e desacelera
		camera.global_transform = camera.global_transform.interpolate_with(cam_goal, w)
		if camera.global_position.distance_to(cam_goal.origin) < 0.001:
			camera.global_transform = cam_goal
	time += delta
	walk(delta)
	# o ícone da câmera atrapalha quando o mestre está em cima dela
	jog.gizmo.visible = camera.global_position.distance_to(jog.cam.global_position) > 1.5
	# parado: só redesenha quando algo muda
	OS.low_processor_usage_mode = not testing and mode != Mode.FLY and walking.is_empty() and not dragging \
		and not aiming and not jog.busy() and not cam_moving() and not visual.animating()
	fps_timer += delta
	if fps_timer > 0.5:
		fps_timer = 0.0
		fps_label.text = "parado (economizando)" if OS.low_processor_usage_mode else "%d FPS" % Engine.get_frames_per_second()


func _on_files_dropped(files: PackedStringArray) -> void:
	var ext := files[0].get_extension().to_lower()
	if ext == "glb" or ext == "gltf":
		load_scenario(files[0])
	elif ext == "json":
		load_table(files[0])
	elif ext in IMAGENS:
		on_add_character(files)
