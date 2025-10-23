AddEventHandler("Help_OnGetCommands", function(p_Event)
	local l_Commands = p_Event:GetReturn() or {}
	
	l_Commands["deathrun"] = {
		["description"] = "Shows gamemode details",
		["usage"] = "sw_deathrun"
	}
	
	l_Commands["kb"] = {
		["description"] = "Kills all bots on the Terrorists team",
		["usage"] = "sw_kb"
	}
	
	l_Commands["speed"] = {
		["description"] = "Changes a player's speed",
		["usage"] = "sw_speed"
	}
	
	l_Commands["t"] = {
		["description"] = "Requests to join the Terrorists",
		["usage"] = "sw_t"
	}
	
	p_Event:SetReturn(l_Commands)
end)

commands:Register("deathrun", function(p_PlayerId, p_Args, p_ArgsCount, p_Silent, p_Prefix)
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player or not l_Player:IsValid() then
		return
	end
	
	if p_Prefix ~= "sw_" then
		l_Player:SendMsg(MessageType.Chat, string.format("{yellow}%s{default} See console for output", g_Config["tag"]))
	end
	
	l_Player:SendMsg(MessageType.Console, string.format("%s\n", g_Config["tag"]))
	l_Player:SendMsg(MessageType.Console, string.format("%s Description\n", g_Config["tag"]))
	l_Player:SendMsg(MessageType.Console, string.format("%s - The Terrorists must prevent the Counter-Terrorists from completing the map by triggering various obstacles\n", g_Config["tag"]))
	l_Player:SendMsg(MessageType.Console, string.format("%s - Each Counter-Terrorist that completes the map will become a \"Terrorist Killer\"\n", g_Config["tag"]))
	l_Player:SendMsg(MessageType.Console, string.format("%s - Only the \"Terrorist Killer\" can fight the Terrorists\n", g_Config["tag"]))
	l_Player:SendMsg(MessageType.Console, string.format("%s\n", g_Config["tag"]))
	
	l_Player:SendMsg(MessageType.Console, string.format("%s Commands\n", g_Config["tag"]))
	l_Player:SendMsg(MessageType.Console, string.format("%s - sw_kb to kill the BOT(s)\n", g_Config["tag"]))
	l_Player:SendMsg(MessageType.Console, string.format("%s - sw_speed to change your speed\n", g_Config["tag"]))
	l_Player:SendMsg(MessageType.Console, string.format("%s - sw_t to join the Terrorists\n", g_Config["tag"]))
	l_Player:SendMsg(MessageType.Console, string.format("%s\n", g_Config["tag"]))
end)

commands:Register("kb", function(p_PlayerId, p_Args, p_ArgsCount, p_Silent, p_Prefix)
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player or not l_Player:IsValid() then
		return
	end
	
	if exports["helpers"]:IsMatchOver() then
		exports["helpers"]:ReplyToCommand(p_PlayerId, "{lightred}" .. g_Config["tag"] .. "{default}", "This command is no longer available")
		return
	end
	
	local l_CTColor = exports["helpers"]:GetTeamChatColor(Team.CT)
	
	if not Deathrun_IsPlayerTerroristKiller(p_PlayerId) then
		exports["helpers"]:ReplyToCommand(p_PlayerId, "{lightred}" .. g_Config["tag"] .. "{default}", string.format("You must be the %sTerrorist Killer{default} to use this command", l_CTColor))
		return
	end
	
	local l_TerroristColor = exports["helpers"]:GetTeamChatColor(Team.T)
	
	if Deathrun_IsValidTerrorist() then
		exports["helpers"]:ReplyToCommand(p_PlayerId, "{lightred}" .. g_Config["tag"] .. "{default}", string.format("The %sTerrorist{default} must be dead to use this command", l_TerroristColor))
		return
	end
	
	local l_Bots = exports["helpers"]:GetTeamAliveBots(Team.T)
	
	if #l_Bots == 0 then
		exports["helpers"]:ReplyToCommand(p_PlayerId, "{lightred}" .. g_Config["tag"] .. "{default}", string.format("There is no BOT alive at %sTerrorists{default}", l_TerroristColor))
		return
	end
	
	local l_PlayerName = exports["helpers"]:GetPlayerName(p_PlayerId)
	local l_PlayerColor = exports["helpers"]:GetPlayerChatColor(p_PlayerId)
	
	for i = 1, #l_Bots do
		local l_BotIterName = exports["helpers"]:GetPlayerName(l_Bots[i])
		local l_BotIterColor = exports["helpers"]:GetPlayerChatColor(l_Bots[i])
		
		playermanager:SendMsg(MessageType.Chat, string.format("{lime}%s{default} %s%s{default} killed %s%s{default}", g_Config["tag"], l_PlayerColor, l_PlayerName, l_BotIterName, l_BotIterColor))
		
		exports["helpers"]:SlayPlayer(l_Bots[i])
	end
end)

commands:Register("speed", function(p_PlayerId, p_Args, p_ArgsCount, p_Silent, p_Prefix)
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player or not l_Player:IsValid() then
		return
	end
	
	if exports["helpers"]:IsMatchOver() then
		exports["helpers"]:ReplyToCommand(p_PlayerId, "{lightred}" .. g_Config["tag"] .. "{default}", "This command is no longer available")
		return
	end
	
	local l_PlayerVelocityModifier = l_Player:GetVar("deathrun.velocity.modifier")
	
	if not l_PlayerVelocityModifier then
		exports["helpers"]:ReplyToCommand(p_PlayerId, "{lightred}" .. g_Config["tag"] .. "{default}", "You have no speed available")
		return
	end
	
	if l_PlayerVelocityModifier == VELOCITY_MODIFIER_X1 then
		l_PlayerVelocityModifier = VELOCITY_MODIFIER_X3
	else
		l_PlayerVelocityModifier = VELOCITY_MODIFIER_X1
	end
	
	exports["helpers"]:SetPlayerVelocityModifier(p_PlayerId, l_PlayerVelocityModifier)
	
	l_Player:SetVar("deathrun.velocity.modifier", l_PlayerVelocityModifier)
end)

commands:Register("t", function(p_PlayerId, p_Args, p_ArgsCount, p_Silent, p_Prefix)
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player or not l_Player:IsValid() then
		return
	end
	
	if g_Config["terrorist.queue.enable"] == 0 then
		exports["helpers"]:ReplyToCommand(p_PlayerId, "{lightred}" .. g_Config["tag"] .. "{default}", "This command is not available")
		return
	end
	
	if exports["helpers"]:IsMatchOver() then
		exports["helpers"]:ReplyToCommand(p_PlayerId, "{lightred}" .. g_Config["tag"] .. "{default}", "This command is no longer available")
		return
	end
	
	local l_TerroristColor = exports["helpers"]:GetTeamChatColor(Team.T)
	
	if not Deathrun_CanPlayerJoinTerroristQueue(p_PlayerId) then
		exports["helpers"]:ReplyToCommand(p_PlayerId, "{lightred}" .. g_Config["tag"] .. "{default}", string.format("You can no longer request to join the %sTerrorists{default}", l_TerroristColor))
		return
	end
	
	l_Player:SetVar("deathrun.terrorist.queue", true)
	
	exports["helpers"]:ReplyToCommand(p_PlayerId, "{lime}" .. g_Config["tag"] .. "{default}", string.format("You will join the %sTerrorists{default} in the next rounds", l_TerroristColor))
end)