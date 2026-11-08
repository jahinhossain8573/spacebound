extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run_tests")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func run_tests() -> void:
	var data := root.get_node("GlobalData")
	var manager := root.get_node("GameManager")
	check(data.launchers.size() == 3, "launcher count")
	check(data.buses.size() == 5, "bus count")
	check(data.components.size() == 34, "component count")
	check(data.missions.size() == 6, "mission count")
	for catalog in [data.launchers, data.buses, data.components, data.missions]:
		var ids := {}
		for item in catalog:
			check(not ids.has(item.id), "unique ID: " + item.id)
			ids[item.id] = true
	for part in data.components:
		check(part.powerGenWatts >= 0 and part.powerDrawWatts >= 0, "power: " + part.id)
		check(not part.isExternal or part.volumeLiters == 0, "external volume: " + part.id)
		check(data.get_part(part.id) == part, "part lookup: " + part.id)
	for launcher in data.launchers:
		check(data.get_launcher(launcher.id) == launcher, "launcher lookup: " + launcher.id)
	for bus in data.buses:
		check(data.get_bus(bus.id) == bus and bus.dimensionsMeters.size() == 3, "bus: " + bus.id)
	for mission in data.missions:
		check(data.get_mission(int(mission.missionNumber)) == mission, "mission lookup")
		check(not data.get_launcher(mission.requiredLauncher).is_empty(), "mission launcher")
		check(not data.get_bus(mission.requiredBus).is_empty(), "mission bus")
		for id in mission.requiredPartIds:
			check(not data.get_part(id).is_empty(), "mission part: " + id)
	check(data.get_part("av_bae_rad750").get("radiationHardened") == true, "RAD750 radiation hardening")
	check(data.get_mission(4).get("requiredLauncher") == "launcher_falcon_9", "mission 4 launcher")
	check(data.get_part("prop_aerojet_r4d15").isExternal and data.get_part("prop_aerojet_r4d15").volumeLiters == 0, "R-4D volume")
	check(not data.get_part("prop_vacco_mips").isExternal, "VACCO internal")
	for pair in [[1, 1], [3, 2], [4, 3], [5, 4]]:
		check(data.get_mission(pair[0]).get("unlocksTier") == pair[1], "tier unlock")
	check(not data.get_mission(2).has("unlocksTier") and not data.get_mission(7).has("unlocksTier"), "no extra tier unlock")
	check(data.get_part("missing").is_empty() and data.get_launcher("missing").is_empty() and data.get_bus("missing").is_empty() and data.get_mission(999).is_empty(), "missing lookups")
	manager.unlocked_part_ids.clear()
	var groups: Dictionary = data.parts_by_subsystem()
	for group in groups.values():
		for part in group:
			check(part.tier == 0, "initial unlock filtering")
	manager.unlocked_part_ids.append("adcs_rw003")
	check(data.get_part("adcs_rw003") in data.parts_by_subsystem().adcs, "unlocked part included")
	check(data.get_part("adcs_st16") in data.parts_by_subsystem(false).adcs, "all parts included")
	manager.unlocked_part_ids.clear()
	var path := "user://spa6_invalid_test.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ malformed")
	file.close()
	check(data._load_catalog(path, "components").is_empty(), "malformed catalog rejected")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify([data.components[0], data.components[0]]))
	file.close()
	check(data._load_catalog(path, "components").is_empty(), "duplicate IDs rejected")
	file = FileAccess.open(path, FileAccess.WRITE)
	var duplicate: Dictionary = data.missions[0].duplicate(true)
	duplicate.id = "different_id"
	file.store_string(JSON.stringify([data.missions[0], duplicate]))
	file.close()
	check(data._load_catalog(path, "missions").is_empty(), "duplicate mission number rejected")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures == 0:
		print("SPA-6 data checks passed")
	quit(1 if failures else 0)
