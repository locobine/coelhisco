extends Control

@onready var label_mensagem = $CanvasLayer/Message
@onready var label_best = $CanvasLayer/Best

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	label_mensagem.text = "GAME OVER\n" + str(GameManager.pontuacao_da_run) + "\nCLICK TO EXIT"
	label_best.text = "BEST:\n" + str(GameManager.best_pontuacao)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		GameManager.zerar_pontuacao()
		get_tree().change_scene_to_file("res://Scenes/menu.tscn")
