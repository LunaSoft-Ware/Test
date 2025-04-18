local flySettings = {
	fly = false,
	flyspeed = 50
}
local Player = game.Players.LocalPlayer
local player = game.Players.LocalPlayer
local character, humanoid, bv, bav, cam
local flying = false

local buttons = {
	W = false,
	A = false,
	S = false,
	D = false,
	Moving = false
}

local function startFly()
	if not player.Character or not player.Character:FindFirstChild("Head") or flying then return end

	character = player.Character
	humanoid = character:FindFirstChildOfClass("Humanoid")
	humanoid.PlatformStand = true

	cam = workspace:WaitForChild("Camera")

	-- BodyVelocity & BodyAngularVelocity 追加
	bv = Instance.new("BodyVelocity")
	bv.Velocity = Vector3.new(0, 0, 0)
	bv.MaxForce = Vector3.new(10000, 10000, 10000)
	bv.P = 1000
	bv.Parent = character.Head

	bav = Instance.new("BodyAngularVelocity")
	bav.AngularVelocity = Vector3.new(0, 0, 0)
	bav.MaxTorque = Vector3.new(10000, 10000, 10000)
	bav.P = 1000
	bav.Parent = character.Head

	flying = true

	humanoid.Died:Connect(function()
		flying = false
	end)
end

local function endFly()
	if not player.Character or not flying then return end
	humanoid.PlatformStand = false
	if bv then bv:Destroy() end
	if bav then bav:Destroy() end
	flying = false
end

local UserInputService = game:GetService("UserInputService")

UserInputService.InputBegan:Connect(function(input, GPE)
	if GPE then return end
	for key, _ in pairs(buttons) do
		if key ~= "Moving" and input.KeyCode == Enum.KeyCode[key] then
			buttons[key] = true
			buttons.Moving = true
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, GPE)
	if GPE then return end
	local stillMoving = false
	for key, _ in pairs(buttons) do
		if key ~= "Moving" then
			if input.KeyCode == Enum.KeyCode[key] then
				buttons[key] = false
			end
			if buttons[key] then
				stillMoving = true
			end
		end
	end
	buttons.Moving = stillMoving
end)

local function setVec(vec)
	return vec * (flySettings.flyspeed / vec.Magnitude)
end

game:GetService("RunService").Heartbeat:Connect(function(step)
	if flying and character and character.PrimaryPart then
		local pos = character.PrimaryPart.Position
		local cf = cam.CFrame
		local ax, ay, az = cf:ToEulerAnglesXYZ()

		character:SetPrimaryPartCFrame(CFrame.new(pos) * CFrame.Angles(ax, ay, az))

		if buttons.Moving then
			local moveVec = Vector3.new()
			if buttons.W then moveVec = moveVec + setVec(cf.LookVector) end
			if buttons.S then moveVec = moveVec - setVec(cf.LookVector) end
			if buttons.A then moveVec = moveVec - setVec(cf.RightVector) end
			if buttons.D then moveVec = moveVec + setVec(cf.RightVector) end

			character:TranslateBy(moveVec * step)
		end
	end
end)

local hitboxEnabled = false
local noCollisionEnabled = false
local hitbox_original_properties = {}
local hitboxSize = 21
local hitboxTransparency = 6
local teamCheck = "FFA" 

local defaultBodyParts = {
	"UpperTorso",
	"Head",
	"HumanoidRootPart"
}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ScreenGui = Instance.new("ScreenGui", LocalPlayer.PlayerGui)
local WarningText = Instance.new("TextLabel", ScreenGui)
-- useless
WarningText.Size = UDim2.new(0, 200, 0, 50)
WarningText.TextSize = 16
WarningText.Position = UDim2.new(0.5, -150, 0, 0)
WarningText.Text = "" -- made it into empty string, you can add whatever
WarningText.TextColor3 = Color3.new(1, 0, 0)
WarningText.BackgroundTransparency = 1
WarningText.Visible = false

