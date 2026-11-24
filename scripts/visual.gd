extends Node
## Visual de cinema: climas, névoa de guerra volumétrica, luzes, efeitos e pós da câmera dos jogadores.

const LAYER_PROP := 4     # colisão pra clicar em luzes e efeitos

const CLIMAS := {
	"Noite com neblina": {"ceu": Color(0.015, 0.03, 0.045), "horiz": Color(0.1, 0.15, 0.18), "amb": Color(0.35, 0.47, 0.56), "amb_e": 0.5,
		"sol": Color(0.55, 0.68, 0.9), "sol_e": 0.6, "sol_ang": Vector3(-35, 30, 0), "nevoa": 0.035, "nevoa_cor": Color(0.45, 0.58, 0.63),
		"brilho": 0.9, "satur": 0.8, "contraste": 1.1, "vinheta": 0.55, "grao": 0.05},
	"Floresta sombria": {"ceu": Color(0.03, 0.045, 0.035), "horiz": Color(0.12, 0.16, 0.12), "amb": Color(0.4, 0.5, 0.4), "amb_e": 0.5,
		"sol": Color(0.75, 0.85, 0.7), "sol_e": 0.65, "sol_ang": Vector3(-50, -20, 0), "nevoa": 0.05, "nevoa_cor": Color(0.5, 0.6, 0.5),
		"brilho": 0.7, "satur": 0.75, "contraste": 1.12, "vinheta": 0.5, "grao": 0.05},
	"Entardecer com neblina": {"ceu": Color(0.3, 0.36, 0.36), "horiz": Color(0.48, 0.55, 0.52), "amb": Color(0.6, 0.68, 0.66), "amb_e": 0.65,
		"sol": Color(0.85, 0.9, 0.88), "sol_e": 0.45, "sol_ang": Vector3(-40, 60, 0), "nevoa": 0.045, "nevoa_cor": Color(0.55, 0.62, 0.6),
		"brilho": 0.35, "satur": 0.62, "contraste": 1.08, "vinheta": 0.45, "grao": 0.04},
	"Dia nublado": {"ceu": Color(0.5, 0.56, 0.62), "horiz": Color(0.75, 0.78, 0.8), "amb": Color(0.72, 0.75, 0.8), "amb_e": 0.8,
		"sol": Color(1, 0.96, 0.9), "sol_e": 0.9, "sol_ang": Vector3(-55, -35, 0), "nevoa": 0.008, "nevoa_cor": Color(0.8, 0.83, 0.86),
		"brilho": 0.25, "satur": 0.95, "contraste": 1.02, "vinheta": 0.25, "grao": 0.02},
	"Noite na cidade": {"ceu": Color(0.01, 0.012, 0.02), "horiz": Color(0.06, 0.05, 0.06), "amb": Color(0.4, 0.42, 0.5), "amb_e": 0.22,
		"sol": Color(0.5, 0.6, 0.85), "sol_e": 0.12, "sol_ang": Vector3(-60, 25, 0), "nevoa": 0.012, "nevoa_cor": Color(0.35, 0.33, 0.35),
		"brilho": 0.8, "satur": 0.9, "contraste": 1.12, "vinheta": 0.5, "grao": 0.05},
	"Sem efeitos": {"ceu": Color(0.12, 0.13, 0.16), "horiz": Color(0.16, 0.17, 0.2), "amb": Color(0.6, 0.62, 0.7), "amb_e": 0.6,
		"sol": Color(1, 1, 1), "sol_e": 1.0, "sol_ang": Vector3(-55, -35, 0), "nevoa": 0.0, "nevoa_cor": Color(0.5, 0.5, 0.5),
		"brilho": 0.0, "satur": 1.0, "contraste": 1.0, "vinheta": 0.0, "grao": 0.0},
}

