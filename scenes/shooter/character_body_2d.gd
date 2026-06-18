extends CharacterBody2D

const MOVEMENT_SPEED = 650.0
const DASH_SPEED = 3200.0
const DASH_TIME = 0.10
const DASH_IFRAMES = 0.18
const DASH_COOLDOWN = 0.20
const HIT_IFRAMES = 0.5  # nietykalność po otrzymaniu obrażeń
const MAX_HP = 5
const SWORD_TILE_PX := 15.0          # tile_size renderu
# punkt chwytu = pozycja węzła TileMapLayerSword z edytora
# (przeciągnij TileMapLayerSword w scenie character, żeby zmienić miejsce miecza w ręce)
var sword_grip := Vector2(55, 36)
const BASE_SHOOT_COOLDOWN := 0.5     # cooldown strzału przy 0 AttackSpeed

var hp = MAX_HP
var projectile_scene = preload("res://scenes/shooter/projectile.tscn")
@onready var projectile_init_point = $TileMapLayerSword/projectile_init_point
@onready var collision = $CollisionShape2D
@onready var hurtbox = $HurtBox
@onready var sword_layer = $TileMapLayerSword

# UI
@onready var hp_bar = $HPBar
@onready var xp_bar = get_node_or_null("/root/game/HUD/XPBar")
@onready var level_up_menu = get_node_or_null("/root/game/HUD/LevelUpMenu")
@onready var perk_btn_rebuild = get_node_or_null("/root/game/HUD/LevelUpMenu/PerkRebuild")
@onready var perk_btn_plus = get_node_or_null("/root/game/HUD/LevelUpMenu/PerkPlus")

# XP
var current_xp = 0
var current_level = 1
var xp_to_next_level = 100

var is_recovering_time = false
var time_recovery_speed = 0.8

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	collision_layer = 1
	collision_mask = 1
	hurtbox.area_entered.connect(_on_hurtbox_entered)
	hurtbox.add_to_group("player_hurtbox")

	if perk_btn_rebuild:
		perk_btn_rebuild.pressed.connect(_on_perk_rebuild)
	if perk_btn_plus:
		perk_btn_plus.pressed.connect(_on_perk_plus)

	if sword_layer:
		sword_grip = sword_layer.position  # domyślny chwyt z edytora (gdy nie było craftingu)
	if GameState.has_sword_grip:
		sword_grip = GameState.sword_grip  # chwyt ustawiony w craftingu (HandSword) — wspólny dla obu
	_restore_state()
	update_hp_bar()
	update_xp_bar()

func _restore_state() -> void:
	if not GameState.has_state:
		return
	hp = GameState.hp
	current_xp = GameState.current_xp
	current_level = GameState.current_level
	xp_to_next_level = GameState.xp_to_next_level
	if GameState.sword_render_data.size() > 0:
		# postać trzyma skondensowany render z craftingu, przypięty kotwicą do chwytu
		sword_layer.tile_map_data = GameState.sword_render_data
		sword_layer.notify_runtime_tile_data_update()
		var off: Vector2 = (Vector2(GameState.sword_anchor_cell) * SWORD_TILE_PX * sword_layer.scale).rotated(sword_layer.rotation)
		sword_layer.position = sword_grip - off

func _save_state() -> void:
	GameState.hp = hp
	GameState.current_xp = current_xp
	GameState.current_level = current_level
	GameState.xp_to_next_level = xp_to_next_level
	# surowej logiki (sword_tile_data) nie ruszamy — należy do craftingu;
	# zapisujemy tylko render, którego postać używa w walce
	GameState.sword_render_data = sword_layer.tile_map_data
	GameState.has_state = true

# === HP ===

func _on_hurtbox_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_body"):
		take_damage(1)

