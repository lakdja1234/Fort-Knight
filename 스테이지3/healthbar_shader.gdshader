shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.8, 0.1, 0.1, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.5, 0.0, 0.0, 1.0);
uniform float progress;
uniform float corner_radius = 5.0;

// 둥근 사각형의 Signed Distance Function (SDF)
// p: 현재 픽셀 위치, b: 사각형 크기, r: 모서리 둥글기
float sdRoundedBox( in vec2 p, in vec2 b, in vec4 r )
{
    r.xy = (p.x>0.0)?r.xy : r.zw;
    r.x  = (p.y>0.0)?r.x  : r.y;
    vec2 q = abs(p)-b+r.x;
    return min(max(q.x,q.y),0.0) + length(max(q,0.0)) - r.x;
}

void fragment() {
    // 1. ProgressBar의 크기를 가져옵니다 (vec2(1.0, 1.0)으로 가정).
    vec2 size = vec2(1.0, 1.0);
    
    // 2. UV 좌표를 [-0.5, 0.5] 범위로 중앙 정렬합니다.
    vec2 p = UV - 0.5;
    
    // 3. progress 값에 따라 가로 길이를 동적으로 조절합니다.
    //    오른쪽에서 줄어들게 하기 위해, x 위치를 progress에 따라 오프셋합니다.
    float offsetX = (1.0 - progress) * 0.5;
    p.x += offsetX;
    
    // 4. 둥근 사각형 SDF 계산
    float d = sdRoundedBox(p, vec2(progress * 0.5, 0.5), vec4(corner_radius / 100.0));

    // 5. SDF 값을 기반으로 픽셀의 알파 값을 결정 (가장자리를 부드럽게 처리)
    float alpha = 1.0 - smoothstep(0.0, 0.01, d);

    // 6. 알파 값이 0.1보다 작으면 픽셀을 버려서 완전한 투명도를 보장합니다.
    if (alpha < 0.1) {
        discard;
    }

    // 7. 위에서 아래로 흐르는 그래디언트 생성
    vec4 gradient = mix(top_color, bottom_color, UV.y);
    
    // 8. 최종 색상에 계산된 알파 값을 적용
    COLOR = vec4(gradient.rgb, alpha);
}