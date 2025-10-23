function Deathrun_CancelPlayerImmunity(p_PlayerId)
	if g_RoundCount == 0 then
		return
	end
	
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player 
		or not l_Player:IsValid() 
		or not exports["helpers"]:IsPlayerAlive(p_PlayerId) 
	then
		return
	end
	
	local l_PlayerImmunityTime = l_Player:GetVar("deathrun.immunity.time")
	
	if not l_PlayerImmunityTime then
		return
	end
	
	local l_ServerTime = math.floor(server:GetCurrentTime() * 1000)
	
	l_Player:SetVar("deathrun.immunity.time", nil)
	l_Player:SetVar("deathrun.immunity.end", {
		["time"] = l_ServerTime,
		["type"] = IMMUNITY_CANCELLED
	})
	
	if p_PlayerId == g_TerroristId then
		exports["helpers"]:SetPlayerRenderColor(p_PlayerId, RENDER_COLOR_TERRORIST)
	elseif p_PlayerId == g_TerroristKillerId then
		exports["helpers"]:SetPlayerRenderColor(p_PlayerId, RENDER_COLOR_TERRORIST_KILLER)
	else
		exports["helpers"]:SetPlayerRenderColor(p_PlayerId, RENDER_COLOR_DEFAULT)
	end
end

function Deathrun_CanPlayerJoinTerroristQueue(p_PlayerId)
	if g_Config["terrorist.queue.player.requests.max"] == 0 then
		return true
	end
	
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player or not l_Player:IsValid() then
		return false
	end
	
	local l_PlayerTerroristRequests = l_Player:GetVar("deathrun.terrorist.requests") or 0
	
	if l_PlayerTerroristRequests == g_Config["terrorist.queue.player.requests.max"] then
		return false
	end
	
	return true
end

function Deathrun_CanPlayerRespawnInWarmup(p_PlayerId)
	if g_RoundCount == 0 or not g_WarmupPeriod then
		return false
	end
	
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player or not l_Player:IsValid() then
		return false
	end
	
	local l_PlayerRemainingWarmupCount = Deathrun_GetPlayerRemainingWarmupCount(p_PlayerId)
	
	if not l_PlayerRemainingWarmupCount or l_PlayerRemainingWarmupCount == 0 then
		return false
	end
	
	return true
end

function Deathrun_CheckPlayerFinishCount()
	if g_RoundCount == 0 or exports["helpers"]:IsRoundOver() then
		return
	end
	
	local l_FinishCount = 0
	local l_PlayerCount = 0
	
	for i = 0, playermanager:GetPlayerCap() - 1 do
		local l_PlayerIter = GetPlayer(i)
		
		if l_PlayerIter and l_PlayerIter:IsValid() and not l_PlayerIter:IsFakeClient() then
			local l_PlayerIterTeam = exports["helpers"]:GetPlayerTeam(i)
			
			if l_PlayerIterTeam == Team.CT and exports["helpers"]:IsPlayerAlive(i) then
				local l_PlayerIterPosition = l_PlayerIter:GetVar("deathrun.position")
				
				if l_PlayerIterPosition then
					l_FinishCount = l_FinishCount + 1
				end
				
				l_PlayerCount = l_PlayerCount + 1
			end
		end
	end
	
	if l_PlayerCount == 0 or l_PlayerCount - l_FinishCount ~= 0 then
		return
	end
	
	if not Deathrun_IsValidTerrorist() then
		exports["helpers"]:TerminateRound(RoundEndReason_t.CTsWin, "deathrun")
		return
	end
	
	local l_Time = g_Config["round.time.finish.min"]
	local l_Factor = math.floor((l_FinishCount - 1) * g_Config["round.time.finish.players.factor"])
	
	Deathrun_SetRoundTime(math.min(l_Time + l_Factor, g_Config["round.time.finish.max"]))
end

function Deathrun_ChooseRandomTerrorist()
	if g_Config["terrorist.random.enable"] == 0 then
		return
	end
	
	local l_Terrorist = nil
	local l_PlayerCount = 0
	
	for i = 0, playermanager:GetPlayerCap() - 1 do
		local l_PlayerIter = GetPlayer(i)
		
		if l_PlayerIter and l_PlayerIter:IsValid() and not l_PlayerIter:IsFakeClient() then
			local l_PlayerIterTeam = exports["helpers"]:GetPlayerTeam(i)
			
			if l_PlayerIterTeam > Team.Spectator then
				local l_PlayerIterTerroristTime = l_PlayerIter:GetVar("deathrun.terrorist.time") or 0
				
				if not l_Terrorist or l_PlayerIterTerroristTime < l_Terrorist["time"] then
					l_Terrorist = {
						["id"] = i,
						["player"] = l_PlayerIter,
						["time"] = l_PlayerIterTerroristTime
					}
				end
				
				l_PlayerCount = l_PlayerCount + 1
			end
		end
	end
	
	if not l_Terrorist then
		return
	end
	
	if g_Config["terrorist.random.players.min"] ~= 0 and l_PlayerCount < g_Config["terrorist.random.players.min"] then
		return
	end
	
	g_TerroristId = l_Terrorist["id"]
	
	local l_ServerTime = math.floor(server:GetCurrentTime() * 1000)
	
	l_Terrorist["player"]:SetVar("deathrun.terrorist.time", l_ServerTime)
	
	Deathrun_SwitchPlayerTeam(l_Terrorist["id"], Team.T)
end

function Deathrun_ChooseQueueTerrorist()
	local l_Terrorist = nil
	
	for i = 0, playermanager:GetPlayerCap() - 1 do
		local l_PlayerIter = GetPlayer(i)
		
		if l_PlayerIter and l_PlayerIter:IsValid() and not l_PlayerIter:IsFakeClient() then
			local l_PlayerIterTeam = exports["helpers"]:GetPlayerTeam(i)
			
			if l_PlayerIterTeam > Team.Spectator then
				local l_PlayerIterTerroristQueue = l_PlayerIter:GetVar("deathrun.terrorist.queue")
				
				if l_PlayerIterTerroristQueue then
					local l_PlayerIterTerroristTime = l_PlayerIter:GetVar("deathrun.terrorist.time") or 0
					
					if not l_Terrorist or l_PlayerIterTerroristTime < l_Terrorist["time"] then
						l_Terrorist = {
							["id"] = i,
							["player"] = l_PlayerIter,
							["time"] = l_PlayerIterTerroristTime
						}
					end
				end
			end
		end
	end
	
	if not l_Terrorist then
		return
	end
	
	g_TerroristId = l_Terrorist["id"]
	
	local l_ServerTime = math.floor(server:GetCurrentTime() * 1000)
	local l_TerroristRequests = l_Terrorist["player"]:GetVar("deathrun.terrorist.requests") or 0
	
	l_Terrorist["player"]:SetVar("deathrun.terrorist.queue", nil)
	l_Terrorist["player"]:SetVar("deathrun.terrorist.requests", l_TerroristRequests + 1)
	l_Terrorist["player"]:SetVar("deathrun.terrorist.time", l_ServerTime)
	
	Deathrun_SwitchPlayerTeam(l_Terrorist["id"], Team.T)
end

function Deathrun_ChooseTerrorist()
	g_TerroristId = nil
	
	Deathrun_ChooseQueueTerrorist()
	
	if g_TerroristId then
		return
	end
	
	Deathrun_ChooseRandomTerrorist()
end

function Deathrun_ChooseTerroristKiller()
	if g_RoundCount == 0 or exports["helpers"]:IsRoundOver() or Deathrun_IsValidTerroristKiller() then
		return
	end
	
	g_TerroristKillerId = nil
	
	local l_TerroristKiller = nil
	
	for i = 0, playermanager:GetPlayerCap() - 1 do
		local l_PlayerIter = GetPlayer(i)
		
		if l_PlayerIter and l_PlayerIter:IsValid() and exports["helpers"]:IsPlayerAlive(i) then
			local l_PlayerIterTeam = exports["helpers"]:GetPlayerTeam(i)
			
			if l_PlayerIterTeam == Team.CT then
				local l_PlayerIterPosition = l_PlayerIter:GetVar("deathrun.position")
				
				if l_PlayerIterPosition then
					if not l_TerroristKiller 
						or l_PlayerIterPosition < l_TerroristKiller["position"] 
					then
						l_TerroristKiller = {
							["id"] = i,
							["player"] = l_PlayerIter,
							["position"] = l_PlayerIterPosition
						}
					end
				end
			end
		end
	end
	
	if not l_TerroristKiller then
		return
	end
	
	g_TerroristKillerId = l_TerroristKiller["id"]
	
	local l_TerroristKillerName = exports["helpers"]:GetPlayerName(l_TerroristKiller["id"])
	local l_TerroristKillerColor = exports["helpers"]:GetPlayerChatColor(l_TerroristKiller["id"])
	
	local l_CTColor = exports["helpers"]:GetTeamChatColor(Team.CT)
	
	playermanager:SendMsg(MessageType.Chat, string.format("{lime}%s{default} %s%s{default} {lime}[#%d]{default} is now the %sTerrorist Killer{default}", g_Config["tag"], l_TerroristKillerColor, l_TerroristKillerName, l_TerroristKiller["position"], l_CTColor))
	
	exports["helpers"]:SetPlayerEntityName(l_TerroristKiller["id"], "deathrun_player_terrorist_killer")
	exports["helpers"]:SetPlayerRenderColor(l_TerroristKiller["id"], RENDER_COLOR_TERRORIST_KILLER)
	
	if g_EndingId then
		if g_Config["endings"][g_EndingId]["terrorist_killer.speed"] then
			Deathrun_SetPlayerSpeed(l_TerroristKiller["id"], VELOCITY_MODIFIER_X1)
		end
	end
	
	Deathrun_EmitSoundToAll(g_Config["terrorist_killer.sounds.join"])
