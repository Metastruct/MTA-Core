if not MetAchievements then return end

local tag = "MetAchievements"
local id = "explosive_technology"

resource.AddFile("materials/metachievements/" .. id .. "/s1/icon.png")

MetAchievements.RegisterAchievement(id, {
	title = "Explosive Technology",
	description = "The MTA has developed a new tech. Don't stand in the same area for too long."
})

local hook_name = ("%s_%s"):format(tag, id)
hook.Add("PlayerDeath", hook_name, function(ply, inflictor, attacker)
	if MetAchievements.HasAchievement(ply, id) then return end

	if (IsValid(inflictor) and inflictor:GetClass() == "grenade_helicopter" and inflictor:GetNWBool("MTABomb"))
		or (IsValid(attacker) and attacker:GetClass() == "grenade_helicopter" and attacker:GetNWBool("MTABomb"))
	then
		MetAchievements.UnlockAchievement(ply, id)
	end
end)