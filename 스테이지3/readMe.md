3스테이지 기술 명세서
=====================================================
* 최종 업데이트: 2025-11-07

-----------------------------------------------------
1. 핵심 시스템
-----------------------------------------------------

### 1.1. 시야 및 렌더링 시스템

*   **기본 암전 효과:** `background_light.gdshader` 커스텀 셰이더를 사용하는 `Background` 노드(`Sprite2D`)를 통해 구현됩니다. 이 셰이더는 기본적으로 화면을 어둡게 처리합니다.
*   **광원 처리 로직:**
    *   셰이더는 `uniform vec2 light_positions[128]` 배열과 `uniform int light_count`를 파라미터로 받습니다.
    *   `player.gd` 스크립트가 매 프레임(`_physics_process`) 플레이어의 현재 위치와 최근 포탄의 충돌 위치들을 `light_positions` 배열에 담아 셰이더로 전달합니다.
    *   셰이더의 `fragment()` 함수는 각 픽셀이 이 광원 위치들로부터 얼마나 떨어져 있는지 계산하여, 가까울수록 밝은 원형의 시야를 그려냅니다.
*   **오브젝트 가시성:**
    *   **조명에 반응하는 오브젝트:** 종유석, 횃불 등은 `Sprite2D.light_mask = 1`로 설정되어, `PointLight2D`의 빛을 받아야만 모습이 드러납니다.
    *   **자체 발광 오브젝트:** 보스 기믹에 사용되는 `BrightSpot`은 `CanvasItemMaterial`의 `blend_mode`를 `BLEND_MODE_ADD`로 설정합니다. 이를 통해 `background_light.gdshader`의 암전 효과를 무시하고 스스로 빛나는 것처럼 항상 화면에 보이게 됩니다.

### 1.2. 게임 흐름 및 디버그

*   **게임 오버/클리어:** 플레이어 또는 보스의 HP가 0이 되면 각각의 UI를 표시하고 `get_tree().paused = true`로 게임을 정지시킵니다. `RetryButton`의 `pressed` 신호는 `game_manager._on_retry_button_pressed`에 연결되어 `get_tree().reload_current_scene()`을 호출, 씬을 재시작합니다.
*   **디버그 기능:** `game_manager.gd`가 `_ready()`에서 `CanvasLayer`와 두 개의 `Button`을 동적으로 생성합니다. 각 버튼은 "1기믹 (HP 50%)", "2기믹 (HP 30%)" 텍스트를 가지며, 클릭 시 보스의 `hp` 변수를 직접 수정하여 해당 기믹을 즉시 발동시킬 수 있습니다.

-----------------------------------------------------
2. 플레이어 (player.gd)
-----------------------------------------------------

*   **노드 타입:** `CharacterBody2D`
*   **이동:** `Input.get_axis("move_left", "move_right")`로 방향 입력을 받고, `move_toward` 함수를 사용하여 `MAX_SPEED`까지 부드럽게 가속하고 `FRICTION`으로 감속합니다. 이를 통해 즉시 멈추지 않고 약간의 관성이 있는 움직임을 구현합니다.
*   **조준:** `CannonPivot`(`Node2D`)을 회전 중심으로 삼고, `clamp(rotation, -PI, 0.0)`를 통해 포신이 탱크의 하반신을 뚫고 들어가지 않도록 상단 180도 내에서만 회전하도록 제한합니다.
*   **발사 및 쿨다운 시스템:**
    *   `can_fire`(발사 가능), `is_charging`(차징 중) 두 개의 boolean 변수로 상태를 관리합니다.
    *   `fire` 입력 시, `setup_bar_for_charging` 함수가 `ProgressBar`의 범위를 `MIN_FIRE_POWER` ~ `MAX_FIRE_POWER`로, 색상을 노란색으로 설정합니다.
    *   `fire` 입력 해제 시, `fire_bullet` 함수를 호출하고 `can_fire`를 `false`로 바꾼 뒤 `CooldownTimer`(3초)를 시작합니다. 동시에 `setup_bar_for_cooldown` 함수가 `ProgressBar`의 범위를 `3.0` ~ `0.0`으로, 색상을 붉은색으로 변경하여 쿨다운 상태를 시각적으로 표시합니다.
