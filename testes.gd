extends "res://interface.gd"
## Testes automáticos (--foto, --fotos, --carga).


func check(label: String, cond: bool) -> bool:
	print(("OK     " if cond else "FALHA  ") + label)
	return cond


func shot(path: String) -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if path != "":
		img.save_png(path)
	return img


# maior diferença de cor num quadrado 5×5 entre duas imagens
func pixel_diff(a: Image, b: Image, at: Vector2) -> float:
	var best := 0.0
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var q := Vector2i(at) + Vector2i(dx, dy)
			var ca := a.get_pixelv(q)
			var cb := b.get_pixelv(q)
			best = maxf(best, maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b))))
	return best


# maior brilho num quadrado 5×5 (linha de 1 px pode cair meio pixel ao lado)
func brightest(img: Image, at: Vector2) -> float:
	var best := 0.0
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			best = maxf(best, img.get_pixelv(Vector2i(at) + Vector2i(dx, dy)).get_luminance())
	return best


func run_photo_test(args: PackedStringArray) -> void:
	testing = true
	jog.unresizable = true   # no Hyprland, janela de tamanho fixo flutua e não é encolhida no meio do teste
	var ok := true
	set_cfg("preset", "Médio")
	set_clima("Sem efeitos")   # sem granulação, pra comparar pixels
	await load_scenario(args[args.find("--foto") + 1])
	var out := ProjectSettings.globalize_path("res://provas")
	DirAccess.make_dir_recursive_absolute(out)

	var a := add_piece("A", Color(0.9, 0.2, 0.2), on_ground(Vector3(-3, 5, -1.5)))
	var b := add_piece("B", Color(0.2, 0.4, 0.9), on_ground(Vector3(-3, 5, 1.5)))
	var c := add_piece("C", Color(0.2, 0.8, 0.3), on_ground(Vector3(-6, 5, 0)))
	ok = check("peças nascem no chão (y=%.2f)" % a.position.y, absf(a.position.y) < 0.05) and ok
	var gap := a.position.distance_to(b.position)
	var c_start := c.position
	set_selected(a, true)
	set_selected(b, true)
	order_walk_to(Vector3(9, 2, 0.75))
	Engine.time_scale = 4.0
	var t := 0.0
	while not walking.is_empty() and t < 30.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	Engine.time_scale = 1.0
	ok = check("A e B chegaram (%.1f s de jogo)" % t, walking.is_empty()) and ok
	ok = check("A em cima da plataforma (y=%.2f, esperado 2)" % a.position.y, absf(a.position.y - 2.0) < 0.05) and ok
	ok = check("B em cima da plataforma (y=%.2f, esperado 2)" % b.position.y, absf(b.position.y - 2.0) < 0.05) and ok
	var dist := a.position.distance_to(b.position)
	ok = check("formação mantida (%.2f m → %.2f m)" % [gap, dist], absf(dist - gap) < 0.01) and ok
	ok = check("C ficou parada", c.position.is_equal_approx(c_start)) and ok
	clear_selection()

	# mesma vista nas duas câmeras, pra comparar pixel a pixel
	jog.smooth = false
	jog.go_to(camera.global_transform)
	jog.size = get_window().size
	set_selected(a, true)
	grid.visible = true
	var pg := camera.unproject_position(Vector3(3 * CELL, ground_at(3 * CELL, 6 * CELL, 5.0) + 0.03, 6 * CELL))
	var img_m: Image = await shot(out + "/foto_mestre.png")
	var img_j := jog.get_texture().get_image()
	img_j.save_png(out + "/foto_jogadores.png")
	var gm := brightest(img_m, pg)
	var gj := brightest(img_j, pg)
	ok = check("grade só no mestre (brilho %.2f mestre × %.2f jogadores)" % [gm, gj], gm - gj > 0.05) and ok
	ok = check("prévia mostra a janela dos jogadores", preview.texture.get_size() == Vector2(jog.size)) and ok
	jog.hide()
	ok = check("janela dos jogadores fechada esvazia a prévia", preview.texture == null) and ok
	jog.show()
	ok = check("reabrir a janela volta a prévia", preview.texture != null) and ok
	clear_selection()

	# câmera dos jogadores: "Câmera aqui" e plano 3, com transição suave
	jog.smooth = true
	var start := camera.global_transform
	set_view(start.translated(Vector3(-6, 3, 4)).looking_at(Vector3.ZERO))
	jog.go_to(camera.global_transform)
	await get_tree().create_timer(jog.TRANSITION + 0.3).timeout
	var err := jog.cam.global_position.distance_to(camera.global_position)
	ok = check("Câmera aqui chega na vista do mestre (erro %.3f m)" % err, err < 0.01) and ok
	shot_key(3, true)
	set_view(start)
	jog.go_to(start)
	await get_tree().create_timer(jog.TRANSITION + 0.3).timeout
	shot_key(3, false)
	await get_tree().create_timer(jog.TRANSITION + 0.3).timeout
	err = jog.cam.global_position.distance_to(jog.shots[3].origin)
	ok = check("plano 3 leva a câmera de volta (erro %.3f m)" % err, err < 0.01) and ok

	# --- fase B: sensação ---
	var d := add_piece("D", Color(0.9, 0.7, 0.2), on_ground(Vector3(3, 5, 9)))
	await get_tree().physics_frame
	var drop := Vector3(6.2, 0, 9.4)
	press_piece = d
	start_drag(false)
	await get_tree().create_timer(0.25).timeout
	var vis_y: float = d.get_node("Visual").position.y
	ok = check("peça pega dá o pulinho (sobe %.2f m)" % vis_y, vis_y > 0.4) and ok
	drag_to(camera.unproject_position(drop))
	ok = check("disco mostra onde vai cair", markers[0].visible and markers[0].position.distance_to(on_ground(d.position)) < 0.05) and ok
	end_drag()
	await get_tree().create_timer(0.5).timeout
	var want := on_ground(drop)
	ok = check("solta onde o mouse soltou, sem grade (%.2f, %.2f)" % [d.position.x, d.position.z], d.position.distance_to(want) < 0.1 and absf(d.get_node("Visual").position.y) < 0.01) and ok
	ok = check("disco some ao soltar", not markers[0].visible) and ok
	press_piece = null
	dragging = false

	ok = check("metros em português (%s, %s)" % [meters(9.0), meters(10.5)], meters(9.0) == "9" and meters(10.5) == "10,5") and ok

	set_hover(d)
	var outl: MeshInstance3D = d.get_node("Visual/Contorno")
	ok = check("mouse em cima acende o contorno, só pro mestre", outl.visible and outl.layers == VIS_MASTER) and ok
	clear_selection()
	set_selected(a, true)
	set_selected(b, true)
	aiming = true
	update_aim(camera.unproject_position(Vector3(4.5, 0, 9)))
	ok = check("mira mostra '%s'" % aim_label.text, aim_label.visible and aim_label.text.ends_with(" m")) and ok
	await shot(out + "/foto_caminho.png")
	end_aim()
	set_hover(null)
	clear_selection()

	var s0 := JSON.stringify(state_dict())
	push_undo()
	var e := add_piece("E", Color.WHITE, on_ground(Vector3(-1, 5, 6)))
	set_selected(d, true)
	delete_selected()
	push_undo()
	set_selected(e, true)
	order_walk_to(e.position + Vector3(3, 0, 0))
	while not walking.is_empty():
		await get_tree().process_frame
	press_piece = e
	start_drag(false)
	drag_to(camera.unproject_position(Vector3(0, 0, 12)))
	end_drag()
	await get_tree().create_timer(0.5).timeout
	press_piece = null
	dragging = false
	clear_selection()
	var s5 := JSON.stringify(state_dict())
	for k in 5:
		undo()
	ok = check("desfazer 5 ações volta ao começo", JSON.stringify(state_dict()) == s0) and ok
	for k in 5:
		redo()
	ok = check("refazer 5 ações volta ao fim", JSON.stringify(state_dict()) == s5) and ok

	orbit_pivot = Vector3.ZERO
	var r0 := cam_goal.origin.distance_to(orbit_pivot)
	orbit(Vector2(120, 40))
	var r1 := cam_goal.origin.distance_to(orbit_pivot)
	ok = check("girar mantém a distância do ponto (%.3f → %.3f)" % [r0, r1], absf(r0 - r1) < 0.001) and ok
	await get_tree().create_timer(0.8).timeout
	ok = check("câmera do mestre desliza até o alvo", not cam_moving()) and ok
	set_view(start)

	var before := JSON.stringify(table_dict(), "", true, true)
	save_table(out + "/mesa_teste.json")
	await load_table(out + "/mesa_teste.json")
	ok = check("mesa salva e aberta igual", JSON.stringify(table_dict(), "", true, true) == before) and ok

	# --- fase C: visual de cinema ---
	set_cfg("preset", "Alto")
	ok = check("Alto liga o modo cinema (%s)" % RenderingServer.get_current_rendering_method(), visual.cinema) and ok
	var spots := {"Fogueira": Vector3(4.5, 0, 5.5), "Tocha": Vector3(1, 0, 3.5), "Lanterna": Vector3(7, 0, -6.5),
		"Sigilos": Vector3(9, 0, 0), "Luz mágica": Vector3(11, 0, 2), "Neblina rasteira": Vector3(3, 0, 7), "Vaga-lumes": Vector3(9, 0, 9)}
	for tipo: String in spots:
		var sp: Vector3 = spots[tipo]
		visual.add_prop(tipo, Vector3(sp.x, ground_at(sp.x, sp.z, 10.0), sp.z))
	ok = check("7 luzes/efeitos na mesa", visual.props_list().size() == 7) and ok
	push_undo()
	visual.add_prop("Tocha", Vector3(0, 0, 9))
	undo()
	ok = check("desfazer tira a tocha nova", visual.props_list().size() == 7) and ok
	ok = check("luzes e efeitos vão pro arquivo da mesa", table_dict().objetos.size() == 7) and ok

	# fotos de cada clima, de um ângulo de cinema
	jog.smooth = false
	jog.go_to(Transform3D(Basis(), Vector3(15, 4.5, 13)).looking_at(Vector3(4, 1, -1)))
	var i := 0
	for nome: String in Visual.CLIMAS:
		set_clima(nome)
		await get_tree().create_timer(1.2).timeout   # partículas aquecem, volumétrico assenta
		await RenderingServer.frame_post_draw
		jog.get_texture().get_image().save_png(out + "/foto_clima_%d.png" % i)
		i += 1
	set_clima("Noite com neblina")
	set_view(Transform3D(Basis(), Vector3(15, 4.5, 13)).looking_at(Vector3(4, 1, -1)).translated(Vector3(0, 6, 4)))
	await get_tree().create_timer(0.8).timeout
	await shot(out + "/foto_mestre_noite.png")

	if personagens.has("arqueiro"):
		ok = await test_characters(out) and ok
	else:
		print("sem a pasta personagens/arqueiro: pulei os testes de personagem")

	print("TUDO OK" if ok else "FALHOU")
	get_tree().quit(0 if ok else 1)


