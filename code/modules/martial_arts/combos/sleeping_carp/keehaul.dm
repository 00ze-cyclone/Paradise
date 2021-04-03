/datum/martial_combo/sleeping_carp/keehaul
	name = "Keehaul"
	steps = list(MARTIAL_COMBO_STEP_HARM, MARTIAL_COMBO_STEP_GRAB)
	explaination_text = "Kick an opponent to the floor, knocking them down and dealing stamina damage to them!"

/datum/martial_combo/sleeping_carp/keehaul/perform_combo(mob/living/carbon/human/user, mob/living/target, datum/martial_art/MA)
	user.do_attack_animation(target, ATTACK_EFFECT_KICK)
	playsound(get_turf(target), 'sound/effects/hit_kick.ogg', 50, TRUE, -1)
	target.apply_damage(10, BRUTE, BODY_ZONE_HEAD)
	target.apply_damage(40, STAMINA)
	target.Weaken(2)
	target.visible_message("<span class='warning'>[user] kicks [target] in the head, sending them face first into the floor!</span>",
						"<span class='userdanger'>You are kicked in the head by [user], sending you crashing to the floor!</span>",)
	add_attack_logs(user, target, "Melee attacked with martial-art [src] : Kneehaul", ATKLOG_ALL)
	return MARTIAL_COMBO_DONE