*   **피해 피드백:** `take_damage` 함수 내부에 `create_tween().set_loops(2)`로 `Tween`을 생성합니다. `tween_property`를 이용해 `self`의 `modulate` 속성을 0.15초 동안 `Color.RED`로, 다시 0.15초 동안 `Color.WHITE`로 변경하는 과정을 2회 반복하여 피격 시 깜빡이는 효과를 연출합니다.

-----------------------------------------------------
3. 환경 및 오브젝트
-----------------------------------------------------

### 3.1. 횃불 (torch.gd)

*   **상태 관리:** 30초짜리 `LightTimer`(`Timer`)의 실행 여부로 점화 상태를 관리합니다.
*   **점화:** 플레이어 포탄(`body.is_in_group("bullets")`)이 충돌하고 `light_timer`가 멈춰있을 때(`is_stopped()`), `on_texture`로 텍스처를 바꾸고 `PointLight2D`를 활성화한 뒤 `light_timer`를 시작합니다.
*   **강제 소등:** `force_extinguish()` 함수는 외부(보스의 2번 기믹)에서 호출 가능하며, 실행 시 `light_timer.stop()`으로 타이머를 멈추고 `_on_light_timer_timeout()` 함수를 직접 호출하여 즉시 소등 상태(텍스처 변경, `PointLight2D` 비활성화)로 만듭니다.
*   **그룹:** "torch" 그룹에 속해 있어, 다른 스크립트에서 쉽게 접근하여 제어할 수 있습니다.

### 3.2. 종유석 (Stalactites.gd & Stalactite.gd)

*   **매니저 (`Stalactites.gd`):**
    *   게임 시작 3초 후 `_on_initial_spawn_timer_timeout`에서 5개의 종유석을 초기 생성합니다.
    *   개별 종유석의 `destroyed` 시그널에 연결된 `_on_stalactite_destroyed` 함수를 통해, 종유석이 파괴될 때마다 5초의 리스폰 타이머를 작동시켜 맵에 항상 5개의 종유석이 유지되도록 관리합니다.
*   **개별 종유석 (`Stalactite.gd`):**
    *   **물리:** `Area2D` 노드이며, `RigidBody2D`가 아닙니다. `is_falling` boolean으로 낙하 상태를 제어하며, 이 상태일 때 `_physics_process`에서 `velocity.y += GRAVITY * delta` 코드를 통해 수동으로 중력 효과를 시뮬레이션합니다.
    *   **낙하 과정:** `start_fall()` 함수가 호출되면, `Tween`을 사용해 붉게 깜빡이는 애니메이션을 먼저 재생합니다. `await tween.finished`로 애니메이션이 끝날 때까지 코드 실행을 잠시 멈춘 후, `is_falling`을 `true`로 바꿔 실제 낙하를 시작합니다.
    *   **충돌 및 파괴:** 낙하 중인 상태에서 `_on_body_entered`를 통해 다른 물리 객체와 충돌하면, 충돌체가 "boss" 또는 "player" 그룹에 속해있을 경우 `take_damage(20)`를 호출합니다. 그 후 어떤 객체와 부딪혔든 관계없이 `explode()` 함수를 호출하여 폭발 이펙트를 생성하고 `queue_free()`로 스스로를 파괴합니다.
    *   **씬 로딩:** `explosion_scene`이 에디터에서 할당되지 않은 경우를 대비해, `_ready()`에서 `load("res://explosion.tscn")`로 안전하게 씬을 불러오는 폴백(fallback) 로직이 포함되어 있습니다.

-----------------------------------------------------
4. 보스 (boss.gd)
-----------------------------------------------------

*   **핵심:** `StaticBody2D` 타입이며, `hp`, `in_gimmick_50`, `has_gimmick_50_triggered` 등의 상태 변수로 모든 동작을 제어합니다.
*   **조준 및 공격 로직 (`_on_attack_timer_timeout`):**
    1.  플레이어와의 거리를 계산하여 오차 범위를 설정합니다.
    2.  `PhysicsRayQueryParameters2D`를 생성하고 `collision_mask = 1` (world 레이어)로 설정합니다.
    3.  플레이어의 x좌표를 기준으로, 화면 상단에서 하단으로 Ray를 발사하여 `space_state.intersect_ray()`를 통해 지형 충돌 지점(`result.position`)을 찾습니다.
    4.  해당 위치에 `WarningScene`을 먼저 생성하여 공격 위치를 예고하고, `WARNING_DURATION`(1.5초) 후에 `_fire_projectile` 함수를 호출합니다.
    5.  `_fire_projectile`는 `calculate_parabolic_velocity` 함수를 통해 목표 지점에 정확히 도달하기 위한 초기 발사 속도 벡터를 계산한 후, 포탄을 발사합니다.

