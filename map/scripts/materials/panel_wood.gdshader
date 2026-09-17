shader_type canvas_item;

uniform vec2 panel_size = vec2(1600.0, 175.0);

uniform float pixel_size : hint_range(2.0, 32.0, 1.0) = 8.0;

uniform float cluster_size : hint_range(1.0, 24.0, 1.0) = 5.0;

uniform vec4 wood_light : source_color =
	vec4(0.72, 0.47, 0.25, 1.0);

uniform vec4 wood_middle : source_color =
	vec4(0.66, 0.41, 0.21, 1.0);

uniform vec4 wood_dark : source_color =
	vec4(0.58, 0.34, 0.17, 1.0);


uniform bool enable_top_border = true;

uniform vec4 border_color : source_color =
	vec4(0.16, 0.075, 0.03, 1.0);

uniform vec4 border_light_color : source_color =
	vec4(0.24, 0.12, 0.055, 1.0);

uniform float border_base_depth
	: hint_range(1.0, 10.0, 1.0) = 2.0;

uniform float border_irregularity
	: hint_range(0.0, 10.0, 1.0) = 3.0;

uniform float border_cluster_width
	: hint_range(1.0, 20.0, 1.0) = 6.0;

uniform float drip_chance
	: hint_range(0.0, 1.0, 0.01) = 0.12;

uniform float drip_length
	: hint_range(0.0, 12.0, 1.0) = 4.0;

uniform float drip_width
	: hint_range(1.0, 10.0, 1.0) = 3.0;


float random_value(vec2 position) {
	return fract(
		sin(dot(position, vec2(12.9898, 78.233))) *
		43758.5453
	);
}


float value_noise(vec2 position) {
	vec2 cell = floor(position);
	vec2 fraction = fract(position);

	fraction = fraction * fraction * (3.0 - 2.0 * fraction);

	float top_left = random_value(cell);
	float top_right = random_value(
		cell + vec2(1.0, 0.0)
	);

	float bottom_left = random_value(
		cell + vec2(0.0, 1.0)
	);

	float bottom_right = random_value(
		cell + vec2(1.0, 1.0)
	);

	float top = mix(
		top_left,
		top_right,
		fraction.x
	);

	float bottom = mix(
		bottom_left,
		bottom_right,
		fraction.x
	);

	return mix(
		top,
		bottom,
		fraction.y
	);
}



void fragment() {
	vec2 local_position = UV * panel_size;

	vec2 pixel_cell = floor(
		local_position / pixel_size
	);


	vec2 cluster_position = vec2(
		pixel_cell.x / (cluster_size * 1.8),
		pixel_cell.y / cluster_size
	);

	float zone_value = value_noise(
		cluster_position
	);

	vec4 final_color = wood_middle;

	if (zone_value < 0.35) {
		final_color = wood_dark;
	} else if (zone_value > 0.65) {
		final_color = wood_light;
	}

	float small_variation = (
		random_value(
			pixel_cell + vec2(91.0, 37.0)
		) - 0.5
	) * 0.035;

	final_color.rgb += vec3(small_variation);


	if (enable_top_border) {
		float border_noise = value_noise(
			vec2(
				pixel_cell.x / border_cluster_width,
				23.7
			)
		);

		float border_depth =
			border_base_depth +
			floor(
				border_noise *
				border_irregularity
			);

		float drip_group = floor(
			pixel_cell.x / drip_width
		);

		float current_drip = random_value(
			vec2(drip_group, 74.3)
		);

		if (current_drip < drip_chance) {
			float drip_variation = random_value(
				vec2(drip_group, 193.8)
			);

			border_depth += floor(
				drip_length *
				(0.5 + drip_variation * 0.5)
			);
		}

		if (pixel_cell.y < border_depth) {
			float border_shade = random_value(
				vec2(
					floor(
						pixel_cell.x / 4.0
					),
					pixel_cell.y
				)
			);

			final_color = mix(
				border_color,
				border_light_color,
				border_shade * 0.35
			);
		}
	}

	COLOR = final_color;
}