// Personagem de papel em pé: sempre virado pra câmera que está olhando (mestre ou jogadores),
// mostra as costas quando a câmera está atrás dele e espelha a arte pro lado em que ele anda.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D frente : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D costas : source_color, filter_linear_mipmap, repeat_disable;
uniform bool contorno = false;   // versão branca, um pouco maior e atrás (mouse em cima)
uniform float brilho_proprio = 0.15;   // pra arte não sumir no escuro (0 = só a luz da cena)

varying float de_costas;
varying float espelho;

void vertex() {
	vec3 origem = MODEL_MATRIX[3].xyz;
	vec3 para_cam = INV_VIEW_MATRIX[3].xyz - origem;
	para_cam.y = 0.0;
	para_cam = length(para_cam) > 0.001 ? normalize(para_cam) : vec3(0.0, 0.0, 1.0);
	vec3 direita = normalize(cross(vec3(0.0, 1.0, 0.0), para_cam));
	vec3 olhando = -MODEL_MATRIX[2].xyz;   // o personagem olha pro -Z dele
	olhando.y = 0.0;
	olhando = normalize(olhando + vec3(0.0001));
	de_costas = dot(olhando, para_cam) < -0.2 ? 1.0 : 0.0;
	espelho = dot(olhando, direita) > 0.0 ? 1.0 : 0.0;
	float s = length(MODEL_MATRIX[0].xyz);
	if (contorno) {
		origem -= para_cam * 0.03;
	}
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(direita * s, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(para_cam * s, 0.0), vec4(origem, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 uv = UV;
	if (espelho > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	if (contorno) {
		float a = 0.0;
		for (int i = 0; i < 8; i++) {
			float ang = float(i) * 0.785398;
			a = max(a, de_costas > 0.5 ? texture(costas, uv + vec2(cos(ang), sin(ang)) * vec2(0.03, 0.012)).a
			                           : texture(frente, uv + vec2(cos(ang), sin(ang)) * vec2(0.03, 0.012)).a);
		}
		ALBEDO = vec3(0.0);
		EMISSION = vec3(1.2);
		ALPHA = a;
	} else {
		vec4 c = de_costas > 0.5 ? texture(costas, uv) : texture(frente, uv);
		ALBEDO = c.rgb;
		EMISSION = c.rgb * brilho_proprio;
		ALPHA = c.a;
		ROUGHNESS = 0.9;
	}
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