### 4.1. 기믹 1 (HP <= 50%)

*   **발동:** `_physics_process`에서 `hp <= max_hp * 0.5` 조건과 `has_gimmick_50_triggered` 플래그를 검사하여 단 한 번만 실행됩니다.
*   **실행 (`start_gimmick_50`):** `in_gimmick_50`을 `true`로 설정, 공격 타이머 정지, `Tween`으로 투명화, 충돌 비활성화 후 `hide()` 호출. 15초짜리 전체 기믹 타이머(`gimmick_50_timer`)와 1초 반복 체력 회복 타이머(`regen_timer`)를 시작합니다.
*   **`BrightSpot` 생성 및 관리:**
    *   `spawn_bright_spot` 함수에서 `BrightSpotScene`을 인스턴스화 한 후, **`collision_layer = 4` (enemy), `collision_mask = 36` (player_bullet, obstacle)으로 충돌 설정을 코드로 직접 덮어씁니다.**
    *   `get_tree().root.add_child()`를 통해 씬 루트에 직접 추가하여, 보스가 `hide()` 상태여도 영향을 받지 않도록 합니다.
    *   `_find_spawn_point_on_wall` 함수를 호출하여 생성 위치를 결정합니다. 이 함수는 Raycast를 통해 벽/천장 표면 좌표를 얻은 뒤, `result.position - result.normal * 50` 코드로 표면의 법선 벡터(normal) 반대 방향으로 50픽셀만큼 안쪽에 생성 위치를 정합니다.
    *   `BrightSpot`의 `hit` 시그널을 `_on_bright_spot_hit`에 연결합니다.
*   **`BrightSpot` 피격 로직 (`_on_bright_spot_hit`):**
    *   `regen_timer`를 멈춰 체력 회복을 중지시키고, 3초짜리 `heal_pause_timer`를 시작합니다.
    *   `take_damage(10, true)`를 호출하여, 기믹 무적 상태를 무시하고 보스에게 10의 피해를 줍니다.
*   **`BrightSpot` 리스폰 (`_on_heal_pause_timer_timeout`):** 3초 후, `spawn_bright_spot`을 다시 호출하여 새로운 `BrightSpot`을 생성하고, `regen_timer`를 다시 시작하여 체력 회복을 재개합니다.
*   **기믹 종료 (`_on_gimmick_50_timer_timeout`):** 15초가 지나면, `in_gimmick_50`을 `false`로, 모든 타이머를 중지, 화면의 모든 `BrightSpot`을 `queue_free()`로 제거하고, 보스를 다시 보이게 한 뒤 공격 패턴을 재개합니다.

### 4.2. 기믹 2 (HP <= 30%)

*   **발동:** `has_gimmick_30_triggered` 플래그를 통해 단 한 번만 실행됩니다.
*   **실행 (`start_gimmick_30`):** `get_tree().get_first_node_in_group("torch")`로 횃불 노드를 찾아 `force_extinguish()`를 호출, 맵을 강제 암전시킵니다. 이후 3초마다 반복되는 `gimmick_30_timer`를 시작합니다.
*   **종유석 낙하 (`_on_gimmick_30_timer_timeout`):** 타이머가 실행될 때마다 `stalactite_manager`의 자식 노드들을 모두 가져와, 그중 `start_fall` 메소드를 가진 노드(실제 종유석)를 무작위로 하나 골라 `start_fall()`을 호출하여 강제로 낙하시킵니다.

### 4.3. `BrightSpot.gd` 상세 구현

