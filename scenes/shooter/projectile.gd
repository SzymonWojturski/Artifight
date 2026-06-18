extends Area2D

var direction: Vector2
var damage: int = 1
var base_speed: float = 350.0
var lifetime: float = 6.0      # czas życia (statystyka Lifetime miecza)
var size_factor: float = 1.0   # mnożnik wielkości (statystyka Size miecza)
var pierce: int = 0            # ile dodatkowych wrogów przebija (statystyka Pierce miecza)

const GRAVITY_STRENGTH = 1200.0
const MIN_DISTANCE = 20.0
const MAX_SPEED = 1200.0
const PLAYER_GRACE = 0.5

var time := 0.0
var vel := Vector2.ZERO

func _ready() -> void:
	add_to_group("projectile")
	rotation = direction.angle() + deg_to_rad(90)
	vel = direction.normalized() * base_speed
	scale *= size_factor
	area_entered.connect(_on_area_entered)

# wołane przez wroga, gdy ten oberwie tym pociskiem
func on_hit() -> void:
	if pierce > 0:
		pierce -= 1
	else:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_body"):
		area.get_parent().take_damage(damage)
		on_hit()
	elif area.is_in_group("player_hurtbox") and time > PLAYER_GRACE:
		area.get_parent().take_damage(damage)
		queue_free()

func _physics_process(delta: float) -> void:
	time += delta

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var to_enemy = enemy.global_position - global_position
		var _dist = max(to_enemy.length(), MIN_DISTANCE)
		vel += to_enemy.normalized() * GRAVITY_STRENGTH * delta

	var player = get_node_or_null("/root/game/character")
	if player:
		var to_player = player.global_position - global_position
		vel += to_player.normalized() * GRAVITY_STRENGTH * delta

	if vel.length() > MAX_SPEED:
		vel = vel.normalized() * MAX_SPEED

	global_position += vel * delta
	rotation = vel.angle() + deg_to_rad(90)

	if time >= lifetime:
		queue_free()
