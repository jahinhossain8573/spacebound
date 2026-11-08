extends Node

enum State { MAIN_MENU, MISSION_SELECT, WORKSHOP, LAUNCH, FLIGHT_OPS, DEBRIEF, TECH_TREE }

var state: State = State.MAIN_MENU
var funds_millions: float = 0.0
var science_points: int = 0
var unlocked_part_ids: Array[String] = []
var owned_tech_nodes: Array[String] = []
var completed_missions: Array[int] = []
var current_mission: Dictionary = {}
