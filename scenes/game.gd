extends Node2D

# Ścieżka do sceny Twojego przeciwnika (dostosuj, jeśli masz inną nazwę/folder!)
var enemy_scene = preload("res://scenes/enemies/enemy.tscn") 

@onready var player = $character # upewnij się, że tak nazywa się Twój gracz w scenie
@onready var spawner_timer = $EnemySpawner

func _ready() -> void:
	spawner_timer.timeout.connect(_on_spawner_timeout)

func _on_spawner_timeout() -> void:
	if player == null: return
	
	var enemy = enemy_scene.instantiate()
	
	# Losowanie pozycji spawnu w promieniu np. 800-1200 pikseli wokół gracza
	# dzięki temu wrogowie nie spawnują się na oczach gracza, tylko "poza ekranem"
	var random_angle = randf() * PI * 2
	var random_distance = randf_range(800.0, 1200.0)
	var spawn_offset = Vector2(cos(random_angle), sin(random_angle)) * random_distance
	
	enemy.global_position = player.global_position + spawn_offset
	add_child(enemy)