end

function Deathrun_CreateTerroristKillerFilter(p_Name)
	local l_Entities = FindEntitiesByClassname("filter_activator_name")
	
	for i = 1, #l_Entities do
		local l_Entity = CBaseEntity(l_Entities[i]:ToPtr())
		
		if l_Entity and l_Entity:IsValid() then
			if l_Entity.Parent.Entity.Name == p_Name then
				return
			end
		end
	end
	
	local l_Entity = CreateEntityByName("filter_activator_name")
	
	if not l_Entity or not l_Entity:IsValid() then
		return
	end
	
	l_Entity = CBaseEntity(l_Entity:ToPtr())
	
	if not l_Entity or not l_Entity:IsValid() then
		return
	end
	
	local l_EntityFilter = CFilterName(l_Entity:ToPtr())
	
	if not l_EntityFilter or not l_EntityFilter:IsValid() then
		return
	end
	
	l_Entity.Parent.Entity.Name = p_Name
	l_Entity:Spawn()
	
	l_EntityFilter.FilterName = "deathrun_player_terrorist_killer"
end

function Deathrun_DisableEndings(...)
	local l_Args = {...}
	
	local l_Entities = FindEntitiesByClassname("filter_activator_name")
	local l_Exclude = {}
	
	for i = 1, #l_Args do
		l_Exclude[l_Args[i]] = true
	end
	
	for i = 1, #l_Entities do
		local l_Entity = CBaseEntity(l_Entities[i]:ToPtr())
		
		if l_Entity and l_Entity:IsValid() then
			if string.sub(l_Entity.Parent.Entity.Name, 1, 32) == "deathrun_filter_terrorist_killer" then
				local l_Id = tonumber(string.sub(l_Entity.Parent.Entity.Name, 33))
				
				if not l_Exclude[l_Id] then
					local l_EntityFilter = CFilterName(l_Entity:ToPtr())
					
					if l_EntityFilter and l_EntityFilter:IsValid() then
						l_EntityFilter.FilterName = "deathrun_player_none"
					end
				end
			end
		end
	end
end

function Deathrun_EmitSoundToAll(p_Sound)
	if #p_Sound == 0 or exports["helpers"]:IsRoundOver() then
		return
	end
	
	SetTimeout(100, function()
		if exports["helpers"]:IsRoundOver() then
			return
		end
		
		exports["helpers"]:EmitSoundToAll(p_Sound, 100, 1.0)
	end)
end

function Deathrun_EndWarmupPeriod(p_Terminate)
	if not g_WarmupPeriod then
		return
	end
	
	g_WarmupPeriod = false
	
	if p_Terminate then
		local l_ServerTime = math.floor(server:GetCurrentTime() * 1000)
		local l_WarmupTime = math.ceil((g_WarmupEndTime - l_ServerTime) / 1000)
		
		playermanager:SendMsg(MessageType.Chat, string.format("{lightred}%s{default} The warmup period of {lightred}%02d:%02d{default} has ended", g_Config["tag"], math.floor(l_WarmupTime / 60), l_WarmupTime % 60))
	else
		playermanager:SendMsg(MessageType.Chat, string.format("{lightred}%s{default} The warmup period has ended", g_Config["tag"]))
	end
end

function Deathrun_FindTeleportDestination(p_Name)
	local l_Entities = FindEntitiesByClassname("info_teleport_destination")
	
	for i = 1, #l_Entities do
		local l_Entity = CBaseEntity(l_Entities[i]:ToPtr())
		
		if l_Entity and l_Entity:IsValid() then
			if p_Name == l_Entity.Parent.Entity.Name then
				return l_Entity
			end
		end
	end
	
	return nil
end

function Deathrun_GetEntityEndingActivator(p_EntityPtr)
	local l_Entity = CBaseEntity(p_EntityPtr)
	
	if not l_Entity or not l_Entity:IsValid() then
		return nil
	end
	
	if g_Config["activators.endings"]["h:" .. l_Entity.UniqueHammerID] then
		return g_Config["activators.endings"]["h:" .. l_Entity.UniqueHammerID]
	end
	
	if g_Config["activators.endings"]["n:" .. l_Entity.Parent.Entity.Name] then
		return g_Config["activators.endings"]["n:" .. l_Entity.Parent.Entity.Name]
	end
	
	return nil
end

function Deathrun_GetEntityTeleporter(p_EntityPtr)
	local l_Entity = CBaseEntity(p_EntityPtr)
	
	if not l_Entity or not l_Entity:IsValid() then
		return nil
	end
	
	if g_Config["teleporters"]["h:" .. l_Entity.UniqueHammerID] then
		return g_Config["teleporters"]["h:" .. l_Entity.UniqueHammerID]
	end
	
	if g_Config["teleporters"]["n:" .. l_Entity.Parent.Entity.Name] then
		return g_Config["teleporters"]["n:" .. l_Entity.Parent.Entity.Name]
	end
	
	return nil
end

function Deathrun_GetEntityTrapActivator(p_EntityPtr)
	local l_Entity = CBaseEntity(p_EntityPtr)
	
	if not l_Entity or not l_Entity:IsValid() then
		return nil
	end
	
	if g_Config["activators.traps"]["h:" .. l_Entity.UniqueHammerID] then
		return g_Config["activators.traps"]["h:" .. l_Entity.UniqueHammerID]
	end
	
	if g_Config["activators.traps"]["n:" .. l_Entity.Parent.Entity.Name] then
		return g_Config["activators.traps"]["n:" .. l_Entity.Parent.Entity.Name]
	end
	
	return nil
end

function Deathrun_GetPlayerRemainingWarmupCount(p_PlayerId)
	if g_Config["warmup.player.respawns.max"] == 0 or not g_WarmupPeriod then
		return nil
	end
	
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player or not l_Player:IsValid() then
		return nil
	end
	
	local l_PlayerTeam = exports["helpers"]:GetPlayerTeam(p_PlayerId)
	
	if l_PlayerTeam ~= Team.CT then
		return nil
	end
	
	local l_PlayerWarmupCount = l_Player:GetVar("deathrun.warmup.count") or 0
	
	return math.max(g_Config["warmup.player.respawns.max"] - l_PlayerWarmupCount, 0)
end

function Deathrun_GetPlayerTeleportVelocity(p_PlayerId, p_EntityPtr)
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player 
		or not l_Player:IsValid() 
		or not exports["helpers"]:IsPlayerAlive(p_PlayerId) 
	then
		return nil
	end
	
	local l_Entity = CBaseEntity(p_EntityPtr)
	
	if not l_Entity or not l_Entity:IsValid() then
		return nil
	end
	
	local l_Destination = Deathrun_FindTeleportDestination(l_Entity.Target)
	
	if not l_Destination then
		return nil
	end
	
	local l_PlayerVelocity = l_Player:GetVar("deathrun.velocity") or exports["helpers"]:GetPlayerVelocity(p_PlayerId)
	local l_PlayerVelocityRotation = exports["helpers"]:GetVectorAngles(l_PlayerVelocity)
	
	local l_DestinationRotation = l_Destination.CBodyComponent.SceneNode.AbsRotation
	
	local l_YawDifference = (l_DestinationRotation.y - l_PlayerVelocityRotation[2] + 180) % 360 - 180
	local l_YawRadianDifference = math.rad(l_YawDifference)
	local l_YawCosDifference = math.cos(l_YawRadianDifference)
	local l_YawSinDifference = math.sin(l_YawRadianDifference)
	
	l_PlayerVelocity = {
		l_PlayerVelocity[1] * l_YawCosDifference - l_PlayerVelocity[2] * l_YawSinDifference,
		l_PlayerVelocity[1] * l_YawSinDifference + l_PlayerVelocity[2] * l_YawCosDifference,
		l_PlayerVelocity[3]
	}
	
	return l_PlayerVelocity
