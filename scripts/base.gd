extends Node3D
## Base da mesa 3D. O programa é uma corrente de arquivos, um por assunto, cada um herdando o anterior:
## base.gd → cenario.gd → pecas.gd → camera.gd → mesa.gd → interface.gd → testes.gd → main.gd
## Assim todos enxergam o mesmo estado sem passar referência pra lá e pra cá.


const Jogadores = preload("res://scripts/jogadores.gd")
const Visual = preload("res://scripts/visual.gd")
const MenuRedondo = preload("res://scripts/menu_redondo.gd")
const Tema = preload("res://scripts/tema.gd")
const TOKEN_SHADER = preload("res://scripts/token.gdshader")
const TOKEN_ALTURA := 1.8
const CELL := 1.5
const WALK_SPEED := 3.0
const CFG_PATH := "user://config.cfg"
const LAYER_MAP := 1
const LAYER_PIECE := 2
# camadas de visão: o mestre vê WORLD+MASTER, os jogadores WORLD+PLAYER
const VIS_WORLD := 1
const VIS_MASTER := 2
const VIS_PLAYER := 4
const PRESETS := {
	"Baixo": {"escala": 0.7, "sombras": 0, "aa": 0, "textura": 1024, "vegetacao": 0.25, "distancia": 150.0, "efeitos": false, "fps": 60, "vsync": true},
	"Médio": {"escala": 1.0, "sombras": 1, "aa": 1, "textura": 2048, "vegetacao": 0.6, "distancia": 300.0, "efeitos": false, "fps": 60, "vsync": true},
	"Alto": {"escala": 1.0, "sombras": 2, "aa": 3, "textura": 0, "vegetacao": 1.0, "distancia": 600.0, "efeitos": true, "fps": 144, "vsync": true},
}

enum Mode { FLY, PIECES, NEW, SCENE }

const HELP := {
	Mode.FLY: "VOAR — WASD anda · Espaço sobe · Shift desce · segure Ctrl pra ir rápido · rodinha muda a velocidade · Tab volta pras peças",
	Mode.PIECES: "PEÇAS — clique seleciona · clique numa porta (ou na geladeira do bar) abre e fecha · Shift+clique soma · arraste no vazio pra pegar várias · arraste a peça pra mover · segure o botão direito e solte pra mandar andar · B troca a variação · Q/E gira · Delete apaga · Ctrl+Z desfaz · Tab voa",
	Mode.NEW: "NOVA PEÇA — clique no chão coloca a peça com o nome, personagem e cor do painel · B troca a variação · Tab voa",
	Mode.SCENE: "AMBIENTAR — escolha no painel e clique no chão · arraste pra mover · botão direito apaga · Tab voa",
}

var mode := Mode.PIECES
var cfg := {}
var selected := {}        # peça -> true
var walking := {}         # peça -> destino
var walk_speed := {}      # peça -> velocidade atual (acelera e freia)
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var scenario_path := ""
var map_aabb := AABB(Vector3(-15, 0, -15), Vector3(30, 0, 30))
var testing := false

var yaw := 0.0
var pitch := 0.0
var fly_speed := 8.0
var fps_timer := 0.0
var time := 0.0
var cam_goal := Transform3D()    # a câmera do mestre desliza até aqui
var orbit_pivot := Vector3.ZERO

var press_pos := Vector2.ZERO
var press_piece: Node3D = null
var dragging := false
var drag_start := {}      # peça -> posição quando o arrasto começou
var grab_start := Vector3.ZERO
var rect_selecting := false
var aiming := false
var hovered: Node3D = null
var markers: Array[MeshInstance3D] = []
var aim_line: MeshInstance3D
var aim_label: Label

var camera: Camera3D
var sun: DirectionalLight3D
var visual: Visual
var prop_opt: OptionButton
var clima_opt: OptionButton
var press_prop: Node3D = null
var scenario: Node3D
var deco: Array[MultiMeshInstance3D] = []   # mato e galhos do cenário, desenhados em lote
var pieces: Node3D
var grid: MeshInstance3D
var jog: Jogadores
var preview: TextureRect
var follow_btn: Button
var shot_btns := {}
var rect: ColorRect
var help: Label
var msg: Label
var fps_label: Label
var name_edit: LineEdit
var color_btn: ColorPickerButton
var mode_btns := {}
var settings_panel: Control          # fundo escurecido + janela de configurações
var settings_vb: VBoxContainer
var ctx_panel: PanelContainer        # opções da ferramenta escolhida (nome da peça, catálogo…)
var ctx_boxes := {}                  # modo -> caixa de opções
var grid_btn: Button
var msg_panel: PanelContainer
var mode_label: Label
var preset_opt: OptionButton
var file_dialog: FileDialog
var file_callback: Callable

