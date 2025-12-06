extends Area2D

@export var on_texture: Texture2D
@export var off_texture: Texture2D

@onready var sprite = $Sprite2D
@onready var light_timer = $LightTimer
@onready var point_light = $PointLight2D
@onready var collision_shape = $CollisionShape2D

var is_locked = false

func _ready():
	add_to_group("torch")
	sprite.texture = off_texture
	light_timer.one_shot = true
	light_timer.wait_time = 30
	body_entered.connect(_on_body_entered)
	light_timer.timeout.connect(_on_light_timer_timeout)

# 일회성 사운드를 재생하는 헬퍼 함수
func _play_sound(sound_path, volume_db = 0):
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = load(sound_path)
	sfx_player.volume_db = volume_db
	add_child(sfx_player)
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)

# 보스의 은신이 시작될 때 호출되어 횃불을 강제로 끄고 잠급니다.
func extinguish_and_lock():
	# 횃불이 이미 꺼져있지 않다면 소화 사운드 재생
	if point_light.enabled:
		_play_sound("res://스테이지3/sound/extinguish.mp3")

	is_locked = true
	light_timer.stop()
	sprite.texture = off_texture
	point_light.enabled = false
	collision_shape.set_deferred("disabled", true)

# 보스의 은신이 끝날 때 호출되어 횃불을 다시 켤 수 있도록 잠금을 해제합니다.
func unlock():
	is_locked = false
	collision_shape.set_deferred("disabled", false)

func _on_body_entered(body):
	# 잠겨있지 않고, 꺼져있는 상태일 때만 켤 수 있음
	if not is_locked and light_timer.is_stopped():
		if body.is_in_group("player_bullets"):
			# --- 점화 사운드 재생 ---
			_play_sound("res://스테이지3/sound/ignition.mp3")

			sprite.texture = on_texture
			point_light.enabled = true
			light_timer.start()
			if body.has_method("explode"):
				body.explode()
			else:
				body.queue_free()

func _on_light_timer_timeout():
	if is_locked: return
	
	# --- 소화 사운드 재생 ---
	_play_sound("res://스테이지3/sound/extinguish.mp3")
	
	sprite.texture = off_texture
	point_light.enabled = false
