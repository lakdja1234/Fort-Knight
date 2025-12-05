# Fort-Knight - 스테이지 1 상세 분석 및 기술 사양

이 문서는 `Fort-Knight` 프로젝트의 스테이지 1(`Fort-Knight-main/스테이지1`)에 대한 상세한 기술 사양 및 구현 내용을 설명합니다.

## 1. 게임 흐름 및 핵심 시스템

### 1.1. 게임 시작 및 화면 전환

*   **전역 시스템**:
	*   **화면 전환**: `SceneTransition` (`fade_layer.tscn`) Autoload 싱글톤을 통해 모든 화면 전환 시 페이드 인/아웃 효과를 제공합니다.
	*   **전역 신호**: `GlobalSignals.gd` Autoload 싱글톤이 `camera_shake_requested`와 같은 전역 이벤트를 관리하여, 씬 간의 직접적인 참조 없이 통신합니다.
*   **화면 흐름**:
	1.  게임은 `title_screen.tscn`에서 시작됩니다.
	2.  키 입력 시 `stage_selection.tscn`으로 이동합니다.
	3.  스테이지 1 선택 시 메인 게임 씬인 `stage1.tscn`이 로드됩니다.

### 1.2. 카메라 시스템 (`Stage1Camera.gd`)

*   **카메라 연결**: `stage1.tscn`에 포함된 `Camera2D` 노드에 `Stage1Camera.gd` 스크립트가 연결되어 있습니다.
*   **화면 흔들림**:
	*   `GlobalSignals`의 `camera_shake_requested(strength, duration)` 신호에 `shake()` 함수가 연결되어 있습니다.
	*   폭발 효과(`explosion.gd`)가 발생할 때 이 신호를 `emit`하여 카메라를 흔듭니다.
	*   `shake()` 함수는 `Tween`을 이용해 카메라의 `offset`을 짧은 시간 동안 여러 번 변경하여 흔들림 효과를 만듭니다.

### 1.3. 게임 상태 관리 (`Stage1_GameManager.gd`)

*   **게임 오버/클리어**: 플레이어(`game_over` 신호)나 보스(`boss_died` 신호)의 상태에 따라 `GameOverUI` 또는 `GameClearUI`를 화면에 표시하고 게임을 일시 정지시킵니다.
*   `RetryButton`을 통해 현재 씬(`stage1.tscn`)을 재시작할 수 있습니다.

## 2. 플레이어 (`player.gd`)

*   **파일**: `Scenes/Player.tscn`, `Scenes/player.gd`
*   **역할**: 플레이어가 조종하는 탱크 캐릭터. 이동, 조준, 차지샷 발사, 피격 처리 등을 담당합니다.
*   **주요 변수 및 로직**:
	-   `bullet_scene: PackedScene`: 플레이어가 발사할 총알 씬. 에디터에서 `bullet.tscn` 또는 `cluster_shell.tscn`으로 설정 가능합니다.
	-   `MAX_SPEED`, `ACCELERATION`, `FRICTION`: 부드러운 좌우 이동을 위한 물리 변수.
	-   `AIM_SPEED`: 포신 회전 속도.
	-   `MIN_FIRE_POWER` / `MAX_FIRE_POWER`: 차지샷의 최소/최대 위력.
	-   `COOLDOWN_DURATION`: 발사 후 쿨다운 시간 (3초).
	-   `fire_bullet(power)`: `bullet_scene`을 생성하고, 발사체를 `player_bullet` 레이어(3번)와 올바른 마스크(105)로 설정한 후 발사합니다.
	-   `take_damage(amount)`: 피격 시 HP가 감소하고, `Tween`을 이용한 깜빡임 효과가 재생됩니다.

## 3. 보스 (`Stage1boss.gd`)

*   **파일**: `Scenes/stage1boss.tscn`, `Scenes/Stage1boss.gd`
*   **역할**: 스테이지 1의 보스. 정해진 패턴에 따라 여러 종류의 포탄을 발사합니다.
*   **주요 변수 및 로직**:
	-   `AttackPattern` (enum): `BASIC`, `BIG_SHOT`, `BURST`, `CLUSTER` 네 가지 공격 패턴을 정의.
	-   `attack_sequence`: 공격 순서를 정의하는 배열.
	-   `basic_bullet_scene`, `big_bullet_scene`, `cluster_bullet_scene`: 공격에 사용할 씬들을 할당.
	-   `_execute_mortar_attack()`: 플레이어 위치를 예측하고 `Raycast`로 지형을 감지하여 포물선 궤적으로 총알을 발사합니다.
	-   `_fire_projectile()`: 총알 생성 시, `collision_layer`를 `16`(5번 레이어: "boss_projectile")으로 설정하고 `owner_node`를 지정하여 자가 충돌을 방지합니다.
	-   `take_damage(amount)`: 피격 시 HP가 감소하고 `health_updated` 신호를 발생시킵니다.

