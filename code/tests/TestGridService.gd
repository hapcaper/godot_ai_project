class_name TestGridService
extends RefCounted

const TestUtilsRef = preload("res://tests/TestUtils.gd")
const GridServiceRef = preload("res://scripts/core/GridService.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var grid = GridServiceRef.new(5, 5)

	# Build a map with two corridors between spawn points.
	for x in range(5):
		grid.set_terrain(Vector2i(x, 2), &"wall")
	grid.set_terrain(Vector2i(1, 2), &"plain")
	grid.set_terrain(Vector2i(3, 2), &"plain")

	var path: Array[Vector2i] = grid.find_path(Vector2i(0, 0), Vector2i(4, 4))
	TestUtilsRef.expect_true(failures, path.size() > 0, "Path should exist")

	var path_count: int = grid.count_distinct_paths_limited(Vector2i(0, 0), Vector2i(4, 4), 2, 40)
	TestUtilsRef.expect_true(failures, path_count >= 2, "Should detect at least two distinct paths")

	var validation: Dictionary = grid.validate_map_constraints(
		Vector2i(0, 0),
		Vector2i(4, 4),
		[Vector2i(2, 1), Vector2i(2, 3)],
		{"infantry": [Vector2i(0, 1), Vector2i(4, 1)]}
	)
	TestUtilsRef.expect_true(failures, bool(validation["valid"]), "Map constraint validation should pass")
	return failures
