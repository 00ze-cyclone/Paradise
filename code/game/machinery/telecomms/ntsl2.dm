GLOBAL_DATUM_INIT(ntsl2_config, /datum/ntsl2_configuration, new())
// Custom Implementations for NTSL2
/* NTSL2 Configuration Datum
 * This is an abstract handler for the configuration loadout. It's set up like this both for ease of transfering in and out of the UI 
 * as well as allowing users to save and load configurations.
 */
/datum/ntsl2_configuration
	/* Simple Toggles */
	var/toggle_activated = TRUE
	var/toggle_jobs = FALSE
	var/toggle_timecode = FALSE
	// Hack section
	var/toggle_gibberish = FALSE
	var/toggle_honk = FALSE

	/* Strings */
	var/setting_language = null

	/* Tables */
	var/list/regex = list()

	/* Arrays */
	var/list/firewall = list()

	/* Meta stuff */
	// These variables requires the source computer to be hacked in order to change
	var/list/requires_unlock = list(
		"firewall" = TRUE
	)

	// This is used to sanitize topic data
	var/list/tables = list("regex")
	var/list/arrays = list("firewall")

	// This tells the datum what is safe to serialize and what's not. It also applies to deserialization.
	var/list/to_serialize = list(
		"toggle_activated",
		"toggle_jobs",
		"toggle_timecode",
		"toggle_gibberish",
		"toggle_honk",
		"setting_language",
		"regex",
		"firewall"
	)

	// This is used for sanitization.
	var/list/serialize_sanitize = list(
		"toggle_activated" = "bool",
		"toggle_jobs" = "bool",
		"toggle_timecode" = "bool",
		"toggle_gibberish" = "bool",
		"toggle_honk" = "bool",
		"setting_language" = "string",
		"regex" = "table",
		"firewall" = "array"
	)

	// Used to determine what languages are allowable for conversion. Generated during runtime.
	var/list/valid_languages = list("--DISABLE--")

/datum/ntsl2_configuration/proc/reset()
	/* Simple Toggles */
	toggle_activated = initial(toggle_activated)
	toggle_jobs = initial(toggle_jobs)
	toggle_timecode = initial(toggle_timecode)
	// Hack section
	toggle_gibberish = initial(toggle_gibberish)
	toggle_honk = initial(toggle_honk)

	/* Strings */
	setting_language = initial(setting_language)

	/* Tables */
	regex = list()

	/* Arrays */
	firewall = list()


/datum/ntsl2_configuration/proc/update_languages()
	for(var/language in all_languages)
		var/datum/language/L = all_languages[language]
		if(L.flags & HIVEMIND)
			continue
		valid_languages[language] = TRUE

// I'd use serialize() but it's used by another system. This converts the configuration into a JSON string.
/datum/ntsl2_configuration/proc/ntsl_serialize()
	var/list/all_vars = list()
	for(var/variable in to_serialize)
		all_vars[variable] = vars[variable]
	. = json_encode(all_vars)

// This loads a configuration from a JSON string.
/datum/ntsl2_configuration/proc/ntsl_deserialize(text)
	var/list/var_list = json_decode(text)
	for(var/variable in var_list)
		if(variable in to_serialize) // Don't just accept any random vars jesus christ!
			var/sanitize_method = serialize_sanitize[variable]
			var/variable_value = var_list[variable]
			variable_value = sanitize(variable_value, sanitize_method)
			if(variable_value)
				vars[variable] = var_list[variable_value]

// Sanitizing user input. Don't blindly trust the JSON.
/datum/ntsl2_configuration/proc/sanitize(variable, sanitize_method)
	if(!variable || !sanitize_method)
		return null

	switch(sanitize_method)
		if("bool")
			return !!variable
		if("table", "array")
			if(!islist(variable))
				return null
			// Insert html filtering for the regexes here if you're boring
			return variable
		if("string")
			return "[variable]"

	return variable

