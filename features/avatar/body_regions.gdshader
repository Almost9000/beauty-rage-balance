shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, hint_default_white;
uniform sampler2D roughness_texture : filter_linear_mipmap, hint_default_white;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;

uniform vec4 base_color : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform int hidden_regions = 0;

varying float v_hide;

void vertex() {
	int region_mask = int(round(COLOR.r * 255.0));
	v_hide = ((hidden_regions & region_mask) != 0) ? 1.0 : 0.0;
}

void fragment() {
	if (v_hide > 0.5) {
		discard;
	}
	vec4 albedo_tex = texture(albedo_texture, UV);
	ALBEDO = base_color.rgb * albedo_tex.rgb;
	ROUGHNESS = roughness * texture(roughness_texture, UV).r;
	METALLIC = metallic;
	NORMAL_MAP = texture(normal_texture, UV).rgb;
}
