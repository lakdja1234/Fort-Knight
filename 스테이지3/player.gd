# player.gd (Merged by Gemini)
extends CharacterBody2D

# ==============================================================================
#  1. 시그널 및 변수 선언 (Signals & Variables)
# ==============================================================================

# --- Signals ---
signal game_over
signal health_updated(current_hp)
signal freeze_gauge_changed(current_value, max_value)

# --- Physics ---
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# --- 외부 씬 참조 (Scene References) & 파츠 시스템 (Part System) ---
@export var bullet_scene: PackedScene # 기본 발사할 총알 씬
@export var player_bright_spot_scene: PackedScene = preload("res://스테이지3/PlayerBrightSpot.tscn") # 드릴 스킬 시각 효과

# Part System
@export var equipped_parts: Array[Part] = [null, null, null] # 최대 3개의 파츠 리소스를 담을 배열
@onready var skill_slots: Array[Node2D] = [
	$SkillSlot1,
	$SkillSlot2,
	$SkillSlot3
]
var current_skill_nodes: Array[Node] = [null, null, null] # 인스턴스화된 스킬 노드를 담을 배열
var next_shot_skill_data: Dictionary = {} # 다음 발사에 사용할 스킬 데이터를 저장 {scene, power, skill_node}

# --- HUD 및 노드 참조 (HUD & Node References) ---
@onready var health_bar = get_node_or_null("PlayerHUD/HUDContainer/PlayerInfoUI/VBoxContainer/HealthBar")
@onready var charge_bar = get_node_or_null("PlayerHUD/HUDContainer/PlayerInfoUI/VBoxContainer/ChargeBar")
@onready var cooldown_timer = $CooldownTimer # 기본 발사 쿨다운
@onready var cannon_pivot = $CannonPivot # 포신 회전 중심
@onready var fire_point = $CannonPivot/FirePoint # 발사 위치
@onready var trajectory_drawer = $TrajectoryDrawer # 포탄 궤적을 그리는 노드
@onready var ice_map_layer: TileMapLayer = null # 스테이지 2용
@onready var background = get_node_or_null("/root/TitleMap/Background") # 스테이지 3용
@onready var skill_cooldown_progress_bars: Array[ProgressBar] = [
	get_node_or_null("PlayerHUD/HUDContainer/SlotUI/Slot1/ProgressBar"),
	get_node_or_null("PlayerHUD/HUDContainer/SlotUI/Slot2/ProgressBar"),
	get_node_or_null("PlayerHUD/HUDContainer/SlotUI/Slot3/ProgressBar")
]
@onready var skill_icon_textures: Array[TextureRect] = [
	get_node_or_null("PlayerHUD/HUDContainer/SlotUI/Slot1/TextureRect"),
	get_node_or_null("PlayerHUD/HUDContainer/SlotUI/Slot2/TextureRect"),
	get_node_or_null("PlayerHUD/HUDContainer/SlotUI/Slot3/TextureRect")
]
@onready var part_icon_sprite: Sprite2D = $PartIconSprite # 파츠 아이콘 표시용 스프라이트 (HEAD version feature)
@onready var skill_slot_1_ui = get_node_or_null("/root/TitleMap/GameUI/PlayerUI/SkillSlot1") # 드릴 스킬 UI 참조 (bolt6281 feature)

# --- 사운드 플레이어 (Sound Players) ---
var barrel_sound_player: AudioStreamPlayer
var charge_sound_player: AudioStreamPlayer

# --- 이동 변수 (Movement Variables) ---
var MAX_SPEED = 300.0
const ACCELERATION = 1000.0
const FRICTION = 1000.0
const ACCELERATION_ICE_ORIGINAL = 500.0
const FRICTION_ICE = 0.001
var is_on_ice = false
var current_floor_type: String = "NORMAL"

# --- 조준 변수 (Aiming Variables) ---
const AIM_SPEED = 2.0

