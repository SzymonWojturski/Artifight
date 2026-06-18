extends Node

var hp: int = 5
var current_xp: int = 0
var current_level: int = 1
var xp_to_next_level: int = 100
var production_count: int = 3
var sword_tile_data: PackedByteArray = PackedByteArray()        # surowa logika (do edycji w craftingu)
var sword_render_data: PackedByteArray = PackedByteArray()      # skondensowany render (to, co postać trzyma)
var sword_anchor_cell: Vector2i = Vector2i.ZERO                 # komórka-kotwica renderu (do przypięcia w dłoni)
var sword_grip: Vector2 = Vector2(55, 36)                       # punkt chwytu ustawiony w craftingu (HandSword) — wspólny dla gry
var has_sword_grip: bool = false
var has_state: bool = false

var collected_productions: Array = []  # Array[ProductionResource] — zużywają się przy expand

var perk_rebuild: bool = false
var has_free_reset: bool = true