end

function Deathrun_GivePlayerItems(p_PlayerId)
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player 
		or not l_Player:IsValid() 
		or not exports["helpers"]:IsPlayerAlive(p_PlayerId) 
	then
		return
	end
	
	local l_PlayerTeam = exports["helpers"]:GetPlayerTeam(p_PlayerId)
	
	l_Player:GetWeaponManager():RemoveWeapons()
	
	exports["helpers"]:GivePlayerWeapon(p_PlayerId, "weapon_knife")
	
	if l_PlayerTeam ~= Team.CT then
		return
	end
	
	exports["helpers"]:GivePlayerWeapon(p_PlayerId, "weapon_usp_silencer")
	
	local l_PlayerWeapons = l_Player:GetWeaponManager():GetWeapons()
	
	for i = 1, #l_PlayerWeapons do
		local l_PlayerWeapon = l_PlayerWeapons[i]:CBasePlayerWeapon()
		
		if l_PlayerWeapon.Parent.AttributeManager.Item.ItemDefinitionIndex == WEAPON_USP_SILENCER then
			l_PlayerWeapon.Parent.Parent.Parent.Parent.Parent.Parent.Entity.Name = "deathrun_item_spawn"
		end
	end
end

function Deathrun_HandlePlayerButtonPress(p_PlayerId, p_EntityPtr)
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player 
		or not l_Player:IsValid() 
		or not exports["helpers"]:IsPlayerAlive(p_PlayerId) 
	then
		return
	end
	
	local l_EntityTrapActivator = Deathrun_GetEntityTrapActivator(p_EntityPtr)
	
	if not l_EntityTrapActivator then
		return
	end
	
	Deathrun_HandlePlayerTrapTrigger(p_PlayerId, l_EntityTrapActivator["id"])
end

function Deathrun_HandlePlayerEndingTrigger(p_PlayerId, p_Id)
	if g_RoundCount == 0 then
		return
	end
	
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player 
		or not l_Player:IsValid() 
		or not exports["helpers"]:IsPlayerAlive(p_PlayerId) 
	then
		return
	end
	
	if not g_EndingId then
		g_EndingId = p_Id
		
		local l_PlayerName = exports["helpers"]:GetPlayerName(p_PlayerId)
		local l_PlayerColor = exports["helpers"]:GetPlayerChatColor(p_PlayerId)
		
		local l_TerroristColor = exports["helpers"]:GetTeamChatColor(Team.T)
		
		playermanager:SendMsg(MessageType.Chat, string.format("{lime}%s{default} %s%s{default} chose {lime}%s{default} to fight the %sTerrorist{default}", g_Config["tag"], l_PlayerColor, l_PlayerName, g_Config["endings"][p_Id]["display"], l_TerroristColor))
		
		if g_Config["endings"][p_Id]["terrorist_killer.speed"] then
			Deathrun_SetPlayerSpeed(p_PlayerId, VELOCITY_MODIFIER_X1)
		end
		
		Deathrun_DisableEndings(p_Id)
	end
	
	if not Deathrun_IsValidTerrorist() then
		return
	end
	
	Deathrun_SetPlayerImmunity(p_PlayerId)
	Deathrun_SetPlayerImmunity(g_TerroristId)
	
	Deathrun_RemovePlayerSpeed(g_TerroristId)
end

function Deathrun_HandlePlayerFinish(p_PlayerId)
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player or not l_Player:IsValid() then
		return
	end
	
	local l_PlayerTeam = exports["helpers"]:GetPlayerTeam(p_PlayerId)
	
	if l_PlayerTeam ~= Team.CT or not exports["helpers"]:IsPlayerAlive(p_PlayerId) then
		return
	end
	
	local l_PlayerPosition = l_Player:GetVar("deathrun.position")
	
	if l_PlayerPosition then
		return
	end
	
	g_FinishCount = g_FinishCount + 1
	
	local l_ServerTime = math.floor(server:GetCurrentTime() * 1000)
	
	local l_PlayerName = exports["helpers"]:GetPlayerName(p_PlayerId)
	local l_PlayerColor = exports["helpers"]:GetPlayerChatColor(p_PlayerId)
	
	local l_Time = l_ServerTime - g_RoundStartTime
	
	playermanager:SendMsg(MessageType.Chat, string.format("{lime}%s{default} %s%s{default} has finished the map {lime}#%d{default} in {lime}%02d:%02d:%02d{default}", g_Config["tag"], l_PlayerColor, l_PlayerName, g_FinishCount, math.floor(l_Time / 60000), math.floor(l_Time / 1000) % 60, l_Time % 100))
	
	l_Player:SetVar("deathrun.position", g_FinishCount)
	
	if not Deathrun_IsValidTerroristKiller() then
		g_TerroristKillerId = p_PlayerId
		
		local l_CTColor = exports["helpers"]:GetTeamChatColor(Team.CT)
		
		playermanager:SendMsg(MessageType.Chat, string.format("{lime}%s{default} %s%s{default} {lime}[#%d]{default} is now the %sTerrorist Killer{default}", g_Config["tag"], l_PlayerColor, l_PlayerName, g_FinishCount, l_CTColor))
		
		exports["helpers"]:SetPlayerEntityName(p_PlayerId, "deathrun_player_terrorist_killer")
		exports["helpers"]:SetPlayerRenderColor(p_PlayerId, RENDER_COLOR_TERRORIST_KILLER)
		
		Deathrun_EmitSoundToAll(g_Config["terrorist_killer.sounds.join"])
	end
	
	Deathrun_RemovePlayerSpawnItems(p_PlayerId)
	
	Deathrun_EndWarmupPeriod(true)
	Deathrun_CheckPlayerFinishCount()
end

function Deathrun_HandlePlayerTeleportTouch(p_PlayerId, p_EntityPtr)
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player 
		or not l_Player:IsValid() 
		or not exports["helpers"]:IsPlayerAlive(p_PlayerId) 
	then
		return
	end
	
	local l_EntityEndingActivator = Deathrun_GetEntityEndingActivator(p_EntityPtr)
	local l_EntityTeleporter = Deathrun_GetEntityTeleporter(p_EntityPtr)
	
	if l_EntityEndingActivator then
		if Deathrun_IsPlayerTerroristKiller(p_PlayerId) then
			Deathrun_HandlePlayerEndingTrigger(p_PlayerId, l_EntityEndingActivator["id"])
		end
	end
	
	if l_EntityTeleporter and l_EntityTeleporter["nospeed"] then
		exports["helpers"]:SetPlayerVelocity(p_PlayerId, {0, 0, 0})
	else
		local l_PlayerVelocity = Deathrun_GetPlayerTeleportVelocity(p_PlayerId, p_EntityPtr)
		
		if not l_PlayerVelocity then
			return
		end
		
		exports["helpers"]:SetPlayerVelocity(p_PlayerId, l_PlayerVelocity)
	end
end

function Deathrun_HandlePlayerTerroristSpawn(p_PlayerId)
	if g_RoundCount == 0 then
		return
	end
	
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player 
		or not l_Player:IsValid() 
		or not exports["helpers"]:IsPlayerAlive(p_PlayerId) 
	then
		return
	end
	
	if Deathrun_IsPlayerTerrorist(p_PlayerId) then
		local l_PlayerName = exports["helpers"]:GetPlayerName(p_PlayerId)
		local l_PlayerColor = exports["helpers"]:GetPlayerChatColor(p_PlayerId)
		
		local l_TerroristColor = exports["helpers"]:GetTeamChatColor(Team.T)
		
		playermanager:SendMsg(MessageType.Chat, string.format("{lime}%s{default} %s%s{default} is now the %sTerrorist{default}", g_Config["tag"], l_PlayerColor, l_PlayerName, l_TerroristColor))
		
		exports["helpers"]:SetPlayerEntityName(p_PlayerId, "deathrun_player_terrorist")
		exports["helpers"]:SetPlayerRenderColor(p_PlayerId, RENDER_COLOR_TERRORIST)
		
		if not g_EndingId then
			if g_Config["terrorist.speed"] then
				Deathrun_SetPlayerSpeed(p_PlayerId, VELOCITY_MODIFIER_X3)
			end
		end
	elseif not l_Player:IsFakeClient() then
		exports["helpers"]:SlayPlayer(p_PlayerId)
	end
end

function Deathrun_HandlePlayerTrapTrigger(p_PlayerId, p_Id)
	if g_RoundCount == 0 then
		return
	end
	
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player 
		or not l_Player:IsValid() 
		or not exports["helpers"]:IsPlayerAlive(p_PlayerId) 
	then
		return
	end
	
	local l_PlayerName = exports["helpers"]:GetPlayerName(p_PlayerId)
	local l_PlayerColor = exports["helpers"]:GetPlayerChatColor(p_PlayerId)
	
	playermanager:SendMsg(MessageType.Chat, string.format("{lime}%s{default} %s%s{default} activated a trap {lime}[#%d/%d]{default}", g_Config["tag"], l_PlayerColor, l_PlayerName, p_Id, g_Config["traps.count"]))