# --- 발사 시스템 변수 (Firing System Variables) ---
const MIN_FIRE_POWER = 500.0
const MAX_FIRE_POWER = 1200.0 # From bolt6281
const CHARGE_RATE = 700.0    # From bolt6281
const COOLDOWN_DURATION = 2.0
var is_charging = false
var current_power = MIN_FIRE_POWER
var charge_direction = 1 # From bolt6281
var can_fire = true

# --- 플레이어 스탯 (Player Stats) ---
var max_hp = 100
var hp = max_hp

# --- 드릴 스킬 변수 (Drill Skill Variables) ---
const DRILL_COOLDOWN = 30.0
const DRILL_DURATION = 3.0
const DRILL_SPEED_MULTIPLIER = 1.5
var is_drill_active = false
var original_max_speed: float
var drill_cooldown_timer: Timer
var drill_duration_timer: Timer
var current_bright_spot_instance: Node2D = null

# --- 스테이지 2 관련 변수 (Stage 2 Specific Variables) ---
@export var player_explosion_radius: float = 100.0
@export var player_projectile_scale: Vector2 = Vector2(1.0, 1.0)
var max_freeze_gauge: float = 100.0
var current_freeze_gauge: float = 0.0
const FREEZE_RATE_ICE: float = 7.0
const FREEZE_RATE_MELTED: float = 2.0
var warm_rate: float = 20.0
var is_warming_up: bool = false
var is_frozen: bool = false

# --- 기타 (Misc) ---
var bullet_path_points = []
const BULLET_PATH_DURATION = 2.0

# --- HUD 색상 변수 (HUD Color Variables) ---
const CHARGE_COLOR = Color("orange")
const COOLDOWN_COLOR = Color.RED
const HEALTH_FULL_COLOR = Color.GREEN
const HEALTH_EMPTY_COLOR = Color.RED

# ==============================================================================
#  2. Godot 내장 함수 (Godot Built-in Functions)
# ==============================================================================

func _ready():
	add_to_group("player")
	
	# --- HUD 초기화 ---
	if health_bar:
		health_bar.max_value = max_hp
		update_health_bar()
	if charge_bar:
		setup_bar_for_charging()
	
	# --- 스킬 사용 후 복원을 위해 원래 최대 속도를 저장
	original_max_speed = MAX_SPEED
	
	# --- 지속성 사운드 플레이어 설정 ---
	barrel_sound_player = AudioStreamPlayer.new()
	barrel_sound_player.stream = load("res://스테이지3/sound/movingBarrel.mp3")
	barrel_sound_player.finished.connect(barrel_sound_player.play)
	add_child(barrel_sound_player)
	
	charge_sound_player = AudioStreamPlayer.new()
	charge_sound_player.stream = load("res://스테이지3/sound/charge6s.mp3")
	charge_sound_player.finished.connect(charge_sound_player.play)
	add_child(charge_sound_player)

	# --- 드릴 스킬 타이머 설정 ---
	drill_cooldown_timer = Timer.new()
	drill_cooldown_timer.wait_time = DRILL_COOLDOWN
	drill_cooldown_timer.one_shot = true
	drill_cooldown_timer.timeout.connect(_on_drill_cooldown_finished)
	add_child(drill_cooldown_timer)

	drill_duration_timer = Timer.new()
	drill_duration_timer.wait_time = DRILL_DURATION
	drill_duration_timer.one_shot = true
	drill_duration_timer.timeout.connect(deactivate_drill)
	add_child(drill_duration_timer)

	# --- 스테이지 2 관련 초기화 ---
	ice_map_layer = get_tree().get_first_node_in_group("ground_tilemap")
	if ice_map_layer != null:
		emit_signal("freeze_gauge_changed", current_freeze_gauge, max_freeze_gauge)
	
	# --- 체력 신호 발생 ---
	emit_signal("health_updated", hp)
	
	# --- 파츠 시스템 초기화 ---
	var player_data = get_node_or_null("/root/PlayerData")
	if is_instance_valid(player_data):
		for i in range(player_data.equipped_parts.size()):
			if i < equipped_parts.size():
				equipped_parts[i] = player_data.equipped_parts[i]
				
	for i in range(equipped_parts.size()):
		equip_part(equipped_parts[i], i)
	_update_part_icon_display(equipped_parts[0])


