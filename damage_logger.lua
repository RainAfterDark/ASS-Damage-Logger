--#region Config

LOG_SKILL_CASTS = true
--Option to log skill casts (autos also count)

LOG_DAMAGE_TO_AVATAR = false
--Option to log damage dealt to characters

LOG_ZERO_DAMAGE = false
--Option to log damage registered as 0 (happens quite often for some reason)

FILE_LOGGING = false
--Write logs to file, filename will always be 'latest.txt' and will append

TABLE_FORMAT = true
--Option to have logs be neatly formatted with uniform spacing (and colors!)
--Disable for performance and to save whitespace on logs
--TO DO: a better frontend log parser with neat graphs and stuff

SHOULD_RESOLVE_NAMES = true
--Option to resolve IDs to readable names
--This applies to avatar, gadget, skill, element, and amp type names

SHOW_PACKETS_ON_FILTER = true
--Disabling will prevent packets to show up in captures window after applying filter
--(Might improve performance, only enable when you really have to)

--#endregion

local resolver = require("resolver")
local util = require("output.util")
util.init()

local last_time = 0
local last_uid = 0
local last_packets = {
	SceneTeamUpdateNotify = 0,
	CombatInvocationsNotify = 0,
	AbilityInvocationsNotify = 0,
	EvtDoSkillSuccNotify = 0
}

