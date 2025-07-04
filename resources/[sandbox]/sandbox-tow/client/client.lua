AddEventHandler("Tow:Shared:DependencyUpdate", RetrieveComponents)
function RetrieveComponents()
	Logger = exports["sandbox-base"]:FetchComponent("Logger")
	Utils = exports["sandbox-base"]:FetchComponent("Utils")
	Keybinds = exports["sandbox-base"]:FetchComponent("Keybinds")
	Targeting = exports["sandbox-base"]:FetchComponent("Targeting")
	Jobs = exports["sandbox-base"]:FetchComponent("Jobs")
	Vehicles = exports["sandbox-base"]:FetchComponent("Vehicles")
	Notification = exports["sandbox-base"]:FetchComponent("Notification")
	Sounds = exports["sandbox-base"]:FetchComponent("Sounds")
	Callbacks = exports["sandbox-base"]:FetchComponent("Callbacks")
	Progress = exports["sandbox-base"]:FetchComponent("Progress")
	Polyzone = exports["sandbox-base"]:FetchComponent("Polyzone")
	PedInteraction = exports["sandbox-base"]:FetchComponent("PedInteraction")
	Tow = exports["sandbox-base"]:FetchComponent("Tow")
	Blips = exports["sandbox-base"]:FetchComponent("Blips")
	Phone = exports["sandbox-base"]:FetchComponent("Phone")
end

AddEventHandler("Core:Shared:Ready", function()
	exports["sandbox-base"]:RequestDependencies("Tow", {
		"Logger",
		"Utils",
		"Keybinds",
		"Targeting",
		"Jobs",
		"Vehicles",
		"Notification",
		"Callbacks",
		"Sounds",
		"Progress",
		"Polyzone",
		"PedInteraction",
		"Tow",
		"Blips",
		"Phone",
	}, function(error)
		if #error > 0 then
			return
		end
		RetrieveComponents()

		PedInteraction:Add("veh_tow_jerry", `a_m_m_eastsa_01`, vector3(-247.645, -1183.099, 22.090), 312.942, 50.0, {
			{
				icon = "truck-tow",
				text = "Request Tow Truck",
				event = "Tow:Client:RequestTruck",
				jobPerms = {
					{
						job = "tow",
						reqDuty = true,
					},
				},
				isEnabled = function()
					return not GlobalState[string.format("TowTrucks:%s", LocalPlayer.state.Character:GetData("SID"))]
				end,
			},
			{
				icon = "truck-tow",
				text = "Return Tow Truck",
				event = "Tow:Client:ReturnTruck",
				jobPerms = {
					{
						job = "tow",
						reqDuty = true,
					},
				},
				isEnabled = function()
					return GlobalState[string.format("TowTrucks:%s", LocalPlayer.state.Character:GetData("SID"))]
				end,
			},
		}, "truck-tow", "WORLD_HUMAN_HANG_OUT_STREET")

		Polyzone.Create:Box("tow_impound_zone", vector3(-236.96, -1173.44, 23.04), 19.4, 24.4, {
			heading = 270,
			minZ = 22.04,
			maxZ = 26.04,
		})
	end)
end)

_TOW = {
	IsTowTruck = function(self, entity)
		local model = GetEntityModel(entity)
		return _towTrucks[model]
	end,
}

AddEventHandler("Proxy:Shared:RegisterReady", function()
	exports["sandbox-base"]:RegisterComponent("Tow", _TOW)
end)

local _towingAction = false