func _physics_process(delta):
	# --- 스킬 활성화 처리 ---
	# 파츠 시스템 스킬
	if Input.is_action_just_pressed("skill_2"):
		if is_instance_valid(current_skill_nodes[1]):
			current_skill_nodes[1].activate()
	if Input.is_action_just_pressed("skill_3"):
		if is_instance_valid(current_skill_nodes[2]):
			current_skill_nodes[2].activate()
	# 드릴 스킬
	if Input.is_action_just_pressed("skill_1") and drill_cooldown_timer.is_stopped():
		activate_drill()

	# 드릴 스킬 이펙트 위치 업데이트
	if is_drill_active and is_instance_valid(current_bright_spot_instance):
		current_bright_spot_instance.global_position = global_position
		
	# --- 중력 ---
	if not is_on_floor():
		velocity.y += gravity * delta

	# --- 스테이지 2: 바닥 타입 체크 & 동결 게이지 업데이트 ---
	if is_instance_valid(ice_map_layer):
		if ice_map_layer.has_method("get_player_floor_type"):
			current_floor_type = ice_map_layer.get_player_floor_type(self)
			is_on_ice = (current_floor_type == "ICE")
		else: is_on_ice = false
		update_freeze_gauge(delta)
	else: is_on_ice = false

	# --- 이동 처리 ---
	var direction = Input.get_axis("move_left", "move_right")
	if is_drill_active:
		velocity.x = direction * MAX_SPEED
	else:
		var accel = ACCELERATION
		var friction = FRICTION
		var speed = MAX_SPEED
		if is_frozen:
			speed = MAX_SPEED * 0.5
			accel = ACCELERATION * 0.5
		if is_on_ice:
			if is_frozen: accel = ACCELERATION_ICE_ORIGINAL * 0.5
			else: accel = ACCELERATION_ICE_ORIGINAL
			friction = FRICTION_ICE
		if direction:
			velocity.x = move_toward(velocity.x, direction * speed, accel * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	move_and_slide()

	# --- 포신 각도 조절 및 사운드 ---
	var aim_direction = Input.get_axis("aim_up", "aim_down")
	if aim_direction != 0 and not is_drill_active:
		cannon_pivot.rotation += aim_direction * AIM_SPEED * delta
		cannon_pivot.rotation = clamp(cannon_pivot.rotation, -PI, 0.0)
		if not barrel_sound_player.playing: barrel_sound_player.play()
	else:
		if barrel_sound_player.playing: barrel_sound_player.stop()

	# --- 발사 및 차지 로직 ---
	if can_fire and not is_drill_active:
		if Input.is_action_just_pressed("fire"):
			is_charging = true
			charge_sound_player.play()
			current_power = MIN_FIRE_POWER
			charge_direction = 1
			if charge_bar: charge_bar.value = current_power
		if is_charging and Input.is_action_pressed("fire"):
			current_power += CHARGE_RATE * charge_direction * delta
			if current_power >= MAX_FIRE_POWER:
				current_power = MAX_FIRE_POWER
				charge_direction = -1
			elif current_power <= MIN_FIRE_POWER:
				current_power = MIN_FIRE_POWER
				charge_direction = 1
			if charge_bar: charge_bar.value = current_power
			update_trajectory_guide()
		if is_charging and Input.is_action_just_released("fire"):
			is_charging = false
			charge_sound_player.stop()
			can_fire = false 
			if trajectory_drawer: trajectory_drawer.update_trajectory([])
			fire_bullet(current_power)
			if cooldown_timer: 
				cooldown_timer.start()
				if charge_bar: setup_bar_for_cooldown()
	elif charge_bar and cooldown_timer and not is_drill_active:
		charge_bar.value = cooldown_timer.time_left

	# --- 스킬 UI 업데이트 ---
	if skill_slot_1_ui and not drill_cooldown_timer.is_stopped():
		skill_slot_1_ui.update_display(drill_cooldown_timer.time_left)

	# --- 스테이지 3: 셰이더 업데이트 ---
	var game_manager = get_node_or_null("/root/TitleMap/GameManager")
	if background and background.material and game_manager and not game_manager.is_darkness_active:
		update_shader_lights()


# ==============================================================================
#  3. 커스텀 함수 (Custom Functions)
# ==============================================================================

# --- 파츠 및 스킬 시스템 ---
func equip_part(new_part: Part, slot_index: int):
	if slot_index < 0 or slot_index >= skill_slots.size():
		printerr("Invalid slot_index for equip_part: ", slot_index)
		return

	var target_slot_node = skill_slots[slot_index]
	var current_skill_node_in_slot = current_skill_nodes[slot_index]

	if is_instance_valid(current_skill_node_in_slot):
		current_skill_node_in_slot.queue_free()
		current_skill_nodes[slot_index] = null

	equipped_parts[slot_index] = new_part
	
	if slot_index == 0: _update_part_icon_display(equipped_parts[0])
	
	if skill_icon_textures.size() > slot_index and is_instance_valid(skill_icon_textures[slot_index]):
		if is_instance_valid(new_part) and is_instance_valid(new_part.part_texture):
			skill_icon_textures[slot_index].texture = new_part.part_texture
			skill_icon_textures[slot_index].visible = true
		else:
			skill_icon_textures[slot_index].texture = null
			skill_icon_textures[slot_index].visible = false

	if is_instance_valid(new_part) and new_part.skill_scene:
		var skill_instance = new_part.skill_scene.instantiate()
		target_slot_node.add_child(skill_instance)
		current_skill_nodes[slot_index] = skill_instance

		if skill_instance.has_signal("cooldown_started"):
			skill_instance.cooldown_started.connect(Callable(self, "_on_skill_cooldown_started").bind(slot_index))
		if skill_instance.has_signal("cooldown_progress"):
			skill_instance.cooldown_progress.connect(Callable(self, "_on_skill_cooldown_progress").bind(slot_index))
		if skill_instance.has_signal("cooldown_finished"):
			skill_instance.cooldown_finished.connect(Callable(self, "_on_skill_cooldown_finished").bind(slot_index))

func _update_part_icon_display(part_resource: Part):
	if not is_instance_valid(part_icon_sprite): return
	
	if is_instance_valid(part_resource) and is_instance_valid(part_resource.part_texture):
		part_icon_sprite.texture = part_resource.part_texture
		part_icon_sprite.visible = true
	else:
		part_icon_sprite.texture = null
		part_icon_sprite.visible = false

func set_next_projectile(projectile_scene: PackedScene, power: float, skill_node: Node):
	next_shot_skill_data = {"scene": projectile_scene, "power": power, "skill_node": skill_node}

# --- 발사 및 데미지 관련 ---
func fire_bullet(power: float):
	var projectile_scene_to_use: PackedScene
	var projectile_power_to_use: float
	var skill_node_that_fired: Node = null

	if not next_shot_skill_data.is_empty() and is_instance_valid(next_shot_skill_data["skill_node"]):
		projectile_scene_to_use = next_shot_skill_data["scene"]
		projectile_power_to_use = next_shot_skill_data["power"]
		skill_node_that_fired = next_shot_skill_data["skill_node"]
		next_shot_skill_data = {}
		
		if is_instance_valid(skill_node_that_fired) and skill_node_that_fired.has_method("_on_shot_fired"):
			skill_node_that_fired._on_shot_fired()
	else:
		projectile_scene_to_use = bullet_scene
		projectile_power_to_use = power

	if not projectile_scene_to_use:
		printerr("Player cannot fire: No projectile scene set!")
		return
	
	# 발사 사운드 재생
	_play_sound("res://스테이지3/sound/fireSound.mp3", -3)
	
	var bullet = projectile_scene_to_use.instantiate()
	get_parent().add_child(bullet)
	
	# 공통 설정
	if "owner_node" in bullet: bullet.owner_node = self
	if bullet.has_method("set_shooter"): bullet.set_shooter(self)

	bullet.global_position = fire_point.global_position
	bullet.global_rotation = cannon_pivot.global_rotation
	bullet.linear_velocity = bullet.transform.x * projectile_power_to_use
	
	# 스테이지별 설정
	if bullet.has_method("set_current_stage"):
		var current_scene_path = get_tree().current_scene.scene_file_path
		bullet.set_current_stage(current_scene_path)
	
	if projectile_scene_to_use == bullet_scene:
		bullet.set_collision_layer_value(3, true)
		# collision_mask에 (1 << 6)을 추가하여 boss_gimmick 레이어와 충돌하도록 함
		bullet.collision_mask = (1 << 0) | (1 << 3) | (1 << 6) | (1 << 7)

	if bullet.has_method("set_explosion_radius"):
		if get_tree().current_scene.scene_file_path.contains("스테이지2"):
			bullet.set_explosion_radius(player_explosion_radius)
		else: bullet.set_explosion_radius(1.0)
			
	if bullet.has_method("set_projectile_scale"):
		if projectile_scene_to_use.resource_path.contains("homing"):
			bullet.set_projectile_scale(Vector2(2.0, 2.0))
		else: bullet.set_projectile_scale(player_projectile_scale)


func take_damage(amount):
	if is_drill_active: return # 드릴 활성화 시 무적
	
	_play_sound("res://스테이지3/sound/playerHit.mp3", 5)
	hp = max(hp - amount, 0)
	
	if health_bar: update_health_bar()
	emit_signal("health_updated", hp)
	
	var tween = create_tween().set_loops(2)
	tween.tween_property(self, "modulate", Color.RED, 0.15)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	
	if hp <= 0:
		await tween.finished
		emit_signal("game_over")
		queue_free()

# --- 드릴 스킬 관련 ---
func activate_drill():
	_play_sound("res://스테이지3/sound/drillSkill.mp3", -5)
	is_drill_active = true
	drill_duration_timer.start()
	drill_cooldown_timer.start()
	if skill_slot_1_ui: skill_slot_1_ui.start_cooldown(DRILL_COOLDOWN)
	
	$CannonPivot.hide()
	$Sprite2D.hide()
	$PointLight2D.hide()
	$CollisionShape2D.set_deferred("disabled", true)
	$Hitbox/CollisionShape2D.set_deferred("disabled", true)
	MAX_SPEED = original_max_speed * DRILL_SPEED_MULTIPLIER
	
	if player_bright_spot_scene:
		current_bright_spot_instance = player_bright_spot_scene.instantiate()
		get_parent().add_child(current_bright_spot_instance)
		current_bright_spot_instance.global_position = global_position

func deactivate_drill():
	is_drill_active = false
	if is_instance_valid(current_bright_spot_instance):
		current_bright_spot_instance.queue_free()
	
	MAX_SPEED = original_max_speed
	$CollisionShape2D.set_deferred("disabled", false)
	$Hitbox/CollisionShape2D.set_deferred("disabled", false)
	
	var tween = create_tween()
	$CannonPivot.modulate.a = 0
	$Sprite2D.modulate.a = 0
	$PointLight2D.modulate.a = 0
	$CannonPivot.show()
	$Sprite2D.show()
	$PointLight2D.show()
	tween.tween_property($CannonPivot, "modulate:a", 1.0, 1.0)
	tween.parallel().tween_property($Sprite2D, "modulate:a", 1.0, 1.0)
	tween.parallel().tween_property($PointLight2D, "modulate:a", 1.0, 1.0)

# --- 궤적 예측 ---
func update_trajectory_guide():
	if not is_instance_valid(trajectory_drawer): return
	var points = calculate_trajectory_points()
	var local_points = []
	for p in points:
		local_points.append(to_local(p))
	trajectory_drawer.update_trajectory(local_points)

func calculate_trajectory_points() -> Array:
	var points = []
	var gravity_val = ProjectSettings.get_setting("physics/2d/default_gravity")
	var current_pos = fire_point.global_position
	var current_velocity = Vector2.RIGHT.rotated(cannon_pivot.global_rotation) * current_power
	var time_step = 0.05
	var max_steps = 100
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.new()
	query.exclude = [self]
	query.collision_mask = 1 # Check for collision with world geometry
	
	for i in range(max_steps):
		current_velocity.y += gravity_val * time_step
		var next_pos = current_pos + current_velocity * time_step
		query.from = current_pos
		query.to = next_pos
		var result = space_state.intersect_ray(query)
		if result:
			points.append(result.position)
			break
		else:
			if i % 2 == 0:
				points.append(current_pos)
			current_pos = next_pos
	return points
	
# --- 유틸리티 함수 ---
func _play_sound(sound_path, volume_db = 0):
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = load(sound_path)
	sfx_player.volume_db = volume_db
	sfx_player.bus = "SFX" # SFX 버스로 라우팅
	add_child(sfx_player)
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)