*   `_ready()` 함수 내에서 `find_child`를 통해 `Sprite2D`와 `PointLight2D`를 찾아, 각각의 `material`과 `enabled` 속성을 설정하여 자체 발광 및 조명 효과를 보장합니다.
*   또한, `CollisionShape2D`가 씬에 존재하지 않을 가능성에 대비하여, `find_child`로 확인 후 없을 경우 `CollisionShape2D.new()`와 `RectangleShape2D.new()`로 직접 생성하여 추가합니다. `monitoring`과 `monitorable` 속성을 `true`로 설정하여 충돌 감지가 반드시 활성화되도록 합니다.
*   `on_hit()` 라는 중앙 처리 함수를 만들어, `_on_body_entered`(총알)와 `_on_area_entered`(종유석) 양쪽에서 모두 이 함수를 호출하여 코드를 중복하지 않고 `hit` 시그널 발신 및 `queue_free()`를 처리합니다.

-----------------------------------------------------
5. UI / UX 상세 구현
-----------------------------------------------------
이 섹션은 게임의 모든 UI 요소와 사용자 경험 향상을 위한 피드백 기능의 구현 방식을 상세히 기술합니다.

### 5.1. 보스 체력바 (Boss Health Bar)

*   **구현 방식:** `boss.gd`의 `_ready()` 함수 내에서 완전히 프로그래밍 방식으로 생성됩니다. 씬에 미리 배치된 UI 노드를 사용하지 않고, 코드를 통해 동적으로 생성하여 유연성과 제어권을 확보했습니다.
*   **독립적 렌더링:**
    *   `CanvasLayer.new()`를 통해 새로운 `CanvasLayer`를 생성하고, 모든 체력바 관련 노드들을 이 레이어의 자식으로 추가합니다.
    *   이 방식을 통해 보스 체력바는 게임 월드와 분리된 독립적인 레이어에 렌더링됩니다. 결과적으로, 게임 월드에 적용되는 암전 효과(셰이더, `CanvasModulate` 등)의 영향을 받지 않고 항상 선명하게 표시됩니다.
*   **노드 구성:**
    *   `health_bar_canvas` (`CanvasLayer`): 모든 UI 요소들을 담는 최상위 컨테이너.
    *   `health_bar_bg` (`ColorRect`): 체력바의 배경. 반투명한 어두운 색상(`Color(0.2, 0.2, 0.2, 0.3)`)으로 설정됩니다.
    *   `health_bar_fg` (`ColorRect`): 실제 체력을 나타내는 전경. `health_bar_bg`의 자식으로 추가되며, 반투명한 녹색(`Color(0.2, 0.8, 0.2, 0.3)`)입니다.
    *   `health_bar_label` (`Label`): 보스의 이름("Driller")을 표시하는 텍스트. `health_bar_bg`의 자식으로 추가되어 중앙에 정렬됩니다.
*   **위치 및 스타일:**
    *   화면 해상도에 관계없이 항상 상단 중앙에 위치하도록 `get_viewport_rect().size.x`를 이용해 x좌표를 계산합니다.
    *   현재 y 위치는 화면 상단에서 40픽셀 아래(`position_y = 40`)이며, 높이는 60픽셀(`bar_height = 60`)로 설정되어 있습니다.
*   **업데이트 로직 (`update_custom_health_bar`):
    *   보스의 `hp`가 변경될 때마다 호출됩니다.
    *   `clamp(float(hp) / float(max_hp), 0.0, 1.0)` 코드를 통해 현재 체력 비율을 0과 1 사이의 값으로 계산합니다.
    *   계산된 비율을 `health_bar_fg`의 x축 크기(`size.x`)에 곱하여 체력 감소를 시각적으로 표현합니다.

### 5.2. 플레이어 HUD (Player HUD)

*   **차징/쿨다운 바 (`player.gd`):
    *   **단일 `ProgressBar`의 이중 활용:** 씬에 있는 하나의 `ProgressBar`(`$ChargeBar`)를 발사 '차징'과 '쿨다운' 두 가지 상태 표시에 모두 사용합니다.
    *   **상태 기반 외형 변경:**
        *   `setup_bar_for_charging()`: 발사 가능 상태일 때 호출. `ProgressBar`의 범위를 `MIN_FIRE_POWER`에서 `MAX_FIRE_POWER`로, 색상을 노란색으로 설정합니다.
        *   `setup_bar_for_cooldown()`: 발사 후 쿨다운 상태일 때 호출. 범위를 `COOLDOWN_DURATION`(3.0)에서 `0.0`으로, 색상을 붉은색으로 설정합니다.
    *   **동적 색상 변경:** `add_theme_stylebox_override("foreground", ...)` 함수를 사용합니다. 기존 `StyleBoxFlat` 테마를 `.duplicate()`로 복제한 뒤, `bg_color`만 변경하여 덮어쓰는 방식으로, 별도의 `ProgressBar` 노드 없이 효율적으로 색상을 전환합니다.

