extends CPUParticles2D

func _ready():
	# 이 노드가 카메라의 자식이라고 가정합니다.
	var camera = get_parent()
	if not (camera is Camera2D):
		print("경고: SnowEffect는 Camera2D의 자식 노드여야 제대로 작동합니다.")
		return

	# 카메라의 줌 값과 뷰포트 크기를 고려하여 파티클 이미터의 위치와 크기를 조정합니다.
	var viewport_size = get_viewport_rect().size
	
	# 1. 위치 조정: 카메라 뷰의 상단 중앙으로 이동
	#    로컬 Y 위치를 (뷰포트 높이의 절반 / Y축 줌) 만큼 위로 올립니다.
	position.y = - (viewport_size.y / 2.0) / camera.zoom.y
	
	# 2. 방출 영역 너비 조정: 카메라 뷰의 너비에 맞게 설정
	#    파티클의 방출 사각형(emission_rect) 너비를 (뷰포트 너비 / X축 줌)으로 설정합니다.
	emission_rect_extents.x = viewport_size.x / camera.zoom.x
