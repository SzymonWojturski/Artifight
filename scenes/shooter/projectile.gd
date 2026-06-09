extends Area2D

var direction: Vector2
var damage: int = 1

const ALIVE_TIME = 100.5
const GRAVITY_STRENGTH = 1200.0
const MIN_DISTANCE = 20.0
const MAX_SPEED = 2000.0
const START_SPEED = 800.0

var time := 0.0
var vel := Vector2.ZERO

func _ready() -> void:
	add_to_group("projectile")
	rotation = direction.angle() + deg_to_rad(90)
	vel = direction.normalized() * START_SPEED
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_body"):
		area.get_parent().take_damage(damage)
		queue_free()

func _physics_process(delta: float) -> void:
	time += delta

	# Przyciąganie do planet
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var to_enemy = enemy.global_position - global_position
		var dist = max(to_enemy.length(), MIN_DISTANCE)
		vel += to_enemy.normalized() * GRAVITY_STRENGTH * delta

	# Przyciąganie do gracza (żeby mógł uderzyć)
	var player = get_node_or_null("/root/game/character")
	if player:
		var to_player = player.global_position - global_position
		var dist = max(to_player.length(), MIN_DISTANCE)
		vel += to_player.normalized() * GRAVITY_STRENGTH * delta

	if vel.length() > MAX_SPEED:
		vel = vel.normalized() * MAX_SPEED

	global_position += vel * delta
	rotation = vel.angle() + deg_to_rad(90)

	if time >= ALIVE_TIME:
		queue_free()
