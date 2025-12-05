shader_type canvas_item;

uniform vec2 light_positions[128];
uniform int light_count = 0;
uniform float light_radius = 150.0;

varying vec2 local_vertex;

void vertex(){
	local_vertex = VERTEX;
}

void fragment() {
    vec4 original_color = texture(TEXTURE, UV);
    COLOR = vec4(0.0, 0.0, 0.0, 1.0); // Default to black

    for (int i = 0; i < light_count; i++) {
        if (distance(light_positions[i], local_vertex) < light_radius) {
            COLOR = original_color;
            break; 
        }
    }
}
