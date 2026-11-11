extends Node

var launchers: Array[Dictionary] = []
var buses: Array[Dictionary] = []
var components: Array[Dictionary] = []
var missions: Array[Dictionary] = []
var tech_nodes: Array[Dictionary] = []
var _tech_index: Dictionary = {}

var _launcher_index: Dictionary = {}
var _bus_index: Dictionary = {}
var _part_index: Dictionary = {}
var _mission_index: Dictionary = {}


func _ready() -> void:
	launchers = _load_catalog("res://data/launchers.json", "launchers")
	buses = _load_catalog("res://data/buses.json", "buses")
	components = _load_catalog("res://data/components.json", "components")
	missions = _load_catalog("res://data/missions.json", "missions")
	tech_nodes = _load_tech_nodes("res://data/tech_tree.json")
	for node in tech_nodes: _tech_index[node.id] = node
	for item in launchers:
		_launcher_index[item.id] = item
	for item in buses:
		_bus_index[item.id] = item
	for item in components:
		_part_index[item.id] = item
	for item in missions:
		_mission_index[int(item.missionNumber)] = item


func _load_catalog(path: String, kind: String) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		push_error("Cannot read catalog: " + path)
		return records
	var contents := FileAccess.get_file_as_string(path)
	if FileAccess.get_open_error() != OK:
		push_error("Cannot read catalog: " + path)
		return records
	var parsed: Variant = JSON.parse_string(contents)
	if not parsed is Array:
		push_error("Invalid JSON catalog: " + path)
		return records
	var ids: Dictionary = {}
	var numbers: Dictionary = {}
	for item: Variant in parsed:
		if not item is Dictionary or not _valid_record(item, kind):
			push_error("Invalid record in catalog: " + path)
			return []
		if ids.has(item.id):
			push_error("Duplicate id in catalog: " + path)
			return []
		ids[item.id] = true
		if kind == "missions":
			var number := int(item.missionNumber)
			if numbers.has(number):
				push_error("Duplicate mission number in catalog: " + path)
				return []
			numbers[number] = true
		records.append(item)
	return records


func _valid_record(item: Dictionary, kind: String) -> bool:
	var string_fields := ["id"]
	var number_fields: Array[String] = []
	match kind:
		"launchers":
			string_fields += ["name", "heritage"]
			number_fields = ["tier", "costMillions", "baseReliability", "fairingDiameterMeters", "fairingHeightMeters", "capacityLeoKg", "capacityGtoKg", "capacityTliKg"]
		"buses":
			string_fields += ["name", "heritage"]
			number_fields = ["tier", "dryMassKg", "internalVolumeLiters", "costMillions"]
			if not item.get("dimensionsMeters") is Array or item.dimensionsMeters.size() != 3:
				return false
			for dimension: Variant in item.dimensionsMeters:
				if not _is_number(dimension) or dimension <= 0:
					return false
		"components":
			string_fields += ["name", "subsystem", "heritage"]
			number_fields = ["tier", "massKg", "volumeLiters", "powerGenWatts", "powerDrawWatts", "costMillions"]
			if not item.get("isExternal") is bool:
				return false
			for field in ["batteryWh", "thrustNewtons", "ispSeconds", "minThrottle", "dataRateKbps"]:
				if item.has(field) and (not _is_number(item[field]) or item[field] < 0):
					return false
			for field in ["throttleable", "radiationHardened", "optical", "deployable", "deepSpace", "activePointing"]:
				if item.has(field) and not item[field] is bool:
					return false
			if item.has("propellantType") and item.propellantType not in ["cold_gas", "hydrazine", "bipropellant"]:
				return false
			if item.has("minThrottle") and item.minThrottle > 1:
				return false
		"missions":
			string_fields += ["title", "briefing", "targetOrbit", "requiredLauncher", "requiredBus"]
			number_fields = ["missionNumber", "targetAltitudeKm", "durationDays", "requiredDeltaVMps", "budgetCapMillions", "rewardFundsMillions", "rewardSciencePoints"]
			for field in ["requiredPartIds", "requiredCapabilities"]:
				if not item.get(field) is Array:
					return false
				for value: Variant in item[field]:
					if not value is String or value.is_empty():
						return false
			if item.has("objectives"):
				if not item.objectives is Array or item.objectives.is_empty(): return false
				var objective_ids := {}
				for objective in item.objectives:
					if not objective is Dictionary: return false
					for key in ["id", "name", "trigger"]:
						if not objective.get(key) is String or objective[key].is_empty(): return false
					if objective.id in objective_ids or objective.trigger not in ["launch", "sunlit_pass", "duration", "imaging", "downlink", "clear_days", "circularize", "powered_part", "trans_lunar", "lunar_corridor", "deep_space_link", "splashdown"]: return false
					objective_ids[objective.id] = true
					if objective.trigger == "imaging" and (not _is_number(objective.get("targetImages")) or objective.targetImages < 1 or objective.targetImages != floor(objective.targetImages)): return false
					if objective.trigger == "clear_days" and (not _is_number(objective.get("minimumClearDays")) or objective.minimumClearDays <= 0): return false
					if objective.trigger == "downlink" and (not _is_number(objective.get("minimumDataRateKbps")) or objective.minimumDataRateKbps <= 0): return false
					if objective.trigger == "circularize" and (not _is_number(objective.get("targetRadiusKm")) or objective.targetRadiusKm <= 0): return false
					if objective.trigger == "powered_part" and (not objective.get("requiredPartId") is String or objective.requiredPartId.is_empty()): return false
					if objective.trigger == "sunlit_pass":
						for key in ["requiredPartId", "message"]:
							if not objective.get(key) is String or objective[key].is_empty(): return false
			if item.has("durationStartsAtOrbit") and not item.durationStartsAtOrbit is bool: return false
			if item.has("guaranteedEventId") and (not item.guaranteedEventId is String or item.guaranteedEventId.is_empty()): return false
			if item.has("unlocksTier") and (not _is_number(item.unlocksTier) or item.unlocksTier < 0 or item.unlocksTier > 4 or item.unlocksTier != floor(item.unlocksTier)):
				return false
		_:
			return false
	for field in string_fields:
		if not item.get(field) is String or item[field].is_empty():
			return false
	for field in number_fields:
		if not _is_number(item.get(field)) or item[field] < 0:
			return false
	if kind != "missions" and (item.tier < 0 or item.tier > 4 or item.tier != floor(item.tier)):
		return false
	if kind == "components" and item.isExternal and item.volumeLiters != 0:
		return false
	if kind == "missions" and (item.missionNumber < 1 or item.missionNumber != floor(item.missionNumber)):
		return false
	return true


