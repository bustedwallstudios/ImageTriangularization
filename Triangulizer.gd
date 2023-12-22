extends Control

@export_range(1, 100_000) var vertexCount:int = 1000

@export_range(1.0, 7.0) var threadCount:float = 4

@export var drawVertices:bool = false # Whether to draw a circle at all the points

const windowSize:Vector2 = Vector2(1280, 720)

const imagePath:String = "res://image.png"

# Will be randomly filled to hold all the triangles 
var vertices       := []
var triangles      := []
var triangleColors := [] # The color of the center pixel in the triangle

func _ready():
	# Set the sprite's texture to the image, while the triangulation and stuff
	# is being done
	var originalImage = Image.new()
	originalImage.load(imagePath)
	$Sprite.texture = ImageTexture.create_from_image(originalImage)
	
	await get_tree().create_timer(0.1).timeout
	
	vertices = deterministicallyGenerateVertices(vertexCount)
	
	# Split the vertices into four quarters
	var Q1 := []
	var Q2 := []
	var Q3 := []
	var Q4 := []
	
	for vertex in vertices:
		var vH = vertex.y
		
		if                              (vH < (windowSize.y * 0.25) + 50): Q1.append(vertex)
		if vH > windowSize.y * 0.25 and (vH < (windowSize.y * 0.5 ) + 50): Q2.append(vertex)
		if vH > windowSize.y * 0.5  and (vH < (windowSize.y * 0.75) + 50): Q3.append(vertex)
		if vH > windowSize.y * 0.75:                                       Q4.append(vertex)
		
	
	print("\nProcessing first quarter")
	processArray(Q1)
	await get_tree().process_frame
	
	print("\nProcessing second quarter")
	processArray(Q2)
	await get_tree().process_frame
	
	print("\nProcessing third quarter")
	processArray(Q3)
	await get_tree().process_frame
	
	print("\nProcessing fourth quarter")
	processArray(Q4)

func processArray(arr:Array):
	for threadIdx in range(0, threadCount):
		var newThread = Thread.new()
		
		var verticesPerThread:int = len(arr)/threadCount
		
		# The points that this thread will be processing
		var thisThreadsPiece:Array = []
		
		# Loop over one segment of the array, plus a bunch of triangles, so that
		# they overlap.
		for j in range(0, verticesPerThread + 50):
			var idx = j + (len(arr)/threadCount * threadIdx)
			
			# On the last one, the overlap will result in extra ones. Don't do those
			if idx >= len(arr): break
			
			thisThreadsPiece.append(arr[idx])
			
		print("Thread ", threadIdx, " processing ", len(thisThreadsPiece), " vertices")
		
		# This function will call drawTriangles() for each eighth.
		newThread.start(Isoceles.triangulation.bind(thisThreadsPiece))

func drawTriangles(triangleList:Array):
	# Load the original image
	var originalImage = Image.new()
	originalImage.load(imagePath)
	
	var imgW = originalImage.get_width()
	var imgH = originalImage.get_height()
	
	for triangle in triangleList:
		# Get the center of the triangle, to determine what color it should be
		var centerPos := getTriangleCenter(triangle)
		
		# That position is on the screen, but there's absolutely no guarantee
		# that the image will be the same size. Thus, figure out where in the
		# image maps to that position on the screen.
		centerPos /= windowSize / Vector2(imgW, imgH)
		
		centerPos = centerPos.clamp(Vector2.ZERO, Vector2(imgW-1, imgH-1)) # If it's outside the image, just use the edge pixel color
		
		# Get the color from the image at those coordinates
		@warning_ignore("narrowing_conversion")
		var polyColor := originalImage.get_pixel(centerPos.x, centerPos.y)
		
		var polygonNode     = Polygon2D.new()
		polygonNode.polygon = PackedVector2Array(triangle)
		polygonNode.color   = polyColor
		polygonNode.z_index = -10
		#polygonNode.color.a = 0.5
		
		self.call_deferred("add_child", polygonNode)

