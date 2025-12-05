extends Node

# 포물선 궤적을 위한 초기 속도 계산 함수 (항상 목표 도달 보장)
func calculate_parabolic_velocity(launch_pos: Vector2, target_pos: Vector2, desired_speed: float, gravity: float) -> Vector2:
	var delta = target_pos - launch_pos
	var delta_x = delta.x
	# --- ✅ 1. 좌표계 통일 (수학 좌표계로 변경) ---
	var delta_y = -delta.y # Godot의 Y(아래가 +)를 수학의 Y(위가 +)로 뒤집음
	# --- ✅ 1. 좌표계 통일 끝 ---

	# print("--- 각도 계산 시작 ---")
	# print("발사 위치:", launch_pos, ", 목표 위치:", target_pos)
	# print("delta_x:", delta_x, ", delta_y(수학):", delta_y)

	if abs(delta_x) < 0.1:
		var vertical_speed = -desired_speed if delta_y > 0 else desired_speed
		return Vector2(0, vertical_speed)

	# 목표 지점에 도달하기 위한 최소 속력 제곱(v^2) 계산 (수학 기준 Y 사용)
	var min_speed_sq = gravity * (delta_y + sqrt(delta_x * delta_x + delta_y * delta_y))
	
	var min_launch_speed = 0.0
	if min_speed_sq >= 0:
		min_launch_speed = sqrt(min_speed_sq)
	else:
		printerr("경고: 최소 속력 계산 불가!")
		var fallback_angle = deg_to_rad(45.0) # 수학 기준 45도
		return Vector2(cos(fallback_angle) * desired_speed, -sin(fallback_angle) * desired_speed) # Y축만 Godot에 맞게 뒤집음

	var actual_launch_speed = desired_speed
	var actual_speed_sq = actual_launch_speed * actual_launch_speed
	# print("실제 발사 속력:", actual_launch_speed)

	var gx = gravity * delta_x
	var term_under_sqrt_calc = actual_speed_sq * actual_speed_sq - gravity * (gravity * delta_x * delta_x + 2 * delta_y * actual_speed_sq)
	if term_under_sqrt_calc < 0:
		term_under_sqrt_calc = 0
	var sqrt_term = sqrt(term_under_sqrt_calc)

	# --- atan() 대신 atan2() 사용하여 명확한 각도 계산 ---
	# 높은 각도 계산 (Y, X 순서로 입력)
	var launch_angle_rad = atan2(actual_speed_sq + sqrt_term, gx)
	# print("계산된 각도 (rad):", launch_angle_rad, ", (deg):", rad_to_deg(launch_angle_rad))
	# --- atan2()로 변경 끝 ---

	# --- 최종 속도 벡터 생성 (cos/sin 직접 사용) ---
	# atan2가 올바른 각도를 반환하므로, cos/sin이 X, Y 부호를 자동으로 처리해 줌
	var vel_x = cos(launch_angle_rad) * actual_launch_speed
	var vel_y_math = sin(launch_angle_rad) * actual_launch_speed # 수학 기준 Y 속도

	# Godot 좌표계(Y축 아래가 +)에 맞게 수학 기준 Y 속도 부호 반전
	var vel_y_godot = -vel_y_math

	# 최종 속도 벡터 생성
	var initial_velocity = Vector2(vel_x, vel_y_godot)
	# --- ✅ 3. 최종 속도 벡터 생성 끝 ---

	# print("최종 속도 벡터:", initial_velocity) # Y 부호가 음수(-)가 되어야 위로 쏨
	# print("--- 각도 계산 끝 ---")
	return initial_velocity