end

function Deathrun_HandleTeleportInput(p_EntityPtr, p_InputName)
	local l_Input = g_Inputs[p_InputName]
	
	if l_Input ~= INPUT_DISABLE then
		return EventResult.Continue
	end
	
	local l_EntityEndingActivator = Deathrun_GetEntityEndingActivator(p_EntityPtr)
	
	if not l_EntityEndingActivator or g_EndingId ~= l_EntityEndingActivator["id"] then
		return EventResult.Continue
	end
	
	return EventResult.Handled
end

function Deathrun_HandleTeleportSpawn(p_EntityPtr)
	local l_Entity = CTriggerTeleport(p_EntityPtr)
	
	if not l_Entity or not l_Entity:IsValid() then
		return
	end
	
	l_Entity.UseLandmarkAngles = true
	
	local l_EntityEndingActivator = Deathrun_GetEntityEndingActivator(p_EntityPtr)
	
	if not l_EntityEndingActivator then
		return
	end
	
	l_Entity.Parent.FilterName = "deathrun_filter_terrorist_killer" .. l_EntityEndingActivator["id"]
	
	Deathrun_CreateTerroristKillerFilter(l_Entity.Parent.FilterName)
end

function Deathrun_HasPlayerImmunity(p_PlayerId)
	if g_RoundCount == 0 then
		return false
	end
	
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player 
		or not l_Player:IsValid() 
		or not exports["helpers"]:IsPlayerAlive(p_PlayerId) 
	then
		return false
	end
	
	local l_PlayerImmunityTime = l_Player:GetVar("deathrun.immunity.time")
	
	if not l_PlayerImmunityTime then
		return false
	end
	
	local l_ServerTime = math.floor(server:GetCurrentTime() * 1000)
	
	if l_ServerTime >= l_PlayerImmunityTime then
		return false
	end
	
	return true
end

function Deathrun_IsFallDamage(p_DamagePtr)
	local l_Damage = CTakeDamageInfo(p_DamagePtr)
	
	if not l_Damage or not l_Damage:IsValid() then
		return false
	end
	
	if l_Damage.BitsDamageType & DamageTypes_t.DMG_FALL == 0 then
		return false
	end
	
	return true
end

function Deathrun_IsPlayerInSwitchQueue(p_PlayerId)
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player or not l_Player:IsValid() then
		return false
	end
	
	return l_Player:GetVar("deathrun.switch.queue") or false
end

function Deathrun_IsPlayerTerrorist(p_PlayerId)
	if p_PlayerId ~= g_TerroristId or not Deathrun_IsValidTerrorist() then
		return false
	end
	
	return true
end

function Deathrun_IsPlayerTerroristKiller(p_PlayerId)
	if p_PlayerId ~= g_TerroristKillerId or not Deathrun_IsValidTerroristKiller() then
		return false
	end
	
	return true
end

function Deathrun_IsValidTerrorist()
	if not g_TerroristId then
		return false
	end
	
	local l_Terrorist = GetPlayer(g_TerroristId)
	
	if not l_Terrorist or not l_Terrorist:IsValid() then
		return false
	end
	
	local l_TerroristTeam = exports["helpers"]:GetPlayerTeam(g_TerroristId)
	
	if l_TerroristTeam ~= Team.T or not exports["helpers"]:IsPlayerAlive(g_TerroristId) then
		return false
	end
	
	return true
end

function Deathrun_IsValidTerroristKiller()
	if not g_TerroristKillerId then
		return false
	end
	
	local l_TerroristKiller = GetPlayer(g_TerroristKillerId)
	
	if not l_TerroristKiller or not l_TerroristKiller:IsValid() then
		return false
	end
	
	local l_TerroristKillerTeam = exports["helpers"]:GetPlayerTeam(g_TerroristKillerId)
	
	if l_TerroristKillerTeam ~= Team.CT or not exports["helpers"]:IsPlayerAlive(g_TerroristKillerId) then
		return false
	end
	
	return true
end

function Deathrun_LoadConfig()
	local l_Map = server:GetMap()
	
	config:Reload("deathrun")
	config:Reload("deathrun/" .. l_Map)
	
	g_Config = {}
	g_Config["tag"] = config:Fetch("deathrun.tag")
	g_Config["immunity.time"] = tonumber(config:Fetch("deathrun.immunity.time"))
	g_Config["round.time.finish.min"] = tonumber(config:Fetch("deathrun.round.time.finish.min"))
	g_Config["round.time.finish.max"] = tonumber(config:Fetch("deathrun.round.time.finish.max"))
	g_Config["round.time.finish.players.factor"] = tonumber(config:Fetch("deathrun.round.time.finish.players.factor"))
	g_Config["terrorist.queue.enable"] = config:Fetch("deathrun.terrorist.queue.enable")
	g_Config["terrorist.queue.player.requests.max"] = tonumber(config:Fetch("deathrun.terrorist.queue.player.requests.max"))
	g_Config["terrorist.random.enable"] = config:Fetch("deathrun.terrorist.random.enable")
	g_Config["terrorist.random.players.min"] = tonumber(config:Fetch("deathrun.terrorist.random.players.min"))
	g_Config["terrorist.speed"] = config:Fetch("deathrun.terrorist.speed")
	g_Config["terrorist_killer.sounds.join"] = config:Fetch("deathrun.terrorist_killer.sounds.join")
	g_Config["warmup.player.respawns.max"] = tonumber(config:Fetch("deathrun.warmup.player.respawns.max"))
	g_Config["warmup.time.min"] = tonumber(config:Fetch("deathrun.warmup.time.min"))
	g_Config["warmup.time.max"] = tonumber(config:Fetch("deathrun.warmup.time.max"))
	g_Config["warmup.time.players.factor"] = tonumber(config:Fetch("deathrun.warmup.time.players.factor"))
	
	if type(g_Config["tag"]) ~= "string" then
		g_Config["tag"] = "[Deathrun]"
	end
	
	if not g_Config["immunity.time"] or g_Config["immunity.time"] < 0 then
		g_Config["immunity.time"] = 0
	end
	
	if not g_Config["round.time.finish.min"] or g_Config["round.time.finish.min"] < 0 then
		g_Config["round.time.finish.min"] = 0
	end
	
	if not g_Config["round.time.finish.max"] or g_Config["round.time.finish.max"] < 0 then
		g_Config["round.time.finish.max"] = 0
	end
	
	if not g_Config["round.time.finish.players.factor"] or g_Config["round.time.finish.players.factor"] < 0 then
		g_Config["round.time.finish.players.factor"] = 0
	end
	
	if type(g_Config["terrorist.queue.enable"]) ~= "boolean" then
		g_Config["terrorist.queue.enable"] = tonumber(g_Config["terrorist.queue.enable"])
		g_Config["terrorist.queue.enable"] = g_Config["terrorist.queue.enable"] and g_Config["terrorist.queue.enable"] ~= 0
	end
	
	if not g_Config["terrorist.queue.player.requests.max"] or g_Config["terrorist.queue.player.requests.max"] < 0 then
		g_Config["terrorist.queue.player.requests.max"] = 0
	end
	
	if type(g_Config["terrorist.random.enable"]) ~= "boolean" then
		g_Config["terrorist.random.enable"] = tonumber(g_Config["terrorist.random.enable"])
		g_Config["terrorist.random.enable"] = g_Config["terrorist.random.enable"] and g_Config["terrorist.random.enable"] ~= 0
	end
	
	if not g_Config["terrorist.random.players.min"] or g_Config["terrorist.random.players.min"] < 0 then
		g_Config["terrorist.random.players.min"] = 0
	end
	
	if type(g_Config["terrorist.speed"]) ~= "boolean" then
		g_Config["terrorist.speed"] = tonumber(g_Config["terrorist.speed"])
		g_Config["terrorist.speed"] = g_Config["terrorist.speed"] and g_Config["terrorist.speed"] ~= 0
	end
	
	if type(g_Config["terrorist_killer.sounds.join"]) ~= "string" then
		g_Config["terrorist_killer.sounds.join"] = ""
	end
	
	if not g_Config["warmup.player.respawns.max"] or g_Config["warmup.player.respawns.max"] < 0 then
		g_Config["warmup.player.respawns.max"] = 0
	end
	
	if not g_Config["warmup.time.min"] or g_Config["warmup.time.min"] < 0 then
		g_Config["warmup.time.min"] = 0
	end
	
	if not g_Config["warmup.time.max"] or g_Config["warmup.time.max"] < 0 then
		g_Config["warmup.time.max"] = 0
	end
	
	if not g_Config["warmup.time.players.factor"] or g_Config["warmup.time.players.factor"] < 0 then
		g_Config["warmup.time.players.factor"] = 0
	end
	
	g_Config["immunity.time"] = math.floor(g_Config["immunity.time"] * 1000)
	
	Deathrun_LoadConfigActivatorEndings()
	Deathrun_LoadConfigActivatorTraps()
	Deathrun_LoadConfigEndings()
	Deathrun_LoadConfigTeleporters()
	Deathrun_LoadConfigTraps()
