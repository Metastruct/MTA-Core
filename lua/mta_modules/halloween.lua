local TAG = "MTAHalloween"
local NET_SHADOW = "MTA_HALLOWEEN_SHADOW"

local coefs = {
	["player"] = {
		["kill_coef"] = 2.5,
		["damage_coef"] = 0,
	},
	["npc_manhack"] = {
		["kill_coef"] = 1,
		["damage_coef"] = 0.75,
	},
	["lua_npc"] = {
		["kill_coef"] = 1,
		["damage_coef"] = 0.5,
	},
	["lua_npc_wander"] = {
		["kill_coef"] = 1,
		["damage_coef"] = 0.5,
	},
	["npc_combine_s"] = {
		["kill_coef"] = 1.5,
		["damage_coef"] = 1,
	},
	["npc_metropolice"] = {
		["kill_coef"] = 1.5,
		["damage_coef"] = 1,
	},
	["npc_zombie"] = {
		["kill_coef"] = 1.5,
		["damage_coef"] = 1,
	},
	["npc_poisonzombie"] = {
		["kill_coef"] = 1.5,
		["damage_coef"] = 1,
	},
	["npc_fastzombie"] = {
		["kill_coef"] = 1.5,
		["damage_coef"] = 1,
	},
	["npc_zombine"] = {
		["kill_coef"] = 1.5,
		["damage_coef"] = 1,
	},
	["npc_headcrab"] = {
		["kill_coef"] = 1,
		["damage_coef"] = 0.75,
	},
	["npc_headcrab_black"] = {
		["kill_coef"] = 1,
		["damage_coef"] = 0.75,
	},
	["npc_headcrab_fast"] = {
		["kill_coef"] = 1,
		["damage_coef"] = 0.75,
	},
	["npc_headcrab_poison"] = { -- same as black but for some reason poison?
		["kill_coef"] = 1,
		["damage_coef"] = 0.75,
	},
	["hwn_pumpkin"] = {
		["kill_coef"] = 1,
		["damage_coef"] = 0.75,
	}
}

local is_halloween = false
local function check_halloween()
	-- if there is an even and its now halloween dont do anything
	if MTA.OnGoingEvent ~= false and MTA.OnGoingEvent ~= "halloween" then return end

	is_halloween = os.date("%m") == "10" -- check for spooktober

	if is_halloween then
		MTA.Coeficients = coefs
		MTA.OnGoingEvent = "halloween"
	else
		MTA.Coeficients = MTA_CONFIG.core.Coeficients

		if MTA.OnGoingEvent == "halloween" then
			MTA.OnGoingEvent = false
		end
	end

	if CLIENT then
		MTA.PrimaryColor = is_halloween and Color(255, 0, 0) or Color(244, 135, 2)
		MTA.WantedText = is_halloween and "HORDE" or "WANTED"
	end
end

check_halloween()
timer.Create(TAG, 60, 0, check_halloween)