# ==============================================================================
#  4. HUD 및 시각 효과 (HUD & Visuals)
# ==============================================================================

func update_health_bar():
	if not health_bar: return
	health_bar.value = hp
	var health_ratio = float(hp) / float(max_hp)
	var current_color = HEALTH_FULL_COLOR.lerp(HEALTH_EMPTY_COLOR, 1.0 - health_ratio)
	
	var stylebox_original = health_bar.get_theme_stylebox("fill")
	if stylebox_original:
		var stylebox_copy = stylebox_original.duplicate()
		stylebox_copy.bg_color = current_color
		health_bar.add_theme_stylebox_override("fill", stylebox_copy)

func setup_bar_for_charging():
	if not charge_bar: return
	charge_bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END
	charge_bar.min_value = MIN_FIRE_POWER
	charge_bar.max_value = MAX_FIRE_POWER
	charge_bar.value = MIN_FIRE_POWER
	
	var stylebox_original = charge_bar.get_theme_stylebox("fill")
	if stylebox_original:
		var stylebox_copy = stylebox_original.duplicate()
		stylebox_copy.bg_color = CHARGE_COLOR
		charge_bar.add_theme_stylebox_override("fill", stylebox_copy)

func setup_bar_for_cooldown():
	if not charge_bar or not cooldown_timer: return
	charge_bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END
	charge_bar.min_value = 0.0
	charge_bar.max_value = COOLDOWN_DURATION
	charge_bar.value = COOLDOWN_DURATION
	
	var stylebox_original = charge_bar.get_theme_stylebox("fill")
	if stylebox_original:
		var stylebox_copy = stylebox_original.duplicate()
		stylebox_copy.bg_color = COOLDOWN_COLOR
		charge_bar.add_theme_stylebox_override("fill", stylebox_copy)