var piece_mesh := CylinderMesh.new()
var piece_shape := CylinderShape3D.new()
var ring_mesh := TorusMesh.new()
var ring_mat := StandardMaterial3D.new()
var outline_mat := StandardMaterial3D.new()
var marker_mesh := CylinderMesh.new()
var marker_mat := StandardMaterial3D.new()
var materials := {}       # cor html -> material
var personagens := {}     # pasta -> {variação: [frente, costas]}
var token_cache := {}     # malhas e materiais dos personagens, reaproveitados entre peças
var standee_shape := CylinderShape3D.new()
var perso_opt: OptionButton
var menu: MenuRedondo
var menu_before := {}


func mouse_hit(pos: Vector2, mask: int) -> Dictionary:
	var from := camera.project_ray_origin(pos)
	var q := PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(pos) * 2000.0, mask)
	return get_world_3d().direct_space_state.intersect_ray(q)


## Porta do cenário: o nome diz como abre (base.py, abre()): "porta_a<graus>p<cm>d<cm>_".
## Gira <graus> em volta do ponto <p> cm no x do modelo e/ou desliza <d> cm; o clique seguinte volta.
func toggle_door(pos: Vector2) -> bool:
	var hit := mouse_hit(pos, LAYER_MAP)
	return not hit.is_empty() and hit.collider.get_parent() is Node3D and move_door(hit.collider.get_parent())


func move_door(mi: Node3D) -> bool:
	var m := RegEx.create_from_string("porta_a(-?\\d+)p(-?\\d+)d(-?\\d+)_").search(mi.name)
	if m == null or mi.has_meta("porta_tween"):
		return false
	var sinal := -1.0 if mi.get_meta("porta_mexida", false) else 1.0
	mi.set_meta("porta_mexida", sinal > 0)
	var base := mi.global_transform
	var ang := deg_to_rad(float(m.get_string(1))) * sinal
	var piv := base * Vector3(float(m.get_string(2)) / 100.0, 0, 0)
	var desliza := base.basis.x.normalized() * float(m.get_string(3)) / 100.0 * sinal
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	mi.set_meta("porta_tween", tw)
	tw.tween_method(func(t: float) -> void:
		var r := Basis(base.basis.y.normalized(), ang * t)
		mi.global_transform = Transform3D(r * base.basis, piv + r * (base.origin - piv) + desliza * t), 0.0, 1.0, 0.7)
	tw.finished.connect(func() -> void: mi.remove_meta("porta_tween"))
	return true


func ray_down(x: float, z: float, from_y: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, from_y - 1000.0, z), LAYER_MAP)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return NAN if hit.is_empty() else hit.position.y


func ground_at(x: float, z: float, from_y: float) -> float:
	var y := ray_down(x, z, from_y)
	return from_y - 1.5 if is_nan(y) else y


func on_ground(v: Vector3) -> Vector3:
	return Vector3(v.x, ground_at(v.x, v.z, v.y + 1.5), v.z)


func piece_at(pos: Vector2) -> Node3D:
	var hit := mouse_hit(pos, LAYER_MAP | LAYER_PIECE)
	if hit.is_empty() or hit.collider.get_parent() != pieces:
		return null
	return hit.collider


func material_for(color: Color) -> StandardMaterial3D:
	var key := color.to_html(false)
	if not materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.6
		materials[key] = m
	return materials[key]


# Peças e objetos: o que o desfazer guarda e o que vai pro arquivo da mesa.
func state_dict() -> Dictionary:
	var pecas := []
	for p: Node3D in pieces.get_children():
		var giro: float = p.get_node("Visual").rotation.y
		pecas.append({"nome": p.get_meta("nome"), "cor": p.get_meta("cor"), "x": p.position.x, "y": p.position.y, "z": p.position.z,
			"perso": p.get_meta("perso"), "var": p.get_meta("var", ""), "giro": giro})
	return {"pecas": pecas, "objetos": visual.props_list()}


# ponytail: guarda a mesa inteira a cada ação (até 100); serve até milhares de peças
func push_undo(before := {}) -> void:
	undo_stack.push_back(before if not before.is_empty() else state_dict())
	if undo_stack.size() > 100:
		undo_stack.pop_front()
	redo_stack.clear()


func add_btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# Aviso que aparece no alto da tela e some sozinho.
func show_msg(text: String) -> void:
	print(text)
	msg.text = text
	msg_panel.show()
	msg_panel.modulate.a = 1.0
	get_tree().create_timer(3.5).timeout.connect(func() -> void:
		if msg.text == text:
			var tw := create_tween()
			tw.tween_property(msg_panel, "modulate:a", 0.0, 0.4)
			tw.tween_callback(func() -> void:
				if msg.text == text:
					msg_panel.hide()))
