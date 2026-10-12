shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Base body uniforms (lighting and textures match body material)
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, hint_default_white;
uniform sampler2D roughness_texture : filter_linear_mipmap, hint_default_white;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;

uniform vec4 base_color : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform int hidden_regions = 0;

// Layer 0: BASE
uniform sampler2D base_mask : hint_default_black, filter_linear_mipmap;
uniform vec4 base_tint : source_color = vec4(1.0);
uniform float base_opacity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 base_smudge = vec2(0.0);

// Layer 1: BLUSH
uniform sampler2D blush_mask : hint_default_black, filter_linear_mipmap;
uniform vec4 blush_tint : source_color = vec4(1.0);
uniform float blush_opacity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 blush_smudge = vec2(0.0);

// Layer 2: EYESHADOW
uniform sampler2D eyeshadow_mask : hint_default_black, filter_linear_mipmap;
uniform vec4 eyeshadow_tint : source_color = vec4(1.0);
uniform float eyeshadow_opacity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 eyeshadow_smudge = vec2(0.0);

// Layer 3: EYELINER
uniform sampler2D eyeliner_mask : hint_default_black, filter_linear_mipmap;
uniform vec4 eyeliner_tint : source_color = vec4(1.0);
uniform float eyeliner_opacity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 eyeliner_smudge = vec2(0.0);

// Layer 4: LIPSTICK
uniform sampler2D lipstick_mask : hint_default_black, filter_linear_mipmap;
uniform vec4 lipstick_tint : source_color = vec4(1.0);
uniform float lipstick_opacity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 lipstick_smudge = vec2(0.0);

varying float v_hide;

void vertex() {
	int region_mask = int(round(COLOR.r * 255.0));
	v_hide = ((hidden_regions & region_mask) != 0) ? 1.0 : 0.0;
}

vec3 blend_makeup_layer(vec3 current_col, sampler2D mask_tex, vec2 uv, vec2 smudge, vec4 tint, float opacity) {
	if (opacity <= 0.0001) {
		return current_col;
	}
	vec2 sample_uv = uv + smudge;
	if (sample_uv.x < 0.0 || sample_uv.x > 1.0 || sample_uv.y < 0.0 || sample_uv.y > 1.0) {
		return current_col;
	}
	float mask_val = texture(mask_tex, sample_uv).r;
	float factor = clamp(mask_val * opacity * tint.a, 0.0, 1.0);
	return mix(current_col, tint.rgb, factor);
}

void fragment() {
	if (v_hide > 0.5) {
		discard;
	}

	vec4 albedo_tex = texture(albedo_texture, UV);
	vec3 col = base_color.rgb * albedo_tex.rgb;

	// Blending in layer order: BASE -> BLUSH -> EYESHADOW -> EYELINER -> LIPSTICK
	col = blend_makeup_layer(col, base_mask, UV, base_smudge, base_tint, base_opacity);
	col = blend_makeup_layer(col, blush_mask, UV, blush_smudge, blush_tint, blush_opacity);
	col = blend_makeup_layer(col, eyeshadow_mask, UV, eyeshadow_smudge, eyeshadow_tint, eyeshadow_opacity);
	col = blend_makeup_layer(col, eyeliner_mask, UV, eyeliner_smudge, eyeliner_tint, eyeliner_opacity);
	col = blend_makeup_layer(col, lipstick_mask, UV, lipstick_smudge, lipstick_tint, lipstick_opacity);

	ALBEDO = col;
	ROUGHNESS = roughness * texture(roughness_texture, UV).r;
	METALLIC = metallic;
	NORMAL_MAP = texture(normal_texture, UV).rgb;
}
