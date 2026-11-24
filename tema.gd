extends RefCounted
## Visual da interface: painéis quase pretos, borda fina, vermelho-sangue no que está ativo e âmbar de
## lampião nos destaques. Fontes e ícones vêm junto do programa (fontes/), pra ficar igual em qualquer PC.

const FUNDO := Color(0.055, 0.056, 0.066, 0.94)
const FUNDO_2 := Color(0.10, 0.10, 0.115)
const BORDA := Color(0.20, 0.20, 0.23)
const TEXTO := Color(0.91, 0.89, 0.86)
const APAGADO := Color(0.60, 0.58, 0.55)
const SANGUE := Color(0.77, 0.20, 0.17)
const AMBAR := Color(0.95, 0.72, 0.32)

static var fonte := load("res://fontes/FiraSans-Regular.ttf") as FontFile
static var fonte_media := load("res://fontes/FiraSans-Medium.ttf") as FontFile
static var fonte_forte := load("res://fontes/FiraSans-SemiBold.ttf") as FontFile
static var fonte_titulo := load("res://fontes/FiraSansCondensed-SemiBold.ttf") as FontFile
static var fonte_icone := load("res://fontes/icones.otf") as FontFile

# códigos dos ícones (Font Awesome Free Solid)
static var I_CURSOR := char(0xf245)
static var I_NOVA := char(0xf234)
static var I_AMBIENTAR := char(0xf06d)
static var I_VOAR := char(0xf03d)
static var I_CONFIG := char(0xf013)
static var I_PASTA := char(0xf07c)
static var I_SALVAR := char(0xf0c7)
static var I_CENARIO := char(0xf6fc)
static var I_GRADE := char(0xf84c)
static var I_CLIMA := char(0xf6c3)
static var I_CAMERA := char(0xf030)
static var I_SEGUIR := char(0xf05b)
static var I_TREMER := char(0xf0e7)
static var I_TRAZER := char(0xf124)
static var I_JANELA := char(0xf390)
static var I_DESFAZER := char(0xf2ea)
static var I_REFAZER := char(0xf2f9)
static var I_DADO := char(0xf6cf)
static var I_FECHAR := char(0xf00d)


static func caixa(cor: Color, borda := Color(0, 0, 0, 0), raio := 6, margem := 8.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.border_color = borda
	s.set_border_width_all(1 if borda.a > 0 else 0)
	s.set_corner_radius_all(raio)
	s.set_content_margin_all(margem)
	s.content_margin_top = margem * 0.6
	s.content_margin_bottom = margem * 0.6
	s.anti_aliasing = true
	return s


static func criar() -> Theme:
	var t := Theme.new()
	for f in [fonte, fonte_media, fonte_forte, fonte_titulo]:
		f.fallbacks = [fonte_icone]
	t.default_font = fonte
	t.default_font_size = 15
	for tipo in ["Label", "Button", "LineEdit", "OptionButton", "CheckBox", "PopupMenu", "TooltipLabel", "MenuButton"]:
		t.set_color("font_color", tipo, TEXTO)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", APAGADO * Color(1, 1, 1, 0.6))
	for tipo in ["Button", "OptionButton", "MenuButton", "CheckBox"]:
		t.set_font("font", tipo, fonte_media)
		t.set_stylebox("normal", tipo, caixa(FUNDO_2, BORDA))
		t.set_stylebox("hover", tipo, caixa(Color(0.15, 0.15, 0.17), Color(0.32, 0.32, 0.36)))
		t.set_stylebox("pressed", tipo, caixa(Color(0.30, 0.09, 0.08), SANGUE))
		t.set_stylebox("hover_pressed", tipo, caixa(Color(0.36, 0.11, 0.10), SANGUE.lightened(0.2)))
		t.set_stylebox("disabled", tipo, caixa(FUNDO_2 * Color(1, 1, 1, 0.5), BORDA * Color(1, 1, 1, 0.5)))
		t.set_stylebox("focus", tipo, StyleBoxEmpty.new())
	for tipo in ["CheckBox", "CheckButton"]:
		for e in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			t.set_stylebox(e, tipo, caixa(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	t.set_stylebox("normal", "LineEdit", caixa(Color(0.035, 0.035, 0.045), BORDA))
	t.set_stylebox("focus", "LineEdit", caixa(Color(0.035, 0.035, 0.045), AMBAR * Color(1, 1, 1, 0.7)))
	t.set_color("caret_color", "LineEdit", AMBAR)
	t.set_color("font_placeholder_color", "LineEdit", APAGADO * Color(1, 1, 1, 0.6))
	t.set_stylebox("panel", "PanelContainer", caixa(FUNDO, BORDA, 10, 12))
	t.set_stylebox("panel", "PopupMenu", caixa(Color(0.07, 0.07, 0.08, 0.98), BORDA, 8, 6))
	t.set_stylebox("hover", "PopupMenu", caixa(Color(0.30, 0.09, 0.08), Color(0, 0, 0, 0), 5, 6))
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_constant("v_separation", "PopupMenu", 8)
	t.set_stylebox("panel", "TooltipPanel", caixa(Color(0.04, 0.04, 0.05, 0.97), BORDA, 6, 8))
	t.set_font_size("font_size", "TooltipLabel", 13)
	t.set_stylebox("slider", "HSlider", caixa(Color(0.035, 0.035, 0.045), BORDA, 3, 3))
	t.set_stylebox("grabber_area", "HSlider", caixa(SANGUE, Color(0, 0, 0, 0), 3, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", caixa(SANGUE.lightened(0.15), Color(0, 0, 0, 0), 3, 3))
	t.set_constant("separation", "HBoxContainer", 6)
	t.set_constant("separation", "VBoxContainer", 6)
	t.set_constant("h_separation", "GridContainer", 6)
	t.set_constant("v_separation", "GridContainer", 6)
	t.set_stylebox("separator", "VSeparator", caixa(BORDA, Color(0, 0, 0, 0), 0, 0))
	t.set_constant("separation", "VSeparator", 14)
	t.set_stylebox("separator", "HSeparator", caixa(BORDA, Color(0, 0, 0, 0), 0, 0))
	t.set_constant("separation", "HSeparator", 10)
	return t


static func titulo(texto: String, cor := APAGADO) -> Label:
	var l := Label.new()
	l.text = texto.to_upper()
	var f := FontVariation.new()
	f.base_font = fonte_titulo
	f.spacing_glyph = 2   # letras espaçadas, jeito de rótulo
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", cor)
	return l


static func icone(cod: String, tam := 16, cor := TEXTO) -> Label:
	var l := Label.new()
	l.text = cod
	l.add_theme_font_override("font", fonte_icone)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# Botão com ícone e texto lado a lado (ou só ícone, se texto vazio). O ícone vai no próprio texto:
# as fontes do tema caem na fonte de ícones quando a letra não existe nelas.
static func botao(cod: String, texto: String, dica := "") -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = dica
	b.text = cod if texto == "" else cod + "   " + texto
	b.custom_minimum_size = Vector2(36, 34)
	return b


# Ferramenta da barra da esquerda: ícone grande em cima, nome embaixo.
static func ferramenta(cod: String, texto: String, dica: String) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = dica
	b.custom_minimum_size = Vector2(68, 60)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 3)
	vb.add_child(icone(cod, 19))
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_font_override("font", fonte_media)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(l)
	b.add_child(vb)
	return b
