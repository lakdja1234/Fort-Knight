extends Control

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var label: Label = $Label

# 인스펙터에서 추적할 온열장치의 노드 이름을 설정합니다.
@export var heater_name: String = ""

func _ready():
	# 씬 트리가 준비될 때까지 기다립니다.
	await get_tree().process_frame
	
	# 온열장치 노드를 찾고 시그널에 연결합니다.
	var heaters = get_tree().get_nodes_in_group("heaters")
	
	var found_heater = false
	for heater in heaters:
		if heater.name == heater_name:
			# 시그널 연결
			heater.health_updated.connect(_on_heater_health_updated)
			
			# 초기값 설정
			if "hp" in heater and "max_hp" in heater:
				_on_heater_health_updated(heater.hp, heater.max_hp, heater.name)
			
			found_heater = true
			# 일치하는 히터를 찾았으면 루프 종료
			break
			
	# 온열장치의 체력이 업데이트될 때 호출되는 함수
func _on_heater_health_updated(current_hp: int, max_hp: int, name: String):
	
	# 이 UI가 담당하는 온열장치가 맞는지 다시 한 번 확인
	if name != heater_name:
		return
		
	# ProgressBar 업데이트
	progress_bar.max_value = max_hp
	progress_bar.value = current_hp
	
	# Label 텍스트 업데이트
	label.text = "%d / %d" % [current_hp, max_hp]
	
	# 체력이 0이면 UI 숨기기 (선택 사항)
	if current_hp <= 0:
		visible = false
