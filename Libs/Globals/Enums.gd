extends Node

#region MenuStates
enum MenuState {
	INACTIVE,
	ACTIVE,
	PARTY_MENU_SHOWN,
	PARTY_MENU_HIDE,
	EQUIPMENT_MENU_HIDE,
	EQUIPMENT_MENU_SHOWN,
	INV_MENU_SHOWN,
	INV_MENU_HIDE,
	QUIT_GAME,
	CLOSE,
}
enum EquipmentMenuState {
	INACTIVE,
	ACTIVE,
	EQUIPMENT_SELECTION_ACTIVE,
	EQUIPMENT_SELECTION_HIDE,
}
enum EquipmentSelectionMenuState {
	INACTIVE,
	ACTIVE,
	SELECTING,
}

enum EquipmentSelectionListState {
	INACTIVE,
	ACTIVE,
}

#endregion
