extends RigidBody2D

# --- 폭발 관련 변수 ---
const ExplosionScene = preload("res://스테이지2/explosion.tscn")
@export var damage: int = 15
@export var explosion_radius: float = 150.0

# --- 미사일 능력치 ---
@export var speed: float = 600.0 # This speed is used by the player's fire_bullet function
@export var homing_speed: float = 1000.0
# 궤도 수정을 시작할 거리 (픽셀 단위, 인스펙터에서 조절 가능)
@export var homing_activation_range: float = 400.0 

var target: Node2D = null
# 방향 꺾기를 한 번만 하도록 체크하는 변수
var homing_turn_done: bool = false

# 일회성 사운드를 재생하는 헬퍼 함수
func _play_sound(sound_path, volume_db = 0, pitch_scale = 1.0):
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = load(sound_path)
	sfx_player.volume_db = volume_db
	sfx_player.pitch_scale = pitch_scale
	sfx_player.bus = "SFX" # SFX 버스로 라우팅
	add_child(sfx_player)
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)

# --- 시각/물리 노드 참조 추가 ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var shooter = null
var explosion_created = false

func set_shooter(new_shooter: Node):
	shooter = new_shooter

func set_damage(amount: int):
	self.damage = amount

func _ready():
	add_to_group("bullets")
	# 물리 설정: 중력의 영향을 받도록 함 (포물선 운동)
	gravity_scale = 1.0
	
	body_entered.connect(_on_body_entered)
	
	if not is_instance_valid(sprite):
		printerr("유도 미사일 오류: Sprite2D 노드를 찾을 수 없습니다! ($Sprite2D 경로 확인)")
	if not is_instance_valid(collision_shape):
		printerr("유도 미사일 오류: CollisionShape2D 노드를 찾을 수 없습니다! ($CollisionShape2D 경로 확인)")

func _physics_process(_delta):
	# If homing has already started, just continue flying straight.
	if homing_turn_done:
		linear_velocity = Vector2.RIGHT.rotated(rotation) * homing_speed
		return

	# --- Proximity-Based Target Acquisition ---
	# While flying in a parabola (before homing), constantly check for nearby targets.
	var potential_targets = get_tree().get_nodes_in_group("boss_weak_points") # <-- "boss_weak_points" 그룹을 대상으로 합니다.
	var closest_target_in_range = null
	var min_distance_sq = INF # Use squared distance for efficiency
	
	for potential_target in potential_targets:
		if not is_instance_valid(potential_target):
			continue
			
		var target_pos = potential_target.global_position
		var sprite_node = potential_target.get_node_or_null("Sprite2D")
		if is_instance_valid(sprite_node):
			target_pos = sprite_node.global_position
			
		var distance_sq = global_position.distance_squared_to(target_pos)
		
		# Check if this target is within activation range AND is the closest so far
		if distance_sq <= homing_activation_range * homing_activation_range:
			if distance_sq < min_distance_sq:
				min_distance_sq = distance_sq
				closest_target_in_range = potential_target
	
	# --- Homing Activation ---
	# If we found a valid target within range, start homing.
	if is_instance_valid(closest_target_in_range):
		_play_sound("res://스테이지2/sound/SFX_Missile_Turn_Fast.mp3", -30, 0.7) # 플레이어 미사일 감지 사운드
		target = closest_target_in_range # Lock the target
		homing_turn_done = true
		gravity_scale = 0.0 # Turn off gravity
		
		# Calculate angle to the visual center of the locked target
		var final_target_pos = target.global_position
		var final_sprite = target.get_node_or_null("Sprite2D")
		if is_instance_valid(final_sprite):
			final_target_pos = final_sprite.global_position
			
		var target_angle = (final_target_pos - global_position).normalized().angle()
		rotation = target_angle
		# The linear_velocity will be set on the next frame by the logic at the top.
	else:
		# If not homing, fly parabolically and rotate to face the flight path.
		rotation = linear_velocity.angle()


func find_target_with_priority():
	# 1순위: 온열장치 (heaters)
	var heaters = get_tree().get_nodes_in_group("heaters")
	if not heaters.is_empty():
		target = find_closest_in_list(heaters)
		# print("Homing missile targeting heater: ", target.name)
		return

# Helper function to find the closest node from a given list
func find_closest_in_list(nodes: Array) -> Node2D:
	var closest = null
	var min_distance = INF
	for node in nodes:
		if not is_instance_valid(node):
			continue
		
		# Use the visual position for the distance check, if available
		var position_to_check = node.global_position
		var sprite_node = node.get_node_or_null("Sprite2D")
		if is_instance_valid(sprite_node):
			position_to_check = sprite_node.global_position
			
		var distance = global_position.distance_to(position_to_check)
		if distance < min_distance:
			min_distance = distance
			closest = node
	return closest
		
func _on_body_entered(body: Node):
	if body == shooter:
		return
	
	if explosion_created: return
	
	explosion_created = true
	body_entered.disconnect(_on_body_entered)

	call_deferred("create_explosion")
	
	set_deferred("monitoring", false)
	set_deferred("collision_mask", 0)
	call_deferred("queue_free")

func create_explosion():
	var explosion = ExplosionScene.instantiate()
	get_tree().root.add_child(explosion)
	explosion.global_position = self.global_position

	var camera = get_tree().get_first_node_in_group("camera")
	if is_instance_valid(camera) and camera.has_method("shake"):
		camera.shake(15, 0.3)

	if explosion.has_method("set_radius"):
		explosion.set_radius(explosion_radius)

	explosion.damage = damage

func set_projectile_scale(new_scale: Vector2):
	if is_instance_valid(sprite):
		sprite.scale = new_scale
	if is_instance_valid(collision_shape):
		collision_shape.scale = new_scale