if SERVER then
	util.AddNetworkString(NET_SHADOW)

	local function default_log(...)
		Msg("[MTA] ")
		print(...)
	end

	local function warn_log(...)
		if not metalog then
			default_log(...)
			return
		end

		metalog.warn("MTA", nil, ...)
	end

	local enemy_types = {
		zombies = function()
			local z = ents.Create("npc_zombie")
			z:SetMaterial("models/alyx/alyxblack")
			return z
		end,
		poison_zombies = function()
			local z = ents.Create("npc_poisonzombie")
			z:SetMaterial("models/alyx/alyxblack")
			return z
		end,
		fast_zombies = function()
			local z = ents.Create("npc_fastzombie")
			z:SetMaterial("models/alyx/alyxblack")
			return z
		end,
		zombines = function()
			local z = ents.Create("npc_zombine")
			z:SetMaterial("models/alyx/alyxblack")
			return z
		end,
	}
	hook.Add("MTANPCSpawnProcess", TAG, function(target, pos, wanted_lvl)
		if not is_halloween then return end
		if IS_MTA_GM then return end
		if target.MTALocalEvent then return end

		-- below 10 is just zombies
		local spawn_function, npc_class = enemy_types.zombies, "npc_zombie"

		-- 10% chance of getting poison zombies here and there
		if math.random(0, 100) <= 10 then
			spawn_function, npc_class = enemy_types.poison_zombies, "npc_poisonzombie"

		-- above level 10 progressively change to only fast zombies
		elseif wanted_lvl < 60 and wanted_lvl >= 10 then
			spawn_function, npc_class = unpack(
				math.random(0, 60) <= (wanted_lvl + 20)
				and { enemy_types.fast_zombies, "npc_fastzombie" }
				or { enemy_types.zombies, "npc_zombie" }
			)

		-- above 60 we add zombines
		elseif wanted_lvl >= 60 then
			spawn_function, npc_class = unpack(
				math.random(0, 100) < 25
				and { enemy_types.zombines, "npc_zombine" }
				or { enemy_types.fast_zombies, "npc_fastzombie" }
		 	)
		end

		return spawn_function, npc_class
	end)

	function update_badge(ply, count)
		local succ, err = pcall(function()
			if MetaBadges then
				local cur_lvl = MetaBadges.GetBadgeLevel(ply, "zombie_massacre") or 0
				MetaBadges.UpgradeBadge(ply, "zombie_massacre", cur_lvl + count)
			end
		end)

		if not succ then
			warn_log("Failed to update badge for:", ply, err)
		end
	end

	hook.Add("MTANPCDrops", TAG, function(npc, attacker)
		if not is_halloween then return end
		if IS_MTA_GM then return end

		if attacker:IsPlayer() then
			attacker.MTAMassacreCount = (attacker.MTAMassacreCount or 0) + 1

			if not GiveCandy then return end

			local candy_count = math.random(0, 3)
			if candy_count <= 0 then return end

			local origin_pos = npc:WorldSpaceCenter()
			timer.Create(("%s_DROP_%d"):format(TAG, npc:EntIndex()), 0.25, candy_count, function()
				local candy = ents.Create("sent_candy")
				candy:SetPos(origin_pos)
				candy:SetAngles(Angle(0,0,0))
				candy.AllowCollect = false

				candy:Spawn()
				candy:Activate()

				local target = attacker
				function candy:Think()
					if not IsValid(target) then
						SafeRemoveEntity(self)
						return
					end

					local pos = self:GetPos()
					local target_pos = target:WorldSpaceCenter()
					local phys = self:GetPhysicsObject()
					if IsValid(phys) then
						phys:SetVelocity((target_pos - pos):GetNormalized() * 1000)
					end

					if pos:DistToSqr(target_pos) <= 10000 then
						SafeRemoveEntity(self)
						GiveCandy(target, 1)
					end
				end

				local phys = candy:GetPhysicsObject()
				if IsValid(phys) then
					phys:EnableCollisions(false)
					phys:EnableGravity(false)
				end
			end)
		else
			if not CreateCandy then return end

			local candy_count = math.random(0, 3)
			if candy_count <= 0 then return end

			for _ = 1, candy_count do
				local candy = CreateCandy(npc:WorldSpaceCenter(), Angle(0, 0, 0))
				local phys = candy:GetPhysicsObject()
				if IsValid(phys) then
					phys:SetVelocity(VectorRand() * 150)
				end
			end
		end
	end)

	local function is_ent_in_lobby(ent)
		if not ms then return false end
		if not ms.GetTrigger then return false end

		local trigger = ms.GetTrigger("lobby")
		if IsValid(trigger) then
			return (trigger:GetEntities() or {})[ent] ~= nil
		end

		return false
	end

	local headcrab_classes = {
		npc_headcrab = true,
		npc_headcrab_black = true,
		npc_headcrab_fast = true,
		npc_headcrab_poison = true,
	}
	hook.Add("OnEntityCreated", TAG, function(ent)
		if not is_halloween then return end
		if IS_MTA_GM then return end
		if not headcrab_classes[ent:GetClass()] then return end

		-- cant do it right away, its too early
		timer.Simple(1, function()
			if not IsValid(ent) then return end
			if ent.CPPIGetOwner and IsValid(ent:CPPIGetOwner()) then return end
			if #MTA.BadPlayers == 0 then return end
			if not is_ent_in_lobby(ent) then return end

			ent:SetMaterial("models/alyx/alyxblack")

			local target = MTA.BadPlayers[math.random(#MTA.BadPlayers)]
			MTA.EnrollNPC(ent, target)
		end)
	end)

	hook.Add("MTAMobileEMPShouldDamage", TAG, function(ply, ent)
		if not is_halloween then return end
		if headcrab_classes[ent:GetClass()] then return true end
	end)

	local function create_badge()
		if not MetaBadges then return end

		local levels = {
			default = {
				title = "Harrowing",
				description = "Tracks how many lost souls you've purged"
			}
		}

		MetaBadges.RegisterBadge("zombie_massacre", {
			basetitle = "Harrowing",
			levels = levels,
			level_interpolation = MetaBadges.INTERPOLATION_FLOOR
		})
	end

	hook.Add("InitPostEntity", TAG, function()
		local succ, err = pcall(create_badge)
		if not succ then
			warn_log("Could not create badge:", err)
		end
	end)

	hook.Add("MTAWantedStateUpdate", TAG, function(ply, is_wanted)
		if not is_halloween then return end
		if is_wanted then return end
		update_badge(ply, ply.MTAMassacreCount or 1)
		ply.MTAMassacreCount = 0
	end)

	hook.Add("MTANPCEnrolled", TAG, function(npc)
		if not is_halloween then return end
		net.Start(NET_SHADOW)
		net.WriteEntity(npc)
		net.Broadcast()
	end)
end

if CLIENT then
	local CVAR_SMOKE = CreateClientConVar("mta_halloween_shadows", "1", true, false)

	hook.Add("MTADisplayJoinPanel", TAG, function()
		if is_halloween then return false end
	end)

	local base_url = "https://raw.githubusercontent.com/Metastruct/MTA-Core/refs/heads/master/external/songs/halloween/TRACK_%d.ogg"
	hook.Add("MTAGetDefaultSong", TAG, function()
		if not is_halloween then return end
		local i = math.random(1, 2)
		return base_url:format(i), ("halloween_%d.dat"):format(i)
	end)

	local Vector = _G.Vector
	local black = Material("models/alyx/alyxblack")
	local ptcle_texture = Material("particle/smokestack_nofog"):IsError() and "particle/Particle_Glow_04" or "particle/smokestack_nofog"
	local function make_shadow_zombie(zombie)
		function zombie:RenderOverride()
			render.MaterialOverride(black)
				self:DrawModel()
			render.MaterialOverride()
		end

		if not CVAR_SMOKE:GetBool() then return end

		-- dont do particles on headcrabs
		if zombie:GetClass():match("headcrab") then return end

		local spread = 10
		local amount = 1
		local pos = zombie:GetPos()
		local timer_name = "MTAShadowZombie_" .. zombie:EntIndex()
		local emitter = ParticleEmitter(pos)
		timer.Create(timer_name, 0.1, 0, function()
			if not IsValid(zombie) then
				timer.Remove(timer_name)
				emitter:Finish()
				return
			end

			pos = zombie:WorldSpaceCenter()
			emitter:SetPos(pos)

			for i = 1, amount  do
				local offset = Vector(math.random(-spread, spread), math.random(-spread, spread), 0) --math.random(0, zombie:OBBMaxs().z))
				local part = emitter:Add(ptcle_texture, pos + offset) -- Create a new particle at pos
				if part then
					part:SetDieTime(2.5)

					part:SetStartAlpha(255)
					part:SetEndAlpha(10)

					part:SetStartSize(40)
					part:SetEndSize(1)

					part:SetGravity(Vector(0, 0, 30))
					part:SetVelocity(Vector(1, 1, 1))
					part:SetColor(0, 0, 0)
					--part:SetParent(zombie)
				end
			end
		end)
	end

	hook.Add("OnEntityCreated", TAG, function(ent)
		if not is_halloween then return end
		if MTA.IsOptedOut() then return end

		timer.Simple(0.5, function()
			if not IsValid(ent) then return end
			if not ent:GetNWBool("MTANPC") then return end
			make_shadow_zombie(ent)
		end)
	end)

	net.Receive(NET_SHADOW, function()
		local npc = net.ReadEntity()
		if not IsValid(npc) then return end

		timer.Simple(0.5, function()
			if not IsValid(npc) then return end
			if not npc:GetNWBool("MTANPC") then return end
			make_shadow_zombie(npc)
		end)
	end)
end