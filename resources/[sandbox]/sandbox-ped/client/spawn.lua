local cam = nil

AddEventHandler("Proxy:Shared:ExtendReady", function(component)
	if component == "Spawn" then
		exports["sandbox-base"]:ExtendComponent(component, SPAWN)
	end
end)

SPAWN = {
	SpawnToWorld = function(self, data, cb)
		DoScreenFadeOut(500)
		while not IsScreenFadedOut() do
			Wait(10)
		end
		Callbacks:ServerCallback("Ped:CheckPed", {}, function(hasPed)
			data.Ped = hasPed.ped
			if not hasPed.existed then
				cb()
				Ped.Creator:Start(data)
			else
				cb()
				Spawn:PlacePedIntoWorld(data)
			end
		end)
	end,
	PlacePedIntoWorld = function(self, data)
		DoScreenFadeOut(500)
		while not IsScreenFadedOut() do
			Wait(10)
		end

		local player = PlayerPedId()
		SetTimecycleModifier("default")

		local model = `mp_f_freemode_01`
		if tonumber(data.Gender) == 0 then
			model = `mp_m_freemode_01`
		end

		if data.Ped.model ~= "" then
			model = GetHashKey(data.Ped.model)
		end

		RequestModel(model)

		while not HasModelLoaded(model) do
			Wait(500)
		end
		SetPlayerModel(PlayerId(), model)

		if model == `sandbox_k9_shepherd` then
			LocalPlayer.state.isK9Ped = true
		else
			LocalPlayer.state.isK9Ped = false
		end
		LocalPlayer.state.ped = player
		SetPedDefaultComponentVariation(player)
		SetEntityAsMissionEntity(player, true, true)
		SetModelAsNoLongerNeeded(model)

		DestroyAllCams(true)
		RenderScriptCams(false, true, 1, true, true)

		NetworkSetEntityInvisibleToNetwork(player, false)
		SetEntityVisible(player, true)
		SetPlayerInvincible(player, false)

		cam = nil

		SetCanAttackFriendly(player, true, true)
		NetworkSetFriendlyFireOption(true)

		SetEntityHealth(PlayerPedId(), data.HP or 200)
		DisplayHud(true)
		SetNuiFocus(false, false)

		LocalPed = LocalPlayer.state.Character:GetData("Ped")
		Ped:ApplyToPed(LocalPed)
		if data.action ~= nil then
			FreezeEntityPosition(player, false)
			TriggerEvent(data.action, data.data)
		else
			SetEntityCoords(
				player,
				data.spawn.location.x + 0.0,
				data.spawn.location.y + 0.0,
				data.spawn.location.z + 0.0
			)

			Wait(200)
			SetEntityHeading(player, data.spawn.location.h)

			local time = GetGameTimer()
			while not HasCollisionLoadedAroundEntity(player) and (GetGameTimer() - time) < 10000 do
				Wait(100)
			end

			FreezeEntityPosition(player, false)

			DoScreenFadeIn(500)
		end

		SetTimeout(500, function()
			SetPedArmour(player, data.Armor)
		end)

		TriggerScreenblurFadeOut(500)
	end,
}
