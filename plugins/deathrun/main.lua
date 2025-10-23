g_Hook_FuncButton_OnPressed = AddHookEntityOutput("func_button", "OnPressed")
g_Hook_TriggerTeleport_OnStartTouch = AddHookEntityOutput("trigger_teleport", "OnStartTouch")

AddEventHandler("OnPluginStart", function(p_Event)
	local l_ServerTime = math.floor(server:GetCurrentTime() * 1000)
	
	g_PluginIsLoading = true
	g_PluginIsLoadingLate = l_ServerTime > 0
	
	Deathrun_ResetVars()
	Deathrun_LoadConfig()
end)

AddEventHandler("OnAllPluginsLoaded", function(p_Event)
	if g_PluginIsLoadingLate then
		server:Execute("mp_restartgame 3")
		
		for i = 0, playermanager:GetPlayerCap() - 1 do
			Deathrun_ResetPlayerVars(i)
		end
		
		Deathrun_SetConVars()
	end
	
	if g_PluginIsLoading then
		if not g_ThinkTimer then
			Deathrun_Think()
			g_ThinkTimer = SetTimer(THINK_INTERVAL, Deathrun_Think)
		end
	end
	
	g_PluginIsLoading = nil
	g_PluginIsLoadingLate = nil
end)

AddEventHandler("OnMapLoad", function(p_Event, p_Map)
	Deathrun_ResetVars()
	Deathrun_LoadConfig()
	
	if not g_PluginIsLoading then
		if not g_ThinkTimer then
			Deathrun_Think()
			g_ThinkTimer = SetTimer(THINK_INTERVAL, Deathrun_Think)
		end
	end
	
	SetTimeout(100, function()
		Deathrun_SetConVars()
	end)
end)

AddEventHandler("OnMapUnload", function(p_Event, p_Map)
	if g_ThinkTimer then
		StopTimer(g_ThinkTimer)
		g_ThinkTimer = nil
	end
end)

AddEventHandler("OnPostCsIntermission", function(p_Event)
	for i = 0, playermanager:GetPlayerCap() - 1 do
		local l_PlayerIter = GetPlayer(i)
		
		if l_PlayerIter and l_PlayerIter:IsValid() then
			l_PlayerIter:SendMsg(MessageType.Center, "")
		end
	end
end)

AddEventHandler("OnPostRoundPrestart", function(p_Event)
	Deathrun_SetBotQuota()
	
	if exports["helpers"]:IsWarmupPeriod() then
		return
	end
	
	g_RoundCount = g_RoundCount + 1
	
	for i = 0, playermanager:GetPlayerCap() - 1 do
		local l_PlayerIter = GetPlayer(i)
		
		if l_PlayerIter and l_PlayerIter:IsValid() then
			l_PlayerIter:SetVar("deathrun.respawn", nil)
			l_PlayerIter:SetVar("deathrun.warmup.count", nil)
		end
	end
	
	Deathrun_PrepareRound()
end)

AddEventHandler("OnPostRoundStart", function(p_Event)
	Deathrun_PrintMapTimeLeft()
end)

AddEventHandler("OnPostRoundEnd", function(p_Event)
	if g_RoundCount == 0 then
		return
	end
	
	g_WarmupPeriod = nil
	g_WarmupPeriodRespawn = nil
	
	local l_Reason = p_Event:GetInt("reason")
	
	if l_Reason == RoundEndReason_t.TerroristsWin then
		g_TeamTerroristScore = g_TeamTerroristScore + 1
	elseif l_Reason == RoundEndReason_t.CTsWin then
		g_TeamCTScore = g_TeamCTScore + 1
	end
	
	exports["helpers"]:SetTeamScore(Team.T, g_TeamTerroristScore)
	exports["helpers"]:SetTeamScore(Team.CT, g_TeamCTScore)
end)

AddEventHandler("OnPostRoundAnnounceWarmup", function(p_Event)
	g_RoundCount = 0
	
	g_TeamTerroristScore = 0
	g_TeamCTScore = 0
	
	for i = 0, playermanager:GetPlayerCap() - 1 do
		local l_PlayerIter = GetPlayer(i)
		
		if l_PlayerIter and l_PlayerIter:IsValid() then
			l_PlayerIter:SendMsg(MessageType.Center, "")
		end
	end
end)

AddEventHandler("OnPostRoundMvp", function(p_Event)
	local l_PlayerId = p_Event:GetInt("userid")
	
	exports["helpers"]:SetPlayerMVPs(l_PlayerId, 0)
end)

