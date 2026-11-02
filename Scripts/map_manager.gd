extends Node2D

# Arraste o seu bloco inicial (a base fixa) para cá
@export var bloco_inicial: PackedScene

# Arraste os seus blocos aleatórios/com obstáculos para este array
@export var templates_modulos: Array[PackedScene] = []

# Quantidade de blocos no total que ficam ativos ao mesmo tempo (incluindo o inicial)
@export var blocos_iniciais: int = 5 

var proxima_posicao_x: float = 0.0
var blocos_ativos: Array[Node2D] = []

@onready var player = $"../Character" # Ajuste o caminho até o seu nó do Player

func _ready() -> void:
	# 1. Primeiro, gera obrigatoriamente a base inicial fixa
	if bloco_inicial:
		gerar_bloco(bloco_inicial)
	
	# 2. Depois, preenche o resto do mapa com blocos aleatórios
	# Começa o loop em 1 porque o primeiro bloco (índice 0) já foi a base inicial
	for i in range(1, blocos_iniciais):
		gerar_bloco_aleatorio()

func _process(_delta: float) -> void:
	# Se o player estiver chegando perto do fim dos blocos gerados, cria mais um
	if player.global_position.x > proxima_posicao_x - 2000:
		gerar_bloco_aleatorio()
		limpar_blocos_antigos()

# Função auxiliar para sortear um bloco e criá-lo
func gerar_bloco_aleatorio() -> void:
	if templates_modulos.is_empty():
		return
	var template_sorteado: PackedScene = templates_modulos.pick_random()
	gerar_bloco(template_sorteado)

# Função principal que faz o trabalho físico de spawn e encaixe
func gerar_bloco(template: PackedScene) -> void:
	var novo_bloco: Node2D = template.instantiate()
	
	# Define a posição com base no X acumulado (o primeiro começará em 0.0)
	novo_bloco.global_position = Vector2(proxima_posicao_x, 0)
	
	add_child(novo_bloco)
	blocos_ativos.append(novo_bloco)
	
	# Encontra o Marker2D ("PontoDeSaida") dentro do bloco gerado
	var ponto_saida = novo_bloco.get_node("PontoDeSaida") as Marker2D
	
	# Atualiza o X acumulado para o próximo bloco saber onde se colar
	proxima_posicao_x += ponto_saida.position.x

func limpar_blocos_antigos() -> void:
	if blocos_ativos.size() > blocos_iniciais + 2:
		var bloco_velho = blocos_ativos.pop_front()
		if is_instance_valid(bloco_velho):
			bloco_velho.queue_free()
