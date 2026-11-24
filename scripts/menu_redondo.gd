extends Control
## Menu redondo (tecla B): as variações do personagem em volta do mouse.
## Passar o mouse em cima já mostra na mesa; clicar escolhe; Esc, B, botão direito ou clicar fora fecha.

const RAIO := 150.0
const LADO := Vector2(90, 130)

var main: Node
var alvos: Array = []
var antes := {}        # peça -> variação quando o menu abriu
var centro := Vector2.ZERO
var raio := RAIO


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	visible = false


func abrir(m: Node, ps: Array, variacoes: Dictionary, pos: Vector2) -> void:
	main = m
	alvos = ps
	antes.clear()
	for p: Node in ps:
		antes[p] = p.get_meta("var")
	for c in get_children():
		c.queue_free()
	var nomes := variacoes.keys()
	raio = maxf(RAIO, nomes.size() * (LADO.x + 14) / TAU)
	var margem := Vector2(raio, raio) + LADO * 0.6
	centro = pos.clamp(margem, (size - margem).max(margem))
	var x := Button.new()
	x.text = "✕"
	x.size = Vector2(44, 44)
	x.position = centro - x.size / 2
	x.add_theme_stylebox_override("normal", estilo(false, 22))
	x.add_theme_stylebox_override("hover", estilo(true, 22))
	x.pressed.connect(fechar)
	add_child(x)
	for i in nomes.size():
		var nome: String = nomes[i]
		var a := TAU * i / nomes.size() - PI / 2
		var b := Button.new()
		b.icon = variacoes[nome][0]
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.text = nome.capitalize()
		b.size = LADO
		b.position = centro + Vector2(cos(a), sin(a)) * raio - LADO / 2
		b.add_theme_stylebox_override("normal", estilo(nome == antes[alvos[0]], 14))
		b.add_theme_stylebox_override("hover", estilo(true, 14))
		b.add_theme_stylebox_override("pressed", estilo(true, 14))
		b.mouse_entered.connect(mostrar.bind(nome))
		b.mouse_exited.connect(voltar)
		b.pressed.connect(escolher.bind(nome))
		add_child(b)
	show()
	queue_redraw()


func estilo(aceso: bool, canto: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.08, 0.1, 0.92)
	s.set_corner_radius_all(canto)
	s.set_border_width_all(3 if aceso else 1)
	s.border_color = Color(1, 0.8, 0.3) if aceso else Color(1, 1, 1, 0.25)
	s.set_content_margin_all(6)
	return s


func _draw() -> void:
	draw_circle(centro, raio + LADO.y * 0.62, Color(0, 0, 0, 0.45))


func mostrar(v: String) -> void:
	for p: Node in alvos:
		main.set_variation(p, v)


func voltar() -> void:
	for p: Node in alvos:
		if is_instance_valid(p):
			main.set_variation(p, antes[p])


func escolher(v: String) -> void:
	for p: Node in alvos:
		antes[p] = v
	fechar()


func fechar() -> void:
	if not visible:
		return
	voltar()
	hide()
	main.menu_closed()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		fechar()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var k := event as InputEventKey
	var sair := k and k.pressed and not k.echo and (k.physical_keycode == KEY_ESCAPE or k.physical_keycode == KEY_B)
	var mb := event as InputEventMouseButton
	if sair or (mb and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT):
		fechar()
		get_viewport().set_input_as_handled()