// Primary signal modification. This is where all of the variables behavior are actually implemented.
/datum/ntsl2_configuration/proc/modify_signal(datum/signal/signal)
	// Servers are deliberately turned off. Mark every signal as rejected.
	if(!toggle_activated)
		signal.data["reject"] = TRUE
		return

	// Firewall 
	// This must happen before anything else modifies the signal ["name"].
	if(islist(firewall) && firewall.len > 0)
		if(firewall.Find(signal.data["name"]))
			signal.data["reject"] = 1

	// These two stack properly.
	// Simple job indicator switch.
	if(toggle_jobs)
		var/new_name = signal.data["name"] + " ([signal.data["job"]]) "
		signal.data["name"] = new_name
		signal.data["realname"] = new_name // this is required because the broadcaster uses this directly if the speaker doesn't have a voice changer on

	// Add the current station time like a time code.
	if(toggle_timecode)
		var/new_name = "\[[station_time_timestamp()]] " + signal.data["name"]
		signal.data["name"] = new_name
		signal.data["realname"] = new_name // this is required because the broadcaster uses this directly if the speaker doesn't have a voice changer on

	// Hacks!
	// Censor dat shit like nobody's business
	if(toggle_gibberish)
		signal.data["message"] = Gibberish(signal.data["message"], 80)

	// Replace everything with HONK!
	if(toggle_honk)
		var/honklength = splittext(signal.data["message"], " ").len
		var/new_message = ""
		for(var/i in 1 to honklength)
			new_message += pick("HoNK!", "HONK", "HOOOoONK", "HONKHONK!", "HoNnnkKK!!!", "HOOOOOOOOOOONK!!!!11!", "henk!")
		signal.data["message"] = new_message


	// Language Conversion
	if(setting_language && valid_languages[setting_language])
		if(setting_language == "--DISABLE--")
			setting_language = null
		else
			signal.data["language"] = all_languages[setting_language]

	// Regex replacements
	if(islist(regex) && regex.len > 0)
		var/original = signal.data["message"]
		var/new_message = original
		for(var/reg in regex)
			var/replacePattern = regex[reg]
			var/regex/start = new(reg, "g")
			new_message = start.Replace(original, replacePattern)
		signal.data["message"] = new_message

	// Check the message for forbidden HTML (REMOVE THIS IF YOU START STRIPPING HTML IN REGEX)
	var/regex/bannedTags = new("(<script|<iframe|<video|<audio)")
	if(bannedTags.Find(signal.data["message"]))
		message_admins("Warning: Current NTSL2 configuration contains banned HTML. Stripping message.")
		log_admin("Warning: Current NTSL2 configuration contains banned HTML. Stripping message.")
		signal.data["message"] = sanitize(signal.data["message"])

	// Make sure the message is valid after we tinkered with it, otherwise reject it
	if(signal.data["message"] == "" || !signal.data["message"])
		signal.data["reject"] = 1