## 4. 발사체 (Projectiles)

### 4.1. 기본 총알 (bullet.gd)

*   **파일**: `Scenes/bullet.tscn`, `스테이지3/bullet.gd` (씬에서 참조)
*   **역할**: 가장 기본적인 충돌-폭발형 포탄입니다.
*   **주요 로직**:
	*   **충돌 설정**: `bullet.tscn` 씬 파일에 `collision_layer = 4`, `collision_mask = 9`가 하드코딩되어 있어, 플레이어 총알로써 보스와 지형에 충돌합니다.
	*   **폭발**: 충돌 시 `explode()` 함수를 호출하여 `res://스테이지3/explosion.tscn`을 생성하고 자신을 파괴합니다.

### 4.2. 클러스터탄 (cluster_shell.gd)

*   **파일**: `Scenes/cluster_shell.tscn`, `Scenes/cluster_shell.gd`
*   **역할**: 보스와 플레이어 양쪽에서 사용되는 하이브리드 포탄.
*   **주요 로직**:
	*   **충돌**: `_on_body_entered` 함수를 통해 지형이나 대상과 충돌하면 `split()` 함수를 호출합니다.
	*   **분기**: `split()` 함수는 `target_positions` 변수의 유무에 따라 동작이 달라집니다.
		*   **보스가 발사 시**: `target_positions`가 존재하므로, 3개의 자탄(`submunition`)을 생성합니다. 이때 각 자탄은 '보스 총알'로 작동하도록 `collision_layer = 16`, `collision_mask = 3`으로 설정됩니다.
		*   **플레이어가 발사 시**: `target_positions`가 비어있으므로, `explosion_scene`을 생성하여 단일 폭발을 일으킵니다.

## 5. UI (`Stage1_GameUI.gd`)

*   **파일**: `Scenes/Stage1_GameUI.tscn`, `Scenes/Stage1_GameUI.gd`
*   **역할**: 스테이지 1의 모든 게임 UI(플레이어 정보, 보스 체력바)를 관리하는 중앙 허브.
*   **주요 로직**:
	*   `_ready()`:
		*   `CenterContainer`를 동적으로 생성하여 화면 상단 중앙에 배치합니다.
		*   `bossHealthbar.png` 이미지를 사용하는 `TextureProgressBar`를 생성하여 위 컨테이너의 자식으로 추가합니다. `CenterContainer`가 자동으로 중앙 정렬을 처리합니다.
	*   `_process()`: 게임 시작 후 한 번만 실행되어, `player` 및 `boss` 노드를 찾아 각각의 `health_updated` 신호를 UI 업데이트 함수에 연결합니다.
	*   `_on_boss_health_updated(current_hp, max_hp)`: 보스로부터 신호를 수신하여 `TextureProgressBar`의 `value`를 갱신합니다.

## 6. 기술 사양: 충돌 레이어 및 마스크

| 레이어 이름 (번호) | 객체                                        | LAYER (비트마스크 값) | MASK (비트마스크 값)           | 비고        |
| :---------------- | :---------------------------------------- | :-------------------- | :----------------------------- | :---------- |
| `world` (1)        | `TileMap`                                 | `1`                   | `-`                            | 지형        |
| `player` (2)       | `Player`                                  | `2`                   | `49` (`world`, `boss_projectile`, `hazard`) |             |
| `player_bullet` (3) | `Player_Bullet`                           | `4`                   | `105` (`world`, `boss`, `hazard`, `boss_gimmick`) |             |
| `boss` (4)         | `Boss`                                    | `8`                   | `36` (`player_bullet`, `hazard`) |             |
| `boss_projectile` (5)| `Boss_Bullet`                             | `16`                  | `7` (`world`, `player`, `hazard`) |             |
| `hazard` (6)       | `Stalactite`                              | `32`                  | `15` (`world`, `player`, `boss`, `player_bullet`) | `Area2D`    |
| `boss_gimmick` (7) | `Torch`                                   | `64`                  | `4` (`player_bullet`)          |             |
| `interactable` (8) | (미사용)                                  | `128`                 | `-`                            |             |

**참고**: `Layer` 값은 비트마스크 값입니다. (예: 3번 레이어 -> `2^(3-1) = 4`)

## 7. 향후 계획 (To-Do)

*   **2스테이지 온도계 UI 생성**
*   **보스 조준 시스템 추가 조정**
*   **보스 공격 패턴 추가** (예: 점프 패턴)
*   **맵 디자인 확장**
