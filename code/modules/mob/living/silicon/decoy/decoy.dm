/mob/living/silicon/decoy
	name = "AI"
	icon = 'icons/mob/AI.dmi'//
	icon_state = "ai"
	anchored = 1 // -- TLE
	canmove = 0
	a_intent = "harm" // This is apparently the only thing that stops other mobs walking through them as if they were thin air.

/mob/living/silicon/decoy/New()
	src.icon = 'icons/mob/AI.dmi'
	src.icon_state = "ai"
	src.anchored = 1
	src.canmove = 0

/mob/living/silicon/decoy/attackby(var/obj/item/W, var/mob/user, params)
	if(istype(W, /obj/item/aicard))
		user.visible_message("<span class='notice'>[user] cannot find an intellicard slot on [src].</span>")
	else
		return ..(W, user, params)

/mob/living/silicon/decoy/syndicate
	faction = list("syndicate")
	name = "R.O.D.G.E.R"
	desc = "Red Operations, Depot General Emission Regulator"
	icon_state = "ai-magma"

/mob/living/silicon/decoy/syndicate/New()
	. = ..()
	icon_state = "ai-magma"

/mob/living/silicon/decoy/syndicate/depot
	var/raised_alert = FALSE

/mob/living/silicon/decoy/syndicate/depot/proc/raise_alert()
	raised_alert = TRUE
	var/area/syndicate_depot/depotarea = get_area(src) // Cannot use myArea or areaMaster as neither will be defined for this mob type
	if(depotarea)
		depotarea.increase_alert("AI Unit Offline")
	else
		say("Connection failure!")

/mob/living/silicon/decoy/syndicate/depot/death(var/pass)
	if(!raised_alert)
		raise_alert()
	. = ..(pass)

/mob/living/silicon/decoy/syndicate/depot/adjustBruteLoss(var/dmg)
	. = ..(dmg)
	updatehealth()

/mob/living/silicon/decoy/syndicate/depot/adjustFireLoss(var/dmg)
	. = ..(dmg)
	updatehealth()

/mob/living/silicon/decoy/syndicate/depot/ex_act(var/severity)
	adjustBruteLoss(250)