func take_damage(amount: int) -> void:
	if iframe_timer > 0.0:
		return
	hp -= amount
	update_hp_bar()
	iframe_timer = HIT_IFRAMES  # krótka nietykalność po trafieniu
	if hp <= 0:
		Engine.time_scale = 1.0
		GameState.has_state = false
		GameState.collected_productions.clear()
		GameState.production_count = 3
		GameState.has_free_reset = true
		get_tree().change_scene_to_file("res://scenes/start.tscn")

func update_hp_bar() -> void:
	if hp_bar:
		hp_bar.max_value = MAX_HP
		hp_bar.value = hp

# === XP / LEVELING ===

func gain_xp(amount: int) -> void:
	current_xp += amount
	update_xp_bar()
	if current_xp >= xp_to_next_level:
		level_up()

func update_xp_bar() -> void:
	if xp_bar:
		xp_bar.max_value = xp_to_next_level
		xp_bar.value = current_xp

func level_up() -> void:
	current_xp -= xp_to_next_level
	current_level += 1
	xp_to_next_level = int(xp_to_next_level * 1.5)
	hp = MAX_HP
	update_hp_bar()
	update_xp_bar()
	_refresh_perk_labels()
	if level_up_menu:
		level_up_menu.show()
	get_tree().paused = true

func _refresh_perk_labels() -> void:
	if perk_btn_rebuild:
		perk_btn_rebuild.text = "Zbuduj miecz od nowa\n(otwiera crafting, resetuje miecz)"
	if perk_btn_plus:
		perk_btn_plus.text = "+1 kliknięcie expand w crafting\n(aktualnie: %d → %d)" % [GameState.production_count, GameState.production_count + 1]

func _close_level_up_menu() -> void:
	if level_up_menu:
		level_up_menu.hide()
	get_tree().paused = false
	Engine.time_scale = 0.2
	is_recovering_time = true

# === PERKS ===

func _on_perk_rebuild() -> void:
	GameState.perk_rebuild = true
	_save_state()
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/crafting.tscn")

func _on_perk_plus() -> void:
	GameState.production_count += 1
	_close_level_up_menu()

# === EQ — otwiera scenę crafting ===

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_eq"):
		if level_up_menu and level_up_menu.visible:
			return
		_save_state()
		get_tree().change_scene_to_file("res://scenes/crafting.tscn")

# === MOVEMENT / DASH / SHOOT ===

var is_dashing = false
var dash_timer = 0.0
var iframe_timer = 0.0
var cooldown_timer = 0.0
var shoot_timer = 0.0
var dash_direction = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return

	if is_recovering_time:
		Engine.time_scale += (time_recovery_speed * delta) / Engine.time_scale
		if Engine.time_scale >= 1.0:
			Engine.time_scale = 1.0
			is_recovering_time = false

	look_at(get_global_mouse_position())

	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	if shoot_timer > 0.0:
		shoot_timer -= delta

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
			dash_direction = input_direction if input_direction != Vector2.ZERO else (get_global_mouse_position() - global_position).normalized()

	if Input.is_action_pressed("schoot") and shoot_timer <= 0.0:
		var stats := {"damage": 1, "attack_speed": 0, "lifetime": 0, "size": 0, "pierce": 0, "speed": 0}
		if sword_layer:
			stats = sword_layer.get_sword_stats()
		var projectile = projectile_scene.instantiate()
		projectile.position = projectile_init_point.global_position
		projectile.direction = (get_global_mouse_position() - global_position).normalized()
		projectile.damage = stats.damage
		projectile.base_speed = 350.0 + stats.speed * 20.0
		projectile.lifetime = 6.0 + stats.lifetime * 1.0
		projectile.size_factor = 1.0 + stats.size * 0.25
		projectile.pierce = stats.pierce
		get_parent().add_child(projectile)
		# AttackSpeed miecza skraca cooldown strzału (większy = szybciej)
		shoot_timer = max(0.08, BASE_SHOOT_COOLDOWN / (1.0 + stats.attack_speed * 0.1))

	move_and_slide()
