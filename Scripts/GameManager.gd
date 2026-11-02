extends Node

var pontuacao_da_run : float = 0
var best_pontuacao : float = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func atualizar_pontuacao(pontuacao : int) -> void:
	pontuacao_da_run = pontuacao
	if pontuacao_da_run > best_pontuacao:
		best_pontuacao = pontuacao_da_run

func zerar_pontuacao() -> void:
	pontuacao_da_run = 0

func trocar_pra_gameover() -> void:
	await get_tree().create_timer(3.0).timeout
	
	# Muda de cena perfeitamente
	get_tree().change_scene_to_file("res://Scenes/gameover.tscn")
