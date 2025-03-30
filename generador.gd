extends Node2D

#region - Variables

#Modo revisión
@export var modo_revision: bool = true
var corriendo_revision: bool = false

#Cámara
@onready var camara: Camera2D = $Camera2D
@export var velocidad_camara: int = 350

#Configuración del lienzo
@onready var mapa: TileMapLayer = $TileMapLayer
var cueva: = []
var pivote: = []
@export var ancho: int = 35
@export var alto: int = 35
enum {vacio, lleno, vacio_procesar, lleno_procesar}

#Llenado inicial
@export var densidad: int = 50

#Dado aleatorio
var dado: RandomNumberGenerator = RandomNumberGenerator.new()
@export var usar_semilla: bool = true
@export var semilla: String = "Roi Eshuk"

#Alisado (cellular automata)
@export var cantidad_alisado: int = 3
@export var umbral_ocupar: int = 4
@export var umbral_vaciar: int = 4

#Quitar artefactos
@export var umbral_derribar: int = 10
@export var umbral_rellenar: int = 10

#Contar cavidades
var cavidades:int = 0

#Llenar área
var area: = []
var area_temporal: = []

#endregion - Variables

#region - funciones de interacción

func _ready() -> void:
	if not modo_revision:
		generar_cueva()
	else:
		print("Corriendo en modo de revisión. Presiona ENTER para iniciar.")

func _process(delta: float) -> void:
	mover_camara(delta)

func mover_camara(delta: float) -> void:
	var dir_camara = Vector2.ZERO
	dir_camara.x = int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"))
	dir_camara.y = int(Input.is_action_pressed("ui_down")) - int(Input.is_action_pressed("ui_up"))
	if dir_camara != Vector2.ZERO:
		camara.position += dir_camara * velocidad_camara * delta

func _input(event) -> void:
	if OS.is_debug_build() and event.is_action_pressed("ui_accept") and not corriendo_revision:
		corriendo_revision = true
		generar_cueva()

#endregion - Funciones de interacción

#region - Funciones del modo revisión

func esperar_teclado(mensaje: String = "Siguiente paso.") -> void:
	if OS.is_debug_build() and modo_revision and corriendo_revision:
		dibujar_cueva(cueva)
		print("SIGUIENTE PASO: " + mensaje)
		while true:
			await get_tree().process_frame
			if Input.is_action_just_pressed("ui_siguiente"):
				break

#endregion - Funciones del modo revisión

#region - Proceso maestro

func generar_cueva() -> void:

	await esperar_teclado("Reestablecer variables.")
	reestablecer_variables()

	await esperar_teclado("Llenar cueva.")
	llenar_cueva(cueva)
	
	for a in cantidad_alisado:
		await esperar_teclado("Alisar cueva: " + str(a + 1))
		alisar_cueva()
	
	await esperar_teclado("Quitar columnas pequeñas.")
	llena_area(0, 0, lleno, lleno_procesar)
	quitar_artefactos(lleno, lleno_procesar, vacio, umbral_derribar, true)

	await esperar_teclado("Llenar huecos pequeños.")
	contar_cavidades()
	if cavidades > 1:
		quitar_artefactos(vacio, vacio_procesar, lleno, umbral_rellenar, false, cavidades)
		llena_area(0, 0, lleno_procesar, lleno)
	
	dibujar_cueva(cueva)
	
	await esperar_teclado("¡Cueva terminada! Preseiona ENTER para empezar de nuevo.")
	corriendo_revision = false

#endregion - Proceso maestro

#region - Funciones de proceso

func reestablecer_variables() -> void:
	formar_matriz(cueva, ancho, alto, 0)
	formar_matriz(pivote, ancho, alto, 0)
	if OS.is_debug_build() and modo_revision:
		print("Variables reestablecidas.")

func llenar_cueva(matriz: Array = cueva) -> void:
	
	tirar_dado()
	
	var vaciar: int = 0
	for x in range(ancho):
		for y in range(alto):
			matriz[x][y] = 0
			if x == 0 or y == 0 or x == ancho - 1 or y == alto - 1:
				matriz[x][y] = lleno
			else:
				vaciar = dado.randi_range(0, 100)
				matriz[x][y] = vacio if vaciar > densidad else lleno

