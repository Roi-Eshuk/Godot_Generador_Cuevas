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

#Caminos
var caminos: = []
var senda: = []
var senda_revisada: = []
var celda_revisar: Vector2i = Vector2i.ZERO
var distancia:int = 1

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
	
	await esperar_teclado("Conectar cuevas.")
	conectar_cuevas()

	await esperar_teclado("Torcer caminos.")
	torcer_caminos()

	await esperar_teclado("Limpieza final.")
	limpieza_final()
	
	dibujar_cueva(cueva)
	
	await esperar_teclado("¡Cueva terminada! Preseiona ENTER para empezar de nuevo.")
	corriendo_revision = false

#endregion - Proceso maestro

#region - Funciones de proceso

func reestablecer_variables() -> void:
	formar_matriz(cueva, ancho, alto, 0)
	formar_matriz(pivote, ancho, alto, 0)
	area.clear()
	area_temporal.clear()
	distancia = 1
	caminos.clear()
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

func conectar_cuevas() -> void:

	var buscando:bool = true
	senda.clear()
	distancia = 1

	for x in range(ancho):
		for y in range(alto):
			pivote[x][y] = 0

	contar_cavidades()

	if cavidades > 1:

		var conexiones:int = cavidades - 1

		#Poner distancia en primera cueva
		for x in range(ancho):
			if !buscando:
				break
			for y in range(alto):
				if buscando and cueva[x][y] == vacio:
					llena_area(x, y, vacio, vacio_procesar)
					buscando = false
					break

		area_conectada()

		while conexiones > 0 and senda.size() > 0:
			celda_revisar = senda.pop_front()
			distancia = pivote[celda_revisar.x][celda_revisar.y] + 1
			
			if celda_revisar.x > 1 and cueva[celda_revisar.x - 1][celda_revisar.y] == lleno and pivote[celda_revisar.x - 1][celda_revisar.y] == vacio:
				senda.append(Vector2i(celda_revisar.x - 1, celda_revisar.y))
				pivote[celda_revisar.x-1][celda_revisar.y] = distancia

			if celda_revisar.x < ancho - 2 and cueva[celda_revisar.x + 1][celda_revisar.y] == lleno and pivote[celda_revisar.x + 1][celda_revisar.y] == vacio:
				senda.append(Vector2i(celda_revisar.x + 1, celda_revisar.y))
				pivote[celda_revisar.x + 1][celda_revisar.y] = distancia
			
			if celda_revisar.y > 1 and cueva[celda_revisar.x][celda_revisar.y - 1] == lleno and pivote[celda_revisar.x][celda_revisar.y - 1] == vacio:
				senda.append(Vector2i(celda_revisar.x,celda_revisar.y-1))
				pivote[celda_revisar.x][celda_revisar.y-1] = distancia
			
			if celda_revisar.y < alto - 2 and cueva[celda_revisar.x][celda_revisar.y + 1] == lleno and pivote[celda_revisar.x][celda_revisar.y + 1] == vacio:
				senda.append(Vector2i(celda_revisar.x,celda_revisar.y + 1))
				pivote[celda_revisar.x][celda_revisar.y + 1] = distancia
			
			if celda_revisar.x > 1 and cueva[celda_revisar.x - 1][celda_revisar.y] == vacio:
				llena_area(celda_revisar.x - 1, celda_revisar.y, vacio, vacio_procesar)
				area_conectada(distancia)
				ubicar_conexiones(celda_revisar.x-1, celda_revisar.y)
				conexiones -= 1
			
			if celda_revisar.x < ancho - 2 and cueva[celda_revisar.x + 1][celda_revisar.y] == vacio:
				llena_area(celda_revisar.x + 1, celda_revisar.y, vacio, vacio_procesar)
				area_conectada(distancia)
				ubicar_conexiones(celda_revisar.x+1, celda_revisar.y)
				conexiones -= 1
			
			if celda_revisar.y > 1 and cueva[celda_revisar.x][celda_revisar.y - 1] == vacio:
				llena_area(celda_revisar.x, celda_revisar.y - 1, vacio, vacio_procesar)
				area_conectada(distancia)
				ubicar_conexiones(celda_revisar.x, celda_revisar.y-1)
				conexiones -= 1
			
			if celda_revisar.y < alto - 2 and cueva[celda_revisar.x][celda_revisar.y + 1] == vacio:
				llena_area(celda_revisar.x, celda_revisar.y + 1, vacio, vacio_procesar)
				area_conectada(distancia)
				ubicar_conexiones(celda_revisar.x, celda_revisar.y+1)
				conexiones -= 1
	
		trazar_caminos()

func torcer_caminos() -> void:
	var dir:int = 1
	for x in range(2, ancho - 2):
		for y in range(2, alto - 2):
			var vecinos:int = 0
			var vecinos_v:int = 0
			var vecinos_h:int = 0
			if cueva[x][y] == vacio:
				for vx in range(-1,2):
					for vy in range(-1,2):
						if vx != 0 or vy != 0:
							if cueva[x+vx][y+vy] == vacio:
								vecinos += 1
								if vx == 0:
									vecinos_v +=1
								if vy == 0:
									vecinos_h +=1
			if vecinos == 2 and vecinos_h == 2:
				dir *= -1
				cueva[x][y] = lleno
				cueva[x][y + dir] = vacio
			if vecinos == 2 and vecinos_v == 2:
				dir *= -1
				cueva[x][y] = lleno
				cueva[x + dir][y] = vacio