function on_filter(packet)

	local uid = packet:uid()
	local name = packet:name()
	local first_run = false

	if uid > last_uid then
		last_uid = uid
		first_run = true
	end

	--Packet is always sent when loading into a new scene / changing teams (even just swapping characters)
	if name == "SceneTeamUpdateNotify" then
		if first_run then return true end
		if last_packets.SceneTeamUpdateNotify >= uid then
			return SHOW_PACKETS_ON_FILTER
		end
		last_packets.SceneTeamUpdateNotify = uid

		resolver.reset_ids()

		local node = packet:content():node()
		local list = node:field("scene_team_avatar_list"):value():get()

		local team_text = "TEAM, "
		for k in ipairs(list) do
			local team_avatar = list[k]:get()
			local entity_id = team_avatar:field("entity_id"):value():get()
			local entity_info = team_avatar:field("scene_entity_info"):value():get()
			local avatar_info = entity_info:field("avatar"):value():get()
			local avatar_id = avatar_info:field("avatar_id"):value():get()
			resolver.add_avatar(entity_id, avatar_id)
			team_text = team_text .. resolver.get_id(avatar_id) .. (k == 4 and "" or ", ")
		end

		if TABLE_FORMAT then
			util.color_bg(240)
			util.write(" ", util.pad(team_text, 205), "\n")
			util.reset_style()
			util.write_row("Type", "UID", "Delta", "Source / Skill", "Attacker", "Damage", "Crit", "Apply", "Element", "Reaction", "Amp Type", "Amp Rate", "Count", "AID", "MID", "Defender")
		else
			util.write(team_text, "\n")
		end

		return SHOW_PACKETS_ON_FILTER

	elseif name == "EvtCreateGadgetNotify" then
		local node = packet:content():node()
		local entity_id = node:field("entity_id"):value():get()
		
		local owner_id = node:field("owner_entity_id"):value():get()
		local config_id = node:field("config_id"):value():get()
		resolver.add_gadget(entity_id, owner_id, config_id)

		if last_uid > uid then
			return SHOW_PACKETS_ON_FILTER
		end
		return true
	end

	if packet:direction() ~= NetIODirection.Send then
		return false
	end

	if name == "UnionCmdNotify" then
		if last_uid > uid then
			return false
		end
		local list_len = #(packet:content():node():field("cmd_list"):value():get())
		return list_len > 1
	
	elseif name == "CombatInvocationsNotify" then
		local node = packet:content():node()
		local list = node:field("invoke_list"):value():get()[1]:get()
		local arg = list:field("argument_type"):value():get()

		--COMBAT_TYPE_ARGUMENT_EVT_BEING_HIT
		if arg ~= 1 then return false end
		if first_run then return true end
		
		if list:has_field("combat_data_unpacked") then
			local data = list:field("combat_data_unpacked"):value():get()
			local attack = data:field("attack_result"):value():get()

			local damage = attack:field("damage"):value():get()
			if not LOG_ZERO_DAMAGE and damage == 0 then
				return false
			end

			local defender = attack:field("defense_id"):value():get()
			if not LOG_DAMAGE_TO_AVATAR and resolver.id_type(defender) == "Avatar" then
				return false
			end

			if last_packets.CombatInvocationsNotify >= uid then
				return SHOW_PACKETS_ON_FILTER
			end
			last_packets.CombatInvocationsNotify = uid

			local crit = attack:field("is_crit"):value():get()
			local apply = attack:field("element_durability_attenuation"):value():get() == 1
			local element = attack:field("element_type"):value():get()
			local amp_type = attack:field("amplify_reaction_type"):value():get()
			local amp_rate = attack:field("element_amplify_rate"):value():get()
			local count = attack:field("attack_count"):value():get()

			local ability = attack:field("ability_identifier"):value():get()
			local aid = ability:field("instanced_ability_id"):value():get() or 0
			local mid = ability:field("instanced_modifier_id"):value():get() or 0
			local reaction = resolver.get_reaction(aid, element)

			local attacker = attack:field("attacker_id"):value():get()
			local source = resolver.get_source(attacker)
			attacker = resolver.get_attacker(attacker, aid, mid, defender)
			defender = resolver.id_type(defender) == "Gadget" and resolver.get_source(defender) or resolver.get_id(defender)

			if SHOULD_RESOLVE_NAMES then
				element = resolver.get_element(element)
				amp_type = resolver.get_amp_type(amp_type)
			end

			local timestamp = packet:timestamp()
			local delta = timestamp - last_time
			if last_time == 0 then delta = 0 end
			last_time = timestamp
			
			util.write_row("DAMAGE", uid, delta, source, attacker, damage, crit, apply, element, reaction, amp_type, amp_rate, count, aid, mid, defender)
			return SHOW_PACKETS_ON_FILTER
		end
	
	elseif name == "AbilityInvocationsNotify" then
		local node = packet:content():node()
		local list = node:field("invokes"):value():get()[1]:get()
		local arg = list:field("argument_type"):value():get()

		--[[local exceptions = {0, 7, 8, 11, 16, 18, 100, 104, 105, 106, 107}
		for _, v in ipairs(exceptions) do
			if arg == v then
				return false
			end
		end]]

		--ABILITY_INVOKE_ARGUMENT_META_MODIFIER_CHANGE
		if arg ~= 1 or not list:has_field("head") then return false end
		if first_run then return true end

		if list:has_field("ability_data_unpacked") then

			local ability = list:field("ability_data_unpacked"):value():get()
			if not ability:has_field("apply_entity_id") then return false end

			if last_packets.AbilityInvocationsNotify >= uid then
				return SHOW_PACKETS_ON_FILTER
			end
			last_packets.AbilityInvocationsNotify = uid
			
			local head = list:field("head"):value():get()
			local target_id = head:field("target_id"):value():get()
			local entity_id = list:field("entity_id"):value():get()
			local apply_id = ability:field("apply_entity_id"):value():get()

			local aid = head:field("instanced_ability_id"):value():get() or 0
			local mid = head:field("instanced_modifier_id"):value():get() or 0

			if apply_id ~= 0 and resolver.id_type(target_id) == "Reaction" then
				resolver.add_ability(aid, mid, entity_id, apply_id)
			end
			return SHOW_PACKETS_ON_FILTER
		end
	
	elseif name == "EvtDoSkillSuccNotify" and LOG_SKILL_CASTS then

		if first_run then return true end
		if last_packets.EvtDoSkillSuccNotify >= uid then
			return SHOW_PACKETS_ON_FILTER
		end
		last_packets.EvtDoSkillSuccNotify = uid

		local timestamp = packet:timestamp()
		local delta = timestamp - last_time
		if last_time == 0 then delta = 0 end
		last_time = timestamp

		local node = packet:content():node()
		local caster = resolver.get_id(node:field("caster_id"):value():get())
		local skill = resolver.get_skill(node:field("skill_id"):value():get())

		util.write_row("SKILL", uid, delta, skill, caster)
	end

	return false
end


