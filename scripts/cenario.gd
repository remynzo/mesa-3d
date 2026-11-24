extends "res://scripts/base.gd"
## Cenário: carregar o .glb, mato em lotes, grade e câmera do mestre.


func make_default_ground() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	pm.material = material_for(Color(0.35, 0.42, 0.3))
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	scenario.add_child(mi)
	mi.create_trimesh_collision()
	await map_ready()


# Cenário dentro do projeto abre pelo que o Godot importou (detalhe menor de longe, textura compactada na
# placa de vídeo). Fora do projeto, lê o arquivo cru, que pesa mais.
# Depois de gerar o .glb de novo: godot --headless --path . --import
func load_scenario(path: String) -> void:
	var scene: Node3D
	var local := ProjectSettings.localize_path(path)
	if local.begins_with("res://") and ResourceLoader.exists(local):
		scene = (load(local) as PackedScene).instantiate()
	else:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(path, state) != OK:
			show_msg("Não consegui abrir " + path.get_file())
			return
		scene = doc.generate_scene(state)
	for c in scenario.get_children():
		scenario.remove_child(c)
		c.queue_free()
	scenario.add_child(scene)
	scenario_path = local if local.begins_with("res://") else path
	var max_tex: int = cfg.textura
	var done := {}
	var lotes := {}   # [malha, pedaço do mapa] -> posições das cópias "deco_*"
	var fixos: Array[MeshInstance3D] = []
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				shrink_textures(mi.mesh.surface_get_material(s), max_tex, done)
		var lote := mi.name.begins_with("lote")
		if mi.name.begins_with("deco") or lote:
			# mato, samambaia, galho: sem colisão, e cópias iguais viram um lote só (uma chamada de desenho)
			# um lote por pedaço de 16 m: lote fora da tela não é desenhado (um lote do mapa todo sempre era)
			var o := mi.global_position
			# "lote_" (cadeira, garrafa, luminária) também vira lote, mas não é desbastado pela qualidade
			lotes.get_or_add([mi.mesh, floori(o.x / 16.0), floori(o.z / 16.0), lote], []).append(mi.global_transform)
			mi.get_parent().remove_child(mi)
			mi.queue_free()
		elif mi.name.begins_with("semcol"):
			fixos.append(mi)   # teto, telhado, prédio vizinho: sem colisão (o clique e as peças chegam no piso), mas esconde o que está atrás
		else:
			mi.create_trimesh_collision()
			fixos.append(mi)
	build_occluders(scene, fixos)
	deco.clear()
	for k: Array in lotes:
		var mesh: Mesh = k[0]
		var ts: Array = lotes[k]
		ts.shuffle()   # assim, mostrando só uma parte (qualidade baixa), o que sobra fica espalhado
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = ts.size()
		for i in ts.size():
			mm.set_instance_transform(i, ts[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if mesh.get_aabb().size.length() < 3.0:
			mmi.visibility_range_end = 150.0   # mato miúdo some só bem longe (a 75 m sumia garrafa e vela na vista do mestre)
		scene.add_child(mmi)
		if not k[3]:
			deco.append(mmi)
	apply_deco()
	await map_ready()
	show_msg("Cenário: " + path.get_file())



# Oclusores: o Godot deixa de desenhar o que está todo escondido atrás deles. Entram as peças fixas grandes
# e simples (paredes, telhados) e uma versão grossa do chão, sempre um pouco abaixo dele (o morro esconde
# a floresta do outro lado). Mato e folhagem recortada não entram: dá pra ver através.
func build_occluders(scene: Node3D, fixos: Array[MeshInstance3D]) -> void:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	var chao: MeshInstance3D = null
	var area := 0.0
	for mi in fixos:
		var a := mi.global_transform * mi.get_aabb()
		if a.size.x * a.size.z > area and not mi.name.begins_with("semcol"):   # prédio vizinho/teto nunca é o chão
			chao = mi
			area = a.size.x * a.size.z
	for mi in fixos:
		var a := mi.global_transform * mi.get_aabb()
		if mi == chao or a.get_longest_axis_size() < 4.0 or not is_solid(mi.mesh):
			continue
		var n := 0
		for s in mi.mesh.get_surface_count():
			n += mi.mesh.surface_get_array_index_len(s)
		if n / 3 > 3000:   # objeto escaneado cheio de detalhe: caro e pequeno demais pra esconder algo
			continue
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var base := verts.size()
			for v: Vector3 in arr[Mesh.ARRAY_VERTEX]:
				verts.append(mi.global_transform * v)
			for i: int in arr[Mesh.ARRAY_INDEX]:
				idx.append(base + i)
	if chao:
		# chão em quadrados de 4 m: cada canto fica na altura do vértice mais baixo dos quadrados em volta,
		# então a versão grossa nunca passa por cima do chão de verdade
		const Q := 4.0
		var a := chao.global_transform * chao.get_aabb()
		var nx := ceili(a.size.x / Q)
		var nz := ceili(a.size.z / Q)
		var baixo := PackedFloat32Array()
		baixo.resize(nx * nz)
		baixo.fill(INF)
		for s in chao.mesh.get_surface_count():
			for v: Vector3 in chao.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var g := chao.global_transform * v
				var k := clampi(int((g.z - a.position.z) / Q), 0, nz - 1) * nx + clampi(int((g.x - a.position.x) / Q), 0, nx - 1)
				baixo[k] = minf(baixo[k], g.y)
		var base := verts.size()
		for j in nz + 1:
			for i in nx + 1:
				var y := INF
				for k in [Vector2i(i - 1, j - 1), Vector2i(i, j - 1), Vector2i(i - 1, j), Vector2i(i, j)]:
					if k.x >= 0 and k.y >= 0 and k.x < nx and k.y < nz:
						y = minf(y, baixo[k.y * nx + k.x])
				verts.append(Vector3(a.position.x + i * Q, y - 0.3 if y < INF else a.position.y - 50.0, a.position.z + j * Q))
		for j in nz:
			for i in nx:
				var q := base + j * (nx + 1) + i
				idx.append_array([q, q + 1, q + nx + 2, q, q + nx + 2, q + nx + 1])
	var occ := ArrayOccluder3D.new()
	occ.set_arrays(verts, idx)
	var oi := OccluderInstance3D.new()
	oi.occluder = occ
	scene.add_child(oi)
	oi.global_transform = Transform3D.IDENTITY


func is_solid(mesh: Mesh) -> bool:
	for s in mesh.get_surface_count():
		var m := mesh.surface_get_material(s) as BaseMaterial3D
		if m and m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return false
	return true


# Reduz as texturas maiores que max_size (o que mais pesa em PC fraco).
func shrink_textures(mat: Material, max_size: int, done: Dictionary) -> void:
	var bm := mat as BaseMaterial3D
	if bm == null:
		return
	if bm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		# folhagem recortada: de longe a textura reduzida tem agulha meio-transparente e o corte em 0,5
		# deixava a copa vazada. Corte mais baixo e, com MSAA, borda suave (alpha to coverage)
		bm.alpha_scissor_threshold = 0.3
		bm.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE_AND_TO_ONE
		bm.alpha_antialiasing_edge = 0.3
	for t in BaseMaterial3D.TEXTURE_MAX:
		var tex := bm.get_texture(t)
		if tex == null:
			continue
		if not done.has(tex):
			done[tex] = tex
			if not tex is ImageTexture:
				# ponytail: importada já vem compactada e com mipmap; não reduz pelo preset (já ocupa ~4× menos)
				continue
			var big := maxi(tex.get_width(), tex.get_height())
			var img := tex.get_image()
			var small := max_size > 0 and big > max_size
			if small or not img.has_mipmaps():   # sem mipmap a textura repetida cintila de longe
				if img.is_compressed():
					img.decompress()
				if small:
					var f := float(max_size) / big
					img.resize(maxi(1, int(img.get_width() * f)), maxi(1, int(img.get_height() * f)), Image.INTERPOLATE_LANCZOS)
				img.generate_mipmaps()
				done[tex] = ImageTexture.create_from_image(img)
		bm.set_texture(t, done[tex])


# Quanto mato aparece, conforme a qualidade.
func apply_deco() -> void:
	var dens: float = cfg.get("vegetacao", 1.0)
	for mmi in deco:
		if is_instance_valid(mmi):
			mmi.multimesh.visible_instance_count = ceili(mmi.multimesh.instance_count * dens)
			# ponytail: mato sem sombra; com 20 luzes que fazem sombra ele era desenhado 6× por luz (28 FPS no Alto)
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func map_ready() -> void:
	var first := true
	for mi: MeshInstance3D in scenario.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = mi.global_transform * mi.get_aabb()
		map_aabb = a if first else map_aabb.merge(a)
		first = false
	# as colisões novas só valem depois de um passo de física
	await get_tree().physics_frame
	await get_tree().physics_frame
	build_grid()
	frame_camera()


func frame_camera() -> void:
	var c := map_aabb.get_center()
	var s := minf(maxf(map_aabb.size.x, map_aabb.size.z), 40.0)   # terreno grande: começa olhando o meio, não a floresta toda
	set_view(Transform3D(Basis(), c + Vector3(0, s * 0.55, s * 0.6)).looking_at(c))
	jog.cam.global_transform = camera.global_transform


func set_view(t: Transform3D) -> void:
	camera.global_transform = t
	cam_goal = t


func cam_moving() -> bool:
	return camera.global_position.distance_to(cam_goal.origin) > 0.001 \
		or not camera.global_basis.is_equal_approx(cam_goal.basis)


# Botão do meio: gira a vista em volta do ponto que estava embaixo do mouse.
func orbit(rel: Vector2) -> void:
	var off := cam_goal.origin - orbit_pivot
	var b := cam_goal.basis
	var yaw_rot := Basis(Vector3.UP, -rel.x * 0.005)
	off = yaw_rot * off
	b = yaw_rot * b
	var pitch_rot := Basis(b.x, -rel.y * 0.005)
	var nb := pitch_rot * b
	if -nb.z.y < -0.05 and -nb.z.y > -0.995:   # não passa do zênite nem fica de baixo pra cima
		off = pitch_rot * off
		b = nb
	cam_goal = Transform3D(b.orthonormalized(), orbit_pivot + off)


# Shift + botão do meio: arrasta a vista, na velocidade da distância.
func pan(rel: Vector2) -> void:
	var k := cam_goal.origin.distance_to(orbit_pivot) * 0.0015
	var fwd := Vector3(-cam_goal.basis.z.x, 0, -cam_goal.basis.z.z).normalized()
	var move := (-cam_goal.basis.x * rel.x + fwd * rel.y) * k
	cam_goal.origin += move
	orbit_pivot += move


# Rodinha: aproxima na direção do mouse.
func zoom(pos: Vector2, closer: bool) -> void:
	var hit := mouse_hit(pos, LAYER_MAP)
	var target: Vector3 = hit.position if not hit.is_empty() else cam_goal.origin - cam_goal.basis.z * 10.0
	if closer and cam_goal.origin.distance_to(target) < 2.0:
		return
	cam_goal.origin = cam_goal.origin.lerp(target, 0.15 if closer else -0.18)


# Linhas da grade coladas no terreno (um raio a cada 0,5 m, só ao carregar).
func build_grid() -> void:
	var top := map_aabb.end.y + 1.0
	var x0 := floori(map_aabb.position.x / CELL)
	var x1 := ceili(map_aabb.end.x / CELL)
	var z0 := floori(map_aabb.position.z / CELL)
	var z1 := ceili(map_aabb.end.z / CELL)
	var verts := PackedVector3Array()
	for k in range(z0, z1 + 1):
		drape_line(verts, Vector3(x0 * CELL, 0, k * CELL), Vector3(x1 * CELL, 0, k * CELL), top)
	for k in range(x0, x1 + 1):
		drape_line(verts, Vector3(k * CELL, 0, z0 * CELL), Vector3(k * CELL, 0, z1 * CELL), top)
	grid.mesh = null
	if verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 0.3)
	am.surface_set_material(0, m)
	grid.mesh = am


func drape_line(verts: PackedVector3Array, a: Vector3, b: Vector3, top: float) -> void:
	var n := maxi(1, ceili(a.distance_to(b) / 0.5))
	var prev := Vector3(NAN, NAN, NAN)
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		p.y = ray_down(p.x, p.z, top) + 0.03
		if not is_nan(p.y) and not is_nan(prev.y):
			verts.append(prev)
			verts.append(p)
		prev = p


func set_clima(nome: String) -> void:
	visual.set_clima(nome)
	clima_opt.select(Visual.CLIMAS.keys().find(nome))