func alisar_cueva() -> void:
	copiar_matriz(cueva, pivote)
	var ocupadas: int = 0
	for x in range(1,ancho-1):
		for y in range(1,alto-1):
			ocupadas = 0
			for vx in range(x-1,x+2):
				for vy in range(y-1,y+2):
					if vx != x or vy != y:
						ocupadas += cueva[vx][vy]
			
			if pivote[x][y] == vacio and ocupadas > umbral_ocupar:
				pivote[x][y] = lleno
				
			if pivote[x][y] == lleno and ocupadas < umbral_vaciar:
				pivote[x][y] = vacio
				
	copiar_matriz(pivote, cueva)

#endregion - Funciones de proceso

#region - Funciones subordinadas y de apoyo

func formar_matriz(matriz: Array, filas: int = ancho, columnas: int = alto, valor: int = 0) -> Array:
	matriz.clear()
	for i in range(filas):
		var columna: = []
		for j in range(columnas):
			columna.append(valor)
		matriz.append(columna)
	return matriz

func dibujar_cueva(matriz: = cueva, esquina_x: int = 0, esquina_y: int = 0) -> void:
	if matriz.size() > 0:
		for x in range(ancho):
			for y in range(alto):
				mapa.set_cell(Vector2i(esquina_x + x, esquina_y + y), 0, Vector2i(matriz[x][y], 0))

func tirar_dado() -> void:
	if usar_semilla:
		if semilla.is_valid_int():
			dado.seed = semilla.to_int()
		else:
			dado.seed = hash(semilla)
		if OS.is_debug_build() and modo_revision:
			print("Semilla:", semilla)
	else:
		dado.randomize()
		if OS.is_debug_build() and modo_revision:
			print("Semilla:", dado.seed)

func copiar_matriz(origen: = cueva, destino: = pivote) -> void:
	for x in range(ancho):
		for y in range(alto):
			destino[x][y] = origen[x][y]

func contar_cavidades() -> void:
	cavidades = 0
	for x in range(ancho):
		for y in range(alto):
			if cueva[x][y] == vacio:
				cavidades += 1
				llena_area(x,y,vacio, vacio_procesar)
	for x in range(ancho):
			for y in range(alto):
				if cueva[x][y] == vacio_procesar:
					cueva[x][y] = vacio

func quitar_artefactos(original: int, puente: int, destino: int, umbral: int, ilimitado: bool = true, limite: int = 1) -> void:
	var conteo: int = limite
	for x_ini in range(ancho):
		for y_ini in range(alto):
			if cueva[x_ini][y_ini] == original and (conteo > 1 or ilimitado):
				llena_area(x_ini, y_ini, original, puente)
				if area.size() <= umbral:
					conteo -= 1
					for cambiar: Vector2i in area:
						cueva[cambiar.x][cambiar.y] = destino
	# Este ciclo for se pone fuera del ciclo principal para evitar que convierta a "original" un área antes de tiempo.
	for x in range(ancho):
		for y in range(alto):
			if cueva[x][y] == puente:
				cueva[x][y] = original

func llena_area(x_ini: int, y_ini: int, buscar: int, convertir: int, matriz: = cueva) -> void:

	area.clear()
	area.append(Vector2i(x_ini,y_ini))

	area_temporal.clear()
	area_temporal.append(Vector2i(x_ini,y_ini))

	while area_temporal.size() > 0:
		var x:int = area_temporal[0].x
		var y:int = area_temporal[0].y
		matriz[x][y] = convertir
		area_temporal.pop_front()
		if x < ancho - 1 and matriz[x+1][y] == buscar and not area_temporal.has(Vector2i(x+1,y)):
			area_temporal.append(Vector2i(x+1,y))
			area.append(Vector2i(x+1,y))
		if x > 0 and matriz[x-1][y] == buscar and not area_temporal.has(Vector2i(x-1,y)):
			area_temporal.append(Vector2i(x-1,y))
			area.append(Vector2i(x-1,y))
		if y < alto - 1 and matriz[x][y+1] == buscar and not area_temporal.has(Vector2i(x,y+1)):
			area_temporal.append(Vector2i(x,y+1))
			area.append(Vector2i(x,y+1))
		if y > 0 and matriz[x][y-1] == buscar and not area_temporal.has(Vector2i(x,y-1)):
			area_temporal.append(Vector2i(x,y-1))
			area.append(Vector2i(x,y-1))


#endregion - Funciones subordinadas y de apoyo