AddEventHandler("Helpers_OnTerminateRound", function(p_Event, p_Reason, p_Identifier)
	if p_Identifier == "deathrun" or p_Identifier == "map" then
		return EventResult.Continue
	end
	
	local l_TimeLeft = exports["helpers"]:GetRoundTimeLeft()
	
	if l_TimeLeft == 0 then
		p_Event:SetReturn(RoundEndReason_t.TerroristsWin)
		return EventResult.Continue
	end
	
	local l_PlayerCount = exports["helpers"]:GetPlayerCount(true)
	
	if l_PlayerCount == 0 then
		return EventResult.Continue
	end
	
	if g_RoundPreparePeriod then
		exports["helpers"]:SetTeamScore(Team.T, g_TeamTerroristScore)
		exports["helpers"]:SetTeamScore(Team.CT, g_TeamCTScore)
		
		return EventResult.Stop
	end
	
	local l_Reason = p_Event:GetReturn() or p_Reason
	
	if l_Reason == RoundEndReason_t.TerroristsWin then
		if g_WarmupPeriodRespawn then
			exports["helpers"]:SetTeamScore(Team.T, g_TeamTerroristScore)
			exports["helpers"]:SetTeamScore(Team.CT, g_TeamCTScore)
			
			return EventResult.Stop
		end
	end
	
	return EventResult.Continue
end)

AddEventHandler("OnEntitySpawned", function(p_Event, p_EntityPtr)
	local l_Entity = CBaseEntity(p_EntityPtr)
	
	if not l_Entity or not l_Entity:IsValid() then
		return
	end
	
	local l_EntityClassname = l_Entity:GetClassname()
	
	if l_EntityClassname == "chicken" 
		or l_EntityClassname == "func_bomb_target" 
		or l_EntityClassname == "func_hostage_rescue" 
		or l_EntityClassname == "point_servercommand" 
	then
		l_Entity:Despawn()
		return
	end
	
	if l_EntityClassname == "trigger_teleport" then
		Deathrun_HandleTeleportSpawn(p_EntityPtr)
	end
end)

AddEventHandler("OnEntityAcceptInput", function(p_Event, p_EntityPtr, p_InputName, p_ActivatorPtr, p_CallerPtr, p_Value, p_OutputID)
	local l_Entity = CBaseEntity(p_EntityPtr)
	
	if not l_Entity or not l_Entity:IsValid() then
		return EventResult.Continue
	end
	
	local l_EntityClassname = l_Entity:GetClassname()
	
	if l_EntityClassname == "trigger_teleport" then
		local l_HandleReturn = Deathrun_HandleTeleportInput(p_EntityPtr, string.lower(p_InputName))
		
		if l_HandleReturn == EventResult.Handled or l_HandleReturn == EventResult.Stop then
			p_Event:SetReturn(false)
			return EventResult.Handled
		end
	end
	
	return EventResult.Continue
end)

AddPostHookListener(g_Hook_FuncButton_OnPressed, function(p_Event, p_IOOutputPtr, p_OutputName, p_ActivatorPtr, p_CallerPtr, p_Delay)
	local l_Caller = CBaseEntity(p_CallerPtr)
	
	if not l_Caller or not l_Caller:IsValid() then
		return
	end
	
	local l_ActivatorPawn = CBasePlayerPawn(p_ActivatorPtr)
	
	if not l_ActivatorPawn 
		or not l_ActivatorPawn:IsValid() 
		or not l_ActivatorPawn.Controller 
		or not l_ActivatorPawn.Controller:IsValid() 
	then
		return
	end
	
	local l_PlayerId = l_ActivatorPawn.Controller:EntityIndex() - 1
	
	Deathrun_HandlePlayerButtonPress(l_PlayerId, p_CallerPtr)
end)

AddPostHookListener(g_Hook_TriggerTeleport_OnStartTouch, function(p_Event, p_IOOutputPtr, p_OutputName, p_ActivatorPtr, p_CallerPtr, p_Delay)
	local l_Caller = CBaseEntity(p_CallerPtr)
	
	if not l_Caller or not l_Caller:IsValid() then
		return
	end
	
	local l_CallerTrigger = CBaseTrigger(p_CallerPtr)
	
	if not l_CallerTrigger or not l_CallerTrigger:IsValid() then
		return
	end
	
	local l_ActivatorPawn = CBasePlayerPawn(p_ActivatorPtr)
	
	if not l_ActivatorPawn 
		or not l_ActivatorPawn:IsValid() 
		or not l_ActivatorPawn.Controller 
		or not l_ActivatorPawn.Controller:IsValid() 
	then
		return
	end
	
	local l_PlayerId = l_ActivatorPawn.Controller:EntityIndex() - 1
	
	Deathrun_HandlePlayerTeleportTouch(l_PlayerId, p_CallerPtr)
end)

