--#region Config

REALTIME_LOGGING = true
--Enable only when using pass through mode in the sniffer (or when not using packet level filter)

LOG_SKILL_CASTS = false
--Option to log skill casts (autos also count)

LOG_ONLY_DAMAGE_TO_MONSTERS = false
--Option to only log damage to monster type entities

LOG_ONLY_NONZERO_DAMAGE = false
--Option to only log non-zero damage (happens quite often but may be important)

FILE_LOGGING = true
--Write logs to file in /damage_logs (in the same directory as the sniffer)

LOG_BY_TEAM_UPDATE = true
--Option to create a new log file for every team update inside a new directory
--If disabled, logs will all collect in one file, with team update rows

SHOW_PACKETS_ON_FILTER = true
--Option to show packets in captures window after applying filter (if using packet level filter method)
--Disabling *might* improve performance but I don't think I've seen much of a difference

USE_REACTION_CORRECTION = false
--EXPERIMENTAL: Might make reaction ownership attribution better or worse
--Should no longer be used! See damage_parser.py for a better reaction source corrector

--#endregion

GAME_VERSION = "3.0.5x"

local packet_ids = require("data.packet_ids")
local resolver = require("resolver")
local util = require("output.util")
util.init()

local last_uid = 0
local last_shown = 0

local function get(node, field)
	return node:field(field):value():get()
end

local function filter_check(uid)
	if REALTIME_LOGGING then return end
	if uid > last_uid then
		last_uid = uid
		return true
	end
	if last_shown >= uid then return SHOW_PACKETS_ON_FILTER end
	last_shown = uid
end