# Personagens de papel (precisa de personagens/arqueiro com arco, capuz e lanterna; a pasta não vai pro GitHub).
func test_characters(out: String) -> bool:
	var ok := true
	# ---- personagens de papel ----
	set_clima("Dia nublado")
	visual.grain.visible = false
	visual.vignette.visible = false
	var tk_t_pos := on_ground(Vector3(3.5, 5, -5.0))
	var tk := add_piece("Arqueiro", Color(0.3, 0.5, 0.3), tk_t_pos, "arqueiro", "", 0.0)   # olha pro -Z
	var tk_quad := (tk.get_node("Visual/Corpo") as MeshInstance3D).mesh as QuadMesh
	ok = check("personagem tem 1,8 m e as variações da pasta (%s)" % ", ".join(personagens.arqueiro.keys()), tk_quad != null and is_equal_approx(tk_quad.size.y, TOKEN_ALTURA) and personagens.arqueiro.size() == 3) and ok
	jog.smooth = false
	var tk_foco := tk_t_pos + Vector3.UP * 1.0
	jog.go_to(Transform3D(Basis(), tk_foco + Vector3(0, 0.4, -3.5)).looking_at(tk_foco))
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var tk_img_f := jog.get_texture().get_image()
	tk_img_f.save_png(out + "/foto_personagem_frente.png")
	var tk_p_torso := jog.cam.unproject_position(tk_t_pos + Vector3.UP * 0.55)   # calça clara na frente, capa preta atrás
	jog.go_to(Transform3D(Basis(), tk_foco + Vector3(0, 0.4, 3.5)).looking_at(tk_foco))
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var tk_img_b := jog.get_texture().get_image()
	tk_img_b.save_png(out + "/foto_personagem_costas.png")
	ok = check("de trás aparecem as costas (muda %.2f)" % pixel_diff(tk_img_f, tk_img_b, tk_p_torso), pixel_diff(tk_img_f, tk_img_b, tk_p_torso) > 0.1) and ok

	menu.abrir(self, [tk], personagens.arqueiro, Vector2(400, 300))
	menu_before = state_dict()
	menu.mostrar("capuz")
	ok = check("menu: passar o mouse mostra a variação", tk.get_meta("var") == "capuz") and ok
	menu.voltar()
	ok = check("menu: tirar o mouse volta pra de antes", tk.get_meta("var") == "arco") and ok
	var tk_n_undo := undo_stack.size()
	menu.escolher("lanterna")
	ok = check("menu: clicar escolhe, fecha e entra no desfazer", tk.get_meta("var") == "lanterna" and not menu.visible and undo_stack.size() == tk_n_undo + 1) and ok
	undo()
	var tk_by_name := func(n: String) -> Node3D:
		for q: Node3D in pieces.get_children():
			if q.get_meta("nome") == n:
				return q
		return null
	ok = check("Ctrl+Z volta a variação", tk_by_name.call("Arqueiro").get_meta("var") == "arco") and ok
	redo()
	tk = tk_by_name.call("Arqueiro")
	tk.get_node("Visual").rotation.y = 1.0
	apply_state(JSON.parse_string(JSON.stringify(state_dict())))
	tk = tk_by_name.call("Arqueiro")
	ok = check("mesa salva guarda personagem, variação e giro", tk.get_meta("perso") == "arqueiro" and tk.get_meta("var") == "lanterna" and is_equal_approx(tk.get_node("Visual").rotation.y, 1.0)) and ok

	clear_selection()
	set_selected(tk, true)
	order_walk_to(tk.position + Vector3(3, 0, 0))
	await get_tree().create_timer(2.0).timeout
	var tk_giro: float = tk.get_node("Visual").rotation.y
	ok = check("andando, vira pra onde vai (tk_giro %.2f, esperado %.2f)" % [tk_giro, -PI / 2], absf(angle_difference(tk_giro, -PI / 2)) < 0.15) and ok
	clear_selection()

	# tk_fila pra olhar: as três variações de frente e uma de costas, à noite
	for q in pieces.get_children():
		pieces.remove_child(q)
		q.queue_free()
	var tk_fila := ["arco", "capuz", "lanterna", "capuz"]
	for k in tk_fila.size():
		var tk_pos := on_ground(Vector3(-4.0 + k * 1.3, 5, 4.0))
		add_piece("P%d" % k, Color(0.5, 0.35, 0.2), tk_pos, "arqueiro", tk_fila[k], PI if k == 3 else 0.0)
	set_clima("Noite com neblina")
	visual.add_prop("Lanterna", Vector3(-1.5, 0, 2.0))
	jog.go_to(Transform3D(Basis(), Vector3(-2.0, 1.6, -0.5)).looking_at(Vector3(-2.0, 1.0, 4.0)))
	set_view(Transform3D(Basis(), Vector3(-2.0, 6.0, -3.0)).looking_at(Vector3(-2.0, 0.5, 4.0)))
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	jog.get_texture().get_image().save_png(out + "/foto_personagens_noite.png")
	set_hover(pieces.get_child(1))
	await shot(out + "/foto_personagens_mestre.png")
	set_hover(null)
	menu.abrir(self, [pieces.get_child(0)], personagens.arqueiro, get_viewport().get_visible_rect().size / 2)
	await shot(out + "/foto_menu.png")
	ok = check("menu abre com uma opção por variação", menu.get_child_count() == 1 + personagens.arqueiro.size()) and ok
	menu.fechar()
	return ok


