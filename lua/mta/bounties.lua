local tag = "mta_bounties"
local NET_MTA_BOUNTIES = "MTA_BOUNTIES"
local NET_MTA_ACCEPT_BOUNTY = "MTA_ACCEPT_BOUNTY"
local NET_MTA_REMOVE_BOUNTY = "MTA_REMOVE_BOUNTY"

local MINIMUM_LEVEL = 20

local color_white = Color(255, 255, 255)
local header_col = Color(250, 58, 60)
local green_col = Color(58, 252, 113)

if SERVER then
	util.AddNetworkString(NET_MTA_BOUNTIES)
	util.AddNetworkString(NET_MTA_ACCEPT_BOUNTY)
	util.AddNetworkString(NET_MTA_REMOVE_BOUNTY)

	local function get_lobby_players()
		local plys = {}
		for _, ply in ipairs(player.GetAll()) do
			if MTA.InLobby(ply) and not MTA.IsWanted(ply) and not MTA.IsOptedOut(ply) then
				table.insert(plys, ply)
			end
		end

		return plys
	end

	local bounties = {}
	local hunters = {}

	local function clear_bounty(ply)
		bounties[ply] = nil
		for _, targets in pairs(hunters) do
			table.RemoveByValue(targets, ply)
		end

		net.Start(NET_MTA_REMOVE_BOUNTY)
		net.WriteEntity(ply)
		net.Broadcast()
	end

	local function check_immunity()
		for ply, targets in pairs(hunters) do
			if IsValid(ply) and #targets == 0 then
				ply.MTAIgnore = nil
				hunters[ply] = nil
				MTA.ReleasePlayer(ply)
			end
		end
	end

	hook.Add("MTAPlayerWantedLevelIncreased", tag, function(ply, wanted_level)
		if wanted_level < MINIMUM_LEVEL then return end
		if bounties[ply] then return end

		bounties[ply] = true
		net.Start(NET_MTA_BOUNTIES)
		net.WriteEntity(ply)
		net.Send(get_lobby_players())
	end)

	local function announce_bounty_end(bounty, was_hunted, hunter, points_earned)
		local filter = {}
		for _, ply in ipairs(player.GetAll()) do
			if (not was_hunted and MTA.InLobby(ply)) or (was_hunted and ply ~= hunter and MTA.InLobby(ply)) then
				table.insert(filter, ply)
			end
		end

		if was_hunted then
			MTA.ChatPrint(filter, bounty, color_white, "'s bounty was claimed by ", hunter, color_white,
				" for ", green_col, ("%d criminal points"):format(points_earned))
		else
			MTA.ChatPrint(filter, bounty, color_white, "'s bounty was ", header_col, "cleared", color_white, " by the police")
		end
	end

	hook.Add("PlayerDeath", tag, function(ply, _, atck)
		-- the bounty gains points for killing its hunters
		if hunters[ply] and table.HasValue(hunters[ply], atck) then
			MTA.GivePoints(atck, 15)
			MTA.ChatPrint(ply, "You have ", header_col, "failed", color_white, " to collect the bounty for ", atck,
				color_white, " you can try again in ", green_col, "30s")

			timer.Simple(30, function()
				if not IsValid(ply) then return end
				if not IsValid(atck) then return end
				if not bounties[atck] then return end

				ply.MTAIgnore = nil
				hunters[ply] = nil
				MTA.ReleasePlayer(ply)

				net.Start(NET_MTA_BOUNTIES)
				net.WriteEntity(atck)
				net.Send(ply)
			end)

			return
		end

		if not bounties[ply] then return end

		local targets = hunters[atck]
		if atck:IsPlayer() and targets and table.HasValue(targets, ply) then
			local point_amount = ply:GetNWInt("MTAFactor")
			local total_points = MTA.GivePoints(atck, point_amount)

			if atck.GiveCoins then
				atck:GiveCoins(point_amount * 300)
			end

			clear_bounty(ply)
			timer.Simple(1, check_immunity)
			announce_bounty_end(ply, true, atck, point_amount)
		else
			clear_bounty(ply)
			check_immunity()
			announce_bounty_end(ply, false)
		end
	end)

	hook.Add("MTAPlayerEscaped", tag, function(ply)
		clear_bounty(ply)
		check_immunity()
	end)

	hook.Add("MTAPlayerFailed", tag, function(ply)
		clear_bounty(ply)
		check_immunity()
	end)

	hook.Add("EntityTakeDamage", tag, function(ent, dmg_info)
		local atck = dmg_info:GetAttacker()
		if hunters[atck] and ent:GetNWBool("MTACombine") then return true end
	end)

	hook.Add("PlayerShouldTakeDamage", tag, function(ply, atck)
		if not atck:IsPlayer() then return end

		-- allow the bounties to fight back
		if bounties[atck] and hunters[ply] then return true end

		local targets = hunters[atck]
		if not targets then return end

		if table.HasValue(targets, ply) then return true end
	end)

	hook.Add("PlayerDisconnected", tag, function(ply)
		clear_bounty(ply)
		check_immunity()
	end)

	net.Receive(NET_MTA_ACCEPT_BOUNTY, function(_, ply)
		local target = net.ReadEntity()
		if not IsValid(target) then return end

		ply.MTAIgnore = true
		hunters[ply] = hunters[ply] or {}
		table.insert(hunters[ply], target)

		MTA.ConstrainPlayer(ply, "MTA bounty hunter")
		ply:Spawn()

		MTA.ChatPrint(target, ply, color_white, " has accepted a bounty for your head!")
	end)
