extends "res://pecas.gd"
## Painel da câmera dos jogadores: prévia, planos, seguir.


# Painel da câmera dos jogadores: prévia ao vivo + controles.
func build_camera_panel(ui: Control) -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1
	panel.anchor_right = 1
	panel.offset_left = -322
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN   # conteúdo largo cresce pra esquerda, não sai da tela
	panel.offset_right = -10
	panel.offset_top = 62
	ui.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	var topo := HBoxContainer.new()
	topo.add_child(Tema.icone(Tema.I_CAMERA, 14, Tema.APAGADO))
	var t := Tema.titulo("Câmera dos jogadores")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(t)
	var ao_vivo := Label.new()   # "● AO VIVO" quando a janela dos jogadores está aberta
	ao_vivo.add_theme_font_override("font", Tema.fonte_titulo)
	ao_vivo.add_theme_font_size_override("font_size", 11)
	topo.add_child(ao_vivo)
	var dobra := Button.new()
	dobra.flat = true
	dobra.focus_mode = Control.FOCUS_NONE
	dobra.text = "▾"
	dobra.tooltip_text = "Recolher / abrir"
	dobra.pressed.connect(func() -> void:
		body.visible = not body.visible
		dobra.text = "▾" if body.visible else "▸")
	topo.add_child(dobra)
	vb.add_child(topo)
	vb.add_child(body)
	vb = body

	var moldura := PanelContainer.new()
	moldura.add_theme_stylebox_override("panel", Tema.caixa(Color.BLACK, Tema.BORDA, 6, 1))
	preview = TextureRect.new()
	preview.texture = jog.get_texture()
	preview.custom_minimum_size = Vector2(296, 166)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	moldura.add_child(preview)
	vb.add_child(moldura)
	var vivo := func() -> void:
		# janela dos jogadores fechada não tem imagem: a prévia esvazia em vez de desenhar textura morta
		preview.texture = jog.get_texture() if jog.visible else null
		ao_vivo.text = "● AO VIVO" if jog.visible else "FECHADA"
		ao_vivo.add_theme_color_override("font_color", Tema.SANGUE.lightened(0.15) if jog.visible else Tema.APAGADO)
	jog.visibility_changed.connect(vivo)
	vivo.call()

	var row := HBoxContainer.new()
	vb.add_child(row)
	var aqui := Tema.botao(Tema.I_TRAZER, "Trazer aqui", "Leva a câmera dos jogadores até a sua vista (C)")
	aqui.pressed.connect(func() -> void: jog.go_to(camera.global_transform))
	aqui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(aqui)
	follow_btn = Tema.botao(Tema.I_SEGUIR, "Seguir", "A câmera acompanha a peça selecionada")
	follow_btn.toggle_mode = true
	follow_btn.pressed.connect(_toggle_follow)
	row.add_child(follow_btn)
	var tremer := Tema.botao(Tema.I_TREMER, "", "Tremer: susto, explosão")
	tremer.pressed.connect(jog.shake)
	row.add_child(tremer)
	var smooth := CheckBox.new()
	smooth.text = "Transição suave (desligado = corte seco)"
	smooth.button_pressed = true
	smooth.focus_mode = Control.FOCUS_NONE
	smooth.add_theme_font_size_override("font_size", 13)
	smooth.toggled.connect(func(on: bool) -> void: jog.smooth = on)
	vb.add_child(smooth)

	vb.add_child(Tema.titulo("Planos"))
	var shots_row := HBoxContainer.new()
	shots_row.add_theme_constant_override("separation", 4)
	vb.add_child(shots_row)
	for n in range(1, 10):
		var b := add_btn(shots_row, str(n), shot_key.bind(n, false))
		b.custom_minimum_size = Vector2(29, 30)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = "Plano %d · Ctrl+%d grava a sua vista aqui" % [n, n]
		shot_btns[n] = b
	var tip := Label.new()
	tip.text = "Ctrl+1…9 grava a sua vista · 1…9 leva a câmera"
	tip.add_theme_color_override("font_color", Tema.APAGADO)
	tip.add_theme_font_size_override("font_size", 12)
	vb.add_child(tip)
	var janela := Tema.botao(Tema.I_JANELA, "Janela dos jogadores", "Mostrar ou esconder a janela que os jogadores veem (F11 nela = tela cheia)")
	janela.pressed.connect(func() -> void: jog.visible = not jog.visible)
	vb.add_child(janela)
	refresh_shot_btns()


func _toggle_follow() -> void:
	jog.toggle_follow(null if selected.is_empty() else selected.keys()[0])
	follow_btn.set_pressed_no_signal(jog.follow != null)


func shot_key(n: int, save: bool) -> void:
	if save:
		jog.save_shot(n, camera.global_transform)
		refresh_shot_btns()
		show_msg("Plano %d gravado" % n)
	elif not jog.recall_shot(n):
		show_msg("Plano %d vazio — Ctrl+%d grava a sua vista" % [n, n])
	follow_btn.set_pressed_no_signal(jog.follow != null)


func refresh_shot_btns() -> void:
	for n: int in shot_btns:
		# plano gravado fica âmbar; vazio fica apagado
		shot_btns[n].add_theme_color_override("font_color", Tema.AMBAR if jog.shots.has(n) else Tema.APAGADO * Color(1, 1, 1, 0.55))
