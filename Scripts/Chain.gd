"""
This script controls the chain.
"""
extends Node2D

@onready var links = $Links		# A slightly easier reference to the links
var direction := Vector2(0,0)	# The direction in which the chain was shot
var tip := Vector2(0,0)			# The global position the tip should be in

const SPEED = 50	# The speed with which the chain moves
const RETRACT_SPEED = 100 # Velocidade de recolhimento (mais rápida que o disparo)

var flying = false	# Whether the chain is moving through the air
var hooked = false	# Whether the chain has connected to a wall
var retracting = false # Novo estado: a corrente está a voltar para o player

# 🌟 NOVA VARIÁVEL: Guarda o comprimento real da corrente em píxeis a cada frame
var current_length := 0.0

# shoot() shoots the chain in a given direction
func shoot(dir: Vector2) -> void:
	direction = dir.normalized()	# Normalize the direction and save it
	flying = true					# Keep track of our current scan
	hooked = false
	retracting = false				# Cancela qualquer retração em curso se disparar de novo
	tip = self.global_position		# reset the tip position to the player's position
	$Tip.global_position = tip      # Garante que a ponta física começa no player
	current_length = 0.0			# Reseta o tamanho ao disparar
	
	# GODOT 4 FIX: Garante que a propriedade Region está ativa no Sprite da corrente
	links.region_enabled = true


# release() the chain
func release() -> void:
	flying = false	# Not flying anymore	
	
	# Se estava presa ou a voar, ativa a retração em vez de sumir imediatamente
	if hooked:
		hooked = false
		retracting = true
	else:
		# Se soltar o clique antes de tocar na parede, desativa tudo direto
		retracting = false
		current_length = 0.0


# Every graphics frame we update the visuals
func _process(_delta: float) -> void:
	# Agora a corrente fica visível também durante o estado de retração
	self.visible = flying or hooked or retracting	
	if not self.visible:
		return	# Not visible -> nothing to draw
		
	var tip_loc = to_local(tip)	# Posição local da ponta em relação ao Player
	var angle = tip_loc.angle() # Ângulo local direto da origem até a ponta
	
	# Rotação da corrente e da ponta
	links.rotation = angle - deg_to_rad(90)
	$Tip.rotation = angle + deg_to_rad(180) - deg_to_rad(90)
	
	# Mantemos a base da corrente sempre ancorada no Player (0,0)
	links.position = Vector2.ZERO					
	
	# CORREÇÃO DO OFFSET:
	# Calculamos a distância total até à ponta.
	var total_length = tip_loc.length()
	
	# Subtraímos o tamanho (em píxeis) da cabeça do gancho para a corrente não passar dela.
	var tip_offset = 17.0 
	
	# Definimos o tamanho final da corrente garantindo que não fica negativo
	links.region_rect.size.y = max(0.0, total_length - tip_offset)


# Every physics frame we update the tip position
func _physics_process(_delta: float) -> void:
	if flying:
		# `if move_and_collide()` always moves, but returns true if we did collide
		var collision = $Tip.move_and_collide(direction * SPEED)
		if collision:
			hooked = true	# Got something!
			flying = false	# Not flying anymore
			
	# LÓGICA DE RETRAÇÃO:
	if retracting:
		# Movemos a ponta física ($Tip) globalmente em direção à posição global do Player
		var player_pos = self.global_position
		var current_tip_pos = $Tip.global_position
		
		# Calcula o vetor em direção ao jogador e move de forma linear
		var to_player = (player_pos - current_tip_pos).normalized()
		$Tip.global_position += to_player * RETRACT_SPEED
		
		# Se a ponta chegar perto o suficiente do jogador, termina o recolhimento
		if current_tip_pos.distance_to(player_pos) <= RETRACT_SPEED:
			retracting = false
			$Tip.global_position = player_pos
	
	# Atualiza a variável interna 'tip' com base nas físicas executadas
	if not hooked:
		tip = $Tip.global_position
	else:
		$Tip.global_position = tip
		
	# 🌟 ATUALIZAÇÃO DO TAMANHO ATUAL:
	# Se a corrente estiver visível em qualquer estado, calcula a distância real em píxeis.
	# Caso contrário, o tamanho é zero.
	if self.visible:
		current_length = global_position.distance_to($Tip.global_position)
	else:
		current_length = 0.0
