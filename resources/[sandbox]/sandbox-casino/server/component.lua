_casinoConfig = {}

_casinoConfigLoaded = false

AddEventHandler("Casino:Shared:DependencyUpdate", RetrieveComponents)
function RetrieveComponents()
	Fetch = exports["sandbox-base"]:FetchComponent("Fetch")
	Utils = exports["sandbox-base"]:FetchComponent("Utils")
	Execute = exports["sandbox-base"]:FetchComponent("Execute")
	Database = exports["sandbox-base"]:FetchComponent("Database")
	Middleware = exports["sandbox-base"]:FetchComponent("Middleware")
	Callbacks = exports["sandbox-base"]:FetchComponent("Callbacks")
	Chat = exports["sandbox-base"]:FetchComponent("Chat")
	Logger = exports["sandbox-base"]:FetchComponent("Logger")
	Generator = exports["sandbox-base"]:FetchComponent("Generator")
	Phone = exports["sandbox-base"]:FetchComponent("Phone")
	Jobs = exports["sandbox-base"]:FetchComponent("Jobs")
	Vehicles = exports["sandbox-base"]:FetchComponent("Vehicles")
	Inventory = exports["sandbox-base"]:FetchComponent("Inventory")
	Wallet = exports["sandbox-base"]:FetchComponent("Wallet")
	Crafting = exports["sandbox-base"]:FetchComponent("Crafting")
	Banking = exports["sandbox-base"]:FetchComponent("Banking")
	Casino = exports["sandbox-base"]:FetchComponent("Casino")
	Loot = exports["sandbox-base"]:FetchComponent("Loot")
end

AddEventHandler("Core:Shared:Ready", function()
	exports["sandbox-base"]:RequestDependencies("Casino", {
		"Fetch",
		"Utils",
		"Execute",
		"Chat",
		"Database",
		"Middleware",
		"Callbacks",
		"Logger",
		"Generator",
		"Phone",
		"Jobs",
		"Vehicles",
		"Inventory",
		"Wallet",
		"Crafting",
		"Banking",
		"Casino",
		"Loot",
	}, function(error)
		if #error > 0 then
			exports["sandbox-base"]:FetchComponent("Logger"):Critical("Casino", "Failed To Load All Dependencies")
			return
		end
		RetrieveComponents()

		TriggerEvent("Casino:Server:Startup")

		if GetConvar("casino_open", "false") == "true" then
			GlobalState["CasinoOpen"] = true
		else
			GlobalState["CasinoOpen"] = false
		end

		Callbacks:RegisterServerCallback("Casino:OpenClose", function(source, data, cb)
			if Player(source).state.onDuty == "casino" and data.state ~= GlobalState["CasinoOpen"] then
				GlobalState["CasinoOpen"] = data.state

				if GlobalState["CasinoOpen"] then
					Execute:Client(source, "Notification", "Success", "Casino Opened")
				else
					Execute:Client(source, "Notification", "Error", "Casino Closed")
				end
			else
				Execute:Client(source, "Notification", "Error", "Error Opening/Closing Casino")
			end
		end)

		Callbacks:RegisterServerCallback("Casino:BuyChips", function(source, amount, cb)
			local char = Fetch:CharacterSource(source)
			if char and amount and amount > 0 then
				local amount = math.floor(amount)
				if Wallet:Modify(source, -amount) then
					local total = Casino.Chips:Modify(source, amount)
					if total then
						SendCasinoPhoneNotification(
							source,
							string.format("Purchased $%s in Chips", formatNumberToCurrency(amount)),
							string.format("You now have a chip balance of $%s", formatNumberToCurrency(total))
						)

						return cb(true)
					end
				end
			end

			cb(false)
		end)

		Callbacks:RegisterServerCallback("Casino:SellChips", function(source, amount, cb)
			local char = Fetch:CharacterSource(source)
			if char and amount and amount > 0 then
				local amount = math.floor(amount)
				local chipTotal = Casino.Chips:Modify(source, -amount)
				if chipTotal then
					if Wallet:Modify(source, amount) then
						SendCasinoPhoneNotification(
							source,
							string.format("Cashed Out $%s of Chips", formatNumberToCurrency(amount)),
							string.format("You now have a chip balance of $%s", formatNumberToCurrency(chipTotal))
						)

						return cb(true)
					end
				end
			end

			cb(false)
		end)

		Callbacks:RegisterServerCallback("Casino:PurchaseVIP", function(source, amount, cb)
			local char = Fetch:CharacterSource(source)
			if char then
				if Wallet:Modify(source, -10000) then
					Inventory:AddItem(char:GetData("SID"), "diamond_vip", 1, {}, 1)
					GiveCasinoMoney(source, "VIP Card", 10000)
				else
					Execute:Client(source, "Notification", "Error", "Not Enough Cash")
				end
			end

			cb(true)
		end)

		Callbacks:RegisterServerCallback("Casino:GetBigWins", function(source, data, cb)
			if Player(source).state.onDuty == "casino" then
				Database.Game:find({
					collection = "casino_bigwins",
					query = {},
				}, function(success, results)
					if success and #results > 0 then
						cb(results)
					else
						cb(false)
					end
				end)
			else
				cb(false)
			end
		end)

		Chat:RegisterCommand("chips", function(source, args, rawCommand)
			local chipTotal = Casino.Chips:Get(source)

			SendCasinoPhoneNotification(
				source,
				"Current Chip Balance",
				string.format("Your current balance is $%s", formatNumberToCurrency(chipTotal))
			)
		end, {
			help = "Show Casino Chip Balance",
		})

		RunConfigStartup()
	end)
end)

