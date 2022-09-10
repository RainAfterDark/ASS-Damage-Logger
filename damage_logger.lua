--#region Config

LOG_SKILL_CASTS = false
--Option to log skill casts (autos also count)

LOG_ONLY_DAMAGE_TO_MONSTERS = true
--Option to only log damage to monster type entities

LOG_ZERO_DAMAGE = false
--Option to log damage registered as 0 (happens quite often but may be important)

FILE_LOGGING = true
--Write logs to file, filename will always be 'latest.txt'

FILE_OPEN_MODE = "w"
--"a" to append, "w" to overwrite

TABLE_FORMAT = false
--Option to have logs be neatly formatted with uniform spacing (and colors!)
--Disable for performance and to save whitespace on logs (and to use the py parser)
--TO DO: a better frontend log parser with neat graphs and stuff

SHOW_PACKETS_ON_FILTER = true
--Option to show packets in captures window after applying filter
--Disabling *might* improve performance but I don't think I've seen much of a difference

USE_REACTION_CORRECTION = false
--EXPERIMENTAL: Might make reaction ownership attribution better or worse
--Should no longer be used! See damage_parser.py for a better reaction source corrector

--#endregion

GAME_VERSION = "3.0.0"

local packet_ids = require("data.packet_ids")
local resolver = require("resolver")
local util = require("output.util")
util.init()

local last_uid = 0
local last_packets = {
	SceneTeamUpdateNotify = 0,
	SceneEntityAppearNotify = 0,
	CombatInvocationsNotify = 0,
	AbilityInvocationsNotify = 0,
	EvtDoSkillSuccNotify = 0
}

