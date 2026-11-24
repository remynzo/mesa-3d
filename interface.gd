extends "res://mesa.gd"
## Barra de botões, modos e configurações de qualidade.


const NOME_MODO := {
	Mode.FLY: "Voar", Mode.PIECES: "Peças", Mode.NEW: "Nova peça",
	Mode.SCENE: "Ambientar",
}


func set_mode(m: Mode) -> void:
	mode = m
	mode_btns[m].button_pressed = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if m == Mode.FLY else Input.MOUSE_MODE_VISIBLE
	if m == Mode.FLY:
		get_viewport().gui_release_focus()
		settings_panel.hide()
		yaw = camera.rotation.y
		pitch = camera.rotation.x
	if m != Mode.PIECES:
		set_hover(null)
		end_aim()
	help.text = HELP[m].get_slice("—", 1).strip_edges() if "—" in HELP[m] else HELP[m]
	mode_label.text = NOME_MODO[m].to_upper()
	# o painel de opções só aparece pras ferramentas que têm opção
	for k in ctx_boxes:
		ctx_boxes[k].visible = k == m
	ctx_panel.visible = ctx_boxes.has(m)


func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()   # raiz de toda a interface: é ela que leva o tema
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = Tema.criar()
	layer.add_child(ui)
	build_top_bar(ui)
	build_tools(ui)
	build_context(ui)
	build_status_bar(ui)

	msg_panel = PanelContainer.new()
	msg_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	msg_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	msg_panel.offset_top = 64
	msg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg_panel.add_theme_stylebox_override("panel", Tema.caixa(Color(0.08, 0.07, 0.06, 0.95), Tema.AMBAR * Color(1, 1, 1, 0.5), 20, 16))
	msg_panel.hide()
	msg = Label.new()
	msg.add_theme_color_override("font_color", Tema.AMBAR)
	msg.add_theme_font_override("font", Tema.fonte_media)
	msg_panel.add_child(msg)
	ui.add_child(msg_panel)

	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 3
	add_child(menu_layer)
	menu = MenuRedondo.new()
	menu_layer.add_child(menu)

	rect = ColorRect.new()
	rect.color = Color(1, 0.85, 0.2, 0.2)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false
	layer.add_child(rect)
	aim_label = Label.new()
	aim_label.add_theme_font_override("font", Tema.fonte_forte)
	aim_label.add_theme_color_override("font_color", Tema.AMBAR)
	aim_label.add_theme_constant_override("outline_size", 6)
	aim_label.visible = false
	var top := CanvasLayer.new()
	top.layer = 2
	add_child(top)
	top.add_child(aim_label)

	build_camera_panel(ui)
	build_settings(ui)

	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.use_native_dialog = true
	file_dialog.file_selected.connect(func(path: String) -> void: file_callback.call(path))
	layer.add_child(file_dialog)