# cor, energia, alcance, quanto treme, altura da luz
const LUZES := {
	"Tocha": [Color(1, 0.55, 0.2), 2.5, 8.0, 0.25, 1.15],
	"Lanterna": [Color(1, 0.68, 0.32), 2.0, 7.0, 0.1, 1.5],
	"Fogueira": [Color(1, 0.45, 0.15), 4.0, 12.0, 0.3, 0.6],
	"Luz mágica": [Color(0.35, 0.6, 1.0), 3.0, 9.0, 0.12, 1.2],
	"Luz quente": [Color(1, 0.62, 0.3), 1.6, 6.0, 0.08, 0.0],   # só a luz: pra lampião, vela e janela do cenário
	# luzes de cenário sem sombra (iluminam a sala inteira; com sombra, dezenas delas pesariam demais)
	"Lâmpada": [Color(1, 0.66, 0.36), 1.4, 5.5, 0.03, 0.0],
	"Luz fria": [Color(0.82, 0.9, 1.0), 1.5, 6.5, 0.0, 0.0],
	"Luz roxa": [Color(0.6, 0.35, 1.0), 1.8, 6.5, 0.0, 0.0],
	"Luz vermelha": [Color(1, 0.16, 0.1), 2.6, 7.0, 0.15, 0.0],
	"Poste": [Color(1, 0.62, 0.3), 5.0, 14.0, 0.0, 0.0],
	"Luz azul": [Color(0.45, 0.65, 1.0), 1.6, 6.5, 0.0, 0.0],
	"Luz verde": [Color(0.35, 1.0, 0.5), 1.4, 6.0, 0.02, 0.0],
	"Vela": [Color(1, 0.58, 0.25), 0.9, 3.5, 0.2, 0.0],
}
const SEM_SOMBRA := ["Lâmpada", "Luz fria", "Luz roxa", "Luz vermelha", "Poste", "Luz azul", "Luz verde", "Vela"]
const CATALOGO := ["Tocha", "Lanterna", "Fogueira", "Luz mágica", "Luz quente", "Lâmpada", "Luz fria", "Luz roxa", "Luz vermelha", "Poste", "Luz azul", "Luz verde", "Vela", "Fogo", "Brasas", "Fumaça", "Neblina rasteira", "Vaga-lumes", "Sigilos", "Impacto"]

var main: Node3D
var clima := "Noite com neblina"
var cinema := false        # preset Alto no Vulkan: volumétrico, SSAO, profundidade de campo
var env_player := Environment.new()
var env_master := Environment.new()
var props: Node3D
var flicker: Array = []    # [luz, energia base, tremor, semente]
var noise := FastNoiseLite.new()
var t := 0.0
var vignette: ColorRect
var grain: ColorRect
var cam_attr := CameraAttributesPractical.new()
var focus_d := -1.0
var dot_tex: GradientTexture2D
var glyph_tex: ImageTexture


func setup(m: Node3D) -> void:
	main = m
	props = Node3D.new()
	m.add_child(props)
	main.camera.environment = env_master
	main.jog.cam.environment = env_player
	main.jog.cam.attributes = cam_attr
	noise.frequency = 1.0


	# pós da câmera dos jogadores: vinheta e granulação, por cima da imagem
	var layer := CanvasLayer.new()
	main.jog.add_child(layer)
	vignette = overlay(layer, """shader_type canvas_item;
uniform float amount = 0.5;
void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.25, 1.0);
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(0.3, 0.85, length(d)) * amount);
}""")
	grain = overlay(layer, """shader_type canvas_item;
uniform float amount = 0.05;
void fragment() {
	float g = fract(sin(dot(floor(FRAGCOORD.xy) + fract(TIME * 7.0) * 113.0, vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(vec3(step(0.5, g)), abs(g - 0.5) * 2.0 * amount);
}""")

	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	dot_tex = GradientTexture2D.new()
	dot_tex.gradient = grad
	dot_tex.fill = GradientTexture2D.FILL_RADIAL
	dot_tex.fill_from = Vector2(0.5, 0.5)
	dot_tex.fill_to = Vector2(1.0, 0.5)
	dot_tex.width = 64
	dot_tex.height = 64
	glyph_tex = make_glyphs()


func overlay(layer: CanvasLayer, code: String) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = code
	r.material = sm
	layer.add_child(r)
	return r


# ---------- clima ----------

func apply(cfg: Dictionary, compat: bool) -> void:
	cinema = cfg.efeitos and not compat
	set_clima(clima)
	for p in props.get_children():
		for gp: GPUParticles3D in p.find_children("*", "GPUParticles3D", true, false):
			gp.amount_ratio = 1.0 if cfg.efeitos else 0.5
		for l: OmniLight3D in p.find_children("*", "OmniLight3D", true, false):
			l.shadow_enabled = cinema and not p.get_meta("tipo") in SEM_SOMBRA