func update_shader_lights():
	var light_positions = []
	light_positions.append(background.to_local(global_position))
	var bullets = get_tree().get_nodes_in_group("bullets")
	for bullet in bullets:
		bullet_path_points.append({"position": background.to_local(bullet.global_position), "timestamp": Time.get_ticks_msec()})

	var current_time = Time.get_ticks_msec()
	bullet_path_points = bullet_path_points.filter(func(point):
		return current_time - point.timestamp < BULLET_PATH_DURATION * 1000
	)
	bullet_path_points.sort_custom(func(a, b): return a.timestamp > b.timestamp)

	var max_points = 127
	var points_to_add = bullet_path_points.slice(0, min(bullet_path_points.size(), max_points))

	for point in points_to_add:
		light_positions.append(point.position)
	
	if background.material:
		background.material.set_shader_parameter("light_positions", light_positions)
		background.material.set_shader_parameter("light_count", light_positions.size())

# ==============================================================================
#  5. 신호 콜백 (Signal Callbacks)
# ==============================================================================

func _on_cooldown_timer_timeout():
	can_fire = true
	if charge_bar: setup_bar_for_charging()

func _on_hitbox_body_entered(body):
	if body.is_in_group("bullets") or body.is_in_group("boss_bullets"):
		if "owner_node" in body and body.owner_node == self: return
		if "shooter" in body and body.shooter == self: return

		take_damage(10)
		if body.has_method("explode"): body.explode()
		else: body.queue_free()

