extends CharacterBody2D

const MOVEMENT_SPEED = 650.0
const DASH_SPEED = 3200.0
const DASH_TIME = 0.10
const DASH_IFRAMES = 0.18
const DASH_COOLDOWN = 0.20
const MAX_HP = 5

var hp = MAX_HP
var projectile_scene = preload("res://scenes/shooter/projectile.tscn")
@onready var projectile_init_point = $TileMapLayerSword/projectile_init_point
@onready var collision = $CollisionShape2D
@onready var hurtbox = $HurtBox

# ODNIESIENIA DO INTERFEJSU
@onready var hp_bar = $HPBar
@onready var xp_bar = get_node_or_null("/root/game/HUD/XPBar")
@onready var level_up_menu = get_node_or_null("/root/game/HUD/LevelUpMenu")
@onready var continue_button = get_node_or_null("/root/game/HUD/LevelUpMenu/ContinueButton")

# SYSTEM XP
var current_xp = 0
var current_level = 1
var xp_to_next_level = 100

# ZMIENNE DO ZWOLNIENIA CZASU
var is_recovering_time = false
var time_recovery_speed = 0.8 # Jak szybko czas wraca do normy (na sekundę)

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	hurtbox.area_entered.connect(_on_hurtbox_entered)
	
	# Podłączenie przycisku z menu
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	
	update_hp_bar()
	update_xp_bar()

func _on_hurtbox_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_body"):
		take_damage(1)

func take_damage(amount: int) -> void:
	if iframe_timer > 0.0:
		return
	hp -= amount
	update_hp_bar()
	
	if hp <= 0:
		Engine.time_scale = 1.0 # Reset czasu na wypadek restartu w slow-mo
		get_tree().reload_current_scene()

func update_hp_bar() -> void:
	if hp_bar:
		hp_bar.max_value = MAX_HP
		hp_bar.value = hp

func update_xp_bar() -> void:
	if xp_bar:
		xp_bar.max_value = xp_to_next_level
		xp_bar.value = current_xp

func gain_xp(amount: int) -> void:
	current_xp += amount
	update_xp_bar()
	
	if current_xp >= xp_to_next_level:
		level_up()

# WYWOŁANIE MENU I PAUZY
func level_up() -> void:
	current_xp -= xp_to_next_level
	current_level += 1
	xp_to_next_level = int(xp_to_next_level * 1.5)
	hp = MAX_HP 
	update_hp_bar()
	update_xp_bar()
	
	# Pokazujemy menu i włączamy pauzę wbudowaną w Godota
	if level_up_menu:
		level_up_menu.show()
	get_tree().paused = true

# KLIKNIĘCIE "DALEJ" W MENU
func _on_continue_pressed() -> void:
	if level_up_menu:
		level_up_menu.hide()
	
	get_tree().paused = false # Wyłączamy pauzę
	
	# Włączamy tryb slow-motion
	Engine.time_scale = 0.2 # Gra rusza na 20% prędkości
	is_recovering_time = true

var is_dashing = false
var dash_timer = 0.0
var iframe_timer = 0.0
var cooldown_timer = 0.0
var dash_direction = Vector2.ZERO

func _physics_process(delta: float) -> void:
	# Płynny powrót do normalnego tempa czasu (Efekt po wyjściu z menu)
	# Ważne: dzielimy przez Engine.time_scale, aby powrót trwał tyle samo sekund czasu rzeczywistego
	if is_recovering_time:
		Engine.time_scale += (time_recovery_speed * delta) / Engine.time_scale
		if Engine.time_scale >= 1.0:
			Engine.time_scale = 1.0
			is_recovering_time = false

	# Zapobieganie obracaniu paska HP
	#if hp_bar:
		#hp_bar.global_rotation = 0.0

	look_at(get_global_mouse_position())

	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	if iframe_timer > 0.0:
		iframe_timer -= delta
		collision.disabled = true
		collision_layer = 0
		hurtbox.monitoring = false
	else:
		collision.disabled = false
		collision_layer = 1
		hurtbox.monitoring = true

	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * DASH_SPEED
		if dash_timer <= 0.0:
			is_dashing = false
			velocity *= 0.6
	else:
		var input_direction = Vector2(
			Input.get_axis("left", "right"),
			Input.get_axis("up", "down")
		).normalized()
		velocity = input_direction * MOVEMENT_SPEED

		if Input.is_action_just_pressed("dash") and cooldown_timer <= 0.0:
			is_dashing = true
			dash_timer = DASH_TIME
			iframe_timer = DASH_IFRAMES
			cooldown_timer = DASH_COOLDOWN
			if input_direction != Vector2.ZERO:
				dash_direction = input_direction
			else:
				dash_direction = (get_global_mouse_position() - global_position).normalized()

	if Input.is_action_just_pressed("schoot"):
		var projectile = projectile_scene.instantiate()
		projectile.position = projectile_init_point.global_position
		projectile.direction = (get_global_mouse_position() - global_position).normalized()
		projectile.damage = 1
		get_parent().add_child(projectile)

	move_and_slide()