func set_clima(nome: String) -> void:
	clima = nome
	var c: Dictionary = CLIMAS[nome]
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = c.ceu
	sky_mat.sky_horizon_color = c.horiz
	sky_mat.ground_horizon_color = c.horiz
	sky_mat.ground_bottom_color = c.ceu
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	for e: Environment in [env_player, env_master]:
		e.background_mode = Environment.BG_SKY
		e.sky = sky
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = c.amb
		e.tonemap_mode = Environment.TONE_MAPPER_AGX
		e.glow_enabled = c.brilho > 0.0
		e.glow_intensity = c.brilho
		e.glow_bloom = 0.05
		e.glow_hdr_threshold = 1.1
		e.adjustment_enabled = true
		e.adjustment_contrast = c.contraste
		e.adjustment_saturation = c.satur
		e.ssao_enabled = cinema
	env_player.ambient_light_energy = c.amb_e
	# volumétrico só nos jogadores (é ele que desenha a névoa de guerra); sem ele, névoa simples
	env_player.volumetric_fog_enabled = cinema
	env_player.volumetric_fog_density = c.nevoa
	env_player.volumetric_fog_albedo = c.nevoa_cor
	env_player.volumetric_fog_anisotropy = 0.4
	env_player.volumetric_fog_length = 80.0
	env_player.volumetric_fog_ambient_inject = 0.5
	env_player.fog_enabled = not cinema and c.nevoa > 0.0
	env_player.fog_light_color = c.nevoa_cor * 0.6
	env_player.fog_density = c.nevoa * 0.5
	# o mestre enxerga mais claro e sem neblina, pra trabalhar
	env_master.ambient_light_energy = maxf(c.amb_e * 2.0, 0.6)
	env_master.volumetric_fog_enabled = false
	env_master.fog_enabled = false
	main.sun.light_color = c.sol
	main.sun.light_energy = c.sol_e
	main.sun.rotation_degrees = c.sol_ang
	vignette.material.set_shader_parameter("amount", c.vinheta)
	grain.material.set_shader_parameter("amount", c.grao)
	vignette.visible = c.vinheta > 0.0
	grain.visible = c.grao > 0.0
	cam_attr.dof_blur_far_enabled = cinema
	focus_d = -1.0


# ---------- luzes e efeitos ----------