func _on_hitbox_area_entered(area):
	if area.is_in_group("stalactites") and area.is_falling:
		take_damage(20)

func _on_drill_cooldown_finished():
	if skill_slot_1_ui: skill_slot_1_ui.update_display(0)
	GlobalMessageBox.add_message("Drill 스킬 사용 가능합니다!")

# --- 파츠 스킬 UI 핸들러 ---
func _on_skill_cooldown_started(duration: float, slot_index: int):
	if slot_index < 0 or slot_index >= skill_cooldown_progress_bars.size() or not is_instance_valid(skill_cooldown_progress_bars[slot_index]): return
	var progress_bar = skill_cooldown_progress_bars[slot_index]
	progress_bar.max_value = duration
	progress_bar.value = duration
	progress_bar.visible = true

func _on_skill_cooldown_progress(time_left: float, slot_index: int):
	if slot_index < 0 or slot_index >= skill_cooldown_progress_bars.size() or not is_instance_valid(skill_cooldown_progress_bars[slot_index]): return
	var progress_bar = skill_cooldown_progress_bars[slot_index]
	progress_bar.value = time_left

func _on_skill_cooldown_finished(slot_index: int):
	if slot_index < 0 or slot_index >= skill_cooldown_progress_bars.size() or not is_instance_valid(skill_cooldown_progress_bars[slot_index]): return
	var progress_bar = skill_cooldown_progress_bars[slot_index]
	progress_bar.value = 0
	progress_bar.visible = false

