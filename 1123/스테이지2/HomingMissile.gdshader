shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float line_thickness : hint_range(0, 10) = 1.0;

void fragment() {
    vec2 size = vec2(textureSize(TEXTURE, 0));
    
    float outline = texture(TEXTURE, UV + vec2(-line_thickness, 0) / size).a;
    outline += texture(TEXTURE, UV + vec2(line_thickness, 0) / size).a;
    outline += texture(TEXTURE, UV + vec2(0, -line_thickness) / size).a;
    outline += texture(TEXTURE, UV + vec2(0, line_thickness) / size).a;
    outline = min(outline, 1.0);

    vec4 color = texture(TEXTURE, UV);
    COLOR = mix(color, line_color, outline - color.a);
}