func _is_number(value: Variant) -> bool:
	return value is int or value is float


func get_launcher(id: String) -> Dictionary:
	return _launcher_index.get(id, {})


func get_bus(id: String) -> Dictionary:
	return _bus_index.get(id, {})


func get_part(id: String) -> Dictionary:
	return _part_index.get(id, {})


func get_mission(number: int) -> Dictionary:
	return _mission_index.get(number, {})


func parts_by_subsystem(unlocked_only: bool = true) -> Dictionary:
	var groups: Dictionary = {}
	for part in components:
		if unlocked_only and not GameManager.is_part_unlocked(part.id):
			continue
		if not groups.has(part.subsystem):
			groups[part.subsystem] = []
		groups[part.subsystem].append(part)
	return groups

func get_tech_node(id: String) -> Dictionary:
	return _tech_index.get(id, {})

func _load_tech_nodes(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		push_error("Cannot read tech catalog: " + path)
		return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Array:
		push_error("Invalid tech catalog: " + path)
		return []
	var ids := {}
	for node in parsed:
		if not node is Dictionary or not node.get("id") is String or node.id.is_empty() or ids.has(node.id) or not node.get("name") is String or not node.get("branch") in ["launch","power","comms","adcs_prop","instruments","landing"] or not _is_number(node.get("tier")) or node.tier < 0 or node.tier > 4 or not _is_number(node.get("cost")) or node.cost < 0 or not node.get("prereqNodes") is Array or not node.get("unlocksParts") is Array or not node.get("hackathonEnabled") is bool or not node.get("description") is String:
			push_error("Invalid tech record: " + path)
			return []
		ids[node.id] = true
		if node.tier != floor(node.tier) or node.cost != floor(node.cost) or not node.has("prereqMission") or not node.has("effect") or (node.effect != null and not node.effect is Dictionary):
			push_error("Invalid tech record: " + path)
			return []
		if node.prereqMission != null:
			var mission_found := false
			if _is_number(node.prereqMission):
				for mission in missions:
					if mission.missionNumber == node.prereqMission: mission_found = true
			if not mission_found:
				push_error("Invalid tech mission prerequisite: " + path)
				return []
		out.append(node)
	for node in out:
		for required in node.prereqNodes:
			if not required is String or not ids.has(required):
				push_error("Invalid tech prerequisite: " + path)
				return []
		for part_id in node.unlocksParts:
			var found := false
			for catalog in [launchers, buses, components]:
				for item in catalog:
					if item.id == part_id: found = true
			if not found:
				push_error("Invalid tech unlock: " + path)
				return []
	return out