func deterministicallyGenerateVertices(howMany:int) -> Array:
	var vertexList := []
	
	# Add the left corners of the screen first, because the points have to be 
	# ordered left to right, so that each thread can just take charge of one
	# piece.
	vertexList.append(Vector2(0, 0))
	vertexList.append(Vector2(0, windowSize.y))
	
	# Calculate the number of points along each axis
	var gridSizeX = int(sqrt(howMany))  # Adjust for the number of points needed
	var gridSizeY = int(sqrt(howMany))  # Adjust for the number of points needed
	
	var cellSizeX = windowSize.x / float(gridSizeX)
	
	for i in range(gridSizeX):
		#await get_tree().process_frame
		#var progress = float(i) / float(gridSizeX)
		#$Label.text = "Generating vertices . . . " + str(round(progress*1000)/10) + "%"
		
		for j in range(gridSizeY):
			var xCompletion = i / float(gridSizeX-1)
			var yCompletion = j / float(gridSizeY-1)
			
			
			var halfXOffset = (0.5*cellSizeX * (j%2)) # So that they form hexagons instead of a grid
			
			
			var x = xCompletion * windowSize.x + halfXOffset  # Distribute points evenly along X
			var y = yCompletion * windowSize.y * 1.5 # Distribute points evenly along Y
			
			var newVertex := Vector2(x, y)
			vertexList.append(newVertex)
	
	# Append the right side corners
	vertexList.append(Vector2(windowSize.x, 0))
	vertexList.append(Vector2(windowSize.x, windowSize.y))
	
	return vertexList

func randomlyGenerateVertices(howMany:int) -> Array:
	var vertexList := []
	
	# Add the corners of the screen
	vertexList.append(Vector2(0, 0))
	vertexList.append(Vector2(0, windowSize.y))
	
	# Calculate the number of points along each axis
	#var gridSizeX = int(sqrt(howMany))  # Adjust for the number of points needed
	#var gridSizeY = int(sqrt(howMany))  # Adjust for the number of points needed
	
	#var cellSizeX = windowSize.x / float(gridSizeX)
	
	for i in range(howMany):
		var x = i/float(howMany) * windowSize.x
		var y = randf_range(0, windowSize.y)  # Distribute points evenly along Y
		
		var newVertex := Vector2(x, y)
		vertexList.append(newVertex)
	
	vertexList.append(Vector2(windowSize.x, 0))
	vertexList.append(Vector2(windowSize.x, windowSize.y))
	
	return vertexList

# Function to calculate center of a triangle
func getTriangleCenter(triangle:Array) -> Vector2:
	var v1:Vector2 = triangle[0]
	var v2:Vector2 = triangle[1]
	var v3:Vector2 = triangle[2]
	
	return (v1 + v2 + v3) / 3.0

# Function to check if a point is inside a triangle
func isPointInsideTriangle(point:Vector2, triangle:Array) -> bool:
	var v1: Vector2 = triangle[0]
	var v2: Vector2 = triangle[1]
	var v3: Vector2 = triangle[2]
	
	var b1 = sign(cross(point - v3, v1 - v3)) < 0.0
	var b2 = sign(cross(point - v1, v2 - v1)) < 0.0
	var b3 = sign(cross(point - v2, v3 - v2)) < 0.0
	
	return (b1 == b2) and (b2 == b3)

func cross(a:Vector2, b:Vector2) -> float:
	return a.x * b.y - a.y * b.x

#region Old pixel way of doing it 
"""
	# Loop through each pixel in the original image
	for y in range(imgH):
		for x in range(imgW):
			
			# For each pixel, try all the triangles to see if they're the one it
			# is inside.
			for triangle in triangles:
				if isPointInsideTriangle(Vector2(x, y), triangle):
					
					var centerOfTriangle:Vector2 = getTriangleCenter(triangle)
					centerOfTriangle = centerOfTriangle.clamp(Vector2.ZERO, Vector2(imgW-1, imgH-1))
					
					var pixelCol = originalImage.get_pixel(centerOfTriangle.x, centerOfTriangle.y)
					
					newImage.set_pixel(x, y, pixelCol)
					
					break# Stop looping over all the triangles, and move on to the next pixel
"""
#endregion

func _input(event):
	# If they press F11, toggle fullscreen within the game
	if event.is_action_pressed("uiFullscreen"):
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN if (!((get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN) or (get_window().mode == Window.MODE_FULLSCREEN))) else Window.MODE_WINDOWED

func _draw():
	if drawVertices:
		for vertex in vertices:
			draw_circle(Vector2(vertex.x, vertex.y), 2, Color.GREEN)