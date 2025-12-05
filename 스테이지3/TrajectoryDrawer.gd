extends Node2D

var trajectory_points: Array = []
var point_color: Color = Color(1.0, 1.0, 1.0, 0.7)
var point_radius: float = 3.0

func _draw():
	if trajectory_points.is_empty():
		return
	
	for point in trajectory_points:
		draw_circle(point, point_radius, point_color)

func update_trajectory(points: Array):
	trajectory_points = points
	queue_redraw()
