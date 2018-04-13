/obj/item/organ/internal/liver/vox
	name = "Vox liver"
	alcohol_intensity = 1.6
	species = "Vox"


/obj/item/organ/internal/stack
	name = "cortical stack"
	icon_state = "cortical-stack"
	parent_organ = "head"
	organ_tag = "stack"
	slot =  "vox_stack"
	robotic = 2
	vital = 1
	var/stackdamaged = 0

/obj/item/organ/internal/stack/vox
	name = "vox cortical stack"

/obj/item/organ/internal/stack/vox/on_life()
	if(damage < 1 && stackdamaged)
		owner.mutations.Remove(SCRAMBLED)
		owner.dna.SetSEState(SCRAMBLEBLOCK,0)
		genemutcheck(owner,SCRAMBLEBLOCK,null,MUTCHK_FORCED)
		stackdamaged = 0
	..()


/obj/item/organ/internal/stack/vox/emp_act(severity)
	if(owner)
		owner.mutations.Add(SCRAMBLED)
		owner.dna.SetSEState(SCRAMBLEBLOCK,1,1)
		genemutcheck(owner,SCRAMBLEBLOCK,null,MUTCHK_FORCED)
		owner.AdjustConfused(20)
		if(!stackdamaged)
			stackdamaged = 1
	..()