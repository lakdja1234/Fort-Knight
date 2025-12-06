# fortknight-godot/스테이지3/MessageBox.gd
extends CanvasLayer

# 이 스크립트는 게임 내에서 발생하는 이벤트 메시지를 화면에 표시하는 UI를 관리합니다.
# CanvasLayer를 상속하여 다른 모든 UI 요소들 위에 그려지도록 보장합니다.
# 이 씬은 project.godot에서 "GlobalMessageBox"라는 이름의 오토로드(싱글톤)로 등록되어,
# 게임 내 어디서든 접근하여 메시지를 추가할 수 있습니다.

# --- 노드 참조 ---
# @onready는 씬 트리가 준비되었을 때 노드를 안전하게 가져옵니다.
# message_container는 메시지 라벨들이 추가될 VBoxContainer입니다.
@onready var message_container = $MessageBox/MarginContainer/VBoxContainer
@onready var message_box_panel = $MessageBox

func _process(_delta):
	# 현재 씬이 유효한지 확인합니다.
	if get_tree().current_scene == null:
		self.visible = false # 씬이 없으면 CanvasLayer 자체를 숨김
		return

	var current_scene_path = get_tree().current_scene.scene_file_path
	
	# 메시지 박스를 보여줄 특정 씬 경로들의 화이트리스트
	var whitelist_scenes = [
		"res://스테이지1/Scenes/stage1.tscn",
		"res://스테이지2/스테이지2.tscn",
		"res://스테이지3/map.tscn"
	]
	
	if current_scene_path in whitelist_scenes:
		self.visible = true # 화이트리스트에 있으면 CanvasLayer를 보이게 함
		message_box_panel.visible = true # 패널도 보이게 함
	else:
		self.visible = false # 화이트리스트에 없으면 CanvasLayer 자체를 숨김
		message_box_panel.visible = false # 패널도 숨김

# add_message: 새로운 메시지를 메시지 박스에 추가하는 핵심 함수입니다.
# text: 표시할 메시지 문자열
# duration: 메시지가 화면에 머무는 시간 (초)
func add_message(text: String, duration: float = 3.0):
	# 1. 새로운 RichTextLabel 노드를 동적으로 생성합니다.
	# RichTextLabel은 자동 줄바꿈(autowrap) 기능을 지원합니다.
	var label = RichTextLabel.new()
	label.text = text
	label.fit_content = true # 내용에 맞게 높이를 조절합니다.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD # 단어 단위로 자동 줄바꿈

	# 2. 페이드인 효과를 위해 초기 투명도를 0으로 설정합니다.
	label.modulate = Color(1, 1, 1, 0)
	
	# 3. VBoxContainer에 자식으로 추가하여 화면에 배치합니다.
	message_container.add_child(label)
	
	# 4. Tween을 사용하여 0.5초 동안 서서히 나타나게 합니다 (페이드인).
	# 'modulate:a'는 노드의 알파(투명도) 속성을 의미합니다.
	var tween_in = create_tween()
	tween_in.tween_property(label, "modulate:a", 1.0, 0.5)
	
	# 5. await 키워드를 사용하여 지정된 시간(duration)만큼 실행을 잠시 멈춥니다.
	# get_tree().create_timer()는 일회용 타이머를 생성합니다.
	await get_tree().create_timer(duration).timeout
	
	# 6. 지정된 시간이 지나면, Tween을 사용하여 0.5초 동안 서서히 사라지게 합니다 (페이드아웃).
	var tween_out = create_tween()
	tween_out.tween_property(label, "modulate:a", 0.0, 0.5)
	
	# 7. 페이드아웃 애니메이션이 모두 끝나기를 기다린 후,
	# queue_free()를 호출하여 라벨 노드를 씬 트리에서 안전하게 제거하고 메모리에서 해제합니다.
	await tween_out.finished
	label.queue_free()