function on_filter(packet)

	local uid = packet:uid()
	local pid = packet:mid()
	local first_run = false

	if uid > last_uid then
		last_uid = uid
		first_run = true
	end

	--Packet is always sent when loading into a new scene / changing teams (even just swapping characters around)
	if pid == packet_ids.SceneTeamUpdateNotify then
		if first_run then return true end
		if last_packets.SceneTeamUpdateNotify >= uid then
			return SHOW_PACKETS_ON_FILTER
		end
		last_packets.SceneTeamUpdateNotify = uid

		resolver.reset_ids()
		util.reset_last_time()

		local node = packet:content():node()
		local list = node:field("scene_team_avatar_list"):value():get()

		local team_text = "TEAM UPDATE: "
		local offsets_text = "AID OFFSETS: "
		for i in ipairs(list) do
			local team_avatar = list[i]:get()
			local guid = team_avatar:field("avatar_guid"):value():get()
			local entity_id = team_avatar:field("entity_id"):value():get()

			local entity_info = team_avatar:field("scene_entity_info"):value():get()
			local avatar_info = entity_info:field("avatar"):value():get()
			local avatar_id = avatar_info:field("avatar_id"):value():get()
			resolver.add_avatar(guid, entity_id, avatar_id)
			team_text = team_text .. resolver.get_id(avatar_id) .. (i == #list and "" or ", ")

			local block = team_avatar:field("ability_control_block"):value():get()
			local embryos = block:field("ability_embryo_list"):value():get()

			local got_offset = false
			for _, a in ipairs(embryos) do
				local aid = a:get():field("ability_id"):value():get()
				local hash = a:get():field("ability_name_hash"):value():get()
				resolver.add_ability_hash(entity_id, aid, hash)
				if not got_offset then
					offsets_text = offsets_text .. aid .. (i == #list and "" or ", ")
					got_offset = true
				end
			end
		end

		util.write_header(team_text, offsets_text)
		return SHOW_PACKETS_ON_FILTER
	
	elseif pid == packet_ids.SceneEntityAppearNotify then
		if first_run then return true end
		if last_packets.SceneEntityAppearNotify >= uid then
			return SHOW_PACKETS_ON_FILTER
		end
		last_packets.SceneEntityAppearNotify = uid

		local node = packet:content():node()
		local list = node:field("entity_list"):value():get()

		for _, v in ipairs(list) do
			local entity = v:get()
			local entity_id = entity:field("entity_id"):value():get()
			local type = entity:field("entity_type"):value():get()

			--PROT_ENTITY_TYPE_MONSTER = 2
			if type == 2 then
				local info = entity:field("monster"):value():get()
				local monster_id = info:field("monster_id"):value():get()
				resolver.add_monster(entity_id, monster_id)
			end
		end

		return SHOW_PACKETS_ON_FILTER
	end

	if packet:direction() ~= NetIODirection.Send then
		return false
	end

	if pid == packet_ids.EvtCreateGadgetNotify then
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

	if pid == packet_ids.UnionCmdNotify then
		if last_uid > uid then
			return false
		end
		return true
	
	elseif pid == packet_ids.CombatInvocationsNotify then
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
			if LOG_ONLY_DAMAGE_TO_MONSTERS and resolver.id_type(defender) ~= "Monster" then
				return false
			end

			if last_packets.CombatInvocationsNotify >= uid then
				return SHOW_PACKETS_ON_FILTER
			end
			last_packets.CombatInvocationsNotify = uid

			local crit = attack:field("is_crit"):value():get()
			local apply = resolver.get_apply(attack:field("element_durability_attenuation"):value():get())
			local element = resolver.get_element(attack:field("element_type"):value():get())
			local amp_type = resolver.get_amp_type(attack:field("amplify_reaction_type"):value():get())
			local amp_rate = attack:field("element_amplify_rate"):value():get()
			local count = attack:field("attack_count"):value():get()

			local ability = attack:field("ability_identifier"):value():get()
			local aid = ability:field("instanced_ability_id"):value():get()
			local mid = ability:field("instanced_modifier_id"):value():get()
			local caster = ability:field("ability_caster_id"):value():get()
			local reaction = resolver.get_reaction(aid, element)

			local attacker = attack:field("attacker_id"):value():get()
			local source = resolver.get_source(attacker, caster, aid, element, defender)
			attacker = resolver.get_attacker(attacker, caster, aid, damage, defender)
			defender = resolver.id_type(defender) == "Gadget" and resolver.get_source(defender) or resolver.get_id(defender)

			--local timestamp = util.convert_time(attack:field("attack_timestamp_ms"):value():get())
			local timestamp = packet:timestamp()
			local time = util.format_time(timestamp)
			local delta = util.delta_time(timestamp)
			
			util.write_row("DAMAGE", uid, time, delta, source, attacker, 
			damage, crit, apply, element, reaction, amp_type, amp_rate, count, aid, mid, defender)
			return SHOW_PACKETS_ON_FILTER
		end
	
	elseif pid == packet_ids.AbilityInvocationsNotify then
		local node = packet:content():node()
		local list = node:field("invokes"):value():get()[1]:get()
		local arg = list:field("argument_type"):value():get()

		--ABILITY_INVOKE_ARGUMENT_META_UPDATE_BASE_REACTION_DAMAGE = 19
		--ABILITY_INVOKE_ARGUMENT_META_TRIGGER_ELEMENT_REACTION = 20
		if arg ~= 19 and arg ~= 20 then return false end
		if first_run then return true end

		if list:has_field("ability_data_unpacked") then

			if last_packets.AbilityInvocationsNotify >= uid then
				return SHOW_PACKETS_ON_FILTER
			end
			last_packets.AbilityInvocationsNotify = uid

			local entity_id = list:field("entity_id"):value():get() or 0
			local ability = list:field("ability_data_unpacked"):value():get()

			if arg == 19 then
				local reaction = ability:field("reaction_type"):value():get()
				local caster = ability:field("source_caster_id"):value():get()
				--print("BaseDmg: " .. reaction .. " " .. resolver.get_id(caster) .. " " ..  resolver.get_id(entity_id))
				resolver.update_reaction(reaction, caster, entity_id)
			else
				local reaction = ability:field("element_reaction_type"):value():get()
				local trigger = ability:field("trigger_entity_id"):value():get()
				--local source = ability:field("element_source_type"):value():get()
				--local reactor = ability:field("element_reactor_type"):value():get()
				--print("Trigger: " .. reaction .. " " .. resolver.get_id(trigger) .. " " ..  resolver.get_id(entity_id))
				resolver.update_reaction(reaction, trigger, entity_id)
				--" / " .. resolver.get_element(source) .. " -> " .. resolver.get_element(reactor))
			end
			
			return SHOW_PACKETS_ON_FILTER
		end
	
	elseif pid == packet_ids.EvtDoSkillSuccNotify and LOG_SKILL_CASTS then

		if first_run then return true end
		if last_packets.EvtDoSkillSuccNotify >= uid then
			return SHOW_PACKETS_ON_FILTER
		end
		last_packets.EvtDoSkillSuccNotify = uid

		local node = packet:content():node()
		local caster = resolver.get_id(node:field("caster_id"):value():get())
		local skill = resolver.get_skill(node:field("skill_id"):value():get())

		local timestamp = packet:timestamp()
		local time = util.format_time(timestamp)
		local delta = util.delta_time(timestamp)

		util.write_row("SKILL", uid, time, delta, skill, caster)
	end

	return false
end





