extends Area2D

signal destroyed

@export var explosion_scene: PackedScene 

var is_falling = false
var is_invulnerable = false # 깜빡이는 동안 무적 상태인지 확인하는 플래그
const GRAVITY = 980.0
var velocity = Vector2.ZERO
var warning_sign: Sprite2D = null

# 사용할 낙하 사운드 파일 목록을 미리 로드
var fall_sounds = [
	load("res://스테이지3/sound/stalFall1.mp3"),
	load("res://스테이지3/sound/stalFall2.mp3"),
	load("res://스테이지3/sound/stalFall3.mp3"),
	load("res://스테이지3/sound/stalFall4.mp3")
]

@onready var sprite = $Sprite2D

func _ready():
	collision_layer = 128
	collision_mask = 15
	explosion_scene = load("res://스테이지3/stalactiteExplosion.tscn")

func _physics_process(delta):
	if is_falling:
		velocity.y += GRAVITY * delta
		global_position += velocity * delta

func _on_body_entered(body):
	if is_invulnerable: return

	if not is_falling:
		if body.is_in_group("player_bullets"):
			if body.has_method("explode"): body.explode()
			else: body.queue_free()
			call_deferred("start_fall", true)
		return

	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(20)
	elif body.is_in_group("player_bullets"):
		if body.has_method("explode"): body.explode()
	elif body.is_in_group("boss"):
		if body.has_method("take_damage"):
			body.take_damage(20)
	
	explode_and_disappear()

# 일회성 사운드를 재생하는 헬퍼 함수
func _play_sound(sound_path, volume_db = 0):
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = load(sound_path)
	sfx_player.volume_db = volume_db
	add_child(sfx_player)
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)

func start_fall(triggered_by_player := false):
	if is_falling or is_invulnerable: return

	# --- 낙하 시작 사운드 재생 ---
	_play_sound("res://스테이지3/sound/stalShake1Sec.mp3", -8)

	var player = get_tree().get_first_node_in_group("player")
	if player:
		warning_sign = Sprite2D.new()
		warning_sign.texture = load("res://스테이지3/Img/warning.png")
		var stalactite_width = (sprite.get_rect().size * sprite.scale).x
		var warning_original_width = warning_sign.texture.get_size().x
		var scale_factor = (stalactite_width / warning_original_width) * 3
		warning_sign.scale = Vector2(scale_factor, scale_factor)
		var target_y = player.global_position.y - 50.0 
		warning_sign.global_position = Vector2(global_position.x, target_y)
		get_parent().add_child(warning_sign)

	if not triggered_by_player:
		var boss = get_tree().get_first_node_in_group("boss")
		if boss and boss.is_hiding:
			var camera = get_tree().get_first_node_in_group("camera")
			if camera and camera.has_method("shake"):
				camera.shake(5.0, 0.3)
	
	is_invulnerable = true
	var tween = create_tween().set_loops(2)
	tween.tween_property($Sprite2D, "modulate", Color.RED, 0.25)
	tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.25)
	tween.finished.connect(_on_fall_tween_finished)

func _on_fall_tween_finished():
	is_invulnerable = false
	is_falling = true
	velocity = Vector2.ZERO

func explode_and_disappear():
	if is_queued_for_deletion(): return
	
	# --- 충돌 사운드 재생 ---
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = fall_sounds.pick_random() # 미리 로드된 사운드 중 하나를 무작위로 선택
	sfx_player.volume_db = -3
	add_child(sfx_player)
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)

	if is_instance_valid(warning_sign):
		warning_sign.queue_free()
	
	emit_signal("destroyed")
	
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		explosion.global_position = self.global_position
		get_parent().add_child(explosion)
	
	queue_free()

func _on_screen_exited():
	if is_falling:
		explode_and_disappear()
