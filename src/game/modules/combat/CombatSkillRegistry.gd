extends RefCounted
class_name CombatSkillRegistry


static func build_default_router() -> TriggerRouter:
	var router := TriggerRouter.new()
	register_default_skills(router)
	return router


static func register_default_skills(router: TriggerRouter) -> void:
	ThermobaricSkill.register(router)
	DryIceSkill.register(router)
	ElectroPierceSkill.register(router)
	GunEvents.register(router)
