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

effect_merge :: proc(eff: ^Effect, to_merge: Effect) {
	switch to_merge.effect_id {
	case .Burn:
		eff.duration += to_merge.duration
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

//returns true if effect has run out
effect_tick :: proc(eff: ^Effect, mob: EntityInstMut(Mobile)) -> bool {
	eff.duration -= 1
	#partial switch eff.effect_id {
	case .Burn:
		add_msg("%s burns!", mob.name)
		system_mob_take_damage(mob, eff.stacks)
	case .Poison:
		add_msg("%s suffers from poison!", mob.name)
		system_mob_take_damage(mob, eff.duration)
	}
	return eff.duration <= 0
}
