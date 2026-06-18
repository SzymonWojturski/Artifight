shader_type canvas_item;

uniform sampler2D bg_texture : filter_nearest, repeat_enable;
uniform vec2 cam_offset = vec2(0.0);
uniform float world_scale = 1.0;
uniform float tiles_on_short_side = 2.0;

void fragment() {
	vec2 tex_px = vec2(textureSize(bg_texture, 0));
	vec2 screen_px_size = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float short_screen = min(screen_px_size.x, screen_px_size.y);
	float short_tex = min(tex_px.x, tex_px.y);
	float scale = short_screen / (short_tex * tiles_on_short_side);
	vec2 tex_size = tex_px * scale;
	vec2 screen_px = UV / SCREEN_PIXEL_SIZE;
	vec2 world_px = screen_px * world_scale + cam_offset;
	vec2 uv = world_px / tex_size;

	// mirror repeat zamiast zwykłego kopiowania
	vec2 t = fract(uv);
	vec2 m = mod(floor(uv), 2.0);
	vec2 mirrored_uv = mix(t, 1.0 - t, m);

	COLOR = texture(bg_texture, mirrored_uv);
}