-- -------------------------------------
-- Utility Functions
-- -------------------------------------
local function savedPart(player, part)
	if not hitbox_original_properties[player] then
		hitbox_original_properties[player] = {}
	end
	if not hitbox_original_properties[player][part.Name] then
		hitbox_original_properties[player][part.Name] = {
			CanCollide = part.CanCollide,
			Transparency = part.Transparency,
			Size = part.Size
		}
	end
end

local function restoredPart(player)
	if hitbox_original_properties[player] then
		for partName, properties in pairs(hitbox_original_properties[player]) do
			local part = player.Character and player.Character:FindFirstChild(partName)
			if part and part:IsA("BasePart") then
				part.CanCollide = properties.CanCollide
				part.Transparency = properties.Transparency
				part.Size = properties.Size
			end
		end
	end
end

local function findClosestPart(player, partName)
	if not player.Character then return nil end
	local characterParts = player.Character:GetChildren()
	for _, part in ipairs(characterParts) do
		if part:IsA("BasePart") and part.Name:lower():match(partName:lower()) then
			return part
		end
	end
	return nil
end

-- -------------------------------------
-- Hitbox Functions
-- -------------------------------------
local function extendHitbox(player)
	for _, partName in ipairs(defaultBodyParts) do
		local part = player.Character and (player.Character:FindFirstChild(partName) or findClosestPart(player, partName))
		if part and part:IsA("BasePart") then
			savedPart(player, part)
			part.CanCollide = not noCollisionEnabled
			part.Transparency = hitboxTransparency / 10
			part.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
		end
	end
end

local function isEnemy(player)
	if teamCheck == "FFA" or teamCheck == "Everyone" then
		return true
	end
	local localPlayerTeam = LocalPlayer.Team
	return player.Team ~= localPlayerTeam
end

local function shouldExtendHitbox(player)
	return isEnemy(player)
end

local function updateHitboxes()
	for _, v in ipairs(Players:GetPlayers()) do
		if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
			if shouldExtendHitbox(v) then
				extendHitbox(v)
			else
				restoredPart(v)
			end
		end
	end
end

-- -------------------------------------
-- Event Handlers
-- -------------------------------------
local function onCharacterAdded(character)
	task.wait(0.1)
	if hitboxEnabled then
		updateHitboxes()
	end
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(onCharacterAdded)
	player.CharacterRemoving:Connect(function()
		restoredPart(player)
		hitbox_original_properties[player] = nil
	end)
end

local function checkForDeadPlayers()
	for player, properties in pairs(hitbox_original_properties) do
		if not player.Parent or not player.Character or not player.Character:IsDescendantOf(game) then
			restoredPart(player)
			hitbox_original_properties[player] = nil
		end
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

local Links = {
	Discord = "mesini"
}

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
	Title = "Elysium Destroyer",
	SubTitle = "Arsenal",
	TabWidth = 160,
	Size = UDim2.fromOffset(580, 460),
	Acrylic = true,
	Theme = "Dark",
	MinimizeKey = Enum.KeyCode.LeftControl 
})

Fluent:Notify({
	Title = "Elysium Destroyer Hub",
	Content = "Version 2",
	SubContent = "Made by Elysium", 
	Duration = 5 
})

--[[
local Welcome = Window:NewTab("Main")
local Gun = Window:NewTab("Gun Modded")
local Player = Window:NewTab("Player")
local Skins = Window:NewTab("Color Skins")
local Extra = Window:NewTab("Extra")
local Visual = Window:NewTab("Visuals")
local Setting = Window:NewTab("Setting")
local Credit = Window:NewTab("Credits")
]]

