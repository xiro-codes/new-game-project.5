extends Node

func _stat_at_lvl(lvl:int, stat:int, growth_curve: Curve):
	var normalized_lvl:float = (lvl ) / 99.0
	var growth_rate_mul:float = growth_curve.sample(normalized_lvl) * 5.0
	return stat + (stat + ( lvl ) * growth_rate_mul)