# Fotos de uma mesa pronta pra conferir o cenário: -- --mesa x.json --fotos [--preset Alto]
func run_table_photos(args: PackedStringArray) -> void:
	testing = true
	set_cfg("preset", args[args.find("--preset") + 1] if "--preset" in args else "Alto")
	if "--ver-oclusores" in args:
		jog.debug_draw = Viewport.DEBUG_DRAW_OCCLUDERS
	if "--sem-oclusao" in args:   # pra comparar quanto os oclusores economizam
		get_viewport().use_occlusion_culling = false
		jog.use_occlusion_culling = false
	var t0 := Time.get_ticks_msec()
	await load_table(args[args.find("--mesa") + 1])
	print("Abriu a mesa em %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if "--clima" in args:
		set_clima(args[args.find("--clima") + 1])
	var out := ProjectSettings.globalize_path("res://provas")
	DirAccess.make_dir_recursive_absolute(out)
	await get_tree().create_timer(6.0).timeout
	print("FPS com as duas janelas: %d  (%s, %d desenhos)" % [Engine.get_frames_per_second(), cfg.preset, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	print("Memória de vídeo: %d MB (texturas %d MB)  ·  triângulos no quadro: %d mil" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) >> 20, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) >> 20, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000])
	await shot(out + "/mesa_mestre.png")
	# a interface em cada ferramenta, pra conferir os painéis
	for m: Mode in [Mode.NEW, Mode.SCENE]:
		set_mode(m)
		await shot(out + "/ui_%s.png" % NOME_MODO[m].to_lower().replace(" ", "_"))
	set_mode(Mode.PIECES)
	toggle_settings()
	await shot(out + "/ui_config.png")
	toggle_settings()
	jog.smooth = false
	var vistas := {
		"entrada": [Vector3(2.5, 1.7, 14.0), Vector3(-0.5, 3.0, -10.0)],
		"cemiterio": [Vector3(4.5, 1.8, -4.0), Vector3(9.0, 0.8, -10.0)],
		"cabana": [Vector3(-5.0, 1.8, 1.5), Vector3(-12.5, 1.5, 6.5)],
		"pedras": [Vector3(4.0, 2.5, 3.0), Vector3(10.0, 0.8, 8.0)],
		"capela_dentro": [Vector3(0.0, 1.8, -8.0), Vector3(0.0, 1.2, -17.0)],
		"alto": [Vector3(-14.0, 14.0, 14.0), Vector3(2.0, 0.0, -6.0)],
		"longe": [Vector3(-30.0, 28.0, 38.0), Vector3(0.0, 0.0, -6.0)],
		"copas": [Vector3(0.0, 14.0, 30.0), Vector3(-14.0, 11.0, 38.0)],
		"capela": [Vector3(-7.0, 4.5, 3.0), Vector3(0.0, 2.0, -9.0)],
		"varanda": [Vector3(-9.5, 1.7, 13.5), Vector3(-12.5, 1.3, 8.0)],
		"mata": [Vector3(-11.0, 2.5, -4.0), Vector3(-17.5, 0.5, -10.0)],
	}
	if not jog.shots.is_empty():   # mesa com planos gravados: fotografa os planos dela
		vistas = {}
		for n: int in jog.shots:
			vistas["plano%d" % n] = jog.shots[n]
	for nome: String in vistas:
		var v: Variant = vistas[nome]
		jog.go_to(v if v is Transform3D else Transform3D(Basis(), v[0]).looking_at(v[1]))
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		jog.get_texture().get_image().save_png(out + "/mesa_%s.png" % nome)
		var rid := jog.get_viewport_rid()
		print("  %s: %d mil triângulos na câmera dos jogadores (+ %d mil nas sombras)" % [nome,
			RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME) / 1000,
			RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME) / 1000])
	var ok_portas := await test_doors(out)
	print("FOTOS OK" if ok_portas else "FOTOS OK, MAS PORTA FALHOU")
	get_tree().quit()


