extends Window
## Janela dos jogadores: só a imagem da câmera que o mestre controla.

const TRANSITION := 1.5

var cam: Camera3D
var gizmo: MeshInstance3D
var smooth := true
var shots := {}           # número -> Transform3D
var follow: Node3D = null
var follow_offset := Vector3.ZERO
var shake_t := 0.0
var tween: Tween


func setup(cull_mask: int, gizmo_layer: int) -> void:
	title = "Mesa — Jogadores"
	size = Vector2i(1280, 720)
	use_occlusion_culling = true   # janela nova começa sem; só a principal segue o project.godot
	if DisplayServer.get_screen_count() > 1:
		current_screen = 1
	else:
		position = DisplayServer.window_get_position() + Vector2i(60, 60)
	cam = Camera3D.new()
	cam.cull_mask = cull_mask
	add_child(cam)
	cam.current = true
	gizmo = make_gizmo(gizmo_layer)
	cam.add_child(gizmo)
	close_requested.connect(hide)
	window_input.connect(_on_window_input)


func _on_window_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_F11:
		mode = Window.MODE_WINDOWED if mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN


# Ícone de câmera com o cone de visão, só na tela do mestre.
func make_gizmo(layer: int) -> MeshInstance3D:
	var a := 0.9
	var b := 0.55
	var d := -1.6
	var c := [Vector3(-a, b, d), Vector3(a, b, d), Vector3(a, -b, d), Vector3(-a, -b, d)]
	var v := PackedVector3Array()
	for i in 4:
		v.append_array([Vector3.ZERO, c[i], c[i], c[(i + 1) % 4]])
	v.append_array([Vector3(-0.3, b + 0.05, d), Vector3(0, b + 0.35, d), Vector3(0, b + 0.35, d), Vector3(0.3, b + 0.05, d)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 0.8, 0.2)
	am.surface_set_material(0, m)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.layers = layer
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func go_to(t: Transform3D) -> void:
	follow = null
	if tween:
		tween.kill()
	if not smooth:
		cam.global_transform = t
		return
	tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cam, "global_transform", t, TRANSITION)


func save_shot(n: int, t: Transform3D) -> void:
	shots[n] = t


func recall_shot(n: int) -> bool:
	if not shots.has(n):
		return false
	go_to(shots[n])
	return true


func toggle_follow(p: Node3D) -> void:
	if follow or p == null:
		follow = null
		return
	if tween:
		tween.kill()
	follow = p
	follow_offset = cam.global_position - p.global_position


func shake() -> void:
	shake_t = 0.6


func busy() -> bool:
	return follow != null or shake_t > 0.0 or (tween != null and tween.is_running())


func _process(delta: float) -> void:
	if follow:
		if not is_instance_valid(follow) or not follow.is_inside_tree():
			follow = null
		else:
			var target := follow.global_position + follow_offset
			cam.global_position = cam.global_position.lerp(target, 1.0 - exp(-4.0 * delta))
			cam.look_at(follow.global_position + Vector3.UP * 0.8)
	if shake_t > 0.0:
		shake_t = maxf(0.0, shake_t - delta)
		var s := shake_t * 0.25
		cam.h_offset = randf_range(-s, s)
		cam.v_offset = randf_range(-s, s)


func shots_dict() -> Dictionary:
	var d := {}
	for n: int in shots:
		var t: Transform3D = shots[n]
		d[str(n)] = var_to_str(t)
	return d


func load_shots(d: Dictionary) -> void:
	shots.clear()
	for k: String in d:
		shots[int(k)] = str_to_var(d[k])