# ==============================================================================
#  6. 스테이지 2 특정 함수 (Stage 2 Specific Functions)
# ==============================================================================

func update_freeze_gauge(delta: float):
	if is_warming_up:
		current_freeze_gauge = max(current_freeze_gauge - warm_rate * delta, 0.0)
	elif current_floor_type == "ICE":
		current_freeze_gauge = min(current_freeze_gauge + FREEZE_RATE_ICE * delta, max_freeze_gauge)
	elif current_floor_type == "MELTED":
		current_freeze_gauge = min(current_freeze_gauge + FREEZE_RATE_MELTED * delta, max_freeze_gauge)
	
	emit_signal("freeze_gauge_changed", current_freeze_gauge, max_freeze_gauge)
	
	if current_freeze_gauge >= max_freeze_gauge and not is_frozen:
		is_frozen = true
		_play_sound("res://스테이지2/sound/SFX_Skill_IceWind_Cast_Burst_[cut_1sec].mp3", -10) # 냉동 게이지 얼어붙는 소리
		GlobalMessageBox.add_message("시스템 동결!")
		GlobalMessageBox.add_message("기동력이 50%로 제한됩니다.")
		apply_freeze_debuff(true)
	elif current_freeze_gauge == 0 and is_frozen:
		is_frozen = false
		GlobalMessageBox.add_message("시스템 정상화.")
		GlobalMessageBox.add_message("기동력이 복구되었습니다.")
		apply_freeze_debuff(false)

func apply_freeze_debuff(frozen: bool):
	if frozen:
		pass # 디버프 효과는 _physics_process에서 직접 처리
	else:
		pass 

func start_warming_up():
	is_warming_up = true

func stop_warming_up():
	is_warming_up = false