# Barra de cima: arquivo, desfazer, clima, grade e configurações.
func build_top_bar(ui: Control) -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var st := Tema.caixa(Tema.FUNDO, Color(0, 0, 0, 0), 0, 10)
	st.border_width_bottom = 1
	st.border_color = Tema.BORDA
	bar.add_theme_stylebox_override("panel", st)
	ui.add_child(bar)
	var hb := HBoxContainer.new()
	bar.add_child(hb)
	hb.add_child(Tema.icone(Tema.I_DADO, 20, Tema.SANGUE))
	var nome := Label.new()
	nome.text = "MESA"
	nome.add_theme_font_override("font", Tema.fonte_titulo)
	nome.add_theme_font_size_override("font_size", 18)
	hb.add_child(nome)
	hb.add_child(VSeparator.new())
	var arq := [
		[Tema.I_PASTA, "Abrir mesa", "Abre uma mesa salva (.json)", ask_file.bind(FileDialog.FILE_MODE_OPEN_FILE, PackedStringArray(["*.json ; Mesa"]), load_table)],
		[Tema.I_SALVAR, "Salvar", "Salva peças, névoa, luzes e planos de câmera", ask_file.bind(FileDialog.FILE_MODE_SAVE_FILE, PackedStringArray(["*.json ; Mesa"]), save_table)],
		[Tema.I_CENARIO, "Cenário", "Troca o cenário 3D (.glb) — também dá pra arrastar o arquivo pra janela", ask_file.bind(FileDialog.FILE_MODE_OPEN_FILE, PackedStringArray(["*.glb, *.gltf ; Cenário 3D"]), load_scenario)],
	]
	for a in arq:
		var b := Tema.botao(a[0], a[1], a[2])
		b.pressed.connect(a[3])
		hb.add_child(b)
	hb.add_child(VSeparator.new())
	for a in [[Tema.I_DESFAZER, "Desfazer (Ctrl+Z)", undo], [Tema.I_REFAZER, "Refazer (Ctrl+Y)", redo]]:
		var b := Tema.botao(a[0], "", a[1])
		b.pressed.connect(a[2])
		hb.add_child(b)
	var meio := Control.new()
	meio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(meio)
	hb.add_child(Tema.icone(Tema.I_CLIMA, 15, Tema.APAGADO))
	clima_opt = OptionButton.new()
	for item in Visual.CLIMAS:
		clima_opt.add_item(item)
	clima_opt.focus_mode = Control.FOCUS_NONE
	clima_opt.tooltip_text = "Clima: céu, luz, neblina e cor"
	clima_opt.item_selected.connect(func(i: int) -> void: set_clima(clima_opt.get_item_text(i)))
	hb.add_child(clima_opt)
	grid_btn = Tema.botao(Tema.I_GRADE, "", "Mostrar a grade (só você vê)")
	grid_btn.toggle_mode = true
	grid_btn.toggled.connect(func(on: bool) -> void: grid.visible = on)
	hb.add_child(grid_btn)
	hb.add_child(VSeparator.new())
	fps_label = Label.new()
	fps_label.add_theme_color_override("font_color", Tema.APAGADO)
	fps_label.add_theme_font_size_override("font_size", 13)
	fps_label.custom_minimum_size.x = 150
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(fps_label)
	var cfg_btn := Tema.botao(Tema.I_CONFIG, "", "Configurações de qualidade (Esc)")
	cfg_btn.pressed.connect(toggle_settings)
	hb.add_child(cfg_btn)


# Barra da esquerda: uma ferramenta por modo.
func build_tools(ui: Control) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(10, 62)
	panel.add_theme_stylebox_override("panel", Tema.caixa(Tema.FUNDO, Tema.BORDA, 12, 6))
	ui.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var group := ButtonGroup.new()
	var lista := [
		[Mode.PIECES, Tema.I_CURSOR, "Peças", "Selecionar, arrastar e mandar andar"],
		[Mode.NEW, Tema.I_NOVA, "Nova peça", "Colocar personagens no mapa"],
		[Mode.SCENE, Tema.I_AMBIENTAR, "Ambientar", "Tochas, fogo, neblina, sigilos…"],
		[Mode.FLY, Tema.I_VOAR, "Voar", "Andar pelo mapa com WASD (Tab)"],
	]
	for item in lista:
		if item[0] == Mode.FLY:
			vb.add_child(HSeparator.new())
		var b := Tema.ferramenta(item[1], item[2], item[3])
		b.button_group = group
		b.pressed.connect(set_mode.bind(item[0]))
		vb.add_child(b)
		mode_btns[item[0]] = b