end

if CLIENT then
	local bounties = {}

	local function clear_invalid_bounties()
		local done_bounties = {}
		for i, bounty in pairs(bounties) do
			if not IsValid(bounty) then
				table.remove(bounties, i)
			else
				if done_bounties[bounty] then
					table.remove(bounties, i)
				end

				done_bounties[bounty] = true
			end
		end
	end

	net.Receive(NET_MTA_BOUNTIES, function()
		local bounty = net.ReadEntity()
		table.insert(bounties, bounty)
		clear_invalid_bounties()

		local bind = (input.LookupBinding("+menu_context", true) or "c"):upper()
		chat.AddText(header_col, "[MTA] ", bounty, color_white, " has become a ", green_col, "valuable target!", color_white,
			" Accept the bounty in the ", green_col, ("context menu [PRESS %s]"):format(bind), color_white, " to get ", green_col, "points and coins!")
	end)

	net.Receive(NET_MTA_REMOVE_BOUNTY, function()
		local bounty = net.ReadEntity()
		table.RemoveByValue(bounties, bounty)
	end)

	local bounty_panels = {}
	hook.Add("OnContextMenuOpen", tag, function()
		clear_invalid_bounties()
		if #bounties == 0 then return end

		local cur_x, cur_y = 200, 100
		for _, bounty in pairs(bounties) do
			local frame = vgui.Create("DFrame")
			frame:SetWide(200)
			frame:SetPos(cur_x, cur_y)
			frame:SetTitle("MTA Bounty")

			-- python hack taken from netgraphx to allow movement
			frame:SetZPos(32000)
			timer.Simple(0,function()
				if IsValid(frame) then
					frame:MakePopup()
					frame:SetKeyboardInputEnabled(false)
					frame:MoveToFront()
				end
			end)

			frame.btnMinim:Hide()
			frame.btnMaxim:Hide()

			function frame.btnClose:Paint(w, h)
				surface.SetTextColor(220, 0, 50)
				surface.SetFont("DermaDefault")

				local tw, th = surface.GetTextSize("X")
				surface.SetTextPos(w / 2 - tw / 2, h / 2 - th / 2)
				surface.DrawText("X")
			end

			local label_name = frame:Add("DLabel")
			label_name:SetText("Target: " .. (UndecorateNick and UndecorateNick(bounty:Nick()) or bounty:Nick()))
			label_name:Dock(TOP)
			label_name:DockMargin(5, 5, 5, 5)

			local btn_accept = frame:Add("DButton")
			btn_accept:SetText("Hunt")
			btn_accept:SetTextColor(color_white)
			btn_accept:Dock(TOP)
			btn_accept:DockMargin(5, 5, 5, 5)

			local label_gains = frame:Add("DLabel")
			label_gains:SetText(("Potential Gains: %dpts"):format(bounty:GetNWInt("MTAFactor")))
			label_gains:SetTextColor(Color(244, 135, 2))
			label_gains:Dock(TOP)
			label_gains:DockPadding(10, 10, 10, 10)
			label_gains:DockMargin(5, 5, 5, 5)
			label_gains:SetContentAlignment(5)

			function label_gains:Paint(w, h)
				surface.SetDrawColor(244, 135, 2)
				surface.DrawOutlinedRect(0, 0, w, h, 2)

				surface.SetDrawColor(244, 135, 2, 10)
				surface.DrawRect(0, 0, w, h)
			end

			frame:InvalidateLayout(true)
			frame:SizeToChildren(false, true)

			function btn_accept:DoClick()
				if not IsValid(bounty) then return end

				net.Start(NET_MTA_ACCEPT_BOUNTY)
				net.WriteEntity(bounty)
				net.SendToServer()

				table.RemoveByValue(bounties, bounty)

				frame:Close()
				chat.AddText(header_col, "[MTA] ", color_white, "You have ", green_col, "accepted", color_white, " the bounty for ", bounty)
			end

			function btn_accept:Paint(w, h)
				surface.SetDrawColor(58, 252, 113, 100)
				surface.DrawRect(0, 0, w, h)

				if self:IsHovered() then
					surface.SetDrawColor(255, 255, 255)
					surface.DrawOutlinedRect(0, 0, w, h)
				end
			end

			function frame:Paint(w, h)
				surface.SetDrawColor(0, 0, 0, 240)
				surface.DrawRect(0, 0, w, 25)

				surface.SetDrawColor(0, 0, 0, 200)
				surface.DrawRect(0, 25, w, h - 25)
			end

			cur_x = cur_x + frame:GetWide() + 20
			if cur_x + frame:GetWide() >= ScrW() then
				cur_x = 200
				cur_y = cur_y + frame:GetTall() + 20
			end

			table.insert(bounty_panels, frame)
		end
	end)

	hook.Add("OnContextMenuClose", tag, function()
		for _, panel in pairs(bounty_panels) do
			if panel:IsValid() then
				panel:Remove()
			end
		end

		table.Empty(bounty_panels)
	end)
end