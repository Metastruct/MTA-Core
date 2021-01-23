AddCSLuaFile("mta/core.lua")
AddCSLuaFile("mta/songs.lua")
AddCSLuaFile("mta/upgrades.lua")
AddCSLuaFile("mta/skill_tree.lua")
AddCSLuaFile("mta/bounties.lua")
AddCSLuaFile("mta/bombs.lua")
AddCSLuaFile("mta/fever.lua")
AddCSLuaFile("mta/riot_shield_texture_manager.lua")

include("mta/core.lua")
include("mta/songs.lua")
include("mta/upgrades.lua")
include("mta/skill_tree.lua")
include("mta/bounties.lua")
include("mta/bombs.lua")
include("mta/fever.lua")
include("mta/riot_shield_texture_manager.lua")

-- better combine tracers
do
	if SERVER then
		-- commenting this for now, so we get the latest update from the workshop addon
		-- for the particles (.pcf) instead of having a dated copy
		-- resource.AddFile("particles/cmb_tracers_rework.pcf")
	end

	PrecacheParticleSystem("cmb_tracer")
	PrecacheParticleSystem("ar2_combineball")

	game.AddParticles("particles/cmb_tracers_rework.pcf")
	game.AddParticles("particles/cmb_tracers_rework.pcf")
end