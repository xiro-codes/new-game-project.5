extends Node
const PLAYER_DATA_PATH = "user://player_data.tres"

func save_player_data(player_data: PlayerData):
	ResourceSaver.save(player_data, PLAYER_DATA_PATH)

func load_player_data() -> PlayerData:
	return ResourceLoader.load(PLAYER_DATA_PATH)