### 5.3. 데미지 피드백 (Blink Effect)

*   **구현 위치:** `player.gd`와 `boss.gd`의 `take_damage` 함수 내에 동일한 로직으로 구현되어 있습니다.
*   **작동 원리:**
    *   `create_tween().set_loops(2)`를 통해 2회 반복하는 `Tween`을 생성합니다.
    *   `tween_property(self, "modulate", Color.RED, 0.15)`: 0.15초 동안 노드의 `modulate` 속성을 붉은색으로 변경합니다.
    *   `tween_property(self, "modulate", Color.WHITE, 0.15)`: 이어서 0.15초 동안 다시 원래 색상(흰색)으로 되돌립니다.
    *   이 과정이 2번 반복되어, 피격 시 짧고 명확한 시각적 피드백을 제공합니다.

### 5.4. 게임 상태 UI (Game State UI)

*   **게임 오버 UI (`game_manager.gd`):
    *   `player.gd`의 `game_over` 시그널을 `_on_game_over` 함수에 연결합니다.
    *   플레이어 HP가 0이 되어 시그널이 방출되면, `game_over_ui.show()`를 통해 숨겨져 있던 게임 오버 UI를 표시하고, `get_tree().paused = true`로 게임 전체를 일시 정지시킵니다.
*   **재시도 버튼 (`RetryButton`):
    *   게임 오버 UI 내의 `RetryButton`은 `pressed` 시그널이 `game_manager._on_retry_button_pressed` 함수에 연결되어 있습니다.
    *   버튼 클릭 시, `get_tree().paused = false`로 정지를 해제하고 `get_tree().reload_current_scene()`을 호출하여 현재 씬을 처음부터 다시 로드합니다.
*   **디버그 UI (`game_manager.gd`):
    *   `_ready()`에서 `CanvasLayer`, `HBoxContainer`, `Button` 노드들을 동적으로 생성하여 화면 좌측 상단에 배치합니다.
    *   각 버튼의 `pressed` 시그널은 보스의 `hp` 변수를 직접 수정하는 함수(`_on_gimmick_1_button_pressed` 등)에 연결되어, 각 기믹을 즉시 테스트할 수 있는 환경을 제공합니다.

-----------------------------------------------------
6. 기술 사양: 충돌 레이어 및 마스크 (현재 상태)
-----------------------------------------------------
| 레이어 이름 (번호) | 객체 | LAYER | MASK | 비고 |
| :---------------- | :-------------------- | :---: | :---: | :--- |
| `world` (1)       | `TileMap`             | **1** | - | 지형 |
| `player` (2)      | `Player`              | **2** | **35** (`world`, `enemy_bullet`, `obstacle`) | |
| `player_bullet` (3) | `Player_Bullet`       | **3** | **53** (`world`, `enemy`, `obstacle`, `hitbox`) | |
| `enemy` (4)       | `Boss` (본체)         | **4** | **36** (`player_bullet`, `obstacle`) | `StaticBody2D` |
| `enemy_bullet` (5) | `Boss_Bullet`         | **5** | **3** (`world`, `player`) | |
| `obstacle` (6)    | `Stalactite`          | **6** | **7** (`world`, `player`, `enemy`) | `Area2D` |
| `hitbox` (7)      | `Boss_WeakPoint`      | **7** | **4** (`player_bullet`) | |
| `enemy` (4)       | `BrightSpot`          | **4** | **36** (`player_bullet`, `obstacle`) | 코드로 직접 설정 |
| `hitbox` (7)      | `Torch` (횃불)        | **7** | **4** (`player_bullet`) | |

-----------------------------------------------------
7. 앞으로 해야 할 일
-----------------------------------------------------
1. 보스 조준 시스템 조정
2. 보스 공격 패턴 추가 (예: 점프 패턴)
3. 게임 클리어 로직 및 UI 구현
4. 맵 디자인
5. 피격 경고 시스템 적용