func add_prop(tipo: String, pos: Vector3) -> Node3D:
	var p := StaticBody3D.new()
	p.collision_layer = LAYER_PROP
	p.collision_mask = 0
	p.position = pos
	p.set_meta("tipo", tipo)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.45
	cs.shape = sh
	cs.position.y = 0.5
	p.add_child(cs)
	# ícone pro mestre achar efeitos sem corpo (neblina, vaga-lumes)
	var icon := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	icon.mesh = sm
	icon.material_override = emissive(Color(1, 0.85, 0.3), 2.0)
	icon.position.y = 0.5
	icon.layers = main.VIS_MASTER
	icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(icon)
	var full: bool = main.cfg.efeitos
	match tipo:
		"Tocha":
			p.add_child(stick(1.1, 0.04))
			p.add_child(particles("Fogo", 0.45, Vector3(0, 1.15, 0)))
		"Lanterna":
			p.add_child(stick(1.5, 0.05))
			var box := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.2, 0.26, 0.2)
			box.mesh = bm
			box.material_override = emissive(Color(1, 0.6, 0.25), 6.0)
			box.position.y = 1.5
			p.add_child(box)
		"Fogueira":
			for i in 3:
				var log := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.08
				cm.bottom_radius = 0.08
				cm.height = 0.9
				log.mesh = cm
				log.material_override = main.material_for(Color(0.25, 0.15, 0.08))
				log.position.y = 0.1
				log.rotation = Vector3(PI / 2, i * TAU / 3, 0)
				p.add_child(log)
			p.add_child(particles("Fogo", 1.2, Vector3(0, 0.15, 0)))
			p.add_child(particles("Brasas", 1.0, Vector3(0, 0.4, 0)))
			p.add_child(particles("Fumaça", 1.0, Vector3(0, 1.2, 0)))
		"Luz mágica":
			var orb := MeshInstance3D.new()
			var om := SphereMesh.new()
			om.radius = 0.12
			om.height = 0.24
			orb.mesh = om
			orb.material_override = emissive(Color(0.4, 0.7, 1.0), 8.0)
			orb.position.y = 1.2
			p.add_child(orb)
			p.add_child(particles("Brilhos", 1.0, Vector3(0, 1.2, 0)))
		"Impacto":
			p.add_child(particles("Impacto", 1.0, Vector3(0, 0.3, 0)))
		"Luz quente", "Lâmpada", "Luz fria", "Luz roxa", "Luz vermelha", "Poste", "Luz azul", "Luz verde", "Vela":
			icon.position.y = 0.0
			cs.position.y = 0.0
		_:
			p.add_child(particles(tipo, 1.0, Vector3.ZERO))
	if LUZES.has(tipo) or tipo == "Impacto":
		var d: Array = LUZES.get(tipo, [Color(1, 0.6, 0.2), 8.0, 10.0, 0.0, 0.8])
		var l := OmniLight3D.new()
		l.light_color = d[0]
		l.light_energy = d[1]
		l.omni_range = d[2]
		l.omni_attenuation = 1.4
		l.position.y = d[4]
		l.shadow_enabled = cinema and not tipo in SEM_SOMBRA
		l.light_volumetric_fog_energy = 2.0
		p.add_child(l)
		if tipo == "Impacto":
			create_tween().tween_property(l, "light_energy", 0.0, 0.5)
		else:
			flicker.append([l, d[1], d[3], randf() * 100.0])
	for gp: GPUParticles3D in p.find_children("*", "GPUParticles3D", true, false):
		gp.amount_ratio = 1.0 if full else 0.5
	props.add_child(p)
	if tipo == "Impacto":
		# efeito de uma vez: some sozinho e não entra na mesa salva
		p.set_meta("passageiro", true)
		main.jog.shake()
		get_tree().create_timer(1.5).timeout.connect(remove_prop.bind(p))
	return p


func remove_prop(p: Node3D) -> void:
	if not is_instance_valid(p) or p.get_parent() != props:
		return
	flicker = flicker.filter(func(f: Array) -> bool: return is_instance_valid(f[0]) and not p.is_ancestor_of(f[0]))
	props.remove_child(p)
	p.queue_free()


func clear_props() -> void:
	for p in props.get_children():
		remove_prop(p)


func props_list() -> Array:
	var out := []
	for p: Node3D in props.get_children():
		if not p.has_meta("passageiro"):
			out.append({"tipo": p.get_meta("tipo"), "x": p.position.x, "y": p.position.y, "z": p.position.z})
	return out


func animating() -> bool:
	return props.get_child_count() > 0


func stick(h: float, r: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r * 1.3
	cm.height = h
	mi.mesh = cm
	mi.material_override = main.material_for(Color(0.22, 0.14, 0.08))
	mi.position.y = h / 2
	return mi


func emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func ramp(points: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(points.map(func(p: Array) -> float: return p[0]))
	g.colors = PackedColorArray(points.map(func(p: Array) -> Color: return p[1]))
	var tex := GradientTexture1D.new()
	tex.gradient = g
	return tex


func curve(a: float, b: float) -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0, a))
	c.add_point(Vector2(1, b))
	var tex := CurveTexture.new()
	tex.curve = c
	return tex


