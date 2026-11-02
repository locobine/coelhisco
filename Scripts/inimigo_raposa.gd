extends Area2D

# 🌟 Configurações do movimento flutuante (Podes ajustar no Inspetor)
@export var amplitude : float = 50.0  # 20 pixels para cima e 20 para baixo = 40 pixels no total
@export var velocidade_flutuar : float = 3.0 # Velocidade da oscilação

# Variáveis internas para controlo do movimento
var posicao_y_inicial : float
var tempo_decorrido : float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 🌟 Guarda a posição Y original onde o inimigo foi colocado no cenário
	posicao_y_inicial = global_position.y


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# 🌟 1. Acumula o tempo decorrido multiplicado pela velocidade
	tempo_decorrido += delta * velocidade_flutuar
	
	# 🌟 2. Atualiza a posição Y suavemente usando a função Seno
	global_position.y = posicao_y_inicial + (sin(tempo_decorrido) * amplitude)


func _on_body_entered(body: Node2D) -> void:
	if body.getIsDashing():
		body.addPontos(200)
		queue_free()
	else:
		body.morrer()
