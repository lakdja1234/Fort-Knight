extends Camera2D

# 플레이어 노드를 저장할 변수
var player: CharacterBody2D = null

# ✅ (선택 사항) 부드러운 카메라 이동을 위한 설정
# 인스펙터에서 이 값을 조절하여 따라오는 속도를 바꿀 수 있습니다.
@export var follow_speed: float = 5.0

func _ready():
	# "player" 그룹에 속한 플레이어 노드를 찾아서 변수에 저장
	# (player.gd 스크립트의 _ready()에 add_to_group("player")가 있어야 함)
	player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		printerr("MainCamera: 'player' 그룹에서 플레이어를 찾을 수 없습니다!")

func _physics_process(delta):
	# 플레이어를 찾았는지 확인
	if is_instance_valid(player):
		# --- 방법 A: 즉시 따라가기 (가장 간단) ---
		# self.global_position = player.global_position

		# --- 방법 B: 부드럽게 따라가기 (Lerp 사용 - 추천) ---
		# 카메라의 현재 위치에서 플레이어 위치를 향해 부드럽게 보간(interpolate)
		self.global_position = self.global_position.lerp(player.global_position, follow_speed * delta)