AddEventHandler("OnClientKeyStateChange", function(p_Event, p_PlayerId, p_Key, p_Pressed)
	if not p_IsPressed or p_Key ~= "space" then
		return
	end
	
	Deathrun_RespawnPlayerOnRequest(p_PlayerId, true)
end)

AddEventHandler("OnPlayerDamage", function(p_Event, p_PlayerId, p_AttackerId, p_DamageInfoPtr, p_InflictorPtr, p_AbilityPtr)
	if exports["helpers"]:IsPlayerInSlayQueue(p_PlayerId) then
		return EventResult.Continue
	end
	
	local l_Player = GetPlayer(p_PlayerId)
	
	if not l_Player or not l_Player:IsValid() then
		return EventResult.Continue
	end
	
	if Deathrun_HasPlayerImmunity(p_PlayerId) then
		p_Event:SetReturn(false)
		return EventResult.Handled
	end
	
	if Deathrun_IsPlayerTerrorist(p_PlayerId) and Deathrun_IsFallDamage(p_DamageInfoPtr) then
		p_Event:SetReturn(false)
		return EventResult.Handled
	end
	
	local l_Attacker = GetPlayer(p_AttackerId)
	
	if not l_Attacker or not l_Attacker:IsValid() then
		return EventResult.Continue
	end
	
	if not Deathrun_IsPlayerTerroristKiller(p_PlayerId) and not Deathrun_IsPlayerTerroristKiller(p_AttackerId) then
		p_Event:SetReturn(false)
		return EventResult.Handled
	end
	
	local l_Ability = CBaseEntity(p_AbilityPtr)
	
	if not l_Ability or not l_Ability:IsValid() then
		return EventResult.Continue
	end
	
	if l_Ability.Parent.Entity.Name == "deathrun_item_spawn" then
		p_Event:SetReturn(false)
		return EventResult.Handled
	end
	
	return EventResult.Continue
end)

AddEventHandler("OnPostPlayerConnectFull", function(p_Event)
	local l_PlayerId = p_Event:GetInt("userid")
	
	Deathrun_LoadPlayerDisconnectionData(l_PlayerId)
end)

AddEventHandler("OnPlayerDisconnect", function(p_Event)
	local l_PlayerId = p_Event:GetInt("userid")
	
	Deathrun_SavePlayerDisconnectionData(l_PlayerId)
	
	Deathrun_ChooseTerroristKiller()
	Deathrun_CheckPlayerFinishCount()
end)

AddEventHandler("OnPostPlayerSpawn", function(p_Event)
	local l_PlayerId = p_Event:GetInt("userid")
	local l_Player = GetPlayer(l_PlayerId)
	
	if not l_Player or not l_Player:IsValid() then
		return
	end
	
	local l_ServerTime = math.floor(server:GetCurrentTime() * 1000)
	
	if g_RoundCount ~= 0 then
		l_Player:SetVar("deathrun.death.time", nil)
		l_Player:SetVar("deathrun.immunity.end", nil)
		l_Player:SetVar("deathrun.immunity.time", nil)
		l_Player:SetVar("deathrun.position", nil)
		l_Player:SetVar("deathrun.respawn", nil)
		l_Player:SetVar("deathrun.velocity", nil)
		l_Player:SetVar("deathrun.velocity.modifier", nil)
		
		l_Player:SendMsg(MessageType.Center, "")
		
		exports["helpers"]:SetPlayerEntityName(l_PlayerId, "deathrun_player")
		exports["helpers"]:SetPlayerRenderColor(l_PlayerId, RENDER_COLOR_DEFAULT)
	end
	
	SetTimeout(200, function()
		if not l_Player:IsValid() then
			return
		end
		
		local l_PlayerTeam = exports["helpers"]:GetPlayerTeam(l_PlayerId)
		
		if l_PlayerTeam == Team.T then
			Deathrun_HandlePlayerTerroristSpawn(l_PlayerId)
		end
		
		Deathrun_GivePlayerItems(l_PlayerId)
		Deathrun_SetPlayerCollision(l_PlayerId)
	end)
end)

