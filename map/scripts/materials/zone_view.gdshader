shader_type canvas_item;


/* =========================
   ПРОЗРАЧНОСТ
   ========================= */

// Каква част от изображението участва в преливането.
// 0.0 изключва fade-а от съответната страна.
uniform float fade_left   : hint_range(0.0, 1.0) = 0.0;
uniform float fade_right  : hint_range(0.0, 1.0) = 0.0;
uniform float fade_top    : hint_range(0.0, 1.0) = 0.0;
uniform float fade_bottom : hint_range(0.0, 1.0) = 0.0;

// Прозрачност точно в съответния край.
// 0.0 = напълно прозрачно.
// 1.0 = напълно видимо.
uniform float left_edge_alpha   : hint_range(0.0, 1.0) = 0.0;
uniform float right_edge_alpha  : hint_range(0.0, 1.0) = 0.0;
uniform float top_edge_alpha    : hint_range(0.0, 1.0) = 0.0;
uniform float bottom_edge_alpha : hint_range(0.0, 1.0) = 0.0;

// По-голяма стойност прави преливането по-рязко.
uniform float fade_power : hint_range(0.1, 5.0) = 1.0;


/* =========================
   BORDER
   ========================= */

uniform bool enable_border = true;

uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Дебелина в пиксели за всяка страна.
uniform float border_left   : hint_range(0.0, 50.0) = 2.0;
uniform float border_right  : hint_range(0.0, 50.0) = 2.0;
uniform float border_top    : hint_range(0.0, 50.0) = 2.0;
uniform float border_bottom : hint_range(0.0, 50.0) = 2.0;

// Ако е true, border-ът също избледнява.
// Ако е false, border-ът винаги остава видим.
uniform bool fade_border = false;


float calculate_fade(
	float distance_from_edge,
	float fade_distance,
	float edge_alpha
) {
	if (fade_distance <= 0.0) {
		return 1.0;
	}

	float fade_value = smoothstep(
		0.0,
		fade_distance,
		distance_from_edge
	);

	fade_value = pow(fade_value, fade_power);

	return mix(edge_alpha, 1.0, fade_value);
}


void fragment() {
	vec4 texture_color = texture(TEXTURE, UV);

	// Прозрачност от всяка страна.
	float left_fade = calculate_fade(
		UV.x,
		fade_left,
		left_edge_alpha
	);

	float right_fade = calculate_fade(
		1.0 - UV.x,
		fade_right,
		right_edge_alpha
	);

	float top_fade = calculate_fade(
		UV.y,
		fade_top,
		top_edge_alpha
	);

	float bottom_fade = calculate_fade(
		1.0 - UV.y,
		fade_bottom,
		bottom_edge_alpha
	);

	// Комбиниране на всички fade ефекти.
	float total_fade =
		left_fade *
		right_fade *
		top_fade *
		bottom_fade;

	vec4 result = texture_color;
	result.a *= total_fade;


	/* =========================
	   СЪЗДАВАНЕ НА BORDER
	   ========================= */

	if (enable_border) {
		vec2 pixel_size = TEXTURE_PIXEL_SIZE;

		float left_border_mask = 1.0 - step(
			border_left * pixel_size.x,
			UV.x
		);

		float right_border_mask = step(
			1.0 - border_right * pixel_size.x,
			UV.x
		);

		float top_border_mask = 1.0 - step(
			border_top * pixel_size.y,
			UV.y
		);

		float bottom_border_mask = step(
			1.0 - border_bottom * pixel_size.y,
			UV.y
		);

		float border_mask = max(
			max(left_border_mask, right_border_mask),
			max(top_border_mask, bottom_border_mask)
		);

		vec4 final_border_color = border_color;

		if (fade_border) {
			final_border_color.a *= total_fade;
		}

		// Поставя border-а върху изображението.
		result = mix(
			result,
			final_border_color,
			border_mask * final_border_color.a
		);
	}

	COLOR = result;
}