local _configStartup = false
function RunConfigStartup()
	if not _configStartup then
		_configStartup = true

		Database.Game:find({
			collection = "casino_config",
			query = {},
		}, function(success, results)
			if success and #results > 0 then
				for k, v in ipairs(results) do
					_casinoConfig[v.key] = v.data
				end
			end

			_casinoConfigLoaded = true
		end)
	end
end

_CASINO = {
	Chips = {
		Get = function(self, source)
			local char = Fetch:CharacterSource(source)
			if char then
				return char:GetData("CasinoChips") or 0
			end
			return 0
		end,
		Has = function(self, source, amount)
			local char = Fetch:CharacterSource(source)
			if char and amount > 0 then
				local currentChips = char:GetData("CasinoChips") or 0
				if currentChips >= amount then
					return true
				end
			end
			return false
		end,
		Modify = function(self, source, amount)
			local char = Fetch:CharacterSource(source)
			if char then
				local currentChips = char:GetData("CasinoChips") or 0
				local newChipBalance = math.floor(currentChips + amount)
				if newChipBalance >= 0 then
					char:SetData("CasinoChips", newChipBalance)
					return newChipBalance
				end
			end
			return false
		end,
	},
	Config = {
		Set = function(self, key, data)
			local p = promise.new()

			Database.Game:findOneAndUpdate({
				collection = "casino_config",
				query = {
					key = key,
				},
				update = {
					["$set"] = {
						data = data,
					},
				},
				options = {
					returnDocument = "after",
					upsert = true,
				},
			}, function(success, results)
				if success and results then
					_casinoConfig[key] = data
					p:resolve(true)
				else
					p:resolve(false)
				end

				_casinoConfigLoaded = true
			end)

			local res = Citizen.Await(p)
			return res
		end,
		Get = function(self, key)
			return _casinoConfig[key]
		end,
	},
}

AddEventHandler("Proxy:Shared:RegisterReady", function()
	exports["sandbox-base"]:RegisterComponent("Casino", _CASINO)
end)

function SendCasinoWonChipsPhoneNotification(source, amount)
	local chipTotal = Casino.Chips:Get(source)
	SendCasinoPhoneNotification(
		source,
		string.format("You Won $%s in Chips!", formatNumberToCurrency(amount)),
		string.format("Your balance is now $%s", formatNumberToCurrency(chipTotal))
	)
end

function SendCasinoSpentChipsPhoneNotification(source, amount)
	local chipTotal = Casino.Chips:Get(source)
	SendCasinoPhoneNotification(
		source,
		string.format("You Paid $%s in Chips!", formatNumberToCurrency(amount)),
		string.format("Your balance is now $%s", formatNumberToCurrency(chipTotal))
	)
end

function SendCasinoPhoneNotification(source, title, description, time)
	Phone.Notification:Add(source, title, description, os.time(), time or 7500, {
		color = "#18191e",
		label = "Casino",
		icon = "cards",
	}, {}, nil)
end

function GiveCasinoMoney(source, game, amount)
	local charInfo = "Unknown"
	local char = Fetch:CharacterSource(source)
	if char then
		charInfo = string.format("%s %s [%s]", char:GetData("First"), char:GetData("Last"), char:GetData("SID"))
	end

	local f = Banking.Accounts:GetOrganization("dgang")
	Banking.Balance:Deposit(f.Account, amount, {
		type = "deposit",
		title = game,
		description = string.format("%s Profit From %s", game, charInfo),
		data = {},
	}, true)

	if game == "Lucky Wheel" then
		amount = 100
		local f = Banking.Accounts:GetOrganization("casino")
		Banking.Balance:Deposit(f.Account, amount, {
			type = "deposit",
			title = game,
			description = string.format("%s Profit From %s", game, charInfo),
			data = {},
		}, true)
	end
end
