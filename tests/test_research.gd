extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run_tests")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func run_tests() -> void:
	var gm := root.get_node("GameManager")
	var data := root.get_node("GlobalData")
	gm.save_path = "user://spa17-%d.json" % Time.get_ticks_usec()
	gm.new_campaign()
	check(data.tech_nodes.size() == 50 and data.get_tech_node("I15").hackathonEnabled == false, "all documented nodes loaded")
	check(gm.research_status("A1") == "Locked by tier" and gm.research_node("A1") != OK, "tier gate")
	gm.unlocked_tier = 1
	gm.science_points = 15
	check(gm.research_node("A1") == OK and gm.science_points == 10 and gm.is_part_unlocked("adcs_rw003"), "purchase unlocks reaction wheels")
	check(gm.research_node("A1") != OK and gm.science_points == 10, "duplicate purchase rejected")
	gm.science_points += 30
	check(gm.research_node("L1") == OK and gm.research_node("I2") == OK and gm.research_node("C1") == OK and gm.research_node("P1") == OK and gm.science_points == 13, "Mission 2 and 3 research path costs 32 SP")
	check(gm.research_status("A5") == "Locked by tier" and gm.research_status("L5") == "Post-hackathon", "tier and disabled gates")
	gm.science_points = 100
	gm.unlocked_tier = 2
	check(gm.research_status("I5") == "Locked by prerequisite", "I5 needs A5 and P2")
	check(gm.research_node("A5") == OK and gm.research_status("I5") == "Locked by prerequisite", "I5 still needs P2")
	check(gm.research_node("P2") == OK and gm.research_node("I5") == OK, "I5 prerequisites and purchase")
	check(gm.load_campaign() == OK and "I5" in gm.owned_tech_nodes and gm.is_part_unlocked("inst_kuka_transponder_suite"), "research persists")
	gm.science_points = 100
	var old_path: String = gm.save_path
	gm.save_path = "user://missing-research-dir/save.json"
	var before: int = gm.science_points
	check(gm.research_node("A8") != OK and gm.science_points == before and "A8" not in gm.owned_tech_nodes and not gm.is_part_unlocked("prop_aerojet_r4d15"), "failed save rolls back purchase")
	gm.save_path = old_path
	gm.completed_missions.assign([1,2])
	gm.start_mission(3)
	gm.finalize_mission({"mission_number":3,"objectives":[{"done":true}]})
	check("L11" in gm.owned_tech_nodes and gm.is_part_unlocked("launcher_falcon_9"), "Mission 3 grants Falcon 9")
	gm.owned_tech_nodes.append("L10")
	var build := {"launcher":data.get_launcher("launcher_electron"), "bus":data.get_bus("bus_cubesat_1u_3u"), "installed_components":[], "propellant_mass_kg":0.0}
	var stats: Dictionary = load("res://scripts/BuildStats.gd").new().calculate_stats(build,data.get_mission(1))
	check(absf(stats.adapter_mass_kg - 0.015) < 0.00001, "L10 reduces adapter mass")
	var scene = load("res://scenes/TechTree.tscn").instantiate()
	root.add_child(scene)
	check(scene._buttons.size() == 50 and scene._buttons["L5"].disabled, "research screen displays tree")
	scene.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(old_path))
	print("Research failures: ",failures)
	quit(1 if failures else 0)