# Cada porta do cenário: abre com move_door, confere que girou/deslizou o que o nome diz em volta da
# dobradiça, fecha e confere que voltou. A geladeira e a porta do escritório vão por clique de verdade na tela.
func test_doors(out: String) -> bool:
	var re := RegEx.create_from_string("porta_a(-?\\d+)p(-?\\d+)d(-?\\d+)_")
	var portas: Array[MeshInstance3D] = []
	for mi in scenario.find_children("*", "MeshInstance3D", true, false):
		if re.search(mi.name):
			portas.append(mi)
	var ruins := 0
	for mi in portas:
		var g := re.search(mi.name)
		var a := float(g.get_string(1))
		var p := Vector3(float(g.get_string(2)) / 100.0, 0, 0)
		var d := float(g.get_string(3)) / 100.0
		var base := mi.global_transform
		move_door(mi)
		await get_tree().create_timer(0.9).timeout
		var t := mi.global_transform
		var giro := rad_to_deg(base.basis.x.normalized().angle_to(t.basis.x.normalized()))
		var anda := (t * p - base * p).length()
		var certo := absf(giro - absf(a)) < 1.0 and absf(anda - absf(d)) < 0.01
		move_door(mi)
		await get_tree().create_timer(0.9).timeout
		var volta := (mi.global_transform.origin - base.origin).length() < 0.01 and mi.global_transform.basis.x.is_equal_approx(base.basis.x)
		if not (certo and volta):
			ruins += 1
			print("  PORTA RUIM %s: girou %.1f° (quer %.0f), andou %.2f m (quer %.2f), voltou: %s" % [mi.name, giro, absf(a), anda, absf(d), volta])
	print("PORTAS: %d de %d abrem e fecham certo" % [portas.size() - ruins, portas.size()])
	# clique de verdade: câmera do mestre olhando a peça, clique no meio dela na tela
	for nome in ["geladeira_amarela", "porta_madeira_000"]:
		var alvo: MeshInstance3D = null
		for mi in portas:
			if nome in mi.name:
				alvo = mi
		if alvo == null:
			print("  CLIQUE: não achei %s" % nome)
			ruins += 1
			continue
		var c := alvo.global_transform * alvo.get_aabb().get_center()
		var frente := alvo.global_transform.basis.z.normalized()   # o -y do Blender vira +z: frente da geladeira, corredor da porta
		var de := c + frente * 1.5 + Vector3.UP * 0.3
		set_mode(Mode.PIECES)   # no modo voar a câmera segue o mouse e o clique não abre porta
		camera.global_transform = Transform3D(Basis(), de).looking_at(c)
		cam_goal = camera.global_transform
		await get_tree().create_timer(0.3).timeout
		var antes := alvo.global_transform
		await shot(out + "/porta_%s_antes.png" % nome)
		var clicou := toggle_door(camera.unproject_position(c))
		await get_tree().create_timer(0.9).timeout
		await shot(out + "/porta_%s_depois.png" % nome)
		var mexeu := not alvo.global_transform.is_equal_approx(antes)
		print("  CLIQUE em %s: %s" % [nome, "abriu/fechou" if clicou and mexeu else "NADA ACONTECEU"])
		if not (clicou and mexeu):
			ruins += 1
	return ruins == 0