# Painel ao lado das ferramentas, com as opções da escolhida.
func build_context(ui: Control) -> void:
	ctx_panel = PanelContainer.new()
	ctx_panel.position = Vector2(96, 62)
	ctx_panel.custom_minimum_size.x = 250
	ui.add_child(ctx_panel)
	var raiz := VBoxContainer.new()
	ctx_panel.add_child(raiz)

	var nova := ctx_box(raiz, Mode.NEW, "Nova peça", "Clique no chão pra colocar. B troca a variação depois.")
	name_edit = LineEdit.new()
	name_edit.text = "Herói"
	name_edit.placeholder_text = "nome da peça"
	nova.add_child(name_edit)
	perso_opt = OptionButton.new()
	perso_opt.add_item("Peça simples")
	for nome: String in personagens:
		perso_opt.add_item(nome)
	perso_opt.selected = mini(1, perso_opt.item_count - 1)
	perso_opt.focus_mode = Control.FOCUS_NONE
	perso_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_btn = ColorPickerButton.new()
	color_btn.color = Color(0.85, 0.25, 0.2)
	color_btn.custom_minimum_size = Vector2(44, 34)
	color_btn.focus_mode = Control.FOCUS_NONE
	color_btn.tooltip_text = "Cor da base"
	var hb := HBoxContainer.new()
	hb.add_child(perso_opt)
	hb.add_child(color_btn)
	nova.add_child(hb)


	var amb := ctx_box(raiz, Mode.SCENE, "Ambientar", "Clique no chão pra pôr · arraste pra mover · botão direito apaga.")
	prop_opt = OptionButton.new()   # guarda a escolha; quem aparece são os botões abaixo
	for item in Visual.CATALOGO:
		prop_opt.add_item(item)
	prop_opt.visible = false
	amb.add_child(prop_opt)
	var g := GridContainer.new()
	g.columns = 2
	amb.add_child(g)
	var grupo := ButtonGroup.new()
	for i in Visual.CATALOGO.size():
		var b := Button.new()
		b.text = Visual.CATALOGO[i]
		b.toggle_mode = true
		b.button_group = grupo
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = i == 0
		b.pressed.connect(func() -> void: prop_opt.select(i))
		g.add_child(b)


func ctx_box(raiz: VBoxContainer, m: Mode, titulo: String, dica: String) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_child(Tema.titulo(titulo, Tema.AMBAR))
	var d := Label.new()
	d.text = dica
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 226
	d.add_theme_color_override("font_color", Tema.APAGADO)
	d.add_theme_font_size_override("font_size", 13)
	vb.add_child(d)
	raiz.add_child(vb)
	ctx_boxes[m] = vb
	return vb


# Barra de baixo: nome do modo e os atalhos dele.
func build_status_bar(ui: Control) -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := Tema.caixa(Color(0.04, 0.04, 0.05, 0.85), Color(0, 0, 0, 0), 0, 12)
	st.border_width_top = 1
	st.border_color = Tema.BORDA
	bar.add_theme_stylebox_override("panel", st)
	ui.add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	bar.add_child(hb)
	mode_label = Tema.titulo("", Tema.AMBAR)
	mode_label.custom_minimum_size.x = 90
	hb.add_child(mode_label)
	help = Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help.add_theme_color_override("font_color", Tema.APAGADO)
	help.add_theme_font_size_override("font_size", 13)
	hb.add_child(help)


func _toggle_grid() -> void:
	grid.visible = not grid.visible
	grid_btn.set_pressed_no_signal(grid.visible)


func ask_file(file_mode: FileDialog.FileMode, filters: PackedStringArray, cb: Callable) -> void:
	file_dialog.file_mode = file_mode
	file_dialog.filters = filters
	file_callback = cb
	file_dialog.popup_centered_ratio(0.7)


func is_compat() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


func auto_preset() -> String:
	var t := RenderingServer.get_video_adapter_type()
	if t == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU or t == RenderingDevice.DEVICE_TYPE_CPU:
		return "Baixo"
	# ponytail: palpite pelo nome da placa; o usuário ajusta no menu
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	for w in ["intel", "uhd", "vega", "llvmpipe", "radeon graphics", "mali", "adreno"]:
		if w in gpu:
			return "Baixo"
	return "Médio"