end

function Deathrun_LoadConfigActivatorEndings()
	g_Config["activators.endings"] = {}
	
	local l_Map = server:GetMap()
	local l_ActivatorEndings = config:Fetch("deathrun." .. l_Map .. ".activators.endings")
	
	if type(l_ActivatorEndings) ~= "table" then
		l_ActivatorEndings = {}
	end
	
	for i = 1, #l_ActivatorEndings do
		local l_Id = tonumber(l_ActivatorEndings[i]["id"])
		local l_Name = l_ActivatorEndings[i]["name"]
		local l_Hammer = l_ActivatorEndings[i]["hammer"]
		
		if not l_Id or l_Id < 1 then
			l_Id = nil
		end
		
		if type(l_Name) ~= "string" or #l_Name == 0 then
			l_Name = nil
		end
		
		if type(l_Hammer) ~= "number" and (type(l_Hammer) ~= "string" or #l_Hammer == 0) then
			l_Hammer = nil
		end
		
		if l_Id then
			if l_Name then
				g_Config["activators.endings"]["n:" .. l_Name] = {
					["id"] = l_Id
				}
			elseif l_Hammer then
				g_Config["activators.endings"]["h:" .. tostring(l_Hammer)] = {
					["id"] = l_Id
				}
			end
		end
	end
end

function Deathrun_LoadConfigActivatorTraps()
	g_Config["activators.traps"] = {}
	
	local l_Map = server:GetMap()
	local l_ActivatorTraps = config:Fetch("deathrun." .. l_Map .. ".activators.traps")
	
	if type(l_ActivatorTraps) ~= "table" then
		l_ActivatorTraps = {}
	end
	
	for i = 1, #l_ActivatorTraps do
		local l_Id = tonumber(l_ActivatorTraps[i]["id"])
		local l_Name = l_ActivatorTraps[i]["name"]
		local l_Hammer = l_ActivatorTraps[i]["hammer"]
		
		if not l_Id or l_Id < 1 then
			l_Id = nil
		end
		
		if type(l_Name) ~= "string" or #l_Name == 0 then
			l_Name = nil
		end
		
		if type(l_Hammer) ~= "number" and (type(l_Hammer) ~= "string" or #l_Hammer == 0) then
			l_Hammer = nil
		end
		
		if l_Id then
			if l_Name then
				g_Config["activators.traps"]["n:" .. l_Name] = {
					["id"] = l_Id
				}
			elseif l_Hammer then
				g_Config["activators.traps"]["h:" .. tostring(l_Hammer)] = {
					["id"] = l_Id
				}
			end
		end
	end
end

function Deathrun_LoadConfigEndings()
	g_Config["endings"] = {}
	g_Config["endings.count"] = 0
	
	local l_Map = server:GetMap()
	local l_Endings = config:Fetch("deathrun." .. l_Map .. ".endings")
	
	if type(l_Endings) ~= "table" then
		l_Endings = {}
	end
	
	for i = 1, #l_Endings do
		local l_Id = tonumber(l_Endings[i]["id"])
		local l_Display = l_Endings[i]["display"]
		local l_TerroristKiller = l_Endings[i]["terrorist_killer"]
		
		if not l_Id or l_Id < 1 then
			l_Id = nil
		end
		
		if type(l_Display) ~= "string" or #l_Display == 0 then
			l_Display = nil
		end
		
		if type(l_TerroristKiller) ~= "table" then
			l_TerroristKiller = {}
		end
		
		local l_TerroristKillerSpeed = l_TerroristKiller["speed"]
		
		if type(l_TerroristKillerSpeed) ~= "boolean" then
			l_TerroristKillerSpeed = tonumber(l_TerroristKillerSpeed)
			l_TerroristKillerSpeed = l_TerroristKillerSpeed and l_TerroristKillerSpeed ~= 0
		end
		
		if l_Id and l_Display then
			g_Config["endings"][l_Id] = {
				["display"] = l_Display,
				["terrorist_killer.speed"] = l_TerroristKillerSpeed
			}
			
			g_Config["endings.count"] = l_Id
		end
	end
end

function Deathrun_LoadConfigTeleporters()
	g_Config["teleporters"] = {}
	
	local l_Map = server:GetMap()
	local l_Teleporters = config:Fetch("deathrun." .. l_Map .. ".teleporters")
	
	if type(l_Teleporters) ~= "table" then
		l_Teleporters = {}
	end
	
	for i = 1, #l_Teleporters do
		local l_Name = l_Teleporters[i]["name"]
		local l_Hammer = l_Teleporters[i]["hammer"]
		local l_Nospeed = l_Teleporters[i]["nospeed"]
		
		if type(l_Name) ~= "string" or #l_Name == 0 then
			l_Name = nil
		end
		
		if type(l_Hammer) ~= "number" and (type(l_Hammer) ~= "string" or #l_Hammer == 0) then
			l_Hammer = nil
		end
		
		if type(l_Nospeed) ~= "boolean" then
			l_Nospeed = tonumber(l_Nospeed)
			l_Nospeed = l_Nospeed and l_Nospeed ~= 0
		end
		
		if l_Name then
			g_Config["teleporters"]["n:" .. l_Name] = {
				["nospeed"] = l_Nospeed
			}
		elseif l_Hammer then
			g_Config["teleporters"]["h:" .. tostring(l_Hammer)] = {
				["nospeed"] = l_Nospeed
			}
		end
	end
end

function Deathrun_LoadConfigTraps()
	g_Config["traps"] = {}
	g_Config["traps.count"] = 0
	
	local l_Map = server:GetMap()
	local l_Traps = config:Fetch("deathrun." .. l_Map .. ".traps")
	
	if type(l_Traps) ~= "table" then
		l_Traps = {}
	end
	
	for i = 1, #l_Traps do
		local l_Id = tonumber(l_Traps[i]["id"])
		
		if not l_Id or l_Id < 1 then
			l_Id = nil
		end
		
		if l_Id then
			g_Config["traps"][l_Id] = true
			g_Config["traps.count"] = l_Id
		end
	end
end

function Deathrun_LoadPlayerDisconnectionData(p_PlayerId)
	if g_RoundCount == 0 or exports["helpers"]:IsMatchOver() then
		return
	end
	
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player or not l_Player:IsValid() then
		return
	end
	
	local l_PlayerSteam = exports["helpers"]:GetPlayerSteam(p_PlayerId)
	
	if not g_Disconnections[l_PlayerSteam] then
		return
	end
	
	if g_Disconnections[l_PlayerSteam]["terrorist.time"] then
		l_Player:SetVar("deathrun.terrorist.time", g_Disconnections[l_PlayerSteam]["terrorist.time"])
	end
	
	if g_Disconnections[l_PlayerSteam]["terrorist.requests"] then
		l_Player:SetVar("deathrun.terrorist.requests", g_Disconnections[l_PlayerSteam]["terrorist.requests"])
	end
	
	if g_Disconnections[l_PlayerSteam]["warmup.count"] then
		l_Player:SetVar("deathrun.warmup.count", g_Disconnections[l_PlayerSteam]["warmup.count"])
	end
	
	g_Disconnections[l_PlayerSteam] = nil
end

function Deathrun_PrepareRound()
	local l_ServerTime = math.floor(server:GetCurrentTime() * 1000)
	
	g_EndingId = nil
	g_FinishCount = 0
	
	g_RoundPreparePeriod = true
	g_RoundStartTime = l_ServerTime
	
	g_TerroristId = nil
	g_TerroristKillerId = nil
	
	for i = 0, playermanager:GetPlayerCap() - 1 do
		local l_PlayerIter = GetPlayer(i)
		
		if l_PlayerIter and l_PlayerIter:IsValid() and not l_PlayerIter:IsFakeClient() then
			local l_PlayerIterTeam = exports["helpers"]:GetPlayerTeam(i)
			
			if l_PlayerIterTeam == Team.T then
				Deathrun_SwitchPlayerTeam(i, Team.CT)
			end
		end
	end
	
	Deathrun_ChooseTerrorist()
	Deathrun_StartWarmupPeriod()
	
	SetTimeout(1000, function()
		g_RoundPreparePeriod = false
	end)
end

function Deathrun_PrintMapTimeLeft()
	if g_RoundCount == 0 then
		return
	end
	
	SetTimeout(200, function()
		if g_RoundCount == 0 then
			return
		end
		
		local l_TimeLeft = math.ceil(exports["helpers"]:GetMapTimeLeft() / 1000)
		
		if not l_TimeLeft or exports["helpers"]:IsTimeIndefinite(l_TimeLeft) then
			return
		end
		
		playermanager:SendMsg(MessageType.Chat, string.format("{lime}%s{default} This map will end in {lime}%02d:%02d{default}", g_Config["tag"], math.floor(l_TimeLeft / 60), l_TimeLeft % 60))
	end)
end

function Deathrun_RefillPlayerAmmo(p_PlayerId)
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player 
		or not l_Player:IsValid() 
		or not exports["helpers"]:IsPlayerAlive(p_PlayerId) 
	then
		return
	end
	
	local l_ServerTime = math.floor(server:GetCurrentTime() * 1000)
	local l_PlayerNextAttackTime = exports["helpers"]:GetPlayerNextAttackTime(p_PlayerId)
	
	if l_PlayerNextAttackTime + REFILL_DELAY_TIME > l_ServerTime then
		return
	end
	
	exports["helpers"]:RefillPlayerAmmo(p_PlayerId)
end

function Deathrun_RemovePlayerImmunity(p_PlayerId)
	if g_RoundCount == 0 then
		return
	end
	
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player 
		or not l_Player:IsValid() 
		or not exports["helpers"]:IsPlayerAlive(p_PlayerId) 
	then
		return
	end
	
	local l_ServerTime = math.floor(server:GetCurrentTime() * 1000)
	
	local l_PlayerImmunityEnd = l_Player:GetVar("deathrun.immunity.end")
	local l_PlayerImmunityTime = l_Player:GetVar("deathrun.immunity.time")
	
	if l_PlayerImmunityTime then
		if l_PlayerImmunityTime > l_ServerTime then
			return
		end
		
		l_Player:SetVar("deathrun.immunity.time", nil)
		l_Player:SetVar("deathrun.immunity.end", {
			["time"] = l_ServerTime,
			["type"] = IMMUNITY_EXPIRED
		})
		
		if p_PlayerId == g_TerroristId then
			exports["helpers"]:SetPlayerRenderColor(p_PlayerId, RENDER_COLOR_TERRORIST)
		elseif p_PlayerId == g_TerroristKillerId then
			exports["helpers"]:SetPlayerRenderColor(p_PlayerId, RENDER_COLOR_TERRORIST_KILLER)
		else
			exports["helpers"]:SetPlayerRenderColor(p_PlayerId, RENDER_COLOR_DEFAULT)
		end
	elseif l_PlayerImmunityEnd then
		if l_PlayerImmunityEnd["time"] + 3000 > l_ServerTime then
			return
		end
		
		l_Player:SetVar("deathrun.immunity.end", nil)
	end
end

function Deathrun_RemovePlayerSpawnItems(p_PlayerId)
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player 
		or not l_Player:IsValid() 
		or not exports["helpers"]:IsPlayerAlive(p_PlayerId) 
	then
		return
	end
	
	local l_PlayerWeapons = l_Player:GetWeaponManager():GetWeapons()
	
	for i = 1, #l_PlayerWeapons do
		local l_PlayerWeapon = l_PlayerWeapons[i]:CBasePlayerWeapon()
		
		if l_PlayerWeapon.Parent.Parent.Parent.Parent.Parent.Parent.Entity.Name == "deathrun_item_spawn" then
			l_PlayerWeapons[i]:Drop()
			l_PlayerWeapons[i]:Remove()
		end
	end
end

function Deathrun_RemovePlayerSpeed(p_PlayerId)
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player 
		or not l_Player:IsValid() 
		or not exports["helpers"]:IsPlayerAlive(p_PlayerId) 
	then
		return
	end
	
	local l_PlayerVelocityModifier = l_Player:GetVar("deathrun.velocity.modifier")
	
	if not l_PlayerVelocityModifier then
		return
	end
	
	local l_PlayerName = exports["helpers"]:GetPlayerName(p_PlayerId)
	local l_PlayerColor = exports["helpers"]:GetPlayerChatColor(p_PlayerId)
	
	playermanager:SendMsg(MessageType.Chat, string.format("{lime}%s{default} %s%s{default} can no longer gain {lime}x3{default} speed", g_Config["tag"], l_PlayerColor, l_PlayerName))
	
	exports["helpers"]:SetPlayerVelocityModifier(p_PlayerId, VELOCITY_MODIFIER_X1)
	
	l_Player:SetVar("deathrun.velocity.modifier", nil)
end

function Deathrun_ResetPlayerVars(p_PlayerId)
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player then
		return
	end
	
	l_Player:SetVar("deathrun.death.time", nil)
	l_Player:SetVar("deathrun.immunity.end", nil)
	l_Player:SetVar("deathrun.immunity.time", nil)
	l_Player:SetVar("deathrun.position", nil)
	l_Player:SetVar("deathrun.respawn", nil)
	l_Player:SetVar("deathrun.switch.queue", nil)
	l_Player:SetVar("deathrun.terrorist.time", nil)
	l_Player:SetVar("deathrun.terrorist.queue", nil)
	l_Player:SetVar("deathrun.terrorist.requests", nil)
	l_Player:SetVar("deathrun.velocity", nil)
	l_Player:SetVar("deathrun.velocity.modifier", nil)
	l_Player:SetVar("deathrun.warmup.count", nil)
	
	l_Player:SendMsg(MessageType.Center, "")
end

function Deathrun_ResetVars()
	g_Disconnections = {}
	
	g_EndingId = nil
	g_FinishCount = 0
	
	g_RoundCount = 0
	g_RoundPreparePeriod = nil
	g_RoundStartTime = nil
	
	g_TeamTerroristScore = 0
	g_TeamCTScore = 0
	
	g_TerroristId = nil
	g_TerroristKillerId = nil
	
	g_ThinkFunctionTime = nil
	
	g_WarmupPeriod = nil
	g_WarmupPeriodRespawn = nil
	g_WarmupEndTime = nil
end

function Deathrun_RespawnPlayer(p_PlayerId)
	if g_RoundCount == 0 then
		return
	end
	
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player or not l_Player:IsValid() then
		return
	end
	
	local l_PlayerRespawn = l_Player:GetVar("deathrun.respawn")
	
	if not l_PlayerRespawn then
		return
	end
	
	local l_ServerTime = math.floor(server:GetCurrentTime() * 1000)
	
	if l_PlayerRespawn["time"] > l_ServerTime then
		return
	end
	
	if l_PlayerRespawn["type"] == RESPAWN_WARMUP then
		local l_PlayerWarmupCount = l_Player:GetVar("deathrun.warmup.count") or 0
		
		l_Player:SetVar("deathrun.warmup.count", l_PlayerWarmupCount + 1)
	end
	
	l_Player:SetVar("deathrun.respawn", nil)
	l_Player:Respawn()
end

function Deathrun_RespawnPlayerOnRequest(p_PlayerId)
	if g_RoundCount == 0 or not convar:Get("mp_deathcam_skippable") then
		return
	end
	
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player or not l_Player:IsValid() then
		return
	end
	
	local l_PlayerRespawn = l_Player:GetVar("deathrun.respawn")
	
	if not l_PlayerRespawn then
		return
	end
	
	local l_PlayerDeathTime = l_Player:GetVar("deathrun.death.time")
	
	if not l_PlayerDeathTime then
		return
	end
	
	local l_ServerTime = math.floor(server:GetCurrentTime() * 1000)
	local l_RespawnLockTime = math.max(convar:Get("spec_freeze_time_lock"), 0)
	
	if l_PlayerDeathTime + math.floor(l_RespawnLockTime * 1000) > l_ServerTime then
		return
	end
	
	if l_PlayerRespawn["type"] == RESPAWN_WARMUP then
		local l_PlayerWarmupCount = l_Player:GetVar("deathrun.warmup.count") or 0
		
		l_Player:SetVar("deathrun.warmup.count", l_PlayerWarmupCount + 1)
	end
	
	l_Player:SetVar("deathrun.respawn", nil)
	l_Player:Respawn()
end

function Deathrun_SavePlayerDisconnectionData(p_PlayerId)
	if g_RoundCount == 0 then
		return
	end
	
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player or l_Player:IsFakeClient() then
		return
	end
	
	local l_PlayerSteam = exports["helpers"]:GetPlayerSteam(p_PlayerId)
	
	local l_PlayerTeroristRequests = l_Player:GetVar("deathrun.terrorist.requests")
	local l_PlayerTeroristTime = l_Player:GetVar("deathrun.terrorist.time")
	local l_PlayerWarmupCount = l_Player:GetVar("deathrun.warmup.count")
	
	if not l_PlayerTeroristRequests and not l_PlayerTeroristTime and not l_PlayerWarmupCount then
		return
	end
	
	g_Disconnections[l_PlayerSteam] = {
		["terrorist.requests"] = l_PlayerTeroristRequests,
		["terrorist.time"] = l_PlayerTeroristTime,
		["warmup.count"] = l_PlayerWarmupCount
	}
end

function Deathrun_SetBotQuota()
	local l_PlayerCount = exports["helpers"]:GetPlayerCount(true)
	
	if l_PlayerCount == 0 then
		exports["helpers"]:SetConVar("bot_quota", 0)
		server:Execute("bot_kick all")
		
		return
	end
	
	exports["helpers"]:SetConVar("bot_quota", 1)
	
	SetTimeout(500, function()
		for i = 0, playermanager:GetPlayerCap() - 1 do
			local l_PlayerIter = GetPlayer(i)
			
			if l_PlayerIter and l_PlayerIter:IsValid() and l_PlayerIter:IsFakeClient() then
				l_PlayerIter:SwitchTeam(Team.T)
				l_PlayerIter:Respawn()
			end
		end
	end)
end

function Deathrun_SetConVars()
	local l_Map = server:GetMap()
	
	local l_Config = exports["helpers"]:ParseGameConfig("cfg/swiftly/deathrun.cfg")
	local l_MapConfig = exports["helpers"]:ParseGameConfig("cfg/swiftly/deathrun/" .. l_Map .. ".cfg")
	
	for l_Key, l_Value in next, l_MapConfig do
		l_Config[l_Key] = l_Value
	end
	
	l_Config["bot_join_team"] = "T"
	l_Config["bot_quota"] = nil
	l_Config["bot_quota_mode"] = "normal"
	l_Config["bot_stop"] = 1
	l_Config["mp_afterroundmoney"] = 0
	l_Config["mp_autoteambalance"] = 0
	l_Config["mp_backup_round_auto"] = 0
	l_Config["mp_backup_round_file"] = ""
	l_Config["mp_backup_round_file_last"] = ""
	l_Config["mp_backup_round_file_pattern"] = ""
	l_Config["mp_buy_anywhere"] = 0
	l_Config["mp_buytime"] = 0
	l_Config["mp_ct_default_melee"] = ""
	l_Config["mp_ct_default_primary"] = ""
	l_Config["mp_ct_default_secondary"] = ""
	l_Config["mp_default_team_winner_no_objective"] = -1
	l_Config["mp_disconnect_kills_bots"] = 0
	l_Config["mp_disconnect_kills_players"] = 1
	l_Config["mp_force_pick_time"] = 30
	l_Config["mp_halftime"] = 0
	l_Config["mp_join_grace_time"] = 0
	l_Config["mp_limitteams"] = 0
	l_Config["mp_maxmoney"] = 0
	l_Config["mp_playercashawards"] = 0
	l_Config["mp_respawn_immunitytime"] = 0
	l_Config["mp_respawn_on_death_ct"] = 0
	l_Config["mp_respawn_on_death_t"] = 0
	l_Config["mp_startmoney"] = 0
	l_Config["mp_t_default_melee"] = ""
	l_Config["mp_t_default_primary"] = ""
	l_Config["mp_t_default_secondary"] = ""
	l_Config["mp_teamcashawards"] = 0
	l_Config["sv_airaccelerate"] = 1000
	l_Config["sv_autobunnyhopping"] = 1
	l_Config["sv_disable_radar"] = 1
	l_Config["sv_disconnected_player_data_hold_time"] = 1
	l_Config["sv_disconnected_players_cleanup_delay"] = 1
	l_Config["sv_enablebunnyhopping"] = 1
	l_Config["sv_jump_precision_enable"] = 0
	l_Config["sv_jump_spam_penalty_time"] = 0
	l_Config["sv_staminajumpcost"] = 0
	l_Config["sv_staminalandcost"] = 0
	l_Config["sv_staminamax"] = 0
	l_Config["sv_staminarecoveryrate"] = 0	
	l_Config["weapon_accuracy_nospread"] = 1
	
	for l_Key, l_Value in next, l_Config do
		exports["helpers"]:SetConVar(l_Key, l_Value)
	end
	
	Deathrun_SetBotQuota()
end

function Deathrun_SetPlayerCollision(p_PlayerId)
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player 
		or not l_Player:IsValid() 
		or not exports["helpers"]:IsPlayerAlive(p_PlayerId) 
	then
		return
	end
	
	exports["helpers"]:SetPlayerCollisionGroup(p_PlayerId, CollisionGroup.COLLISION_GROUP_INTERACTIVE_DEBRIS)
end

function Deathrun_SetPlayerImmunity(p_PlayerId)
	if g_Config["immunity.time"] == 0 or g_RoundCount == 0 then
		return
	end
	
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player 
		or not l_Player:IsValid() 
		or not exports["helpers"]:IsPlayerAlive(p_PlayerId) 
	then
		return
	end
	
	local l_ServerTime = math.floor(server:GetCurrentTime() * 1000)
	
	l_Player:SetVar("deathrun.immunity.time", l_ServerTime + g_Config["immunity.time"])
	
	exports["helpers"]:SetPlayerRenderColor(p_PlayerId, RENDER_COLOR_IMMUNITY)
end

function Deathrun_SetPlayerSpeed(p_PlayerId, p_Speed)
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player 
		or not l_Player:IsValid() 
		or not exports["helpers"]:IsPlayerAlive(p_PlayerId) 
	then
		return
	end
	
	local l_PlayerName = exports["helpers"]:GetPlayerName(p_PlayerId)
	local l_PlayerColor = exports["helpers"]:GetPlayerChatColor(p_PlayerId)
	
	playermanager:SendMsg(MessageType.Chat, string.format("{lime}%s{default} %s%s{default} can gain {lime}x3{default} speed", g_Config["tag"], l_PlayerColor, l_PlayerName))
	
	exports["helpers"]:SetPlayerVelocityModifier(p_PlayerId, p_Speed)
	
	l_Player:SetVar("deathrun.velocity.modifier", p_Speed)
end

function Deathrun_SetRoundTime(p_Time)
	if p_Time == 0 then
		return
	end
	
	local l_Time = math.floor(p_Time * 1000)
	local l_TimeLeft = exports["helpers"]:GetRoundTimeLeft()
	
	if l_Time > l_TimeLeft then
		return
	end
	
	playermanager:SendMsg(MessageType.Chat, string.format("{lightred}%s{default} This round will end in {lightred}%02d:%02d{default}", g_Config["tag"], math.floor(p_Time / 60), p_Time % 60))
	
	exports["helpers"]:SetRoundTime(l_Time)
end

function Deathrun_StartWarmupPeriod()
	g_WarmupPeriod = nil
	g_WarmupPeriodRespawn = nil
	
	local l_PlayerCount = exports["helpers"]:GetTeamPlayerCount(Team.CT, false)
	
	local l_Time = g_Config["warmup.time.max"]
	local l_Factor = math.floor((l_PlayerCount - 1) * g_Config["warmup.time.players.factor"])
	
	l_Time = l_PlayerCount ~= 0 and math.max(l_Time - l_Factor, g_Config["warmup.time.min"]) or l_Time
	
	if l_Time == 0 then
		return
	end
	
	local l_ServerTime = math.floor(server:GetCurrentTime() * 1000)
	
	g_WarmupPeriod = true
	g_WarmupPeriodRespawn = true
	
	g_WarmupEndTime = l_ServerTime + l_Time * 1000
	
	playermanager:SendMsg(MessageType.Chat, string.format("{lime}%s{default} The warmup period of {lime}%02d:%02d{default} has started", g_Config["tag"], math.floor(l_Time / 60), l_Time % 60))
	
	for l_Key, l_Value in next, g_Disconnections do
		l_Value["warmup.count"] = nil
	end
end

function Deathrun_StorePlayerVelocity(p_PlayerId)
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player 
		or not l_Player:IsValid() 
		or not exports["helpers"]:IsPlayerAlive(p_PlayerId) 
	then
		return
	end
	
	local l_PlayerVelocity = exports["helpers"]:GetPlayerVelocity(p_PlayerId)
	
	l_Player:SetVar("deathrun.velocity", l_PlayerVelocity)
end

function Deathrun_SwitchPlayerTeam(p_PlayerId, p_Team)
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player or not l_Player:IsValid() then
		return
	end
	
	local l_PlayerTeam = exports["helpers"]:GetPlayerTeam(p_PlayerId)
	
	if p_Team == l_PlayerTeam then
		return
	end
	
	l_Player:SetVar("deathrun.switch.queue", true)
	
	l_Player:SwitchTeam(p_Team)
	
	l_Player:SetVar("deathrun.switch.queue", nil)
end

function Deathrun_Think()
	if exports["helpers"]:IsMatchOver() then
		return
	end
	
	local l_ServerTime = math.floor(server:GetCurrentTime() * 1000)
	
	if g_WarmupPeriod and l_ServerTime >= g_WarmupEndTime then
		Deathrun_EndWarmupPeriod()
	end
	
	local l_CTCount = 0
	local l_AliveCTCount = 0
	local l_RespawnCTCount = 0
	
	local l_WarmupTime = g_WarmupPeriod and math.ceil((g_WarmupEndTime - l_ServerTime) / 1000) or 0
	
	local l_Terrorist = nil
	local l_TerroristKiller = nil
	
	local l_Players = {}
	
	for i = 0, playermanager:GetPlayerCap() - 1 do
		local l_PlayerIter = GetPlayer(i)
		
		if l_PlayerIter and l_PlayerIter:IsValid() then
			if g_RoundCount ~= 0 then
				if Deathrun_IsPlayerTerrorist(i) then
					l_Terrorist = {
						["id"] = i,
						["player"] = l_PlayerIter
					}
				elseif Deathrun_IsPlayerTerroristKiller(i) then
					l_TerroristKiller = {
						["id"] = i,
						["player"] = l_PlayerIter
					}
				end
			end
			
			l_Players[i] = l_PlayerIter
		end
	end
	
	if g_RoundCount ~= 0 then
		if l_Terrorist then
			l_Terrorist["name"] = exports["helpers"]:GetPlayerName(l_Terrorist["id"])
			l_Terrorist["color"] = exports["helpers"]:GetPlayerHintColor(l_Terrorist["id"])
			
			l_Terrorist["name"] = string.sub(l_Terrorist["name"], 1, HINT_NAME_LENGTH)
			l_Terrorist["name"] = exports["helpers"]:EncodeString(l_Terrorist["name"])
		end
		
		if l_TerroristKiller then
			l_TerroristKiller["name"] = exports["helpers"]:GetPlayerName(l_TerroristKiller["id"])
			l_TerroristKiller["color"] = exports["helpers"]:GetPlayerHintColor(l_TerroristKiller["id"])
			
			l_TerroristKiller["name"] = string.sub(l_TerroristKiller["name"], 1, HINT_NAME_LENGTH)
			l_TerroristKiller["name"] = exports["helpers"]:EncodeString(l_TerroristKiller["name"])
		end
	end
	
	for l_PlayerIterId, l_PlayerIter in pairs(l_Players) do
		if not g_ThinkFunctionTime or l_ServerTime >= g_ThinkFunctionTime + THINK_FUNCTION_INTERVAL then
			Deathrun_RefillPlayerAmmo(l_PlayerIterId)
			Deathrun_RemovePlayerImmunity(l_PlayerIterId)
			Deathrun_RespawnPlayer(l_PlayerIterId)
		end
		
		Deathrun_StorePlayerVelocity(l_PlayerIterId)
		
		if g_RoundCount ~= 0 then
			local l_PlayerIterTeam = exports["helpers"]:GetPlayerTeam(l_PlayerIterId)
			
			if l_PlayerIterTeam ~= Team.None then
				local l_PlayerIterAlive = exports["helpers"]:IsPlayerAlive(l_PlayerIterId)
				
				local l_HintTextTop = ""
				local l_HintTextBottom = ""
				
				if #l_HintTextTop ~= 0 then
					l_HintTextTop = l_HintTextTop .. "<br>"
				end
				
				if l_Terrorist then
					l_HintTextTop = l_HintTextTop 
						.. string.format("<font color='%s'>%s</font>", l_Terrorist["color"], l_Terrorist["name"])
				else
					l_HintTextTop = l_HintTextTop 
						.. string.format("<font color='#FF4500'>No T</font>")
				end
				
				l_HintTextTop = l_HintTextTop .. " vs "
				
				if l_TerroristKiller then
					l_HintTextTop = l_HintTextTop 
						.. string.format("<font color='%s'>%s</font>", l_TerroristKiller["color"], l_TerroristKiller["name"])
				else
					l_HintTextTop = l_HintTextTop 
						.. string.format("<font color='#FF4500'>No TK</font>")
				end
				
				if g_EndingId then
					l_HintTextTop = l_HintTextTop 
						.. string.format(" <font color='#A5FF50'>(%s)</font>", g_Config["endings"][g_EndingId]["display"])
				end
				
				if g_WarmupPeriod then
					if #l_HintTextBottom ~= 0 then
						l_HintTextBottom = l_HintTextBottom .. "<br>"
					end
					
					l_HintTextBottom = l_HintTextBottom 
						.. string.format("Warmup <font color='#6BDBFF'>%02d:%02d</font>", math.floor(l_WarmupTime / 60), l_WarmupTime % 60)
					
					local l_PlayerIterRemainingWarmupCount = Deathrun_GetPlayerRemainingWarmupCount(l_PlayerIterId)
					
					if l_PlayerIterRemainingWarmupCount then
						l_HintTextBottom = l_HintTextBottom 
							.. string.format(" <font color='%s'>[%dw]</font>", l_PlayerIterRemainingWarmupCount ~= 0 and "#A5FF50" or "#FF4500", l_PlayerIterRemainingWarmupCount)
					end
				end
				
				if l_PlayerIterAlive then
					local l_PlayerIterSpeed = exports["helpers"]:GetPlayerSpeed(l_PlayerIterId)
					local l_PlayerIterProtectionEnd = l_PlayerIter:GetVar("deathrun.immunity.end")
					local l_PlayerIterProtectionTime = l_PlayerIter:GetVar("deathrun.immunity.time")
					local l_PlayerIterVelocityModifier = l_PlayerIter:GetVar("deathrun.velocity.modifier")
					
					if l_PlayerIterImmunityTime then
						if #l_HintTextBottom ~= 0 then
							l_HintTextBottom = l_HintTextBottom .. "<br>"
						end
						
						l_HintTextBottom = l_HintTextBottom 
							.. string.format("Immunity <font color='#FFA500'>%0.1fs</font>", (l_PlayerIterImmunityTime - l_ServerTime) / 1000)
					elseif l_PlayerIterImmunityEnd then
						if #l_HintTextBottom ~= 0 then
							l_HintTextBottom = l_HintTextBottom .. "<br>"
						end
						
						l_HintTextBottom = l_HintTextBottom 
							.. string.format("Immunity <font color='#FF4500'>%s</font>", l_PlayerIterImmunityEnd.type == IMMUNITY_EXPIRED and "EXPIRED" or "CANCELLED")
					end
					
					if #l_HintTextBottom ~= 0 then
						l_HintTextBottom = l_HintTextBottom .. "<br>"
					end
					
					l_HintTextBottom = l_HintTextBottom 
						.. string.format("Speed <font color='#FFEA50'>%03d</font>", l_PlayerIterSpeed)
					
					if l_PlayerIterVelocityModifier then
						l_HintTextBottom = l_HintTextBottom 
							.. string.format(" <font color='#A5FF50'>[x%d]</font>", l_PlayerIterVelocityModifier)
					end
				end
				
				if #l_HintTextTop ~= 0 and #l_HintTextBottom ~= 0 then
					l_PlayerIter:SendMsg(MessageType.Center, string.format("%s<br><font color='gray'> -------------------------------- </font><br>%s", l_HintTextTop, l_HintTextBottom))
				elseif #l_HintTextTop ~= 0 then
					l_PlayerIter:SendMsg(MessageType.Center, l_HintTextTop)
				elseif #l_HintTextBottom ~= 0 then
					l_PlayerIter:SendMsg(MessageType.Center, l_HintTextBottom)
				end
				
				if l_PlayerIterTeam == Team.CT then
					local l_PlayerIterRespawn = l_PlayerIter:GetVar("deathrun.respawn")
					
					if l_PlayerIterAlive then
						l_AliveCTCount = l_AliveCTCount + 1
					end
					
					if l_PlayerIterRespawn then
						l_RespawnCTCount = l_RespawnCTCount + 1
					end
					
					l_CTCount = l_CTCount + 1
				end
			end
		end
	end
	
	if g_WarmupPeriodRespawn and l_RespawnCTCount == 0 then
		if l_CTCount ~= 0 and l_AliveCTCount == 0 then
			g_WarmupPeriodRespawn = false
			
			exports["helpers"]:TerminateRound(RoundEndReason_t.TerroristsWin, "deathrun")
		elseif not g_WarmupPeriod then
			g_WarmupPeriodRespawn = false
		end
	end
	
	if not g_ThinkFunctionTime or l_ServerTime >= g_ThinkFunctionTime + THINK_FUNCTION_INTERVAL then
		g_ThinkFunctionTime = l_ServerTime
	end
end