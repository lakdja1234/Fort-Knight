shader_type canvas_item;

// 재사용 대기시간 효과를 위한 셰이더

// progress: 쿨다운 진행 상태를 나타내는 변수 (0.0에서 1.0까지).
// 이 값이 커질수록 시계 방향으로 채워진 부분이 사라집니다.
uniform float progress;

// cooldown_color: 쿨다운 오버레이의 색상을 지정합니다.
// source_color 힌트는 Godot 에디터에서 색상 선택기를 사용할 수 있게 해줍니다.
uniform vec4 cooldown_color : source_color = vec4(0.0, 0.0, 0.0, 0.8);

void fragment() {
    // 1. UV 좌표를 텍스처의 중심으로 이동시킵니다.
    // 기본 UV 좌표는 좌상단 (0,0)에서 우하단 (1,1)까지입니다.
    // 이를 (-0.5, -0.5)에서 (0.5, 0.5) 범위로 변경하여 중심을 (0,0)으로 만듭니다.
    vec2 centered_uv = UV - vec2(0.5);

    // 2. 각도 계산 (atan 함수 사용)
    // atan(y, x)는 주어진 y, x 좌표에 대한 각도를 라디안 단위로 반환합니다.
    // 여기서는 atan(centered_uv.x, centered_uv.y)를 사용하여 3시 방향에서 시작하여
    // 시계 반대 방향(CCW)으로 증가하는 각도를 얻습니다.
    float angle = atan(centered_uv.x, centered_uv.y);
    
    // 3. 시작점 보정 (12시 방향으로)
    // atan의 기본 시작점은 3시 방향(angle=0)입니다. 
    // 12시 방향에서 시작하려면 각도를 90도 (PI / 2.0 라디안)만큼 시계 반대 방향으로 이동시킵니다.
    angle += PI / 2.0;
    
    // 4. 정규화 및 방향 전환
    // 현재 각도는 시계 반대 방향으로 증가합니다. 이를 시계 방향으로 바꾸기 위해 1.0에서 빼줍니다.
    // angle / (2.0 * PI)는 라디안 각도를 [0.0, 1.0] 범위로 정규화하는 과정입니다.
    float angle_progress = 1.0 - (angle / (2.0 * PI));
    
    // 5. 픽셀 그리기 결정
    // 현재 픽셀의 각도 진행률(angle_progress)이 전체 진행률(progress)보다 작으면
    // 해당 픽셀은 "사라진" 부분이므로 투명하게 처리합니다.
    // 그렇지 않으면, 설정된 쿨다운 색상으로 그립니다.
    if (angle_progress < progress) {
        COLOR.a = 0.0; // 완전히 투명하게 만듭니다.
    } else {
        COLOR = cooldown_color; // 반투명한 쿨다운 색상으로 칠합니다.
    }
}