# Catálogo de partículas. s = escala do efeito.
func particles(kind: String, s: float, at: Vector3) -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.billboard_keep_scale = true   # sem isso o tamanho de cada partícula é ignorado
	dm.vertex_color_use_as_albedo = true
	dm.albedo_texture = dot_tex
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6) * s
	quad.material = dm
	gp.draw_pass_1 = quad
	gp.process_material = pm
	gp.position = at
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.direction = Vector3.UP
	match kind:
		"Fogo":
			gp.amount = 48
			gp.lifetime = 0.9
			pm.emission_sphere_radius = 0.25 * s
			pm.spread = 12.0
			pm.initial_velocity_min = 1.0 * s
			pm.initial_velocity_max = 1.8 * s
			pm.gravity = Vector3(0, 0.5, 0)
			pm.damping_min = 0.5
			pm.damping_max = 1.0
			pm.scale_min = 0.6
			pm.scale_max = 1.0
			pm.scale_curve = curve(1.0, 0.2)
			pm.color_ramp = ramp([[0.0, Color(1.6, 1.2, 0.6, 1)], [0.3, Color(1.4, 0.55, 0.12, 0.9)], [0.7, Color(0.8, 0.15, 0.04, 0.5)], [1.0, Color(0.2, 0.05, 0.02, 0)]])
		"Brasas":
			gp.amount = 24
			gp.lifetime = 2.5
			pm.emission_sphere_radius = 0.4 * s
			pm.spread = 25.0
			pm.initial_velocity_min = 0.6
			pm.initial_velocity_max = 1.6
			pm.gravity = Vector3(0, 0.3, 0)
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 0.6
			pm.scale_min = 0.07
			pm.scale_max = 0.14
			pm.color_ramp = ramp([[0.0, Color(1.3, 0.7, 0.25, 1)], [0.7, Color(1.0, 0.35, 0.1, 0.8)], [1.0, Color(0.8, 0.2, 0.05, 0)]])
		"Fumaça":
			gp.amount = 16
			gp.lifetime = 4.0
			pm.emission_sphere_radius = 0.3 * s
			pm.spread = 15.0
			pm.initial_velocity_min = 0.4
			pm.initial_velocity_max = 0.8
			pm.gravity = Vector3.ZERO
			pm.scale_min = 1.6
			pm.scale_max = 2.6
			pm.scale_curve = curve(0.5, 1.5)
			pm.angle_min = -180.0
			pm.angle_max = 180.0
			pm.angular_velocity_min = -20.0
			pm.angular_velocity_max = 20.0
			dm.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
			dm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
			pm.color_ramp = ramp([[0.0, Color(0.5, 0.5, 0.52, 0)], [0.25, Color(0.5, 0.5, 0.52, 0.16)], [1.0, Color(0.55, 0.55, 0.57, 0)]])
		"Neblina rasteira":
			gp.amount = 18
			gp.lifetime = 9.0
			gp.preprocess = 9.0
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			pm.emission_box_extents = Vector3(3, 0.1, 3) * s
			pm.direction = Vector3(1, 0, 0)
			pm.spread = 180.0
			pm.initial_velocity_min = 0.05
			pm.initial_velocity_max = 0.2
			pm.gravity = Vector3.ZERO
			pm.scale_min = 5.0
			pm.scale_max = 8.0
			gp.position.y += 0.4
			dm.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
			dm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
			pm.color_ramp = ramp([[0.0, Color(0.7, 0.75, 0.8, 0)], [0.5, Color(0.7, 0.75, 0.8, 0.18)], [1.0, Color(0.7, 0.75, 0.8, 0)]])
		"Vaga-lumes", "Brilhos":
			var magic := kind == "Brilhos"
			gp.amount = 16 if magic else 24
			gp.lifetime = 3.0 if magic else 6.0
			gp.preprocess = gp.lifetime
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			pm.emission_box_extents = Vector3(0.6, 0.6, 0.6) if magic else Vector3(4, 1.2, 4) * s
			if not magic:
				gp.position.y += 1.0
			pm.spread = 180.0
			pm.initial_velocity_min = 0.1
			pm.initial_velocity_max = 0.3
			pm.gravity = Vector3(0, 0.2 if magic else 0.0, 0)
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 1.0
			pm.scale_min = 0.12 if magic else 0.14
			pm.scale_max = 0.2 if magic else 0.22
			var c := Color(0.6, 1.1, 1.8) if magic else Color(1.0, 1.4, 0.4)
			pm.color_ramp = ramp([[0.0, Color(c, 0)], [0.25, Color(c, 1)], [0.45, Color(c, 0.2)], [0.65, Color(c, 1)], [1.0, Color(c, 0)]])
		"Sigilos":
			gp.amount = 10
			gp.lifetime = 5.0
			gp.preprocess = 5.0
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			pm.emission_box_extents = Vector3(1.6, 0.6, 1.6) * s
			gp.position.y += 0.9
			pm.spread = 10.0
			pm.initial_velocity_min = 0.15
			pm.initial_velocity_max = 0.3
			pm.gravity = Vector3.ZERO
			pm.scale_min = 0.9
			pm.scale_max = 1.5
			pm.angle_min = -180.0
			pm.angle_max = 180.0
			pm.angular_velocity_min = -15.0
			pm.angular_velocity_max = 15.0
			pm.anim_offset_min = 0.0
			pm.anim_offset_max = 1.0
			dm.albedo_texture = glyph_tex
			dm.particles_anim_h_frames = 4
			dm.particles_anim_v_frames = 1
			var c := Color(0.7, 1.4, 2.2)
			pm.color_ramp = ramp([[0.0, Color(c, 0)], [0.2, Color(c, 1)], [0.75, Color(c, 0.8)], [1.0, Color(c, 0)]])
		"Impacto":
			gp.amount = 70
			gp.lifetime = 0.9
			gp.one_shot = true
			gp.explosiveness = 1.0
			pm.emission_sphere_radius = 0.2
			pm.spread = 180.0
			pm.initial_velocity_min = 3.0
			pm.initial_velocity_max = 7.0
			pm.gravity = Vector3(0, -9, 0)
			pm.scale_min = 0.08
			pm.scale_max = 0.18
			pm.color_ramp = ramp([[0.0, Color(2.2, 1.8, 0.9, 1)], [0.4, Color(1.8, 0.7, 0.15, 1)], [1.0, Color(0.6, 0.15, 0.05, 0)]])
	return gp