func load_config() -> void:
	var cf := ConfigFile.new()
	if cf.load(CFG_PATH) != OK:
		var p := auto_preset()
		cfg = PRESETS[p].duplicate()
		cfg.preset = p
	else:
		cfg = PRESETS["Médio"].duplicate()
		cfg.preset = "Médio"
		for k in cfg.keys():
			cfg[k] = cf.get_value("qualidade", k, cfg[k])
	apply_config()
	save_config()


func save_config() -> void:
	if testing:   # teste não grava por cima das configurações de quem usa
		return
	var cf := ConfigFile.new()
	for k in cfg:
		cf.set_value("qualidade", k, cfg[k])
	cf.save(CFG_PATH)


func apply_config() -> void:
	var compat := is_compat()
	for vp: Viewport in [get_viewport(), jog]:
		vp.scaling_3d_scale = cfg.escala
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if (not compat and cfg.escala < 1.0) else Viewport.SCALING_3D_MODE_BILINEAR
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if cfg.aa == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
		vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][cfg.aa]
	sun.shadow_enabled = cfg.sombras > 0
	RenderingServer.directional_shadow_atlas_set_size(4096 if cfg.sombras == 2 else 1024, true)
	camera.far = cfg.distancia
	jog.cam.far = cfg.distancia
	Engine.max_fps = cfg.fps
	# ponytail: no OpenGL a segunda janela custa caro (~110 FPS numa RTX 4050, contra 165+ só com uma);
	# se pesar em PC fraco, desenhar os jogadores num SubViewport e só copiar a imagem pra janela
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if cfg.vsync else DisplayServer.VSYNC_DISABLED)
	# a janela dos jogadores nunca espera o monitor: escondida no Wayland (outra área de trabalho,
	# atrás de outra janela) essa espera dura ~1 s por quadro e trava o programa inteiro em 1 FPS.
	# O limite de FPS da config continua valendo pra ela.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED, jog.get_window_id())
	visual.apply(cfg, compat)
	apply_deco()


func set_cfg(key: String, v) -> void:
	if key == "preset":
		if PRESETS.has(v):
			cfg.merge(PRESETS[v], true)
		cfg.preset = v
		rebuild_settings.call_deferred()
	else:
		cfg[key] = v
		cfg.preset = "Personalizado"
		preset_opt.select(3)
	apply_config()
	save_config()


# override.cfg troca o renderizador na próxima vez que o programa abrir
func override_path() -> String:
	var dir := ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	return dir.path_join("override.cfg")


func set_light_mode(on: bool) -> void:
	if on:
		var f := FileAccess.open(override_path(), FileAccess.WRITE)
		f.store_string('[rendering]\n\nrenderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"\n')
	else:
		DirAccess.remove_absolute(override_path())
	show_msg("Vale quando abrir o programa de novo.")


# Configurações: janela no meio da tela, com o resto escurecido (clicar fora fecha).
func build_settings(ui: Control) -> void:
	settings_panel = ColorRect.new()
	settings_panel.color = Color(0, 0, 0, 0.55)
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_panel.visible = false
	settings_panel.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			settings_panel.hide())
	ui.add_child(settings_panel)
	var janela := PanelContainer.new()
	janela.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	janela.grow_horizontal = Control.GROW_DIRECTION_BOTH
	janela.grow_vertical = Control.GROW_DIRECTION_BOTH
	janela.custom_minimum_size.x = 470
	janela.add_theme_stylebox_override("panel", Tema.caixa(Color(0.06, 0.06, 0.07, 0.99), Tema.BORDA, 14, 22))
	settings_panel.add_child(janela)
	settings_vb = VBoxContainer.new()
	settings_vb.add_theme_constant_override("separation", 10)
	janela.add_child(settings_vb)