/datum/ntsl2_configuration/Topic(mob/user, href_list, window_id, obj/machinery/computer/telecomms/traffic/source)
	// Toggles
	if(href_list["toggle"])
		var/var_to_toggle = href_list["toggle"]
		if(requires_unlock[var_to_toggle] && !source.unlocked)
			return
		if(!(var_to_toggle in to_serialize))
			return
		vars[var_to_toggle] = !vars[var_to_toggle]

	// Strings
	if(href_list["setting_language"])
		var/new_language = input(user, "Pick a language to convert messages to.", "Language Conversion") as null|anything in valid_languages
		if(!new_language)
			return
		if(new_language == "--DISABLE--")
			setting_language = null
			to_chat(user, "<span class='notice'>Language conversion disabled.</span>")
		else
			setting_language = new_language
			to_chat(user, "<span class='notice'>Messages will now be converted to [new_language].</span>")

	// Tables
	if(href_list["create_row"])
		if(href_list["table"] && href_list["table"] in tables)
			if(requires_unlock[href_list["table"]] && !source.unlocked)
				return
			var/new_key = input(user, "Provide a key for the new row.", "New Row") as text|null
			if(!new_key)
				return
			var/new_value = input(user, "Provide a new value for the key [new_key]", "New Row") as text|null
			if(new_value == null)
				return
			vars[href_list["table"]][new_key] = new_value
			to_chat(user, "<span class='notice'>Added row [new_key] -> [new_value].</span>")

	if(href_list["delete_row"])
		if(href_list["table"] && href_list["table"] in tables)
			if(requires_unlock[href_list["table"]] && !source.unlocked)
				return
			vars[href_list["table"]].Remove(href_list["delete_row"])
			to_chat(user, "<span class='warning'>Removed row [href_list["delete_row"]] from [href_list["table"]]</span>")

	// Arrays
	if(href_list["create_item"])
		if(href_list["array"] && href_list["array"] in arrays)
			if(requires_unlock[href_list["array"]] && !source.unlocked)
				return
			var/new_value = input(user, "Provide a value for the new index.", "New Index") as text|null
			if(new_value == null) 
				return
			vars[href_list["array"]].Add(new_value)
			to_chat(user, "<span class='notice'>Added row [new_value].</span>")

	if(href_list["delete_item"])
		if(href_list["array"] && href_list["array"] in arrays)
			if(requires_unlock[href_list["array"]] && !source.unlocked)
				return
			vars[href_list["array"]].Remove(href_list["delete_item"])
			to_chat(user, "<span class='warning'>Removed [href_list["delete_item"]] from [href_list["array"]]</span>")

	// Spit out the serialized config to the user
	if(href_list["save_config"])
		user << browse(ntsl_serialize(), "window=save_ntsl2")

	if(href_list["load_config"])
		ntsl_deserialize(input(user, "Provide configuration JSON below.", "Load Config", ntsl_serialize()) as message)

	user << output(list2params(list(ntsl_serialize())), "[window_id].browser:updateConfig")

/* Asset datum for the UI */
/datum/asset/simple/ntsl2
	assets = list(
		"bundle.css" = 'html/ntsl2/dist/bundle.css',
		"bundle.js" = 'html/ntsl2/dist/bundle.js',
		"tab_home.html" = 'html/ntsl2/dist/tab_home.html',
		"tab_hack.html" = 'html/ntsl2/dist/tab_hack.html',
		"tab_filtering.html" = 'html/ntsl2/dist/tab_filtering.html',
		"tab_firewall.html" = 'html/ntsl2/dist/tab_firewall.html',
		"tab_regex.html" = 'html/ntsl2/dist/tab_regex.html',
		"uiTitleFluff.png" = 'html/ntsl2/dist/uiTitleFluff.png'
	)

/* Custom subtype of /datum/browser that behaves as we want for our project */
/datum/browser/ntsl2
	var/initial_config // Initial NTSL2 configuration

/datum/browser/ntsl2/New(nuser, nwindow_id, ntitle = 0, nwidth = 0, nheight = 0, var/atom/nref = null, ntsl2_config)
	. = ..()
	initial_config = ntsl2_config
// Prevent all stylesheets from being added, we have our own CSS that's bundled with gulp
/datum/browser/ntsl2/add_stylesheet()
	return
// No header, we're running a fully complete .html file
/datum/browser/ntsl2/get_header()
	return
// We inject a little code at the bottom of the file, similar to NanoUI, but more limited.
// This code is used for delivering live updates of config changes & allowing the UI to provide Topic data.
/datum/browser/ntsl2/get_footer()
	var/byondSrc = "byond://?src=[ref.UID()];"
	var/dat = "<script type='text/javascript'>"
	dat += "window.byondSrc = '[byondSrc]';"
	dat += "window.originalConfig = '[html_encode(initial_config)]';"
	dat += "window.updateConfig = function(config) { window.config = JSON.parse(config); window.reload_tab() };"
	dat += "</script>"
	return dat
