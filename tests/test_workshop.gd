extends SceneTree

var failures := 0
var changes := 0

func _initialize() -> void:
	call_deferred("run_tests")

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1

func changed() -> void:
	changes += 1

func run_tests() -> void:
	var manager := root.get_node("GameManager")
	var data := root.get_node("GlobalData")
	var sim := root.get_node("FlightSim")
	var scene: PackedScene = load("res://scenes/Workshop.tscn")
	var workshop = scene.instantiate()
	root.add_child(workshop)
	workshop.build_changed.connect(changed)
	check(workshop.mission.missionNumber == 1 and workshop.launcher.id == "launcher_electron", "mission 1 defaults")
	check(workshop.find_child("ElectronPreview", true, false) is SubViewport, "Electron model preview appears in the Workshop header")
	check(workshop.bus.id == "bus_cubesat_1u_3u", "mission 1 bus")
	check(not workshop.add_part("av_bae_rad750"), "locked part rejected")
	check(workshop.add_part("pwr_gomspace_p31u"), "add panel")
	check(workshop.add_part("pwr_gomspace_p31u"), "duplicate panel")
	check(workshop.add_part("com_endurosat_uhf") and workshop.add_part("av_gomspace_a3200") and workshop.add_part("pwr_gomspace_bp4"), "add mission 1 parts")
	check(workshop.installed_components.size() == 5 and changes == 5, "add signals")
	workshop.remove_part(0)
	check(workshop.installed_components.size() == 4 and workshop.installed_components[0].id == "pwr_gomspace_p31u" and changes == 6, "remove duplicate occurrence")
	check(workshop.add_part("prop_vacco_mips"), "add engine")
	check(not workshop.add_part("prop_vacco_mips"), "second engine rejected")
	workshop.set_propellant_mass(12.0)
	check(is_equal_approx(workshop._slider.value, 12.0) and is_equal_approx(workshop._spin.value, 12.0), "fuel synchronized")
	workshop.remove_part(workshop.installed_components.size() - 1)
	check(workshop.propellant_mass_kg == 0.0 and not workshop._fuel_box.visible, "fuel reset after engine removal")
	var before := changes
	workshop.set_propellant_mass(0.0)
	workshop.remove_part(-1)
	check(changes == before, "no signal for unchanged values")
	workshop.queue_free()
	await process_frame
	workshop = scene.instantiate()
	root.add_child(workshop)
	workshop.add_part("com_endurosat_uhf")
	workshop.add_part("pwr_gomspace_p31u")
	workshop.add_part("av_gomspace_a3200")
	workshop.add_part("pwr_gomspace_p31u")
	var rows: Array[Node] = workshop._installed_container.get_children()
	check(rows[0].text == "POWER" and rows[3].text == "AVIONICS" and rows[5].text == "COMMS", "installed parts grouped in catalog order")
	rows[1].get_child(1).pressed.emit()
	check(workshop.installed_components.size() == 3 and workshop.installed_components[0].id == "com_endurosat_uhf" and workshop.installed_components[1].id == "av_gomspace_a3200" and workshop.installed_components[2].id == "pwr_gomspace_p31u", "grouped remove selects correct duplicate")
	check(workshop._visuals.size() == 3, "visual associations rebuilt after grouped removal")
	workshop.queue_free()
	await process_frame
	for entry in [[4, "prop_aerojet_r4d15"], [7, "prop_lpsc_throttleable"]]:
		manager.current_mission = data.get_mission(entry[0])
		manager.unlocked_part_ids.clear()
		manager.unlocked_part_ids.append(entry[1])
		workshop = scene.instantiate()
		root.add_child(workshop)
		check(workshop.add_part(entry[1]), "mission %d engine" % entry[0])
		workshop.fill_to_required_delta_v()
		var engine: Dictionary = data.get_part(entry[1])
		var base: float = workshop.bus.dryMassKg + engine.massKg
		var dry: float = base + workshop.propellant_mass_kg * sim.TANK_MASS_RATIO
		var dv: float = sim.calculate_delta_v(dry, dry + workshop.propellant_mass_kg, engine.ispSeconds)
		check(dv >= workshop.mission.requiredDeltaVMps * 1.1, "mission %d fuel target" % entry[0])
		workshop.queue_free()
		await process_frame
	manager.current_mission = data.get_mission(7)
	manager.unlocked_part_ids.clear()
	workshop = scene.instantiate()
	root.add_child(workshop)
	workshop.add_part("prop_vacco_mips")
	workshop.set_propellant_mass(2.0)
	workshop.fill_to_required_delta_v()
	check(workshop.propellant_mass_kg == 2.0 and not workshop._message.text.is_empty(), "unreachable target preserves fuel")
	workshop.queue_free()
	manager.current_mission = {}
	manager.unlocked_part_ids.clear()
	print("Workshop failures: ", failures)
	quit(1 if failures else 0)
