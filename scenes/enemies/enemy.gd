extends CharacterBody2D

@onready var player = get_node("/root/game/character")
@onready var hurtbox = $HurtBox
@onready var hp_bar = $HPBar # Teraz szuka paska nad swoją głową

const GRAVITY_STRENGTH = 5800.0
const MIN_DISTANCE = 80.0
const SEPARATION_RADIUS = 150.0
const SEPARATION_FORCE = 60000.0
const MAX_SPEED = 1500.0
const MAX_HP = 3
const DAMAGE = 1
const XP_VALUE = 25

var hp = MAX_HP

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 1
	hurtbox.area_entered.connect(_on_hurtbox_entered)
	
	if hp_bar:
		hp_bar.max_value = MAX_HP
		hp_bar.value = hp

	var to_player = player.global_position - global_position
	var direction = to_player.normalized()
	var tangent = Vector2(-direction.y, direction.x)
	var dist = to_player.length()
	var orbital_speed = sqrt(GRAVITY_STRENGTH * dist)
	var sign = 1.0 if randf() > 0.5 else -1.0
	velocity = tangent * orbital_speed * sign

func _on_hurtbox_entered(area: Area2D) -> void:
	if area.is_in_group("projectile"):
		take_damage(area.damage)

func take_damage(amount: int) -> void:
	hp -= amount
	if hp_bar:
		hp_bar.value = hp
		
	if hp <= 0:
		if player and player.has_method("gain_xp"):
			player.gain_xp(XP_VALUE)
		queue_free()

func _physics_process(delta: float) -> void:
	if player == null:
		return

	var to_player = player.global_position - global_position
	var distance = max(to_player.length(), MIN_DISTANCE)
	var direction = to_player.normalized()

	velocity += direction * GRAVITY_STRENGTH * delta

	for body in get_tree().get_nodes_in_group("enemies"):
		if body == self:
			continue
		var to_other = global_position - body.global_position
		var dist = to_other.length()
		if dist < SEPARATION_RADIUS and dist > 0.0:
			velocity += to_other.normalized() * (SEPARATION_FORCE / max(dist * dist, 1.0)) * delta

	if velocity.length() > MAX_SPEED:
		velocity = velocity.normalized() * MAX_SPEED

	move_and_slide()