func limpieza_final() -> void:
	
	for x in range(ancho):
		for y in range(alto):
			if cueva[x][y] == lleno_procesar:
				cueva[x][y] = lleno
			if cueva[x][y] == vacio_procesar:
				cueva[x][y] = vacio
				
	llena_area(0, 0, lleno, lleno_procesar)
	quitar_artefactos(lleno, lleno_procesar, vacio, umbral_derribar, true)
	llena_area(0, 0, lleno_procesar, lleno)
	unir_esquinas()


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

func area_conectada(distancia_recorrida: int = 1) -> void:
	
	for dato: Vector2i in area:
		senda.append(dato)
			
	for celda: Vector2i in area:
		if celda.x > 0 and celda.x < ancho - 1 and celda.y > 0 and celda.y < alto - 1:
			if (cueva[celda.x + 1][celda.y] == lleno or 
				cueva[celda.x - 1][celda.y] == lleno or
				cueva[celda.x][celda.y + 1] == lleno or
				cueva[celda.x][celda.y - 1] == lleno):
					pivote[celda.x][celda.y] = distancia_recorrida

func ubicar_conexiones(x:int, y:int) -> void:
	
	var minimo:int = pivote[x][y]
	var x_original: int = x
	var y_original: int = y
	var dir_x: int = 0
	var dir_y: int = 0
	var dar_paso: bool = true
	
	while dar_paso:
		dir_x = 0
		dir_y = 0
		dar_paso = false
		if x > 1 and pivote[x-1][y] < minimo and pivote[x-1][y] > 0 and (cueva[x-1][y] == lleno or pivote[x-1][y] == 1):
			dir_x = -1
			dir_y = 0
			minimo = pivote[x + dir_x][y + dir_y]
			dar_paso = true
		if x < ancho - 2 and pivote[x+1][y] < minimo and pivote[x+1][y] > 0 and (cueva[x+1][y] == lleno or pivote[x+1][y] == 1):
			dir_x = 1
			dir_y = 0
			minimo = pivote[x + dir_x][y + dir_y]
			dar_paso = true
		if y > 1 and pivote[x][y-1] < minimo and pivote[x][y-1] > 0 and (cueva[x][y-1] == lleno or pivote[x][y-1] == 1):
			dir_x = 0
			dir_y = -1
			minimo = pivote[x + dir_x][y + dir_y]
			dar_paso = true
		if y < alto - 2 and pivote[x][y+1] < minimo and pivote[x][y+1] > 0 and (cueva[x][y+1] == lleno or pivote[x][y+1] == 1):
			dir_x = 0
			dir_y = 1
			minimo = pivote[x+dir_x][y+dir_y]
			dar_paso = true
		x += dir_x
		y += dir_y
	caminos.append(Vector4i(x_original, y_original, x, y))
	
func trazar_caminos() -> void:
	
	for camino:Vector4i in caminos:
		var x1: int = 0
		var x2: int = 0
		var y1: int = 0
		var y2: int = 0
		
		if camino.x < camino.z:
			x1 = camino.x
			x2 = camino.z
			y1 = camino.y
			y2 = camino.w
		else:
			x1 = camino.z
			x2 = camino.x
			y1 = camino.w
			y2 = camino.y
		
		var dx:int = x2 - x1
		var dy:int = y2 - y1
		
		if dx == 0:
			for p in range(min(y1,y2), max(y1,y2)+1):
				cueva[x1][p] = vacio
		elif dy == 0:
			for p in range(x1, x2 + 1):
				cueva[p][y1] = vacio
		else:
			if abs(dx) >= abs(dy):
				for p in range(x1,x2+1):
					var px: int = p
					var py: int = round(y1 + (p-x1)*(dy)/(dx))
					cueva[px][py] = vacio
			else:
				for p in range(y1,y2+sign(dy), sign(dy)):
					var py: int = p
					var px: int = round(x1 + (p-y1)*(dx)/(dy))
					cueva[px][py] = vacio

func unir_esquinas() -> void:
	var unir: bool = true
	while unir:
		unir = false
		for x in range(1, ancho-2):
			for y in range(1,alto-2):
				var a: int = cueva[x][y]
				var b: int = cueva[x+1][y]
				var c: int = cueva[x][y+1]
				var d: int = cueva[x+1][y+1]
				var ajuste: int = randi_range(0,1)
				if a + d == 2 and b + c == 0:
					unir = true
					cueva[x + ajuste][y + ajuste] = vacio
				elif a + d == 0 and b + c == 2:
					unir = true
					cueva[x + 1 - ajuste][y + ajuste] = vacio

#endregion - Funciones subordinadas y de apoyo