AddEventHandler("Vehicles:Client:BeginTow", function(entityData)
	local truck = entityData.entity
	local truckState = Entity(truck).state
	local truckModel = GetEntityModel(truck)
	if not _towingAction and _towTrucks[truckModel] and truckState and not truckState.towingVehicle then
		local targetVehicle = GetVehicleBehindTowTruck(truck, 8.0)
		local canTow, errorMessage = CanTowVehicle(truck, targetVehicle)
		if canTow then
			Sounds.Play:Distance(5.0, "tow_truck.ogg", 0.2)
			Progress:ProgressWithStartAndTick({
				name = "tow_attaching",
				duration = 1 * 1000,
				label = "Starting Tow",
				canCancel = true,
				tickrate = 1000,
				ignoreModifier = true,
				controlDisables = {
					disableMovement = true,
					disableCarMovement = true,
					disableMouse = false,
					disableCombat = true,
				},
				animation = {
					animDict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@",
					anim = "machinic_loop_mechandplayer",
					flags = 49,
				},
			}, function()
				_towingAction = true
			end, function()
				local canTow, errorMessage = CanTowVehicle(truck, targetVehicle)
				if not canTow then
					Progress:Cancel()
					Notification:Error(errorMessage, 5000, "truck-tow")
				end
			end, function(wasCancelled)
				_towingAction = false
				if not wasCancelled then
					local success = AttachVehicleToTow(truck, targetVehicle, truckModel)
					if success then
						truckState:set("towingVehicle", VehToNet(success), true)
						Notification:Success("Vehicle Now on Tow Truck", 5000, "truck-tow")

						if Entity(success).state.towObjective then
							Blips:Remove("towjob-pickup")
							Phone.Notification:Update("TOW_OBJ", "Yard Manager", "Great, bring it back to the yard")
						end
					else
						truckState:set("towingVehicle", false, true)
						Notification:Error("Failed to Tow Vehicle", 5000, "truck-tow")
					end
				end
			end)
		else
			Notification:Error(errorMessage, 5000, "truck-tow")
		end
	end
end)

AddEventHandler("Vehicles:Client:ReleaseTow", function(entityData)
	local truck = entityData.entity
	local truckState = Entity(truck).state
	local truckModel = GetEntityModel(truck)
	if _towTrucks[truckModel] and truckState then
		if truckState.towingVehicle then
			local success = DetachVehicleFromTow(truck, NetToVeh(truckState.towingVehicle))
			if success then
				Notification:Success("Vehicle Released from Truck", 5000, "truck-tow")
				truckState:set("towingVehicle", false, true)
			end
		else
			Notification:Error("No Vehicle Being Towed", 5000, "truck-tow")
		end
	end
end)

RegisterNetEvent("Tow:Client:MarkPickup", function(coords, vehNet)
	Blips:Add("towjob-pickup", "Vehicle Pickup", coords, 326, 65, 0.8, 2, false, true)
	SetEntityAsMissionEntity(NetToVeh(vehNet))
end)

RegisterNetEvent("Tow:Client:CleanupPickup", function()
	Blips:Remove("towjob-pickup")
end)

function AttachVehicleToTow(towTruck, targetVeh, truckModel)
	local boneIndex = "bodyshell"
	if truckModel == `trailersmall` then
		boneIndex = "chassis"
	end

	local attachOffset = GetVehicleAttachOffset(GetEntityModel(towTruck), targetVeh)

	local towTruckControl = RequestControlWithTimeout(towTruck, 1500)
	local targetVehControl = RequestControlWithTimeout(targetVeh, 1500)

	if attachOffset and towTruckControl and targetVehControl then
		AttachEntityToEntity(
			targetVeh,
			towTruck,
			GetEntityBoneIndexByName(towTruck, boneIndex),
			attachOffset.x,
			attachOffset.y,
			attachOffset.z,
			0,
			0,
			0,
			1,
			1,
			0,
			1,
			0,
			1
		)
		--SetCanClimbOnEntity(targetVeh, false)
		return targetVeh
	end
	return false
end

function DetachVehicleFromTow(towTruck, towedVehicle)
	if towedVehicle and DoesEntityExist(towedVehicle) then
		local towTruckControl = RequestControlWithTimeout(towTruck, 1500)
		local towedVehControl = RequestControlWithTimeout(towedVehicle, 1500)

		if towTruckControl and towedVehControl and IsEntityAttachedToEntity(towTruck, towedVehicle) then
			local releaseCoords = GetOffsetFromEntityInWorldCoords(towTruck, 0.0, -10.0, 0.0)
			DetachEntity(towedVehicle, true)
			Wait(150)
			SetEntityCoords(towedVehicle, releaseCoords)
			Wait(50)
			SetVehicleOnGroundProperly(towedVehicle)

			if Entity(towedVehicle).state.towObjective then
				SetVehicleDoorsLockedForAllPlayers(veh, true)
			end

			return true
		end
	end
	return false
end