function on_filter(packet)

	local uid = packet:uid()
	local pid = packet:mid()

	--Packet is always sent when loading into a new scene / changing teams (even just swapping characters around)
	if pid == packet_ids.SceneTeamUpdateNotify then
		local fc = filter_check(uid)
		if fc ~= nil then return fc end

		resolver.reset_ids()
		util.reset_last_time()

		local node = packet:content():node()
		local list = get(node, "scene_team_avatar_list")

		local team_avatars = {}
		local offsets = {}
		for i in ipairs(list) do
			local team_avatar = list[i]:get()
			local block = get(team_avatar, "ability_control_block")
			local embryos = get(block, "ability_embryo_list")
			if #embryos == 0 then return false end --avoid unnecessary dupe rows
			
			local guid = get(team_avatar, "avatar_guid")
			local entity_id = get(team_avatar, "entity_id")

			local entity_info = get(team_avatar, "scene_entity_info")
			local avatar_info = get(entity_info, "avatar")
			local avatar_id = get(avatar_info, "avatar_id")
			resolver.add_avatar(guid, entity_id, avatar_id)
			team_avatars[i] = resolver.get_root(avatar_id)

			local got_offset = false
			for _, a in ipairs(embryos) do
				local ability = a:get()
				local aid = get(ability, "ability_id")
				local hash = get(ability, "ability_name_hash")
				resolver.add_ability_hash(entity_id, aid, hash)
				if not got_offset then
					offsets[i] = aid
					got_offset = true
				end
			end
		end

		util.write_header(team_avatars, offsets)
		return SHOW_PACKETS_ON_FILTER
	
	elseif pid == packet_ids.SceneEntityAppearNotify then
		local fc = filter_check(uid)
		if fc ~= nil then return fc end

		local node = packet:content():node()
		local list = get(node, "entity_list")

		for _, v in ipairs(list) do
			local entity = v:get()
			local entity_id = get(entity, "entity_id")
			local type = get(entity, "entity_type")

			if type == 2 then --PROT_ENTITY_TYPE_MONSTER = 2
				local info = get(entity, "monster")
				local monster_id = get(info, "monster_id")
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
		local entity_id = get(node, "entity_id")
		
		local owner_id = get(node, "owner_entity_id")
		local config_id = get(node, "config_id")
		resolver.add_gadget(entity_id, owner_id, config_id)

		if last_uid > uid then return SHOW_PACKETS_ON_FILTER end
		return true
	end

	if pid == packet_ids.UnionCmdNotify then
		if last_uid > uid then return false end
		return true
	
	elseif pid == packet_ids.CombatInvocationsNotify then
		local node = packet:content():node()
		local list = get(node, "invoke_list")[1]:get()
		local arg = get(list, "argument_type")

		if arg ~= 1 then return false end --COMBAT_TYPE_ARGUMENT_EVT_BEING_HIT
		local fc = filter_check(uid)
		if fc ~= nil then return fc end
		
		if list:has_field("combat_data_unpacked") then
			local data = get(list, "combat_data_unpacked")
			local attack = get(data, "attack_result")

			local damage = get(attack, "damage")
			local defender = get(attack, "defense_id")
			if (LOG_ONLY_NONZERO_DAMAGE and damage == 0) or
			   (LOG_ONLY_DAMAGE_TO_MONSTERS and resolver.id_type(defender) ~= "Monster") then
				return false
			end

			local crit = get(attack, "is_crit")
			local apply = resolver.get_apply(get(attack, "element_durability_attenuation"))
			local element = resolver.get_element(get(attack, "element_type"))
			local amp_type = resolver.get_amp_type(get(attack, "amplify_reaction_type"))
			local amp_rate = get(attack, "element_amplify_rate")
			local count = get(attack, "attack_count")

			local ability = get(attack, "ability_identifier")
			local aid = get(ability, "instanced_ability_id")
			local mid = get(ability, "instanced_modifier_id")
			local caster = get(ability, "ability_caster_id")
			local attacker = get(attack, "attacker_id")
			local reaction = resolver.get_reaction(aid, mid, element, attacker)

			local source = resolver.get_source(attacker, caster, aid, element, defender)
			attacker = resolver.get_attacker(attacker, caster, aid, damage, defender)
			defender = resolver.id_type(defender) == "Gadget" and resolver.get_source(defender) or resolver.get_root(defender)

			--local timestamp = util.convert_time(attack, "attack_timestamp_ms"))
			local timestamp = packet:timestamp()
			local time = util.format_time(timestamp)
			local delta = util.delta_time(timestamp)
			
			util.write_row("DAMAGE", uid, time, delta, source, attacker, 
			damage, crit, apply, element, reaction, amp_type, amp_rate, count, aid, mid, defender)
			return SHOW_PACKETS_ON_FILTER
		end
	
	elseif pid == packet_ids.AbilityInvocationsNotify then
		local node = packet:content():node()
		local list = get(node, "invokes")[1]:get()
		local arg = get(list, "argument_type")

		if arg ~= 19 --ABILITY_INVOKE_ARGUMENT_META_UPDATE_BASE_REACTION_DAMAGE = 19
		--and arg ~= 20 --ABILITY_INVOKE_ARGUMENT_META_TRIGGER_ELEMENT_REACTION = 20
		then return false end
		local fc = filter_check(uid)
		if fc ~= nil then return fc end

		if list:has_field("ability_data_unpacked") then
			local entity_id = get(list, "entity_id") or 0
			local ability = get(list, "ability_data_unpacked")

			--if arg == 19 then
				local reaction = get(ability, "reaction_type")
				local caster = get(ability, "source_caster_id")
				--print("BaseDmg: " .. reaction .. " " .. resolver.get_id(caster) .. " " ..  resolver.get_id(entity_id))
				resolver.update_reaction(reaction, caster, entity_id)
			--else
				--local reaction = get(ability, "element_reaction_type")
				--local trigger = get(ability, "trigger_entity_id")
				--local source = get(ability, "element_source_type")
				--local reactor = get(ability, "element_reactor_type")
				--print("Trigger: " .. reaction .. " " .. resolver.get_id(trigger) .. " " ..  resolver.get_id(entity_id))
				--" / " .. resolver.get_element(source) .. " -> " .. resolver.get_element(reactor))
				--resolver.update_reaction(reaction, trigger, entity_id)
			--end
			
			return SHOW_PACKETS_ON_FILTER
		end
	
	elseif pid == packet_ids.EvtDoSkillSuccNotify then
		local fc = filter_check(uid)
		if fc ~= nil then return fc end
		if not LOG_SKILL_CASTS then return false end

		local node = packet:content():node()
		local caster = resolver.get_root(get(node, "caster_id"))
		local skill = resolver.get_skill(get(node, "skill_id"))

		local timestamp = packet:timestamp()
		local time = util.format_time(timestamp)
		local delta = util.delta_time(timestamp)

		util.write_row("SKILL", uid, time, delta, skill, caster)
	end

	return false
end