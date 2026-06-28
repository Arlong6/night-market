extends GutTest

const CityGen = preload("res://scripts/city_gen.gd")

func test_same_seed_same_layout() -> void:
	var a = CityGen.new().generate(42)
	var b = CityGen.new().generate(42)
	assert_eq(a["buildings"], b["buildings"])
	assert_eq(a["props"].size(), b["props"].size())

func test_different_seed_differs() -> void:
	var a = CityGen.new().generate(1)
	var b = CityGen.new().generate(2)
	assert_ne(a["buildings"], b["buildings"])

func test_produces_some_content() -> void:
	var g = CityGen.new().generate(7)
	assert_gt(g["buildings"].size(), 0)
	assert_gt(g["props"].size(), 0)

func test_no_content_on_road_cells() -> void:
	var g = CityGen.new().generate(3)
	for cell in g["buildings"]:
		assert_false(CityGen.is_road(cell), "building must not sit on a road")
	for p in g["props"]:
		assert_false(CityGen.is_road(p["cell"]), "prop must not sit on a road")
