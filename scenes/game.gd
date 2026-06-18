extends Node2D

# Ścieżka do sceny Twojego przeciwnika (dostosuj, jeśli masz inną nazwę/folder!)
var enemy_scene = preload("res://scenes/enemies/enemy.tscn") 

@onready var player = $character # upewnij się, że tak nazywa się Twój gracz w scenie
@onready var spawner_timer = $EnemySpawner
@onready var bg_rect = $Background/BGRect

const DIFFICULTY_STEP := 30.0  # co ile sekund rośnie poziom trudności
var game_time := 0.0

func _ready() -> void:
	spawner_timer.timeout.connect(_on_spawner_timeout)
	var img = Image.load_from_file("res://sprites/nowe.jpg")
	if img and bg_rect and bg_rect.material:
		bg_rect.material.set_shader_parameter("bg_texture", ImageTexture.create_from_image(img))

func _process(delta: float) -> void:
	game_time += delta
	if bg_rect and bg_rect.material:
		var ct = get_viewport().get_canvas_transform()
		var zoom = ct.x.x
		bg_rect.material.set_shader_parameter("cam_offset", -ct.origin / zoom)
		bg_rect.material.set_shader_parameter("world_scale", 1.0 / zoom)

func _on_spawner_timeout() -> void:
	if player == null: return

	var enemy = enemy_scene.instantiate()

	# z czasem (co DIFFICULTY_STEP sekund) NOWI wrogowie są silniejsi i szybsi
	var tier := int(game_time / DIFFICULTY_STEP)
	enemy.hp_mult = 1.0 + tier * 0.5
	enemy.speed_mult = 1.0 + tier * 0.15

	# Losowanie pozycji spawnu w promieniu np. 800-1200 pikseli wokół gracza
	# dzięki temu wrogowie nie spawnują się na oczach gracza, tylko "poza ekranem"
	var random_angle = randf() * PI * 2
	var random_distance = randf_range(800.0, 1200.0)
	var spawn_offset = Vector2(cos(random_angle), sin(random_angle)) * random_distance

	enemy.global_position = player.global_position + spawn_offset
	add_child(enemy)