local Tabs = {
	Home = Window:AddTab({ Title = "Home", Icon = "home" }),
	Main = Window:AddTab({ Title = "Main", Icon = "rbxassetid://10734887784" }),
	Gun = Window:AddTab({ Title = "Gun Modded", Icon = "rbxassetid://10723395896" }),
	Player = Window:AddTab({ Title = "Player", Icon = "user" }),
	Skins = Window:AddTab({ Title = "Skins", Icon = "rbxassetid://10734919503" }),
	Extra = Window:AddTab({ Title = "Extra", Icon = "rbxassetid://10723346684" }),
	Visual = Window:AddTab({ Title = "Visuals", Icon = "eye" }),
	Setting = Window:AddTab({ Title = "Settings", Icon = "rbxassetid://10734950309" }),
}

local Section = Tabs.Home:AddSection("Welcome")

Tabs.Home:AddParagraph({
	Title = "Welcome to Elysium Destroyer Hub",
	Content = "Welcome "..Player.DisplayName.." !"
})

local Section = Tabs.Home:AddSection("Discord")

Tabs.Home:AddParagraph({
	Title = "Discord",
	Content = "Click button for Copy link"
})

Tabs.Home:AddButton({
	Title = "Copy",
	Description = "Copy Discord link",
	Callback = function()
		setclipboard(Links.Discord)
	end
})

local NotifyLoopEnabled = false

local Section = Tabs.Home:AddSection("System")

local Toggle = Tabs.Home:AddToggle("CountNotify", 
	{
		Title = "Countdown Notify", 
		Description = "Time ( 3minutes )",
		Default = false,
		Callback = function(Value)
			NotifyLoopEnabled = Value
			if Value then
				task.spawn(function()
					while NotifyLoopEnabled do
						Fluent:Notify({
							Title = "System",
							Content = "Three minutes have passed!",
							SubContent = "Script by Elysium",
							Duration = 5 
						})
						for i = 1, 180 do 
							if not NotifyLoopEnabled then
								break
							end
							task.wait(1)
						end
					end
				end)
			end
		end 
	})

local Section = Tabs.Main:AddSection("Hitbox")

local Toggle = Tabs.Main:AddToggle("HitboxEna", 
	{
		Title = "Hitbox", 
		Description = "Enable Hitbox",
		Default = false,
		Callback = function(enabled)
			hitboxEnabled = enabled
			if not enabled then
				for _, player in ipairs(Players:GetPlayers()) do
					restoredPart(player)
				end
				hitbox_original_properties = {}
			else
				updateHitboxes()
			end
		end 
	})

local Slider = Tabs.Main:AddSlider("Slider", {
	Title = "Hitbox Size",
	Description = "Change Hitbox Size",
	Default = 2,
	Min = 1,
	Max = 25,
	Rounding = 1,
	Callback = function(value)
		hitboxSize = value
		if hitboxEnabled then
			updateHitboxes()
		end
	end
})

local Slider = Tabs.Main:AddSlider("Slider", {
	Title = "Hitbox Transparency",
	Description = "Change Hitbox Transparency",
	Default = 2,
	Min = 1,
	Max = 10,
	Rounding = 1,
	Callback = function(value)
		hitboxTransparency = value
		if hitboxEnabled then
			updateHitboxes()
		end
	end
})

local Dropdown = Tabs.Main:AddDropdown("Dropdown", {
	Title = "Team Check",
	Values = {"FFA", "Team-Based", "Everyone"},
	Multi = false,
	Default = 1,
	Callback = function(Value)
		teamCheck = Value
		if hitboxEnabled then
			updateHitboxes()
		end
	end
})

local Section = Tabs.Main:AddSection("Triggerbot")

getgenv().triggerb = false
local teamcheck = "Team-Based"
local delay = 0.2
local isAlive = true

local Toggle = Tabs.Main:AddToggle("Trigrbot", 
	{
		Title = "Enable Triggerbot", 
		Description = "Enable Triggerbot",
		Default = false,
		Callback = function(state)
			getgenv().triggerb = state
		end 
	})

local Dropdown = Tabs.Main:AddDropdown("Dropdown", {
	Title = "Team Check Mode",
	Values = {"FFA", "Team-Based", "Everyone"},
	Multi = false,
	Default = 1,
	Callback = function(Value)
		teamcheck = Value
	end
})

