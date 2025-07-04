dIds = 1
dropzones = {}
local closerDrops = {}
local closerDropsIds = {}

function runDropsUpdate(checkRemovals)
	if LocalPlayer.state.myPos ~= nil then
		closerDrops = {}
		closerDropsIds = {}
		if #dropzones > 0 then
			for k, v in ipairs(dropzones) do
				local distance = #(LocalPlayer.state.myPos - vector3(v.coords.x, v.coords.y, v.coords.z))
				if distance <= 25.0 then
					if not closerDrops[k] then
						table.insert(
							closerDrops,
							{ coords = vector3(v.coords.x, v.coords.y, v.coords.z + 0.2), route = v.route }
						)
						closerDropsIds[k] = #closerDrops
					end
				elseif closerDropsIds[k] then
					table.remove(closerDrops, closerDropsIds[k])
					closerDropsIds[k] = nil
				end
			end
		end
	end
end

function startDropsTick()
	CreateThread(function()
		while LocalPlayer.state.loggedIn do
			runDropsUpdate()
			Wait(1000)
		end
	end)

	CreateThread(function()
		while LocalPlayer.state.loggedIn do
			if #closerDrops > 0 then
				for k, v in ipairs(closerDrops) do
					if v.route == LocalPlayer.state.currentRoute then
						DrawMarker(
							2,
							v.coords,
							0,
							0,
							0,
							0,
							0,
							0,
							0.25,
							0.25,
							0.25,
							255,
							255,
							255,
							200,
							false,
							false,
							2,
							false,
							false,
							false,
							false
						)
					end
				end
			else
				Wait(800)
			end
			Wait(3)
		end
	end)
end

RegisterNetEvent("Inventory:Client:DropzoneForceUpdate", function(dzs)
	dropzones = dzs
end)

RegisterNetEvent("Inventory:Client:AddDropzone", function(data)
	table.insert(dropzones, data)
end)

RegisterNetEvent("Inventory:Client:RemoveDropzone", function(id)
	for k, v in ipairs(dropzones) do
		if v.id == id then
			table.remove(dropzones, k)
			break
		end
	end
end)