AddEventHandler("OnPlayerDeath", function(p_Event)
	local l_PlayerId = p_Event:GetInt("userid")
	local l_Player = GetPlayer(l_PlayerId)
	
	if not l_Player or not l_Player:IsValid() then
		return EventResult.Continue
	end
	
	if exports["helpers"]:IsWarmupPeriod() then
		local l_PlayerTeam = exports["helpers"]:GetPlayerTeam(l_PlayerId)
		
		if l_PlayerTeam == Team.CT then
			p_Event:FireEventToClient(l_PlayerId)
			p_Event:SetReturn(false)
			
			return EventResult.Handled
		end
	end
	
	if Deathrun_CanPlayerRespawnInWarmup(l_PlayerId) then
		p_Event:FireEventToClient(l_PlayerId)
		p_Event:SetReturn(false)
		
		return EventResult.Handled
	end
	
	return EventResult.Continue
end)

AddEventHandler("OnPostPlayerDeath", function(p_Event)
	local l_PlayerId = p_Event:GetInt("userid")
	local l_Player = GetPlayer(l_PlayerId)
	
	if not l_Player or not l_Player:IsValid() then
		return
	end
	
	if g_RoundCount ~= 0 then
		if Deathrun_CanPlayerRespawnInWarmup(l_PlayerId) then
			local l_ServerTime = math.floor(server:GetCurrentTime() * 1000)
			local l_RespawnTime = exports["helpers"]:GetRespawnTime()
			
			l_Player:SetVar("deathrun.death.time", l_ServerTime)
			l_Player:SetVar("deathrun.respawn", {
				["time"] = l_ServerTime + l_RespawnTime,
				["type"] = RESPAWN_WARMUP
			})
		else
			l_Player:SetVar("deathrun.death.time", nil)
			l_Player:SetVar("deathrun.respawn", nil)
		end
		
		l_Player:SendMsg(MessageType.Center, "")
		
		exports["helpers"]:SetPlayerRenderColor(l_PlayerId, RENDER_COLOR_DEFAULT)
	end
	
	Deathrun_ChooseTerroristKiller()
	Deathrun_CheckPlayerFinishCount()
end)

AddEventHandler("OnPlayerTeam", function(p_Event)
	if p_Event:GetBool("disconnect") then
		return EventResult.Continue
	end
	
	local l_PlayerId = p_Event:GetInt("userid")
	local l_Player = GetPlayer(l_PlayerId)
	
	if not l_Player or not l_Player:IsValid() then
		return EventResult.Continue
	end
	
	if Deathrun_IsPlayerInSwitchQueue(l_PlayerId) then
		p_Event:SetReturn(false)
		return EventResult.Handled
	end
	
	return EventResult.Continue
end)

AddEventHandler("OnPostPlayerTeam", function(p_Event)
	if p_Event:GetBool("disconnect") then
		return
	end
	
	local l_PlayerId = p_Event:GetInt("userid")
	local l_Player = GetPlayer(l_PlayerId)
	
	if not l_Player or not l_Player:IsValid() then
		return
	end
	
	if g_RoundCount ~= 0 then
		local l_Team = p_Event:GetInt("team")
		
		l_Player:SetVar("deathrun.death.time", nil)
		
		if l_Team == Team.Spectator then
			l_Player:SetVar("deathrun.respawn", nil)
			l_Player:SetVar("deathrun.terrorist.queue", nil)
		else
			if Deathrun_CanPlayerRespawnInWarmup(l_PlayerId) then
				local l_ServerTime = math.floor(server:GetCurrentTime() * 1000)
				
				l_Player:SetVar("deathrun.respawn", {
					["time"] = l_ServerTime + 100,
					["type"] = RESPAWN_WARMUP
				})
			end
		end
		
		l_Player:SendMsg(MessageType.Center, "")
	end
	
	Deathrun_ChooseTerroristKiller()
	Deathrun_CheckPlayerFinishCount()
end)

AddEventHandler("OnPostPlayerShoot", function(p_Event)
	local l_PlayerId = p_Event:GetInt("userid")
	
	Deathrun_CancelPlayerImmunity(l_PlayerId)
end)

AddEventHandler("Team_OnPlayerJoinTeam", function(p_Event, p_PlayerId, p_Team, p_Force)
	if p_Team == Team.T then
		return EventResult.Handled
	end
	
	return EventResult.Continue
end)

AddEventHandler("Zones_OnPlayerStartTouch", function(p_Event, p_PlayerId, p_Name, p_Origin, p_Mins, p_Maxs)
	if g_RoundCount == 0 or p_Name ~= "deathrun_zone_end" then
		return
	end
	
	Deathrun_HandlePlayerFinish(p_PlayerId)
end)