local Slider = Tabs.Main:AddSlider("Slider", {
	Title = "Shot Delay",
	Description = "delay between shots (1-10)",
	Default = 2,
	Min = 1,
	Max = 10,
	Rounding = 1,
	Callback = function(value)
		delay = value / 10
	end
})

local function isEnemy(targetPlayer)
	if teamcheck == "FFA" then
		return true
	elseif teamcheck == "Everyone" then
		return targetPlayer ~= game.Players.LocalPlayer
	elseif teamcheck == "Team-Based" then
		local localPlayerTeam = game.Players.LocalPlayer.Team
		return targetPlayer.Team ~= localPlayerTeam
	end
	return false
end

local function checkhealth()
	local player = game.Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.HealthChanged:Connect(function(health)
			isAlive = health > 0
		end)
	end
end

game.Players.LocalPlayer.CharacterAdded:Connect(checkhealth)
checkhealth()

game:GetService("RunService").RenderStepped:Connect(function()
	if getgenv().triggerb and isAlive then
		local player = game.Players.LocalPlayer
		local mouse = player:GetMouse()
		local target = mouse.Target
		if target and target.Parent:FindFirstChild("Humanoid") and target.Parent.Name ~= player.Name then
			local targetPlayer = game:GetService("Players"):FindFirstChild(target.Parent.Name)
			if targetPlayer and isEnemy(targetPlayer) then
				mouse1press()
				wait(delay)
				mouse1release()
			end
		end
	end
end)

local Section = Tabs.Gun:AddSection("Infinite Ammo")

local Toggle = Tabs.Gun:AddToggle("InfAmoone", 
	{
		Title = "Infinite Ammo v1", 
		Description = "Enable Infinite Ammo v1",
		Default = false,
		Callback = function(Value)
			game:GetService("ReplicatedStorage").wkspc.CurrentCurse.Value = Value and "Infinite Ammo" or ""
		end 
	})

local SettingsInfinite = false

local Toggle = Tabs.Gun:AddToggle("Infamotwo", 
	{
		Title = "Infinite Ammo v2", 
		Description = "Enable Infinite Ammo v2",
		Default = false,
		Callback = function(Value)
			SettingsInfinite = Value
			if SettingsInfinite then
				game:GetService("RunService").Stepped:connect(function()
					pcall(function()
						if SettingsInfinite then
							local playerGui = game:GetService("Players").LocalPlayer.PlayerGui
							playerGui.GUI.Client.Variables.ammocount.Value = 99
							playerGui.GUI.Client.Variables.ammocount2.Value = 99
						end
					end)
				end)
			end 
		end
	})

local originalValues = {
	FireRate = {},
	ReloadTime = {},
	EReloadTime = {},
	Auto = {},
	Spread = {},
	Recoil = {}
}

local Section = Tabs.Gun:AddSection("Gun Modded")

local Toggle = Tabs.Gun:AddToggle("FastReload", 
	{
		Title = "Fast Reload", 
		Description = "Enable Fast Reload",
		Default = false,
		Callback = function(Value)
			for _, v in pairs(game.ReplicatedStorage.Weapons:GetChildren()) do
				if v:FindFirstChild("ReloadTime") then
					if Value then
						if not originalValues.ReloadTime[v] then
							originalValues.ReloadTime[v] = v.ReloadTime.Value
						end
						v.ReloadTime.Value = 0.01
					else
						if originalValues.ReloadTime[v] then
							v.ReloadTime.Value = originalValues.ReloadTime[v]
						else
							v.ReloadTime.Value = 0.8 
						end
					end
				end
				if v:FindFirstChild("EReloadTime") then
					if Value then
						if not originalValues.EReloadTime[v] then
							originalValues.EReloadTime[v] = v.EReloadTime.Value
						end
						v.EReloadTime.Value = 0.01
					else
						if originalValues.EReloadTime[v] then
							v.EReloadTime.Value = originalValues.EReloadTime[v]
						else
							v.EReloadTime.Value = 0.8 
						end
					end
				end
			end
		end
	})

