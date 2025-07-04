characterLoaded = false
_withinShowroom = false
_withinCatalog = false

_justBoughtBike = {}
-- DEALERSHIPS = {}

AddEventHandler("Dealerships:Shared:DependencyUpdate", RetrieveComponents)
function RetrieveComponents()
	Logger = exports["sandbox-base"]:FetchComponent("Logger")
	Utils = exports["sandbox-base"]:FetchComponent("Utils")
	Game = exports["sandbox-base"]:FetchComponent("Game")
	Callbacks = exports["sandbox-base"]:FetchComponent("Callbacks")
	Targeting = exports["sandbox-base"]:FetchComponent("Targeting")
	Jobs = exports["sandbox-base"]:FetchComponent("Jobs")
	Fetch = exports["sandbox-base"]:FetchComponent("Fetch")
	Blips = exports["sandbox-base"]:FetchComponent("Blips")
	Polyzone = exports["sandbox-base"]:FetchComponent("Polyzone")
	Action = exports["sandbox-base"]:FetchComponent("Action")
	Menu = exports["sandbox-base"]:FetchComponent("Menu")
	Hud = exports["sandbox-base"]:FetchComponent("Hud")
	Vehicles = exports["sandbox-base"]:FetchComponent("Vehicles")
	ListMenu = exports["sandbox-base"]:FetchComponent("ListMenu")
	PedInteraction = exports["sandbox-base"]:FetchComponent("PedInteraction")
	Notification = exports["sandbox-base"]:FetchComponent("Notification")
	Input = exports["sandbox-base"]:FetchComponent("Input")
	Confirm = exports["sandbox-base"]:FetchComponent("Confirm")
	--Dealerships = exports['sandbox-base']:FetchComponent('Dealerships')
end

AddEventHandler("Core:Shared:Ready", function()
	exports["sandbox-base"]:RequestDependencies("Dealerships", {
		"Logger",
		"Utils",
		"Game",
		"Callbacks",
		"Targeting",
		"Jobs",
		"Fetch",
		"Polyzone",
		"Blips",
		"Action",
		"Menu",
		"Hud",
		"Vehicles",
		"ListMenu",
		"PedInteraction",
		"Notification",
		"Input",
		"Confirm",
		--'Dealerships',
	}, function(error)
		if #error > 0 then
			return
		end
		RetrieveComponents()
		CreateDealerships()

		CreateRentalSpots()
		CreateBikeStands()
		CreateGovermentFleetShops()

		CreateDonorDealerships()
	end)
end)

RegisterNetEvent("Characters:Client:Spawn")
AddEventHandler("Characters:Client:Spawn", function()
	characterLoaded = true

	CreateDealershipBlips()
	CreateRentalSpotsBlips()
	CreateBikeStandBlips()
end)

RegisterNetEvent("Characters:Client:Logout")
AddEventHandler("Characters:Client:Logout", function()
	characterLoaded = false

	_justBoughtBike = {}
end)

-- AddEventHandler('Proxy:Shared:RegisterReady', function()
--     exports['sandbox-base']:RegisterComponent('Dealerships', DEALERSHIPS)
-- end)

function CreatePolyzone(id, zone, data)
	if zone.type == "poly" then
		Polyzone.Create:Poly("dealerships_" .. id, zone.points, zone.options, data)
	elseif zone.type == "box" then
		Polyzone.Create:Box("dealerships_" .. id, zone.center, zone.length, zone.width, zone.options, data)
	elseif zone.type == "circle" then
		Polyzone.Create:Circle("dealerships_" .. id, zone.center, zone.radius, zone.options, data)
	end
end