func measure() -> Array:
	await get_tree().create_timer(2.0).timeout
	return [Engine.get_frames_per_second(), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))]


func run_load_test(args: PackedStringArray) -> void:
	testing = true
	var i := args.find("--preset")
	if i >= 0:
		set_cfg("preset", args[i + 1])
	cfg.fps = 0
	cfg.vsync = "--vsync" in args
	apply_config()
	i = args.find("--carga")
	if i + 1 < args.size() and args[i + 1].ends_with(".glb"):
		await load_scenario(args[i + 1])
	else:
		await make_default_ground()
	var empty: Array = await measure()
	for k in 300:
		var pos := Vector3(map_aabb.position.x + (k % 20) * CELL, map_aabb.end.y + 1, map_aabb.position.z + (k / 20) * CELL)
		add_piece("P%d" % k, Color.from_hsv(k / 300.0, 0.7, 0.9), on_ground(pos))
	var full: Array = await measure()
	set_clima("Noite com neblina")
	var kinds := ["Fogueira", "Tocha", "Tocha", "Lanterna", "Luz mágica", "Sigilos", "Vaga-lumes", "Fumaça", "Neblina rasteira", "Brasas"]
	for k in 20:
		var px := map_aabb.position.x + 2.0 + (k % 5) * 6.0
		var pz := map_aabb.position.z + 2.0 + (k / 5) * 7.0
		visual.add_prop(kinds[k % kinds.size()], Vector3(px, ground_at(px, pz, map_aabb.end.y + 1), pz))
	var fx: Array = await measure()
	print("renderizador: %s | placa: %s | preset: %s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(), cfg.preset])
	print("vazio:                 %4d FPS  %4d desenhos" % empty)
	print("+ 300 peças:           %4d FPS  %4d desenhos" % full)
	print("+ clima noite e 20 luzes/efeitos: %4d FPS  %4d desenhos" % fx)
	print("(as duas janelas abertas: mestre %s, jogadores %s)" % [get_window().size, jog.size])
	get_tree().quit()