local Toggle = Tabs.Gun:AddToggle("FastFire", 
	{
		Title = "Fast Fire Rate", 
		Description = "Enable Fast Fire Rate",
		Default = false,
		Callback = function(state)
			for _, v in pairs(game.ReplicatedStorage.Weapons:GetDescendants()) do
				if v.Name == "FireRate" or v.Name == "BFireRate" then
					if state then
						if not originalValues.FireRate[v] then
							originalValues.FireRate[v] = v.Value
						end
						v.Value = 0.02
					else
						if originalValues.FireRate[v] then
							v.Value = originalValues.FireRate[v]
						else
							v.Value = 0.8 
						end
					end
				end
			end
		end
	})

local Toggle = Tabs.Gun:AddToggle("AlwaysAuto", 
	{
		Title = "Always Auto", 
		Description = "Enable Always Auto",
		Default = false,
		Callback = function(state)
			for _, v in pairs(game.ReplicatedStorage.Weapons:GetDescendants()) do
				if v.Name == "Auto" or v.Name == "AutoFire" or v.Name == "Automatic" or v.Name == "AutoShoot" or v.Name == "AutoGun" then
					if state then
						if not originalValues.Auto[v] then
							originalValues.Auto[v] = v.Value
						end
						v.Value = true
					else
						if originalValues.Auto[v] then
							v.Value = originalValues.Auto[v]
						else
							v.Value = false 
						end
					end
				end
			end
		end
	})

local Toggle = Tabs.Gun:AddToggle("Nospra", 
	{
		Title = "No Spread", 
		Description = "Enable No Spread",
		Default = false,
		Callback = function(state)
			for _, v in pairs(game:GetService("ReplicatedStorage").Weapons:GetDescendants()) do
				if v.Name == "MaxSpread" or v.Name == "Spread" or v.Name == "SpreadControl" then
					if state then
						if not originalValues.Spread[v] then
							originalValues.Spread[v] = v.Value
						end
						v.Value = 0
					else
						if originalValues.Spread[v] then
							v.Value = originalValues.Spread[v]
						else
							v.Value = 1 
						end
					end
				end
			end
		end
	})

local Toggle = Tabs.Gun:AddToggle("Noreco", 
	{
		Title = "No Recoil", 
		Description = "Enable No Recoil",
		Default = false,
		Callback = function(state)
			for _, v in pairs(game:GetService("ReplicatedStorage").Weapons:GetDescendants()) do
				if v.Name == "RecoilControl" or v.Name == "Recoil" then
					if state then
						if not originalValues.Recoil[v] then
							originalValues.Recoil[v] = v.Value
						end
						v.Value = 0
					else
						if originalValues.Recoil[v] then
							v.Value = originalValues.Recoil[v]
						else
							v.Value = 1 
						end
					end
				end
			end
		end
	})

local Section = Tabs.Player:AddSection("Fly")


--[[
local Tabs = {
    Home = Window:AddTab({ Title = "Home", Icon = "home" }),
    Main = Window:AddTab({ Title = "Main", Icon = "rbxassetid://10734887784" }),
    Gun = Window:AddTab({ Title = "Gun Modded", Icon = "rbxassetid://10723395896" }),
    Player = Window:AddTab({ Title = "Player", Icon = "user" }),
    Skins = Window:AddTab({ Title = "Skins", Icon = "rbxassetid://10734919503" }),
    Extra = Window:AddTab({ Title = "Extra", Icon = "rbxassetid://10723346684" }),
    Visual = Window:AddTab({ Title = "Visuals", Icon = "eye" }),
    Setting = Window:AddTab({ Title = "Settings", Icon = "rbxassetid://10734950309" }),
}
--]]

Window:SelectTab(1)