# Quatro sigilos desenhados por código (círculos e traços), lado a lado.
func make_glyphs() -> ImageTexture:
	var img := Image.create(256, 64, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 4:
		var c := Vector2(32 + 64 * i, 32)
		ring_px(img, c, 27.0, 1.6)
		ring_px(img, c, 19.0, 1.0)
		var pts: Array[Vector2] = []
		for k in 6:
			pts.append(c + Vector2.from_angle(rng.randf() * TAU) * 19.0)
		for k in 4:
			line_px(img, pts[k], pts[(k + 2) % 6], 1.4)
		for k in 3:
			var ang := rng.randf() * TAU
			line_px(img, c + Vector2.from_angle(ang) * 21.0, c + Vector2.from_angle(ang) * 30.0, 1.2)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func line_px(img: Image, a: Vector2, b: Vector2, w: float) -> void:
	var n := ceili(a.distance_to(b) * 2.0)
	for i in n + 1:
		dot_px(img, a.lerp(b, float(i) / n), w)


func ring_px(img: Image, c: Vector2, r: float, w: float) -> void:
	var n := ceili(TAU * r * 2.0)
	for i in n:
		dot_px(img, c + Vector2.from_angle(TAU * i / n) * r, w)


func dot_px(img: Image, p: Vector2, w: float) -> void:
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var q := Vector2i(p) + Vector2i(dx, dy)
			if q.x < 0 or q.y < 0 or q.x >= img.get_width() or q.y >= img.get_height():
				continue
			var a := clampf(w + 0.5 - p.distance_to(Vector2(q) + Vector2(0.5, 0.5)), 0.0, 1.0)
			if a > img.get_pixelv(q).a:
				img.set_pixelv(q, Color(1, 1, 1, a))


# ---------- a cada quadro ----------

func _process(delta: float) -> void:
	t += delta
	for f: Array in flicker:
		var l: OmniLight3D = f[0]
		l.light_energy = f[1] * (1.0 + f[2] * noise.get_noise_1d(t * 6.0 + f[3]))
	if cinema:
		# foca no que está no centro da câmera dos jogadores
		var cam: Camera3D = main.jog.cam
		var from := cam.global_position
		var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_basis.z * 300.0, main.LAYER_MAP | main.LAYER_PIECE)
		var hit := main.get_world_3d().direct_space_state.intersect_ray(q)
		var d := 40.0 if hit.is_empty() else from.distance_to(hit.position)
		if absf(d - focus_d) > 0.5:   # só mexe se mudou, pra não acordar o modo econômico
			focus_d = d
			cam_attr.dof_blur_far_distance = d + 6.0
			cam_attr.dof_blur_far_transition = 12.0
			cam_attr.dof_blur_amount = 0.03
