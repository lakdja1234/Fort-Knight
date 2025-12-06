# stalactite.gd (Merged by Gemini)
extends Area2D

signal destroyed

@export var explosion_scene: PackedScene
const WarningScene = preload("res://스테이지3/HitboxIndicator.tscn")

var is_falling = false
var is_invulnerable = false # 깜빡이는 동안 무적 상태
const GRAVITY = 980.0
var velocity = Vector2.ZERO
var warning_indicator = null

# 사용할 낙하 사운드 파일 목록을 미리 로드 (bolt6281 버전 기능)
var fall_sounds = [
	load("res://스테이지3/sound/stalFall1.mp3"),
	load("res://스테이지3/sound/stalFall2.mp3"),
	load("res://스테이지3/sound/stalFall3.mp3"),
	load("res://스테이지3/sound/stalFall4.mp3")
]

func _ready():
	# AnimationPlayer가 있다면 'blink' 애니메이션을 재생합니다.
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("blink")

	# 폭발 씬이 지정되지 않았다면 기본값을 로드합니다.
	if explosion_scene == null:
		explosion_scene = load("res://스테이지3/stalactiteExplosion.tscn")

func _physics_process(delta):
	if is_falling:
		velocity.y += GRAVITY * delta
		global_position += velocity * delta

func _on_body_entered(body):
	if is_invulnerable: return # 무적 상태일 때는 충돌 무시

	# 아직 떨어지지 않은 상태일 때
	if not is_falling:
		# 플레이어의 총알에 맞으면 낙하 시작
		if body.is_in_group("bullets") or body.is_in_group("player_bullets"):
			if body.has_method("explode"):
				body.explode()
			else:
				body.queue_free()
			call_deferred("start_fall")
		return

	# 떨어지는 중일 때
	# 플레이어나 보스에게 피해를 줌
	if body.is_in_group("player") or body.is_in_group("boss"):
		if body.has_method("take_damage"):
			body.take_damage(20) # bolt6281 버전의 데미지 값
	
	# 어떤 물리 객체든 부딪히면 폭발
	explode()

# 일회성 사운드를 재생하는 헬퍼 함수
func _play_sound(sound_path, volume_db = 0):
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = load(sound_path)
	sfx_player.volume_player.bus = "SFX" # SFX 버스로 라우팅
	add_child(sfx_player)
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)

func start_fall():
	if is_falling or is_invulnerable: return

	is_invulnerable = true
	
	# --- 낙하 준비 사운드 재생 ---
	_play_sound("res://스테이지3/sound/stalShake1Sec.mp3", -8)

	# --- 경고 표시 생성 (HEAD 버전 방식) ---
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 2000))
	query.collision_mask = 1 # "world" 레이어
	var result = space_state.intersect_ray(query)
	
	if result:
		warning_indicator = WarningScene.instantiate()
		get_tree().root.add_child(warning_indicator)
		warning_indicator.global_position = result.position
		
		warning_indicator.get_node("Timer").stop() # 자동 파괴 타이머 중지
		
		# 종유석 크기에 맞춰 경고 표시 크기 조절
		var sprite_width = 0.0
		if $Sprite2D.texture:
			sprite_width = $Sprite2D.texture.get_width() * $Sprite2D.scale.x
			warning_indicator.set_radius(sprite_width) # HEAD의 1.5배 대신 1배로 조정
		
		# 경고 표시가 바닥 위에 위치하도록 조정
		var visual_node = warning_indicator.get_node_or_null("Sprite2D")
		if visual_node and visual_node.texture:
			var half_height = visual_node.texture.get_height() * visual_node.scale.y / 2.0
			warning_indicator.global_position.y -= half_height

	# --- 빨갛게 깜빡이는 효과 ---
	var tween = create_tween().set_loops(2)
	tween.tween_property($Sprite2D, "modulate", Color.RED, 0.25)
	tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.25)
	await tween.finished
	
	is_invulnerable = false
	is_falling = true
	velocity = Vector2.ZERO # 낙하 시작 전 속도 초기화

func explode():
	if is_queued_for_deletion(): return
	
	# --- 무작위 충돌 사운드 재생 ---
	_play_sound(fall_sounds.pick_random(), -3)

	# 경고 표시가 있다면 제거
	if is_instance_valid(warning_indicator):
		warning_indicator.queue_free()
	
	emit_signal("destroyed")
	
	# 폭발 이펙트 생성
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		explosion.global_position = self.global_position
		get_parent().add_child(explosion)
	
	queue_free()

func _on_screen_exited():
	if is_falling:
		explode()
	else:
		# 떨어지지 않고 화면 밖으로 나가는 경우 (예: 매니저가 제거)
		emit_signal("destroyed")
		queue_free()