function CreateDealerships()
	for dealerId, data in pairs(_dealerships) do
		-- Polyzones
		if data.zones then
			if data.zones.dealership then
				CreatePolyzone(dealerId .. "_main", data.zones.dealership, {
					dealer = true,
					dealerId = dealerId,
					type = "main",
				})
			end

			if #data.zones.catalog > 0 then
				for k, v in ipairs(data.zones.catalog) do
					CreatePolyzone((dealerId .. "_catalog_" .. k), v, {
						dealer = true,
						dealerId = dealerId,
						type = "catalog",
					})
				end
			end

			if data.zones.buyback then
				CreatePolyzone(dealerId .. "_buyback", data.zones.buyback, {
					dealer = true,
					dealerId = dealerId,
					type = "buyback",
					dealerBuyback = true,
				})
			end
		end

		-- Targets
		if data.zones and #data.zones.employeeInteracts > 0 then
			for k, v in ipairs(data.zones.employeeInteracts) do
				Targeting.Zones:AddBox(
					string.format("dealership_%s_employee_%s", dealerId, k),
					"car-building",
					v.center,
					v.length,
					v.width,
					v.options,
					{
						{
							icon = "car-garage",
							text = "Edit Showroom",
							event = "Dealerships:Client:ShowroomManagement",
							data = { dealerId = dealerId },
							jobPerms = {
								{
									job = dealerId,
									reqDuty = true,
									permissionKey = "dealership_showroom",
								},
							},
						},
						-- {
						--     icon = 'magnifying-glass-dollar',
						--     text = 'Run Credit Check',
						--     event = 'Dealerships:Client:StartRunningCredit',
						--     data = { dealerId = dealerId },
						--     jobPerms = {
						--         {
						--             job = dealerId,
						--             reqDuty = true,
						--             permissionKey = 'dealership_sell',
						--         }
						--     },
						-- },
						-- {
						--     icon = 'file-invoice-dollar',
						--     text = 'Sell Vehicle',
						--     event = 'Dealerships:Client:OpenSales',
						--     data = { dealerId = dealerId },
						--     jobPerms = {
						--         {
						--             job = dealerId,
						--             reqDuty = true,
						--             permissionKey = 'dealership_sell',
						--         }
						--     },
						-- },
						-- {
						--     icon = 'memo-pad',
						--     text = 'View Stock',
						--     event = 'Dealerships:Client:StockViewing',
						--     data = { dealerId = dealerId },
						--     jobPerms = {
						--         {
						--             job = dealerId,
						--             reqDuty = true,
						--             permissionKey = 'dealership_stock',
						--         }
						--     },
						-- },
						-- {
						--     icon = 'pen-to-square',
						--     text = 'Dealer Management',
						--     event = 'Dealerships:Client:StartManagement',
						--     data = { dealerId = dealerId },
						--     jobPerms = {
						--         {
						--             job = dealerId,
						--             reqDuty = true,
						--             permissionKey = 'dealership_manage',
						--         }
						--     },
						-- },
						{
							icon = "briefcase-clock",
							text = "Go On Duty",
							event = "Dealerships:Client:ToggleDuty",
							data = { dealerId = dealerId, state = true },
							jobPerms = {
								{
									job = dealerId,
									reqOffDuty = true,
								},
							},
						},
						{
							icon = "briefcase-clock",
							text = "Go Off Duty",
							event = "Dealerships:Client:ToggleDuty",
							data = { dealerId = dealerId, state = false },
							jobPerms = {
								{
									job = dealerId,
									reqDuty = true,
								},
							},
						},
						-- {
						-- 	icon = "tablet-screen",
						-- 	text = "Open Tablet",
						-- 	event = "MDT:Client:Toggle",
						-- 	data = {},
						-- 	jobPerms = {
						-- 		{
						-- 			job = dealerId,
						-- 			reqDuty = true,
						-- 		},
						-- 	},
						-- },
					},
					3.5
				)
			end
		end
	end
end

function CreateDealershipBlips()
	for dealerId, data in pairs(_dealerships) do
		if data.blip then
			Blips:Add(
				"dealership_" .. dealerId,
				data.name,
				data.blip.coords,
				data.blip.sprite,
				data.blip.colour,
				data.blip.scale
			)
		end
	end
end

AddEventHandler("Polyzone:Enter", function(id, point, insideZones, data)
	if characterLoaded and data and data.dealer and data.dealerId and data.type then
		if data.type == "main" then
			_withinShowroom = data.dealerId
			SpawnShowroom(data.dealerId)
		elseif data.type == "catalog" and _dealerships[data.dealerId] then
			_withinCatalog = data.dealerId
			Action:Show(
				"pdm",
				"{keybind}primary_action{/keybind} View " .. _dealerships[data.dealerId].abbreviation .. " Catalog"
			)
		end
	end
end)

AddEventHandler("Polyzone:Exit", function(id, point, insideZones, data)
	if data and data.dealer and data.dealerId and data.type then
		if data.type == "main" then
			DeleteShowroom(data.dealerId)
			_withinShowroom = false
		elseif data.type == "catalog" then
			Action:Hide("pdm")
			_withinCatalog = false
			ForceCloseCatalog()
		end
	end
end)

AddEventHandler("Keybinds:Client:KeyUp:primary_action", function()
	if _withinCatalog then
		Action:Hide("pdm")
		OpenCatalog(_withinCatalog)
	end
end)

AddEventHandler("Dealerships:Client:ToggleDuty", function(entityData, data)
	if data and data.dealerId then
		if data.state then
			Jobs.Duty:On(data.dealerId)
		else
			Jobs.Duty:Off(data.dealerId)
		end
	end
end)
