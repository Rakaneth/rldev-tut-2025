package main

Effect :: struct {
	duration:  int,
	stacks:    int,
	effect_id: Effect_Names,
}

Effect_Names :: enum {
	Poison,
	Burn,
	Paralyze,
}

Effect_Proc :: proc(mob: Mobile) -> Effect

effect_merge :: proc(eff: ^Effect, to_merge: Effect) {
	switch to_merge.effect_id {
	case .Burn:
		eff.duration += to_merge.duration
		eff.stacks = max(eff.stacks, to_merge.stacks)
	case .Paralyze:
		eff.duration = to_merge.duration
	case .Poison:
		eff.duration += to_merge.duration
	}
}

effect_apply :: proc(eff: Effect, mob: EntityInstMut(Mobile)) {
	for &current_eff in mob.effects {
		if eff.effect_id == current_eff.effect_id {
			effect_merge(&current_eff, eff)
			switch eff.effect_id {
			case .Burn:
				add_msg("Burning of %s intensifies!", mob.name)
			case .Paralyze:
				add_msg("Paralysis of %s worsens!", mob.name)
			case .Poison:
				add_msg("Poison of %s becomes more virulent!", mob.name)
			}
			return
		}
	}

	append(&mob.effects, eff)
	switch eff.effect_id {
	case .Burn:
		add_msg("%s is burning!", mob.name)
	case .Paralyze:
		add_msg("%s stiffens and cannot move!", mob.name)
	case .Poison:
		add_msg("%s is poisoned!", mob.name)
	}
}

//sets eff.to_remove to true if duration runs out
effect_tick :: proc(eff: ^Effect, mob: EntityInstMut(Mobile)) {
	if eff.duration > 0 {
		#partial switch eff.effect_id {
		case .Burn:
			add_msg("%s burns!", mob.name)
			system_mob_take_damage(mob, eff.stacks)
		case .Poison:
			add_msg("%s suffers from poison!", mob.name)
			system_mob_take_damage(mob, eff.duration)
		}
		eff.duration -= 1
		if eff.duration <= 0 {
			effect_remove(eff^, mob)
		}
	}
}

effect_remove :: proc(eff: Effect, mob: EntityInstMut(Mobile)) {
	for meff, i in mob.effects {
		if eff.effect_id == meff.effect_id {
			switch eff.effect_id {
			case .Burn:
				add_msg("%s is no longer burning.", mob.name)
			case .Paralyze:
				add_msg("%s is no longer paralyzed.", mob.name)
			case .Poison:
				add_msg("%s is no longer poisoned.", mob.name)
			}
			ordered_remove(&mob.effects, i)
			return
		}
	}
}