func toggle_settings() -> void:
	if settings_panel.visible:
		settings_panel.hide()
		return
	if mode == Mode.FLY:
		set_mode(Mode.PIECES)
	rebuild_settings()
	settings_panel.show()


func rebuild_settings() -> void:
	var vb := settings_vb
	for c in vb.get_children():
		vb.remove_child(c)
		c.queue_free()
	var compat := is_compat()
	var topo := HBoxContainer.new()
	topo.add_child(Tema.icone(Tema.I_CONFIG, 18, Tema.SANGUE))
	var t := Label.new()
	t.text = "Configurações"
	t.add_theme_font_override("font", Tema.fonte_forte)
	t.add_theme_font_size_override("font_size", 20)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(t)
	var fechar := Tema.botao(Tema.I_FECHAR, "", "Fechar (Esc)")
	fechar.pressed.connect(settings_panel.hide)
	topo.add_child(fechar)
	vb.add_child(topo)

	vb.add_child(Tema.titulo("Geral"))
	preset_opt = opt_row(vb, "Qualidade", "preset", ["Baixo", "Médio", "Alto", "Personalizado"], ["Baixo", "Médio", "Alto", "Personalizado"])
	var row := HBoxContainer.new()
	var val := Label.new()
	val.text = "%d%%" % int(cfg.escala * 100)
	val.custom_minimum_size.x = 44
	var s := HSlider.new()
	s.min_value = 0.5
	s.max_value = 1.0
	s.step = 0.05
	s.value = cfg.escala
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(func(v: float) -> void:
		val.text = "%d%%" % int(v * 100)
		set_cfg("escala", v))
	row.add_child(s)
	row.add_child(val)
	add_row(vb, "Resolução interna", row)
	opt_row(vb, "Limite de FPS", "fps", ["30", "60", "144", "Sem limite"], [30, 60, 144, 0])
	check_row(vb, "VSync", cfg.vsync, func(on: bool) -> void: set_cfg("vsync", on))

	vb.add_child(Tema.titulo("Imagem"))
	opt_row(vb, "Sombras", "sombras", ["Desligadas", "Baixa", "Alta"], [0, 1, 2])
	opt_row(vb, "Antisserrilhado", "aa", ["Desligado", "FXAA", "MSAA 2×", "MSAA 4×"], [0, 1, 2, 3])
	opt_row(vb, "Textura máxima*", "textura", ["512", "1024", "2048", "Original"], [512, 1024, 2048, 0])
	opt_row(vb, "Distância de visão", "distancia", ["100 m", "150 m", "300 m", "600 m"], [100.0, 150.0, 300.0, 600.0])
	check_row(vb, "SSAO e brilho", cfg.efeitos, func(on: bool) -> void: set_cfg("efeitos", on), compat)
	check_row(vb, "Modo leve (OpenGL)**", FileAccess.file_exists(override_path()), set_light_mode)

	vb.add_child(HSeparator.new())
	var info := Label.new()
	info.text = "* vale ao carregar o cenário  ·  ** vale ao reabrir\n%s  ·  %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_method()]
	info.add_theme_color_override("font_color", Tema.APAGADO)
	info.add_theme_font_size_override("font_size", 12)
	vb.add_child(info)


func add_row(vb: VBoxContainer, label: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 190
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	vb.add_child(row)


func opt_row(vb: VBoxContainer, label: String, key: String, names: Array, values: Array) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	for n in names:
		o.add_item(n)
	o.select(maxi(0, values.find(cfg[key])))
	o.item_selected.connect(func(i: int) -> void: set_cfg(key, values[i]))
	add_row(vb, label, o)
	return o


func check_row(vb: VBoxContainer, label: String, on: bool, cb: Callable, disabled := false) -> void:
	var c := CheckButton.new()
	c.button_pressed = on
	c.disabled = disabled
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(cb)
	var hb := HBoxContainer.new()
	hb.add_child(c)
	add_row(vb, label, hb)
