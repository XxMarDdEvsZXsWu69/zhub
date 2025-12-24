-- security checks (cleaned)
local username = game.Players.LocalPlayer.Name

-- Removed:
-- expectedURL
-- expectedHash
-- whitelistMonitoringURL
-- sha256 check
-- sendDiscordWebhook()
-- showWhitelistErrorMessage()
-- whitelist loading & verify()

-- =============================================================
-- Load Rayfield **once**
if not getgenv().BeastHubRayfield then
    getgenv().BeastHubRayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end
local Rayfield = getgenv().BeastHubRayfield
local beastHubIcon = 88823002331312

-- Prevent multiple Rayfield instances
if getgenv().BeastHubLoaded then
    if Rayfield then
        Rayfield:Notify({
            Title = "BeastHub",
            Content = "Already running! Press H",
            Duration = 5,
            Image = beastHubIcon
        })
    else
        warn("BeastHub is already running!")
    end    
    return
end

getgenv().BeastHubLoaded = true
getgenv().BeastHubLink = "https://pastebin.com/raw/GjsWnygW"


-- Load my reusable functions
if not getgenv().BeastHubFunctions then
    getgenv().BeastHubFunctions = loadstring(game:HttpGet("https://pastebin.com/raw/wEUUnKuv"))()
end
local myFunctions = getgenv().BeastHubFunctions

-- ================== MISSING FUNCTIONS ==================
-- Add Discord webhook function
local function sendDiscordWebhook(url, message)
    if not url or url == "" then return end
    local success = pcall(function()
        game:HttpPost(url, game:GetService("HttpService"):JSONEncode({
            content = message
        }), Enum.HttpContentType.ApplicationJson)
    end)
    if success then
        print("[BeastHub] Webhook sent: " .. message)
    else
        warn("[BeastHub] Failed to send webhook")
    end
end

-- Delay variable for hatching eggs
local delayToHatchEggs = 0.1

-- Delay variable for selling pets (can be adjusted via UI input)
local delayToSellPets = 0.05

-- ================== EGG STATUS GUI ==================
-- Create Egg Status GUI (replaces Luck GUI)
local eggStatusGUI = nil
local eggStatusLabel = nil
local originalEggCount = nil -- FIXED value captured ONCE when script starts (nil = not captured yet)
local trackedEggName = "" -- The egg type we're tracking
local originalCaptured = false -- Flag to ensure we only capture once

-- Get inventory count of a specific egg type from backpack
local function getInventoryEggCount(eggName)
    if not eggName or eggName == "" then return 0 end

    local player = game.Players.LocalPlayer
    local backpack = player:WaitForChild("Backpack")
    local character = player.Character
    local totalCount = 0

    -- Check backpack
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            -- Match egg name (case insensitive, partial match)
            if string.lower(tool.Name):find(string.lower(eggName)) then
                -- Try to parse count from name like "Spooky Egg x2491"
                local countStr = tool.Name:match("x(%d+)")
                if countStr then
                    totalCount = totalCount + tonumber(countStr)
                else
                    -- If no count in name, check for Amount attribute
                    local amount = tool:GetAttribute("Amount")
                    if amount then
                        totalCount = totalCount + amount
                    else
                        totalCount = totalCount + 1
                    end
                end
            end
        end
    end

    -- Also check character (if egg is equipped)
    if character then
        for _, tool in ipairs(character:GetChildren()) do
            if tool:IsA("Tool") then
                if string.lower(tool.Name):find(string.lower(eggName)) then
                    local countStr = tool.Name:match("x(%d+)")
                    if countStr then
                        totalCount = totalCount + tonumber(countStr)
                    else
                        local amount = tool:GetAttribute("Amount")
                        if amount then
                            totalCount = totalCount + amount
                        else
                            totalCount = totalCount + 1
                        end
                    end
                end
            end
        end
    end

    return totalCount
end

-- Get count of placed eggs of a specific type in the farm
local function getPlacedEggCountByName(eggName)
    if not eggName or eggName == "" then return 0 end

    local petEggsList = myFunctions.getMyFarmPetEggs()
    local count = 0

    for _, egg in ipairs(petEggsList) do
        if egg:IsA("Model") then
            local matched = false

            -- Method 1: Check EggType attribute
            local eggType = egg:GetAttribute("EggType")
            if eggType and string.lower(tostring(eggType)):find(string.lower(eggName)) then
                matched = true
            end

            -- Method 2: Check EggName attribute
            if not matched then
                local eggNameAttr = egg:GetAttribute("EggName")
                if eggNameAttr and string.lower(tostring(eggNameAttr)):find(string.lower(eggName)) then
                    matched = true
                end
            end

            -- Method 3: Check Model.Name
            if not matched then
                if string.lower(egg.Name):find(string.lower(eggName)) then
                    matched = true
                end
            end

            -- Method 4: Check for child with matching name
            if not matched then
                for _, child in ipairs(egg:GetChildren()) do
                    if string.lower(child.Name):find(string.lower(eggName)) then
                        matched = true
                        break
                    end
                end
            end

            if matched then
                count = count + 1
            end
        end
    end

    return count
end

-- Get total egg count (inventory + placed in farm) for a specific egg type
local function getTotalEggCount(eggName)
    local inventoryCount = getInventoryEggCount(eggName)
    local placedCount = getPlacedEggCountByName(eggName)
    return inventoryCount + placedCount
end

local function createEggStatusGUI()
    local player = game.Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    -- Remove existing if present
    if playerGui:FindFirstChild("EggStatusGUI") then
        playerGui.EggStatusGUI:Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "EggStatusGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 140, 0, 16) -- Increased width to fit 5 digits (e.g. 23281 - 23281)
    frame.Position = UDim2.new(1, -150, 1, -20) -- Adjusted position for new width
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -4, 1, 0)
    label.Position = UDim2.new(0, 2, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 9 -- Smallest text size
    label.Font = Enum.Font.GothamBold
    label.Text = "Egg Status: --"
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    eggStatusGUI = screenGui
    eggStatusLabel = label
    return screenGui
end

local function updateEggStatus(fixedValue, newValue, placedCount)
    if not eggStatusLabel then return end
    if fixedValue == nil then fixedValue = 0 end
    if newValue == nil then newValue = 0 end
    if placedCount == nil then placedCount = 0 end

    local trendColor = Color3.fromRGB(255, 255, 255)

    if newValue > fixedValue then
        trendColor = Color3.fromRGB(100, 255, 100) -- green
    elseif newValue < fixedValue then
        trendColor = Color3.fromRGB(255, 100, 100) -- red
    else
        trendColor = Color3.fromRGB(255, 255, 255) -- white when same
    end

    eggStatusLabel.Text = string.format("Egg Status: %d - %d", fixedValue, newValue)
    eggStatusLabel.TextColor3 = trendColor
end

-- Initialize the Egg Status GUI
createEggStatusGUI()

-- Real-time Egg Status update loop (runs continuously in background)
local eggStatusUpdateThread = nil
local function startEggStatusRealTimeUpdate()
    if eggStatusUpdateThread then return end -- Already running

    eggStatusUpdateThread = task.spawn(function()
        while true do
            -- Only update if we have a tracked egg and original value captured
            if trackedEggName ~= "" and originalCaptured and originalEggCount then
                local currentTotal = getTotalEggCount(trackedEggName)
                local currentPlaced = getPlacedEggCountByName(trackedEggName)
                updateEggStatus(originalEggCount, currentTotal, currentPlaced)
            end
            task.wait(0.5) -- Update every 0.5 seconds for real-time feel
        end
    end)
end

-- Start the real-time update loop
startEggStatusRealTimeUpdate()

-- ================== MAIN ==================
local Window = Rayfield:CreateWindow({
   Name = "BeastHub 2.0 | Modified by Markdevs",
   Icon = beastHubIcon, --Cat icon
   LoadingTitle = "BeastHub 2.0",
   LoadingSubtitle = "Modified by Markdevs",
   ShowText = "Rayfield",
   Theme = "Default",
   ToggleUIKeybind = "H",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "BeastHub",
      FileName = "userConfig"
   }
})

local function beastHubNotify(title, message, duration)
    Rayfield:Notify({
        Title = title,
        Content = message,
        Duration = duration,
        Image = beastHubIcon
    })
end

local mainModule = loadstring(game:HttpGet("https://pastebin.com/raw/K4yBnmbf"))()
mainModule.init(Rayfield, beastHubNotify, Window, myFunctions, reloadScript, beastHubIcon)



local Shops = Window:CreateTab("Shops", "circle-dollar-sign")
local PetEggs = Window:CreateTab("Eggs", "egg")
local Misc = Window:CreateTab("Misc", "code")
-- ===Declarations
local workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
--local TeleportService = game:GetService("TeleportService")
local player = Players.LocalPlayer
local placeId = game.PlaceId
local character = player.Character
local Humanoid = character:WaitForChild("Humanoid")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")







-- Safe Reload button
local function reloadScript(message)
    -- Reset flags first so main script can run again
    getgenv().BeastHubLoaded = false
    getgenv().BeastHubRayfield = nil

    -- Destroy existing Rayfield UI safely
    if Rayfield and Rayfield.Destroy then
        Rayfield:Destroy()
        print("Rayfield destroyed")
    elseif game:GetService("CoreGui"):FindFirstChild("Rayfield") then
        game:GetService("CoreGui").Rayfield:Destroy()
        print("Rayfield destroyed in CoreGui")
    end

    -- Reload main script from Pastebin
    if getgenv().BeastHubLink then
        local ok, err = pcall(function()
            loadstring(game:HttpGet(getgenv().BeastHubLink))()
        end)
        if ok then
            Rayfield = getgenv().BeastHubRayfield
            Rayfield:Notify({
                Title = "BeastHub",
                Content = message.." successful",
                Duration = 3,
                Image = beastHubIcon
            })
            print("BeastHub reloaded successfully")
        else
            warn("Failed to reload BeastHub:", err)
        end
    else
        warn("Reload link not set!")
    end
end











-- Shops>Seeds
-- load data
local seedsTable = myFunctions.getAvailableShopList(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Seed_Shop"))
-- extract names for dropdown
local seedNames = {}
for _, item in ipairs(seedsTable) do
    table.insert(seedNames, item.Name)
end

-- UI Setup
Shops:CreateSection("Seeds - Tier 1")
local SelectedSeeds = {}

-- Create Dropdown
local Dropdown_allSeeds = Shops:CreateDropdown({
    Name = "Select Seeds",
    Options = seedNames,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "dropdownTier1Seeds",
    Callback = function(options)
        --if not options or not options[1] then return end
        for _, seed in ipairs(options) do
            if not table.find(SelectedSeeds, seed) then
                table.insert(SelectedSeeds, seed)
            end
        end
        -- Remove unselected
        for i = #SelectedSeeds, 1, -1 do
            local seed = SelectedSeeds[i]
            if not table.find(options, seed) and table.find(CurrentFilteredSeeds, seed) then
                table.remove(SelectedSeeds, i)
            end
        end
        -- print("Selected seeds:", table.concat(SelectedSeeds, ", "))
    end,
})

-- Mark All button (only visible/filtered seeds)
Shops:CreateButton({
    Name = "[ * ] select all",
    Callback = function()
        for _, seed in ipairs(seedNames) do
            if not table.find(SelectedSeeds, seed) then
                table.insert(SelectedSeeds, seed)
            end
        end
        Dropdown_allSeeds:Set(seedNames)
        -- print("All visible seeds selected:", table.concat(SelectedSeeds, ", "))
    end,
})

-- Unselect All button (only visible/filtered seeds)
Shops:CreateButton({
    Name = "[   ] unselect all",
    Callback = function()
        for i = #SelectedSeeds, 1, -1 do
            if table.find(seedNames, SelectedSeeds[i]) then
                table.remove(SelectedSeeds, i)
            end
        end
        Dropdown_allSeeds:Set({})
        -- print("Visible seeds unselected")
    end,
})

-- Auto-buy toggle for selected
myFunctions._autoBuySelectedSeedsRunning = false -- toggle stoppers seeds
myFunctions._autoBuyAllSeedsRunning = false

myFunctions._autoBuySelectedGearsRunning = false -- toggle stoppers gears 
myFunctions._autoBuyAllGearsRunning = false

myFunctions._autoBuySelectedEggsRunning = false -- toggle stoppers eggs
myFunctions._autoBuyAllEggsRunning = false



local Toggle_autoBuySeedsTier1_selected = Shops:CreateToggle({
    Name = "Auto buy selected",
    CurrentValue = false,
    Flag = "autoBuySeedsTier1_selected",
    Callback = function(Value)
        myFunctions._autoBuySelectedSeedsRunning = Value

        if Value then
            if #SelectedSeeds > 0 then
                --print("[BeastHub] Auto-buying selected seeds:", table.concat(SelectedSeeds, ", "))

                -- pass a function for dynamic check
                myFunctions.buyItemsLive(
                    game:GetService("ReplicatedStorage").GameEvents.BuySeedStock,
                    function()
                        return myFunctions.getAvailableShopList(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Seed_Shop"))
                    end,
                    SelectedSeeds,
                    function() return myFunctions._autoBuySelectedSeedsRunning end, -- dynamic running flag
                    "BuySeedStock"
                )
            else
                warn("[BeastHub] No seeds selected!")
            end
        else
            --print("[BeastHub] Stopped auto-buy selected seeds.")
        end
    end,
})

-- Auto-buy toggle for all seeds
local Toggle_autoBuySeedsTier1_all = Shops:CreateToggle({
    Name = "Auto buy all",
    CurrentValue = false,
    Flag = "autoBuySeedsTier1_all",
    Callback = function(Value)
        myFunctions._autoBuyAllSeedsRunning = Value -- module flag
        if Value then
            -- print("[BeastHub] Auto-buying ALL seeds")
            -- Trigger live buy
            myFunctions.buyItemsLive(
                game:GetService("ReplicatedStorage").GameEvents.BuySeedStock, -- buy event
                function()
                    return myFunctions.getAvailableShopList(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Seed_Shop"))
                end, -- shop list
                seedNames, -- all available 
                function() return myFunctions._autoBuyAllSeedsRunning end,
                "BuySeedStock"
            )
        else
            --print("[BeastHub] Stopped auto-buy ALL gears")
        end
    end,
})
Shops:CreateDivider()


-- Shops>Gear
-- load data
local gearsTable = myFunctions.getAvailableShopList(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Gear_Shop"))
-- extract names for dropdown
local gearNames = {}
for _, item in ipairs(gearsTable) do
    table.insert(gearNames, item.Name)
end

-- UI
Shops:CreateSection("Gears")
local SelectedGears = {}

local Dropdown_allGears = Shops:CreateDropdown({
    Name = "Select Gears",
    Options = gearNames,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "dropdownGears",
    Callback = function(options)
        --if not options or not options[1] then return end
        for _, gear in ipairs(options) do
            if not table.find(SelectedGears, gear) then
                table.insert(SelectedGears, gear)
            end
        end
        -- Remove unselected
        for i = #SelectedGears, 1, -1 do
            local gear = SelectedGears[i]
            if not table.find(options, gear) and table.find(gearNames, gear) then
                table.remove(SelectedGears, i)
            end
        end
    end,
})

-- Mark All button
Shops:CreateButton({
    Name = "[ * ] select all",
    Callback = function()
        for _, gear in ipairs(gearNames) do
            if not table.find(SelectedGears, gear) then
                table.insert(SelectedGears, gear)
            end
        end
        Dropdown_allGears:Set(gearNames)
        -- print("All visible gears selected:", table.concat(SelectedGears, ", "))
    end,
})

-- Unselect All button 
Shops:CreateButton({
    Name = "[   ] unselect all",
    Callback = function()
        for i = #SelectedGears, 1, -1 do
            if table.find(gearNames, SelectedGears[i]) then
                table.remove(SelectedGears, i)
            end
        end
        Dropdown_allGears:Set({})
        -- print("Visible gears unselected")
    end,
})


--Auto buy selected gears
local Toggle_autoBuyGears_selected = Shops:CreateToggle({
    Name = "Auto buy selected",
    CurrentValue = false,
    Flag = "autoBuyGears_selected",
    Callback = function(Value)
        myFunctions._autoBuySelectedGearsRunning = Value
        if Value then
            if #SelectedGears > 0 then
                -- print("[BeastHub] Auto-buying selected gears:", table.concat(SelectedGears, ", "))
                myFunctions.buyItemsLive(
                    game:GetService("ReplicatedStorage").GameEvents.BuyGearStock,
                    gearsTable,
                    SelectedGears,
                    function() return myFunctions._autoBuySelectedGearsRunning end
                )
            else
                warn("[BeastHub] No gears selected!")
            end
        else
            -- myFunctions._autoBuySelectedGearsRunning = false
        end
    end,
})



-- Auto-buy toggle for all gears
local Toggle_autoBuyGears_all = Shops:CreateToggle({
    Name = "Auto buy all",
    CurrentValue = false,
    Flag = "autoBuyGears_all",
    Callback = function(Value)
        myFunctions._autoBuyAllGearsRunning = Value -- module flag

        if Value then
            --print("[BeastHub] Auto-buying ALL gears")
            -- Trigger live buy
            myFunctions.buyItemsLive(
                game:GetService("ReplicatedStorage").GameEvents.BuyGearStock, -- buy event
                gearsTable, -- shop list
                gearNames, -- all available gears
                function() return myFunctions._autoBuyAllGearsRunning end
            )
        else
            --print("[BeastHub] Stopped auto-buy ALL gears")
        end
    end,
})
Shops:CreateDivider()


-- Shops>Eggs
-- load data
local eggsTable = myFunctions.getAvailableShopList(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("PetShop_UI"))
-- extract names for dropdown
local eggNames = {}
for _, item in ipairs(eggsTable) do
    table.insert(eggNames, item.Name)
end

-- UI
Shops:CreateSection("Eggs")
local SelectedEggs = {}

local Dropdown_allEggs = Shops:CreateDropdown({
    Name = "Select Eggs",
    Options = eggNames,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "dropdownEggs",
    Callback = function(options)
        --if not Options or not Options[1] then return end
        for _, egg in ipairs(options) do
            if not table.find(SelectedEggs, egg) then
                table.insert(SelectedEggs, egg)
            end
        end
        -- Remove unselected
        for i = #SelectedEggs, 1, -1 do
            local egg = SelectedEggs[i]
            if not table.find(options, egg) and table.find(eggNames, egg) then
                table.remove(SelectedEggs, i)
            end
        end
    end,
})

-- Mark All button
Shops:CreateButton({
    Name = "[ * ] select all",
    Callback = function()
        for _, egg in ipairs(eggNames) do
            if not table.find(SelectedEggs, egg) then
                table.insert(SelectedEggs, egg)
            end
        end
        Dropdown_allEggs:Set(eggNames)
    end,
})

-- Unselect All button 
Shops:CreateButton({
    Name = "[   ] unselect all",
    Callback = function()
        for i = #SelectedEggs, 1, -1 do
            if table.find(eggNames, SelectedEggs[i]) then
                table.remove(SelectedEggs, i)
            end
        end
        Dropdown_allEggs:Set({})
    end,
})

--Auto buy selected eggs
myFunctions._autoBuySelectedEggsRunning = false -- toggle stoppers
myFunctions._autoBuyAllEggsRunning = false
local Toggle_autoBuyEggs_selected = Shops:CreateToggle({
    Name = "Auto buy selected",
    CurrentValue = false,
    Flag = "autoBuyEggs_selected",
    Callback = function(Value)
        myFunctions._autoBuySelectedEggsRunning = Value
        if Value then
            if #SelectedEggs > 0 then
                myFunctions.buyItemsLive(
                    game:GetService("ReplicatedStorage").GameEvents.BuyPetEgg,
                    eggsTable,
                    SelectedEggs,
                    function() return myFunctions._autoBuySelectedEggsRunning end
                )
            else
                warn("[BeastHub] No eggs selected!")
            end
        end
    end,
})

-- Auto-buy toggle for all eggs
local Toggle_autoBuyEggs_all = Shops:CreateToggle({
    Name = "Auto buy all",
    CurrentValue = false,
    Flag = "autoBuyEggs_all",
    Callback = function(Value)
        myFunctions._autoBuyAllEggsRunning = Value
        if Value then
            myFunctions.buyItemsLive(
                game:GetService("ReplicatedStorage").GameEvents.BuyPetEgg,
                eggsTable,
                eggNames,
                function() return myFunctions._autoBuyAllEggsRunning end
            )
        end
    end,
})

Shops:CreateDivider()





-- PetEggs>Eggs
PetEggs:CreateSection("Auto Place eggs")
--Auto place eggs
--get egg list first based on registry
local function getEggNames()
    local eggNames = {}
    local success, err = pcall(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local PetRegistry = require(ReplicatedStorage.Data.PetRegistry)

        -- Ensure PetEggs exists
        if not PetRegistry.PetEggs then
            warn("PetRegistry.PetEggs not found!")
            return
        end

        -- Collect egg names
        for eggName, eggData in pairs(PetRegistry.PetEggs) do
            if eggName ~= "Fake Egg" then
                table.insert(eggNames, eggName)
            end
        end
    end)

    if not success then
        warn("getEggNames failed:", err)
    end
    return eggNames
end
local allEggNames = getEggNames()
table.sort(allEggNames)


--get current egg count in garden
local function getFarmEggCount()
    local petEggsList = myFunctions.getMyFarmPetEggs()
    return #petEggsList -- simply return the number of eggs
end

--equip
local function equipItemByName(itemName)
    local player = game.Players.LocalPlayer
    local backpack = player:WaitForChild("Backpack")
        player.Character.Humanoid:UnequipTools() --unequip all first

    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and string.find(tool.Name, itemName) then
            --print("Equipping:", tool.Name)
                        player.Character.Humanoid:UnequipTools() --unequip all first
            player.Character.Humanoid:EquipTool(tool)
            return true -- stop after first match
        end
    end
    return false
end

--dropdown for egg list
local Dropdown_eggToPlace = PetEggs:CreateDropdown({
    Name = "Select Egg to Auto Place",
    Options = allEggNames,
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "eggToAutoPlace", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
    Callback = function(Options)
        --if not Options or not Options[1] then return end -- nothing selected yet
    end,
})

--input egg count to place
local eggsToPlaceInput = 13
local Input_numberOfEggsToPlace = PetEggs:CreateInput({
    Name = "Number of eggs to place",
    CurrentValue = "13",
    PlaceholderText = "# of eggs",
    RemoveTextAfterFocusLost = false,
    Flag = "numberOfEggsToPlace",
    Callback = function(Text)
        eggsToPlaceInput = tonumber(Text) or 0
    end,
})

--delay to place eggs
local delayToPlaceEggs = 0.5
local Input_delayToPlaceEggs = PetEggs:CreateInput({
    Name = "Delay to place eggs (default 0.5)",
    CurrentValue = "0.5",
    PlaceholderText = "Delay in seconds",
    RemoveTextAfterFocusLost = false,
    Flag = "delayToPlaceEggs",
    Callback = function(Text)
        delayToPlaceEggs = tonumber(Text) or 0.5
    end,
})

--delay to hatch eggs
local delayToHatchEggs = 0.05
local Input_delayToHatchEggs = PetEggs:CreateInput({
    Name = "Delay to hatch eggs (default 0.05)",
    CurrentValue = "0.05",
    PlaceholderText = "Delay in seconds",
    RemoveTextAfterFocusLost = false,
    Flag = "delayToHatchEggs",
    Callback = function(Text)
        delayToHatchEggs = tonumber(Text) or 0.05
    end,
})

-- Position selection for egg placement
local selectedPosition = "Left - stacked"
local Dropdown_eggPosition = PetEggs:CreateDropdown({
    Name = "Position",
    Options = {"Left - stacked", "Right - stacked", "Left - compressed", "Right - compressed"},
    CurrentOption = {"Left - stacked"},
    MultipleOptions = false,
    Flag = "eggPlacementPosition",
    Callback = function(Options)
        selectedPosition = Options[1] or "Left - stacked"
    end,
})

-- Listen for Notification event once for too close eggs
local tooCloseFlag = false
local petAlreadyInMachineFlag = false
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Notification = ReplicatedStorage.GameEvents.Notification
Notification.OnClientEvent:Connect(function(message)
    if typeof(message) == "string" and message:lower():find("too close to another egg") then
        tooCloseFlag = true
        --print("[DEBUG] Too close notification received, skipping increment")
    end

    if typeof(message) == "string" and message:lower():find("a pet is already in the machine!") then
        petAlreadyInMachineFlag = true
    end
end)

--=======HANDEL LOCATIONS FOR  AUTO PLACE EGG
local localPlayer = Players.LocalPlayer
-- find player's farm
local function getMyFarm()
    if not localPlayer then
        warn("[BeastHub] Local player not found!")
        return nil
    end

    local farmsFolder = workspace:WaitForChild("Farm")
    for _, farm in pairs(farmsFolder:GetChildren()) do
        if farm:IsA("Folder") or farm:IsA("Model") then
            local ownerValue = farm:FindFirstChild("Important") 
                            and farm.Important:FindFirstChild("Data") 
                            and farm.Important.Data:FindFirstChild("Owner")
            if ownerValue and ownerValue.Value == localPlayer.Name then
                return farm
            end
        end
    end

    warn("[BeastHub] Could not find your farm!")
    return nil
end

-- get farm spawn point CFrame
local function getFarmSpawnCFrame() --old code
    local myFarm = getMyFarm()
    if not myFarm then return nil end

    local spawnPoint = myFarm:FindFirstChild("Spawn_Point")
    if spawnPoint and spawnPoint:IsA("BasePart") then
        return spawnPoint.CFrame
    end

    warn("[BeastHub] Spawn_Point not found in your farm!")
    return nil
end


-- relative egg positions (local space relative to spawn point)
local eggPositionPresets = {
    ["Left - stacked"] = {
        Vector3.new(-36, 0, -18),
        Vector3.new(-27, 0, -18),
        Vector3.new(-18, 0, -18),
        Vector3.new(-9, 0, -18),

        Vector3.new(-36, 0, -33),
        Vector3.new(-27, 0, -33),
        Vector3.new(-18, 0, -33),
        Vector3.new(-9, 0, -33),

        Vector3.new(-36, 0, -48),
        Vector3.new(-27, 0, -48),
        Vector3.new(-18, 0, -48),
        Vector3.new(-9, 0, -48),

        Vector3.new(-36, 0, -63),
        Vector3.new(-27, 0, -63),
        Vector3.new(-18, 0, -63),
        Vector3.new(-9, 0, -63),
    },
    ["Right - stacked"] = {
        Vector3.new(36, 0, -18),
        Vector3.new(27, 0, -18),
        Vector3.new(18, 0, -18),
        Vector3.new(9, 0, -18),

        Vector3.new(36, 0, -33),
        Vector3.new(27, 0, -33),
        Vector3.new(18, 0, -33),
        Vector3.new(9, 0, -33),

        Vector3.new(36, 0, -48),
        Vector3.new(27, 0, -48),
        Vector3.new(18, 0, -48),
        Vector3.new(9, 0, -48),

        Vector3.new(36, 0, -63),
        Vector3.new(27, 0, -63),
        Vector3.new(18, 0, -63),
        Vector3.new(9, 0, -63),
    },
   ["Left - compressed"] = {
        Vector3.new(-18, 0, -12),
        Vector3.new(-14, 0, -12),
        Vector3.new(-10, 0, -12),
        Vector3.new(-6, 0, -12),

        Vector3.new(-18, 0, -18),
        Vector3.new(-14, 0, -18),
        Vector3.new(-10, 0, -18),
        Vector3.new(-6, 0, -18),

        Vector3.new(-18, 0, -24),
        Vector3.new(-14, 0, -24),
        Vector3.new(-10, 0, -24),
        Vector3.new(-6, 0, -24),

        Vector3.new(-18, 0, -30),
        Vector3.new(-14, 0, -30),
        Vector3.new(-10, 0, -30),
        Vector3.new(-6, 0, -30),
    },
    ["Right - compressed"] = {
        Vector3.new(18, 0, -12),
        Vector3.new(14, 0, -12),
        Vector3.new(10, 0, -12),
        Vector3.new(6, 0, -12),

        Vector3.new(18, 0, -18),
        Vector3.new(14, 0, -18),
        Vector3.new(10, 0, -18),
        Vector3.new(6, 0, -18),

        Vector3.new(18, 0, -24),
        Vector3.new(14, 0, -24),
        Vector3.new(10, 0, -24),
        Vector3.new(6, 0, -24),

        Vector3.new(18, 0, -30),
        Vector3.new(14, 0, -30),
        Vector3.new(10, 0, -30),
        Vector3.new(6, 0, -30),
    },
}

-- convert to world positions
local function getFarmEggLocations()
    local spawnCFrame = getFarmSpawnCFrame()
    if not spawnCFrame then return {} end

    local eggOffsets = eggPositionPresets[selectedPosition] or eggPositionPresets["Left - stacked"]

    local locations = {}
    for _, offset in ipairs(eggOffsets) do
        table.insert(locations, spawnCFrame:PointToWorldSpace(offset))
    end
    return locations
end

--=====================


--toggle auto place eggs
local autoPlaceEggsThread -- store the task
local autoPlaceEggsEnabled = false
local Toggle_autoPlaceEggs = PetEggs:CreateToggle({
    Name = "Auto place eggs",
    CurrentValue = false,
    Flag = "autoPlaceEggs",
    Callback = function(Value)
        -- Stop old loop if already running
        if autoPlaceEggsThread then
            autoPlaceEggsEnabled = false
            autoPlaceEggsThread = nil -- we just stop the thread by flipping the boolean
        end

        if Value then
            -- Get selected egg name
            local selectedEgg = Dropdown_eggToPlace.CurrentOption[1] or ""
            if selectedEgg == "" then
                beastHubNotify("Error", "Please select an egg type first!", 3)
                return
            end

            -- If egg type changed, recapture the original value
            if trackedEggName ~= selectedEgg then
                trackedEggName = selectedEgg
                originalEggCount = getTotalEggCount(trackedEggName)
                originalCaptured = true
            elseif not originalCaptured then
                -- First time capture
                trackedEggName = selectedEgg
                originalEggCount = getTotalEggCount(trackedEggName)
                originalCaptured = true
            end
            updateEggStatus(originalEggCount, getTotalEggCount(trackedEggName), getPlacedEggCountByName(trackedEggName))

            beastHubNotify("Auto place eggs: ON", "Max Eggs to place: "..tostring(eggsToPlaceInput), 4)
            autoPlaceEggsEnabled = true
            local autoPlaceEggLocations = getFarmEggLocations() --off setting for dynamic farm location
            autoPlaceEggsThread = task.spawn(function()
                while autoPlaceEggsEnabled do
                    local maxFarmEggs = eggsToPlaceInput
                    local currentEggsInFarm = getFarmEggCount()

                    -- Update Egg Status GUI: originalEggCount (FIXED) vs currentInventory (REAL-TIME)
                    local currentInventory = getTotalEggCount(trackedEggName)
                    local currentPlaced = getPlacedEggCountByName(trackedEggName)
                    updateEggStatus(originalEggCount, currentInventory, currentPlaced)

                    if currentEggsInFarm < maxFarmEggs then
                        for _, location in ipairs(autoPlaceEggLocations) do
                            if currentEggsInFarm >= maxFarmEggs then
                                break
                            end

                            if Dropdown_eggToPlace.CurrentOption[1] then
                                equipItemByName(Dropdown_eggToPlace.CurrentOption[1])
                            end

                            local args = { "CreateEgg", location }
                            game:GetService("ReplicatedStorage").GameEvents.PetEggService:FireServer(unpack(args))
                            --add algo here to trap 'too close to another egg and dont increment'
                            task.wait(delayToPlaceEggs)
                            if tooCloseFlag then
                                tooCloseFlag = false -- reset flag for next iteration
                                -- skip increment
                            else
                                currentEggsInFarm = currentEggsInFarm + 1
                            end

                            -- Update Egg Status GUI: originalEggCount (FIXED) vs currentInventory (REAL-TIME)
                            currentInventory = getTotalEggCount(trackedEggName)
                            currentPlaced = getPlacedEggCountByName(trackedEggName)
                            updateEggStatus(originalEggCount, currentInventory, currentPlaced)

                        end
                    end

                    task.wait(1.5)
                end
            end)
        else
            autoPlaceEggsEnabled = false
            autoPlaceEggsThread = nil
            -- Show final status: originalEggCount (FIXED) vs final inventory
            local finalInventory = getTotalEggCount(trackedEggName)
            local finalPlaced = getPlacedEggCountByName(trackedEggName)
            updateEggStatus(originalEggCount, finalInventory, finalPlaced)
            beastHubNotify("Auto place eggs: OFF", "", 2)
        end
    end,
})

--Auto hatch
PetEggs:CreateButton({
    Name = "Click to HATCH ALL",
    Callback = function()
        print("[BeastHub] Hatching eggs...")

        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local PetEggService = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetEggService")

        -- Get all PetEgg models in your farm
        local petEggs = myFunctions.getMyFarmPetEggs()
        if #petEggs == 0 then
            --print("[BeastHub] No PetEggs found in your farm!")
            return
        end

        -- Loop through all eggs and fire the hatch event
        for _, egg in ipairs(petEggs) do
            local args = {
                [1] = "HatchPet",
                [2] = egg
            }
            PetEggService:FireServer(unpack(args))
            task.wait(delayToHatchEggs)
            --print("[BeastHub] Fired hatch for:", egg.Name)
        end
    end,
})
PetEggs:CreateDivider()

--PetEggs>Auto Sell Pets
local petList = myFunctions.getPetOdds()
    -- Get names only
local petListNamesOnlyAndSorted = myFunctions.getPetList()
table.sort(petListNamesOnlyAndSorted)

    --function to auto sell
local function autoSellPets(targetPets, weightTargetBelow, onComplete)
    -- USAGE:
    -- autoSellPets({"Bunny", "Dog"}, 3, function()
    --     print("Selling complete, now do next step!")
    -- end)

    if not targetPets or #targetPets == 0 then
        warn("[BeastHub] No pets to sell!")
        return false
    end

    if not weightTargetBelow or weightTargetBelow <= 0 then
        warn("[BeastHub] Invalid weight threshold!")
        return false
    end

    local player = game.Players.LocalPlayer
    local backpack = player:WaitForChild("Backpack")
    local SellPet_RE = game:GetService("ReplicatedStorage").GameEvents.SellPet_RE
    local soldCount = 0

    -- Unequip first
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid:UnequipTools()
    end

    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") then
            local b = item:GetAttribute("b") -- pet type
            local d = item:GetAttribute("d") -- favorite

        if b == "l" and d == false then
            local petName = item.Name:match("^(.-)%s*%[") or item.Name
            petName = petName:match("^%s*(.-)%s*$") -- trim spaces

            local weightStr = item.Name:match("%[(%d+%.?%d*)%s*[Kk][Gg]%]")
            local weight = weightStr and tonumber(weightStr)

            -- Check if this is a target pet
            local isTarget = false
            for _, name in ipairs(targetPets) do
                if petName == name then
                    isTarget = true
                    break
                end
            end

            -- Sell if matches criteria
            if isTarget and weight and weight < weightTargetBelow then
                if player.Character and player.Character:FindFirstChild("Humanoid") then
                    player.Character.Humanoid:UnequipTools()
                    task.wait(0.1)
                    player.Character.Humanoid:EquipTool(item)
                    task.wait(0.2) -- ensure pet equips before selling

                    local success = pcall(function()
                        SellPet_RE:FireServer(item.Name)
                    end)

                    if success then
                        print("[BeastHub] Sold: " .. item.Name)
                        soldCount = soldCount + 1
                    end
                    task.wait(delayToSellPets)
                end
            end
        end
        end
    end

    print("[BeastHub] Auto Sell complete - Sold " .. soldCount .. " pets")

    -- Call the callback AFTER finishing all pets
    if typeof(onComplete) == "function" then
        onComplete()
    end

    return true
end



--auto sell pets UI
local selectedPets --for UI paragraph
local selectedPetsForAutoSell = {} --container for dropdown
local sealsLoady

local Paragraph_selectedPets = PetEggs:CreateParagraph({Title = "Auto Sell Pets:", Content = "No pets selected."})
local Dropdown_sealsLoadoutNum = PetEggs:CreateDropdown({
    Name = "Select 'Seals' loadout",
    Options = {"None", "1", "2", "3"},
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "sealsLoadoutNum", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
    Callback = function(Options)
        --if not Options or not Options[1] then return end
        sealsLoady = tonumber(Options[1])
    end,
})
local suggestedAutoSellList = {
    "Ostrich", "Peacock", "Capybara", "Scarlet Macaw",
    "Bat", "Bone Dog", "Spider", "Black Cat",
    "Oxpecker", "Zebra", "Giraffe", "Rhino",
    "Tree Frog", "Hummingbird", "Iguana", "Chimpanzee",
    "Robin", "Badger", "Grizzly Bear",
    "Ladybug", "Pixie", "Imp", "Glimmering Sprite",
    "Dairy Cow", "Jackalope", "Seedling",
    "Bagel Bunny", "Pancake Mole", "Sushi Bear", "Spaghetti Sloth",
    "Shiba Inu", "Nihonzaru", "Tanuki", "Tanchozuru", "Kappa",
    "Parasaurolophus", "Iguanodon", "Ankylosaurus",
    "Raptor", "Triceratops", "Stegosaurus", "Pterodactyl", 
    "Flamingo", "Toucan", "Sea Turtle", "Orangutan",
    "Wasp", "Tarantula Hawk", "Moth",
    "Bee", "Honey Bee", "Petal Bee",
    "Hedgehog", "Mole", "Frog", "Echo Frog", "Night Owl",
    "Caterpillar", "Snail", "Giant Ant", "Praying Mantis",
    "Topaz Snail", "Amethyst Beetle", "Emerald Snake", "Sapphire Macaw"
}
local Dropdown_petList = PetEggs:CreateDropdown({
    Name = "Select Pets",
    Options = petListNamesOnlyAndSorted,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "autoSellPetsSelection", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
    Callback = function(Options)
        --if not Options or not Options[1] then return end
        selectedPetsForAutoSell = Options
        -- Convert table to string for paragraph display
        local names = table.concat(Options, ", ")
        if names == "" then
            names = "No pets selected."
        end

        Paragraph_selectedPets:Set({
            Title = "Auto Sell Pets:",
            Content = names
        })    
    end,
})

--search pets
local searchDebounce = nil
local Input_petSearch = PetEggs:CreateInput({
    Name = "Search (click dropdown to load)",
    PlaceholderText = "Search Pet...",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        if searchDebounce then
            task.cancel(searchDebounce)
        end

        searchDebounce = task.delay(0.5, function()
            local results = {}
            local query = string.lower(Text)

            if query == "" then
                results = petListNamesOnlyAndSorted
            else
                for _, petName in ipairs(petListNamesOnlyAndSorted) do
                    if string.find(string.lower(petName), query, 1, true) then
                        table.insert(results, petName)
                    end
                end
            end

            Dropdown_petList:Refresh(results)

            -- Force redraw by re-setting selection (even empty table works)
            Dropdown_petList:Set(selectedPetsForAutoSell)

            -- Extra fallback: if no match, clear UI text
            if #results == 0 then
                Paragraph_selectedPets:Set({
                    Title = "Auto Sell Pets:",
                    Content = "No pets found."
                })
            end
        end)
    end,
})

PetEggs:CreateButton({
    Name = "Load Suggested List",
    Callback = function()
        Dropdown_petList:Set(suggestedAutoSellList) --Clear selection properly
        selectedPetsForAutoSell = suggestedAutoSellList
    end,
})

PetEggs:CreateButton({
    Name = "Clear selection",
    Callback = function()
        Dropdown_petList:Set({}) --Clear selection properly
        selectedPetsForAutoSell = {}
    end,
})

local sellBelow
local Dropdown_sellBelowKG = PetEggs:CreateDropdown({
    Name = "Below (KG)",
    Options = {"1","2","3"},
    CurrentOption = {"3"},
    MultipleOptions = false,
    Flag = "sellBelowKG", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
    Callback = function(Options)
        --if not Options or not Options[1] then return end
        sellBelow = tonumber(Options[1])
    end,
})

--delay to sell pets (input field to adjust delay speed)
local Input_delayToSellPets = PetEggs:CreateInput({
    Name = "Delay to sell (Default 0.05)",
    CurrentValue = "0.05",
    PlaceholderText = "Delay in seconds (lower = faster)",
    RemoveTextAfterFocusLost = false,
    Flag = "delayToSellPets",
    Callback = function(Text)
        local newDelay = tonumber(Text)
        if newDelay and newDelay > 0 then
            delayToSellPets = newDelay
            beastHubNotify("Sell Speed Updated", "Delay: " .. tostring(delayToSellPets) .. "s", 2)
        else
            beastHubNotify("Invalid Input", "Use a positive number", 3)
            delayToSellPets = 0.05
        end
    end,
})

PetEggs:CreateButton({
    Name = "Click to SELL",
    Callback = function()
        -- Validate settings
        if not selectedPetsForAutoSell or #selectedPetsForAutoSell == 0 then
            beastHubNotify("Auto Sell Error", "No pets selected!", 3)
            return
        end
        if not sellBelow then
            beastHubNotify("Auto Sell Error", "Please set KG threshold", 3)
            return
        end

        -- Switch to seals loadout if configured
        if sealsLoady and sealsLoady ~= "None" then
            print("Switching to seals loadout first")
            myFunctions.switchToLoadout(sealsLoady)
            beastHubNotify("Waiting for Seals to load", "Auto Sell", 5)
            task.wait(6)
        end

        -- Execute auto sell
        local success, err = pcall(function()
            autoSellPets(selectedPetsForAutoSell, sellBelow)
        end)

        if success then
            beastHubNotify("Auto Sell Done", "Successful", 2)
        else
            beastHubNotify("Auto Sell Error", tostring(err), 4)
            warn("Auto Sell failed: " .. tostring(err))
        end
    end,
})
PetEggs:CreateDivider()

--Pet/Eggs>SMART HATCHING
PetEggs:CreateSection("SMART Auto Hatching")
-- local Paragraph = Pets:CreateParagraph({Title = "INSTRUCTIONS:", Content = "1.) Setup your Auto place Eggs above and turn on toggle for auto place eggs. 2.) Setup your selected pets for Auto Sell above. 3.) Selected desginated loadouts below. 4.) Turn on toggle for Full Auto Hatching"})
PetEggs:CreateParagraph({
    Title = "INSTRUCTIONS:",
    Content = "1.) Setup your Auto place Eggs above and turn on toggle for auto place eggs.\n2.) Setup your selected pets for Auto Sell above.\n3.) Selected designated loadouts below.\n4.) Turn on Speedhub Egg ESP, then turn on Egg ESP support below"
})
local koiLoady
local brontoLoady
local autoBrontoAntiHatch
local incubatingLoady
local webhookRares
local webhookHuge
local webhookURL
local sessionHatchCount = 0

PetEggs:CreateDropdown({
    Name = "Incubating/Eagles Loadout",
    Options = {"None", "1", "2", "3"},
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "incubatingLoadoutNum", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
    Callback = function(Options)
        --if not Options or not Options[1] then return end
        incubatingLoady = tonumber(Options[1])
    end,
})
PetEggs:CreateDropdown({
    Name = "Koi Loadout",
    Options = {"None", "1", "2", "3"},
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "koiLoadoutNum", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
    Callback = function(Options)
        --if not Options or not Options[1] then return end
        koiLoady = tonumber(Options[1])
    end,
})
PetEggs:CreateDropdown({
    Name = "Select Bronto Loadout",
    Options = {"None", "1", "2", "3", "4", "5", "6"},
    CurrentOption = {"None"},
    MultipleOptions = false,
    Flag = "brontoLoadoutNum", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
    Callback = function(Options)
        --if not Options or not Options[1] then return end
        if Options[1] ~= "None" then
            brontoLoady = tonumber(Options[1])
        else
            brontoLoady = nil
        end
    end,
})
local skipHatchAboveKG = 0
PetEggs:CreateDropdown({
    Name = "Skip hatch Above KG (any egg):",
    Options = {"0", "2", "2.5", "2.6", "2.7", "2.8", "2.9", "3", "3.5", "4", "5"},
    CurrentOption = {"0"},
    MultipleOptions = false,
    Flag = "skipHatchAboveKG",
    Callback = function(Options)
        skipHatchAboveKG = tonumber(Options[1]) or 0
    end,
})

--Auto Bronto Anti Hatch List toggle
PetEggs:CreateToggle({
    Name = "Auto Bronto Anti Hatch List?",
    CurrentValue = false,
    Flag = "autoBrontoAntiHatch",
    Callback = function(Value)
        autoBrontoAntiHatch = Value
    end,
})

-- Anti Hatch Pets UI
local antiHatchPetsList = {}
local allPetNamesForAntiHatch = myFunctions.getPetList() or {}
table.sort(allPetNamesForAntiHatch)

local function getAntiHatchDisplayText()
    if #antiHatchPetsList == 0 then
        return "No pets selected."
    else
        return table.concat(antiHatchPetsList, ", ")
    end
end

local antiHatchParagraph = PetEggs:CreateParagraph({
    Title = "Anti Hatch Pets (HUGE by default are skipped):",
    Content = getAntiHatchDisplayText()
})

local Dropdown_antiHatchPets = PetEggs:CreateDropdown({
    Name = "Anti Hatch Pets:",
    Options = allPetNamesForAntiHatch,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "antiHatchPets",
    Callback = function(Options)
        antiHatchPetsList = Options or {}
        antiHatchParagraph:Set({
            Title = "Anti Hatch Pets (HUGE by default are skipped):",
            Content = getAntiHatchDisplayText()
        })
    end,
})

PetEggs:CreateButton({
    Name = "Clear Anti Hatch",
    Callback = function()
        antiHatchPetsList = {}
        Dropdown_antiHatchPets:Set({})
        antiHatchParagraph:Set({
            Title = "Anti Hatch Pets (HUGE by default are skipped):",
            Content = "No pets selected."
        })
        beastHubNotify("Anti Hatch Cleared", "All pets removed from anti-hatch list", 3)
    end,
})

local function isInAntiHatchList(petName)
    for _, name in ipairs(antiHatchPetsList) do
        if name == petName then
            return true
        end
    end
    return false
end

task.wait(.5) --to wait for loadout variables to load
--Only two variables needed
local smartAutoHatchingEnabled = false
local smartAutoHatchingThread = nil

local sessionHugeList = {}
local Toggle_smartAutoHatch = PetEggs:CreateToggle({
    Name = "SMART Auto Hatching",
    CurrentValue = false,
    Flag = "smartAutoHatching",
    Callback = function(Value)
        smartAutoHatchingEnabled = Value
        if(smartAutoHatchingEnabled) then
            beastHubNotify("SMART AUTO HATCH ENABLED!", "Process will begin in 8 seconds..", 5)
            beastHubNotify("5", "", 1)
            task.wait(1)
            beastHubNotify("4", "", 1)
            task.wait(1)
            beastHubNotify("3", "", 1)
            task.wait(1)
            beastHubNotify("2", "", 1)
            task.wait(1)
            beastHubNotify("1", "", 1)
            task.wait(1)
            -- task.wait(8)
            -- Check again before proceeding
            if not smartAutoHatchingEnabled then
                beastHubNotify("SMART HATCH CANCELLED!", "Toggle was turned off before start.", 5)
                return
            end

            --recheck setup
            if not koiLoady or koiLoady == "None"
            -- or not brontoLoady or brontoLoady == "None"
            or not sealsLoady or sealsLoady == "None"
            or not incubatingLoady or incubatingLoady == "None" then
                beastHubNotify("Missing setup!", "Please recheck loadouts for koi, bronto, seals and turn on EGG ESP Support", 15)
                return
            end
        end

        -- If ON, start thread (only once)
        if smartAutoHatchingEnabled and not smartAutoHatchingThread then
            smartAutoHatchingThread = task.spawn(function()
                local function isInHugeList(target)
                    for _, value in ipairs(sessionHugeList) do
                        if value == target then
                            return true
                        end
                    end
                    return false
                end

                local function notInHugeList(tbl, target)
                    for _, value in ipairs(tbl) do
                        if value == target then
                            return false  -- found → NOT allowed
                        end
                    end
                    return true  -- not found → allowed
                end



                local petOdds = myFunctions.getPetOdds()
                local rarePets = myFunctions.getRarePets(petOdds)

                while smartAutoHatchingEnabled do

                    --check eggs
                    local myPetEggs = myFunctions.getMyFarmPetEggs()
                    local readyCounter = 0

                    for _, egg in pairs(myPetEggs) do
                        if egg:IsA("Model") and egg:GetAttribute("TimeToHatch") == 0 then
                            readyCounter = readyCounter + 1
                        end
                    end

                    if #myPetEggs > 0 and #myPetEggs == readyCounter and smartAutoHatchingEnabled then
                        --all eggs ready to hatch
                        beastHubNotify("All eggs Ready!", "", 3)
                        local espFolderFound
                        local rareOrHugeFound
                        local ReplicatedStorage = game:GetService("ReplicatedStorage")
                        local PetEggService = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetEggService")


                        --all eggs now must start with koi loadout, infinite loadout has been patched 10/24/25
                        beastHubNotify("Switching to Kois", "", 8)
                        Toggle_autoPlaceEggs:Set(false)
                        myFunctions.switchToLoadout(koiLoady)
                        task.wait(12)

                        --get egg data such as pet name and size
                        --=======================================
                        for _, egg in pairs(myPetEggs) do
                            if egg:IsA("Model") then
                                --ESP access part, this is mainly for bronto hatching
                                --====
                                local espFolder = egg:FindFirstChild("BhubESP")
                                if espFolder then
                                    print("espFolder found")
                                    espFolderFound = true
                                    for _, espObj in ipairs(espFolder:GetChildren()) do
                                        -- if espObj:IsA("BoxHandleAdornment") then
                                            local billboard = espFolder:FindFirstChild("EggBillboard")
                                            if billboard then
                                                local textLabel = billboard:FindFirstChildWhichIsA("TextLabel")
                                                if textLabel then
                                                    local text = textLabel.Text
                                                    -- Get values using string match 
                                                    -- local petName = string.match(text, "0%)'>(.-)</font>")
                                                    -- local stringKG = string.match(text, ".*=%s*<font.-'>(.-)</font>")
                                                    local petName = text:match('rgb%(%s*0,%s*255,%s*0%s*%)">(.-)</font>%s*=')
                                                    local stringKG = text:match("= (%d+%.?%d*)")

                                                    -- print("petName")
                                                    -- print(petName)
                                                    -- print("stringKG")
                                                    -- print(stringKG)

                                                    local isRare
                                                    local isHuge

                                                    -- print("petName found: " .. tostring(petName))
                                                    -- print("stringKG found: "..tostring(stringKG))

                                                    if petName and stringKG and smartAutoHatchingEnabled then
                                                        -- Trim whitespace in case it grew from previous runs
                                                        stringKG = stringKG:match("^%s*(.-)%s*$") 
                                                        local playerNameWebhook = game.Players.LocalPlayer.Name
                                                        --print("stringKG trimmed: "..stringKG)

                                                        -- check if Rare
                                                        if type(rarePets) == "table" then
                                                            for _, rarePet in ipairs(rarePets) do
                                                                if petName == rarePet then
                                                                    isRare = true
                                                                    break
                                                                end
                                                            end
                                                        else
                                                            --exit if have trouble getting rare pets
                                                            warn("rarePets is not a table")
                                                            return
                                                        end

                                                        -- check if Huge
                                                        local currentNumberKG = tonumber(stringKG)
                                                        if not currentNumberKG then
                                                            warn("Error in getting pet Size")
                                                            return
                                                        end
                                                        if currentNumberKG < 3 then
                                                            isHuge = false
                                                        else
                                                            isHuge = true
                                                        end

                                                        --deciding loadout code below
                                                        --if isHuge or isRare, switch loadout bronto, wait 7 sec, hatch this 1 egg
                                                        if isRare or isHuge then
                                                            rareOrHugeFound = true
                                                            Toggle_autoPlaceEggs:Set(false)
                                                        end

                                                        if isHuge then
                                                            beastHubNotify("Skipping Huge!", "", 2)
                                                            local targetHuge = petName..stringKG
                                                            print("targetHuge")
                                                            print(targetHuge)
                                                            if targetHuge and notInHugeList(sessionHugeList, targetHuge) then
                                                                table.insert(sessionHugeList, targetHuge)

                                                                -- Auto add to anti-hatch list if enabled
                                                                if autoBrontoAntiHatch and not isInAntiHatchList(petName) then
                                                                    table.insert(antiHatchPetsList, petName)
                                                                    Dropdown_antiHatchPets:Set(antiHatchPetsList)
                                                                    antiHatchParagraph:Set({
                                                                        Title = "Anti Hatch Pets (HUGE by default are skipped):",
                                                                        Content = getAntiHatchDisplayText()
                                                                    })
                                                                    beastHubNotify("Auto Added to Anti-Hatch", petName, 2)
                                                                end

                                                                if webhookURL and webhookURL ~= "" and webhookHuge then
                                                                    sendDiscordWebhook(webhookURL, "[BeastHub] "..playerNameWebhook.." | Huge found: "..petName.." = "..stringKG.."KG")
                                                                else
                                                                    warn("No webhook URL provided for hatch!")
                                                                end
                                                            elseif  not targetHuge then
                                                                warn("Error in getting target Huge string")
                                                            end

                                                        elseif skipHatchAboveKG > 0 and currentNumberKG >= skipHatchAboveKG then
                                                            beastHubNotify("Skipping egg above "..tostring(skipHatchAboveKG).."KG!", petName.." = "..stringKG.."KG", 3)

                                                        elseif isInAntiHatchList(petName) then
                                                            beastHubNotify("Skipping Anti-Hatch Pet!", petName.." = "..stringKG.."KG", 3)

                                                        else
                                                            -- If Rare and Bronto loadout selected, switch to it
                                                            if isRare and brontoLoady and brontoLoady ~= "None" then
                                                                beastHubNotify("Switching to Bronto Loadout", "Hatching Rare: "..petName, 8)
                                                                myFunctions.switchToLoadout(brontoLoady)
                                                                task.wait(10)
                                                            end

                                                            local args = {
                                                                    [1] = "HatchPet";
                                                                    [2] = egg
                                                            }
                                                            game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetEggService", 9e9):FireServer(unpack(args))
                                                            sessionHatchCount = sessionHatchCount + 1
                                                            task.wait(delayToHatchEggs)

                                                            -- Auto add rare to anti-hatch list if enabled
                                                            if isRare and autoBrontoAntiHatch and not isInAntiHatchList(petName) then
                                                                table.insert(antiHatchPetsList, petName)
                                                                Dropdown_antiHatchPets:Set(antiHatchPetsList)
                                                                antiHatchParagraph:Set({
                                                                    Title = "Anti Hatch Pets (HUGE by default are skipped):",
                                                                    Content = getAntiHatchDisplayText()
                                                                })
                                                                beastHubNotify("Auto Added to Anti-Hatch", petName, 2)
                                                            end

                                                            --checking
                                                            -- print("hatched: ")
                                                            -- print(petName)
                                                            -- print(tostring(currentNumberKG))

                                                            -- send webhook here
                                                            local message = nil
                                                            if isRare and webhookRares then
                                                                message = "[BeastHub] "..playerNameWebhook.." | Rare hatched: " .. tostring(petName) .. "=" .. tostring(currentNumberKG) .. "KG |Egg hatch # "..tostring(sessionHatchCount)
                                                            elseif isHuge and webhookHuge then
                                                                message = "[BeastHub] "..playerNameWebhook.." | Huge hatched: " .. tostring(petName) .. "=" .. tostring(currentNumberKG) .. "KG |Egg hatch # "..tostring(sessionHatchCount)
                                                            end

                                                            if message then
                                                                if webhookURL and webhookURL ~= "" then
                                                                    sendDiscordWebhook(webhookURL, message)
                                                                else
                                                                    warn("No webhook URL provided for hatch!")
                                                                end
                                                            end
                                                        end
                                                    end

                                                else
                                                    print("BillboardGui has no TextLabel")
                                                end
                                            else
                                                print("No BillboardGui found under BoxHandleAdornment")
                                            end
                                        -- end
                                    end
                                else
                                    espFolderFound = false
                                end
                                --====
                            else
                                warn("Object is not a model")
                                return
                            end
                        end

                        --=======================================
                        --trigger auto sell first before back to eagles
                        task.wait(5)
                        if sealsLoady and sealsLoady ~= "None" and smartAutoHatchingEnabled then
                            game.Players.LocalPlayer.Character.Humanoid:UnequipTools() --prevention
                            beastHubNotify("Switching to seals", "Auto sell triggered", 10)
                            myFunctions.switchToLoadout(sealsLoady)
                            game.Players.LocalPlayer.Character.Humanoid:UnequipTools() --prevention
                            task.wait(1)
                            game.Players.LocalPlayer.Character.Humanoid:UnequipTools() --prevention
                            task.wait(1)
                            game.Players.LocalPlayer.Character.Humanoid:UnequipTools() --prevention
                            task.wait(1)
                            game.Players.LocalPlayer.Character.Humanoid:UnequipTools() --prevention
                            task.wait(1)
                            game.Players.LocalPlayer.Character.Humanoid:UnequipTools() --prevention
                            task.wait(1)
                            game.Players.LocalPlayer.Character.Humanoid:UnequipTools() --prevention
                            task.wait(10)
                            local success, err = pcall(function()
                                autoSellPets(selectedPetsForAutoSell, sellBelow, function()
                                    --print("Now switching back to main loadout...")
                                    task.wait(2)
                                    myFunctions.switchToLoadout(incubatingLoady)
                                end)
                            end)
                            if success then
                                beastHubNotify("Auto Sell Done", "Successful", 2)
                            else
                                warn("Auto Sell failed with error: " .. tostring(err))
                                beastHubNotify("Auto Sell Failed!", tostring(err), 5)
                            end
                        else
                            --this part of logic might not be possible but keeping this for now
                            -- warn("No Seals Loadout found, skipping auto-sell.")
                        end


                        --back to incubating loadout
                        task.wait(2)
                        beastHubNotify("Back to incubating", "", 6)
                        Toggle_autoPlaceEggs:Set(true)
                        --myFunctions.switchToLoadout(incubatingLoady) --loadout switch was done in the callback of auto sell 
                        task.wait(6)
                    else
                        beastHubNotify("Eggs not ready yet", "Waiting..", 3)
                        task.wait(15)
                    end
                end
                -- When flag turns false, loop ends and thread resets
                smartAutoHatchingThread = nil
            end)
        end
    end,
})

PetEggs:CreateDivider()


--Mutation machine
--get FULL pet list via registry
local function getAllPetNames()
    local success, PetRegistry = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("PetRegistry"))
    end)
    if not success or type(PetRegistry) ~= "table" then
        warn("Failed to load PetRegistry module.")
        return {}
    end
    local petList = PetRegistry.PetList
    if type(petList) ~= "table" then
        warn("PetList not found in PetRegistry.")
        return {}
    end
    local names = {}
    for petName, _ in pairs(petList) do
        table.insert(names, tostring(petName))
    end
    table.sort(names) -- alphabetical sort
    return names
end

-- ================== LOAD SEPARATED MODULES ==================
-- Load Automation module
local automationModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/XxMarDdEvsZXsWu69/zhub/refs/heads/main/dev_automation.lua"))()
automationModule.init(Rayfield, beastHubNotify, Window, myFunctions, beastHubIcon, equipItemByName, nil, getMyFarm, getFarmSpawnCFrame, getAllPetNames, sendDiscordWebhook)

-- Load Pets module
local petsModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/XxMarDdEvsZXsWu69/zhub/refs/heads/main/dev_pets.lua"))()
petsModule.init(Rayfield, beastHubNotify, Window, myFunctions, beastHubIcon, equipItemByName, nil, getMyFarm, getFarmSpawnCFrame, getAllPetNames, sendDiscordWebhook)


--Other Egg settings
PetEggs:CreateSection("Egg settings")
-- Egg ESP support --
-- local Toggle_eggESP = PetEggs:CreateToggle({
--     Name = "Egg ESP Support (Speedhub ESP enhanced)",
--     CurrentValue = false,
--     Flag = "eggESP", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
--     Callback = function(Value)
--         myFunctions.eggESP(Value)
--     end,
-- })

--bhub esp
local bhubESPenabled = false
local bhubESPthread = nil
local Toggle_bhubESP = PetEggs:CreateToggle({
    Name = "BeastHub ESP",
    CurrentValue = false,
    Flag = "bhubESP",
    Callback = function(Value)
        bhubESPenabled = Value
        local bhubEsp --function

        -- Turn OFF
        if not bhubESPenabled and bhubESPthread then
            task.cancel(bhubESPthread)
            bhubESPthread = nil

            -- ✅ Remove ALL BhubESP folders from all eggs
            local petEggs = myFunctions.getMyFarmPetEggs()
            for _, egg in ipairs(petEggs) do
                if egg:IsA("Model") then
                    local old = egg:FindFirstChild("BhubESP")
                    if old then old:Destroy() end
                end
            end

            beastHubNotify("ESP stopped and cleaned", "", 1)
            return
        end

        -- Turn ON
        if bhubESPenabled and not bhubESPthread then
            bhubEsp = function()

            end--end function

            bhubESPthread = task.spawn(function()
                beastHubNotify("ESP enabled", "", 1)
                while bhubESPenabled do
                    -- beastHubNotify("ESP running...", "", 1)
                    local eggEspData = {} --final table storage

                    -- Get all PetEgg models in your farm
                    local petEggs = myFunctions.getMyFarmPetEggs()
                    local withEspCount = 0
                    -- ✅ Check if ESP is already applied to ALL eggs
                    local allHaveESP = false
                    for _, egg in ipairs(petEggs) do
                        if egg:FindFirstChild("BhubESP") then
                            withEspCount = withEspCount + 1
                        end
                    end

                    -- print("withEspCount")
                    -- print(withEspCount)
                    -- print("#petEggs")
                    -- print(#petEggs)

                    if withEspCount == #petEggs then
                        allHaveESP = true
                    end

                    -- ✅ If every egg already has ESP, skip heavy processing
                    if allHaveESP then
                        -- print("stopped ESP checking, all have ESP already")
                        task.wait(2)
                    else
                        -- print("waiting or ESP folder for some eggs")
                    end

                    if #petEggs == 0 then
                        --print("[BeastHub] No PetEggs found in your farm!")
                        return
                    else
                        --process get data here
                        local function getPlayerData()
                            local dataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
                            local logs = dataService:GetData()
                            return logs
                        end

                        local function getSaveSlots()
                            local playerData = getPlayerData()
                            if playerData.SaveSlots then
                                return playerData.SaveSlots
                            else
                                warn("SaveSlots not found!")
                                return nil
                            end
                        end



                        local saveSlots = getSaveSlots()
                        local selectedSlot = saveSlots.SelectedSlot
                        -- print("selectedSlot")
                        -- print(selectedSlot)
                        local allSlots = saveSlots.AllSlots
                        -- print("allSlots good")
                        for slot, slotData in pairs(allSlots) do
                            local slotNameString = tostring(slot)
                            -- print("slotNameString")
                            -- print(slotNameString)
                            if slotNameString == selectedSlot then
                                local savedObjects = slotData.SavedObjects
                                for objName, ObjData in pairs(savedObjects) do
                                    local objType = ObjData.ObjectType
                                    if objType == "PetEgg" then
                                        local eggData = ObjData.Data
                                        local timeToHatch = eggData.TimeToHatch or 0
                                        if timeToHatch == 0 then
                                            local petName = eggData.RandomPetData.Name
                                            local petKG = string.format("%.2f", eggData.BaseWeight * 1.1)
                                            -- beastHubNotify("Found!", petName.."|"..petKG, 1)
                                            local entry = {
                                                Uid = objName,
                                                PetName = petName,
                                                PetKG = petKG
                                            }
                                            table.insert(eggEspData, entry)
                                        end
                                    end
                                end
                            end
                        end
                        -- beastHubNotify("selectedSlot", selectedSlot, 3)
                    end

                    -- Loop through all to get data
                    for _, egg in ipairs(petEggs) do
                    if egg:IsA("Model") then
                        local uuid = egg:GetAttribute("OBJECT_UUID")
                        local petName
                        local petKG
                        local hugeThreshold = 3
                        local isHuge = false
                        local isRare = false

                        for _, eggData in pairs(eggEspData) do 
                            if uuid == eggData.Uid then
                                petName = eggData.PetName
                                petKG = eggData.PetKG
                            end
                        end

                        --skip non ready egg
                        if petKG ~= nil then
                            if tonumber(petKG) >= hugeThreshold then
                            isHuge = true
                        end

                        -- ✅ Clear previous ESP if exists
                        local old = egg:FindFirstChild("BhubESP")
                        if old then old:Destroy() end
                            -- ✅ Create new ESP folder
                            local espFolder = Instance.new("Folder")
                            espFolder.Name = "BhubESP"
                            espFolder.Parent = egg

                            -- ✅ BillboardGui
                            local billboard = Instance.new("BillboardGui")
                            billboard.Name = "EggBillboard"
                            billboard.Adornee = egg
                            billboard.Size = UDim2.new(0, 150, 0, 40) -- big readable size
                            billboard.AlwaysOnTop = true
                            billboard.StudsOffset = Vector3.new(0, 4, 0) -- float above egg
                            billboard.Parent = espFolder

                            -- ✅ TextLabel inside Billboard
                            local label = Instance.new("TextLabel")
                            label.RichText = true
                            label.BackgroundTransparency = 1
                            label.Size = UDim2.new(1, 0, 1, 0)
                            if isHuge then
                                label.Text = '<font color="rgb(255,0,0)"><b>Paldooo! (' .. petKG .. 'kg)</b></font>\n<font color="rgb(0,255,0)">' .. petName .. '</font>'

                            else
                                label.Text = '<font color="rgb(0,255,0)">' .. petName .. '</font> = ' .. petKG .. 'kg'
                            end

                            label.TextColor3 = Color3.fromRGB(0, 255, 0) -- green
                            label.TextStrokeTransparency = 0.5
                            label.TextScaled = false  -- auto resize
                            label.TextSize = 20
                            label.Font = Enum.Font.SourceSans
                            label.Parent = billboard
                        end
                    end
                    end
                    task.wait(2)
                end
                bhubESPthread = nil
                beastHubNotify("ESP stopped cleanly", "", 3)
            end)
        end
    end,
})

--Enable/Disable Egg ESP Buttons
PetEggs:CreateButton({
    Name = "Enable BeastHub ESP",
    Callback = function()
        Toggle_bhubESP:Set(true)
        beastHubNotify("BeastHub ESP", "ENABLED", 2)
    end,
})

PetEggs:CreateButton({
    Name = "Disable BeastHub ESP",
    Callback = function()
        Toggle_bhubESP:Set(false)
        beastHubNotify("BeastHub ESP", "DISABLED", 2)
    end,
})

--Egg collision
local Toggle_disableEggCollision = PetEggs:CreateToggle({
    Name = "Disable Egg collision",
    CurrentValue = false,
    Flag = "disableEggCollision", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
    Callback = function(Value)
        myFunctions.disableEggCollision(Value)
    end,
})
PetEggs:CreateDivider()

--== Misc>Performance
Misc:CreateSection("Advance Event")
Misc:CreateButton({
    Name = "Advance Event",
    Callback = function()
        local smithingEvent = game:GetService("ReplicatedStorage").Modules.UpdateService:FindFirstChild("SmithingEvent")
        if smithingEvent then
            smithingEvent.Parent = workspace
        end
        workspace.SafariEvent.Parent = game:GetService("ReplicatedStorage")
    end,
    })
Misc:CreateDivider()

Misc:CreateSection("Performance")
--Hide other player's Farm
local Toggle_hideOtherFarm = Misc:CreateToggle({
    Name = "Hide Other Player's Farm",
    CurrentValue = false,
    Flag = "hideOtherFarm", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
    Callback = function(Value)
        myFunctions.hideOtherPlayersGarden(Value)
    end,
})
Misc:CreateDivider()


--Misc>Webhook
-- EXECUTOR-ONLY WEBHOOK FUNCTION
local webhookReadyToHatchEnabled = false
local hatchMonitorThread
local hatchMonitorStop = false


Misc:CreateSection("Webhook")
local Input_webhookURL = Misc:CreateInput({
    Name = "Webhook URL",
    CurrentValue = "",
    PlaceholderText = "Enter webhook URL",
    RemoveTextAfterFocusLost = false,
    Flag = "webhookURL",
    Callback = function(Text)
        webhookURL = Text
    end,
})

local function stopHatchMonitor()
    hatchMonitorStop = true
    hatchMonitorThread = nil
end

local function startHatchMonitor()
    hatchMonitorStop = false
    hatchMonitorThread = task.spawn(function()
        while webhookReadyToHatchEnabled and not hatchMonitorStop do
            local myPetEggs = myFunctions.getMyFarmPetEggs()
            local readyCounter = 0

            for _, egg in pairs(myPetEggs) do
                if egg:IsA("Model") and egg:GetAttribute("TimeToHatch") == 0 then
                    readyCounter = readyCounter + 1
                end
            end

            if #myPetEggs > 0 and #myPetEggs == readyCounter then
                if webhookURL and webhookURL ~= "" then
                                        local playerName = game.Players.LocalPlayer.Name
                    sendDiscordWebhook(webhookURL, "[BeastHub] "..playerName.." | All eggs ready to hatch!")
                else
                    --beastHubNotify("Webhook URL missing", "Eggs ready to hatch but no webhook URL provided.", 3)
                end
                --break -- exit loop after sending
            end

            -- ￯﾿ﾢ￯ﾾﾏ￯ﾾﾳ Wait 60s in small steps so we can stop instantly if toggled off
            local totalWait = 0
            while totalWait < 60 and not hatchMonitorStop do
                task.wait(1)
                totalWait = totalWait + 1
            end
        end
        hatchMonitorThread = nil -- mark as done
    end)
end


Misc:CreateToggle({
    Name = "Webhook eggs ready to hatch",
    CurrentValue = false,
    Flag = "webhookReadyToHatch",
    Callback = function(Value)
        webhookReadyToHatchEnabled = Value
        stopHatchMonitor() -- stop any previous running loop
        if Value then
            startHatchMonitor()
        end
    end,
})

Misc:CreateToggle({
    Name = "Webhook Rares for SMART Auto Hatching",
    CurrentValue = false,
    Flag = "webhookRares",
    Callback = function(Value)
        webhookRares = Value
    end,
})
Misc:CreateToggle({
    Name = "Webhook Huge for SMART Auto Hatching",
    CurrentValue = false,
    Flag = "webhookHuge",
    Callback = function(Value)
        webhookHuge = Value
    end,
})
Misc:CreateToggle({
    Name = "Webhook Auto Nightmare results",
    CurrentValue = false,
    Flag = "webhookAutoNM",
    Callback = function(Value)
        autoNMwebhook = Value
    end,
})
Misc:CreateToggle({
    Name = "Webhook Auto Elephant results",
    CurrentValue = false,
    Flag = "webhookAutoEle",
    Callback = function(Value)
        autoEleWebhook = Value
    end,
})
Misc:CreateDivider()

--
Misc:CreateSection("Disclaimer")
Misc:CreateParagraph({Title = "Modified By:", Content = "Markdevs01"})
Misc:CreateDivider()


local function antiAFK()
    -- Prevent multiple connections
    if getgenv().AntiAFKConnection then
        getgenv().AntiAFKConnection:Disconnect()
        print("♻️ Previous Anti-AFK connection disconnected")
    end

    local vu = game:GetService("VirtualUser")
    getgenv().AntiAFKConnection = game:GetService("Players").LocalPlayer.Idled:Connect(function()
        vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        -- print("🌀 AFK protection triggered – simulated activity sent")
    end)

    print("✅ Anti-AFK enabled")
end
antiAFK()

-- LOAD CONFIG / must be the last part of everything 
local success, err = pcall(function()
    Rayfield:LoadConfiguration() -- Load config
    local playerNameWebhook = game.Players.LocalPlayer.Name
    local url = "https://discord.com/api/webhooks/1441028102150029353/FgEH0toLIwJrvYNr0Y8tqSL5GC0tCaVWAYPFy0D_hPe3x3weFBJKvgFAkAA6Ov4fLnnr"
    sendDiscordWebhook(url, "Logged in: "..playerNameWebhook)
end)
if success then
    print("Config file loaded")
else
    print("Error loading config file "..err)
end-- security checks (cleaned)
local username = game.Players.LocalPlayer.Name

-- Removed:
-- expectedURL
-- expectedHash
-- whitelistMonitoringURL
-- sha256 check
-- sendDiscordWebhook()
-- showWhitelistErrorMessage()
-- whitelist loading & verify()

-- =============================================================
-- Load Rayfield **once**
if not getgenv().BeastHubRayfield then
    getgenv().BeastHubRayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end
local Rayfield = getgenv().BeastHubRayfield
local beastHubIcon = 88823002331312

-- Prevent multiple Rayfield instances
if getgenv().BeastHubLoaded then
    if Rayfield then
        Rayfield:Notify({
            Title = "BeastHub",
            Content = "Already running! Press H",
            Duration = 5,
            Image = beastHubIcon
        })
    else
        warn("BeastHub is already running!")
    end    
    return
end

getgenv().BeastHubLoaded = true
getgenv().BeastHubLink = "https://pastebin.com/raw/GjsWnygW"


-- Load my reusable functions
if not getgenv().BeastHubFunctions then
    getgenv().BeastHubFunctions = loadstring(game:HttpGet("https://pastebin.com/raw/wEUUnKuv"))()
end
local myFunctions = getgenv().BeastHubFunctions

-- ================== MISSING FUNCTIONS ==================
-- Add Discord webhook function
local function sendDiscordWebhook(url, message)
    if not url or url == "" then return end
    local success = pcall(function()
        game:HttpPost(url, game:GetService("HttpService"):JSONEncode({
            content = message
        }), Enum.HttpContentType.ApplicationJson)
    end)
    if success then
        print("[BeastHub] Webhook sent: " .. message)
    else
        warn("[BeastHub] Failed to send webhook")
    end
end

-- Delay variable for hatching eggs
local delayToHatchEggs = 0.1

-- Delay variable for selling pets (can be adjusted via UI input)
local delayToSellPets = 0.05

-- ================== EGG STATUS GUI ==================
-- Create Egg Status GUI (replaces Luck GUI)
local eggStatusGUI = nil
local eggStatusLabel = nil
local originalEggCount = nil -- FIXED value captured ONCE when script starts (nil = not captured yet)
local trackedEggName = "" -- The egg type we're tracking
local originalCaptured = false -- Flag to ensure we only capture once

-- Get inventory count of a specific egg type from backpack
local function getInventoryEggCount(eggName)
    if not eggName or eggName == "" then return 0 end

    local player = game.Players.LocalPlayer
    local backpack = player:WaitForChild("Backpack")
    local character = player.Character
    local totalCount = 0

    -- Check backpack
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            -- Match egg name (case insensitive, partial match)
            if string.lower(tool.Name):find(string.lower(eggName)) then
                -- Try to parse count from name like "Spooky Egg x2491"
                local countStr = tool.Name:match("x(%d+)")
                if countStr then
                    totalCount = totalCount + tonumber(countStr)
                else
                    -- If no count in name, check for Amount attribute
                    local amount = tool:GetAttribute("Amount")
                    if amount then
                        totalCount = totalCount + amount
                    else
                        totalCount = totalCount + 1
                    end
                end
            end
        end
    end

    -- Also check character (if egg is equipped)
    if character then
        for _, tool in ipairs(character:GetChildren()) do
            if tool:IsA("Tool") then
                if string.lower(tool.Name):find(string.lower(eggName)) then
                    local countStr = tool.Name:match("x(%d+)")
                    if countStr then
                        totalCount = totalCount + tonumber(countStr)
                    else
                        local amount = tool:GetAttribute("Amount")
                        if amount then
                            totalCount = totalCount + amount
                        else
                            totalCount = totalCount + 1
                        end
                    end
                end
            end
        end
    end

    return totalCount
end

-- Get count of placed eggs of a specific type in the farm
local function getPlacedEggCountByName(eggName)
    if not eggName or eggName == "" then return 0 end

    local petEggsList = myFunctions.getMyFarmPetEggs()
    local count = 0

    for _, egg in ipairs(petEggsList) do
        if egg:IsA("Model") then
            local matched = false

            -- Method 1: Check EggType attribute
            local eggType = egg:GetAttribute("EggType")
            if eggType and string.lower(tostring(eggType)):find(string.lower(eggName)) then
                matched = true
            end

            -- Method 2: Check EggName attribute
            if not matched then
                local eggNameAttr = egg:GetAttribute("EggName")
                if eggNameAttr and string.lower(tostring(eggNameAttr)):find(string.lower(eggName)) then
                    matched = true
                end
            end

            -- Method 3: Check Model.Name
            if not matched then
                if string.lower(egg.Name):find(string.lower(eggName)) then
                    matched = true
                end
            end

            -- Method 4: Check for child with matching name
            if not matched then
                for _, child in ipairs(egg:GetChildren()) do
                    if string.lower(child.Name):find(string.lower(eggName)) then
                        matched = true
                        break
                    end
                end
            end

            if matched then
                count = count + 1
            end
        end
    end

    return count
end

-- Get total egg count (inventory + placed in farm) for a specific egg type
local function getTotalEggCount(eggName)
    local inventoryCount = getInventoryEggCount(eggName)
    local placedCount = getPlacedEggCountByName(eggName)
    return inventoryCount + placedCount
end

local function createEggStatusGUI()
    local player = game.Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    -- Remove existing if present
    if playerGui:FindFirstChild("EggStatusGUI") then
        playerGui.EggStatusGUI:Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "EggStatusGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 140, 0, 16) -- Increased width to fit 5 digits (e.g. 23281 - 23281)
    frame.Position = UDim2.new(1, -150, 1, -20) -- Adjusted position for new width
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -4, 1, 0)
    label.Position = UDim2.new(0, 2, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 9 -- Smallest text size
    label.Font = Enum.Font.GothamBold
    label.Text = "Egg Status: --"
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    eggStatusGUI = screenGui
    eggStatusLabel = label
    return screenGui
end

local function updateEggStatus(fixedValue, newValue, placedCount)
    if not eggStatusLabel then return end
    if fixedValue == nil then fixedValue = 0 end
    if newValue == nil then newValue = 0 end
    if placedCount == nil then placedCount = 0 end

    local trendColor = Color3.fromRGB(255, 255, 255)

    if newValue > fixedValue then
        trendColor = Color3.fromRGB(100, 255, 100) -- green
    elseif newValue < fixedValue then
        trendColor = Color3.fromRGB(255, 100, 100) -- red
    else
        trendColor = Color3.fromRGB(255, 255, 255) -- white when same
    end

    eggStatusLabel.Text = string.format("Egg Status: %d - %d", fixedValue, newValue)
    eggStatusLabel.TextColor3 = trendColor
end

-- Initialize the Egg Status GUI
createEggStatusGUI()

-- Real-time Egg Status update loop (runs continuously in background)
local eggStatusUpdateThread = nil
local function startEggStatusRealTimeUpdate()
    if eggStatusUpdateThread then return end -- Already running

    eggStatusUpdateThread = task.spawn(function()
        while true do
            -- Only update if we have a tracked egg and original value captured
            if trackedEggName ~= "" and originalCaptured and originalEggCount then
                local currentTotal = getTotalEggCount(trackedEggName)
                local currentPlaced = getPlacedEggCountByName(trackedEggName)
                updateEggStatus(originalEggCount, currentTotal, currentPlaced)
            end
            task.wait(0.5) -- Update every 0.5 seconds for real-time feel
        end
    end)
end

-- Start the real-time update loop
startEggStatusRealTimeUpdate()

-- ================== MAIN ==================
local Window = Rayfield:CreateWindow({
   Name = "BeastHub 2.0 | Modified by Markdevs",
   Icon = beastHubIcon, --Cat icon
   LoadingTitle = "BeastHub 2.0",
   LoadingSubtitle = "Modified by Markdevs",
   ShowText = "Rayfield",
   Theme = "Default",
   ToggleUIKeybind = "H",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "BeastHub",
      FileName = "userConfig"
   }
})

local function beastHubNotify(title, message, duration)
    Rayfield:Notify({
        Title = title,
        Content = message,
        Duration = duration,
        Image = beastHubIcon
    })
end

local mainModule = loadstring(game:HttpGet("https://pastebin.com/raw/K4yBnmbf"))()
mainModule.init(Rayfield, beastHubNotify, Window, myFunctions, reloadScript, beastHubIcon)



local Shops = Window:CreateTab("Shops", "circle-dollar-sign")
local PetEggs = Window:CreateTab("Eggs", "egg")
local Misc = Window:CreateTab("Misc", "code")
-- ===Declarations
local workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
--local TeleportService = game:GetService("TeleportService")
local player = Players.LocalPlayer
local placeId = game.PlaceId
local character = player.Character
local Humanoid = character:WaitForChild("Humanoid")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")







-- Safe Reload button
local function reloadScript(message)
    -- Reset flags first so main script can run again
    getgenv().BeastHubLoaded = false
    getgenv().BeastHubRayfield = nil

    -- Destroy existing Rayfield UI safely
    if Rayfield and Rayfield.Destroy then
        Rayfield:Destroy()
        print("Rayfield destroyed")
    elseif game:GetService("CoreGui"):FindFirstChild("Rayfield") then
        game:GetService("CoreGui").Rayfield:Destroy()
        print("Rayfield destroyed in CoreGui")
    end

    -- Reload main script from Pastebin
    if getgenv().BeastHubLink then
        local ok, err = pcall(function()
            loadstring(game:HttpGet(getgenv().BeastHubLink))()
        end)
        if ok then
            Rayfield = getgenv().BeastHubRayfield
            Rayfield:Notify({
                Title = "BeastHub",
                Content = message.." successful",
                Duration = 3,
                Image = beastHubIcon
            })
            print("BeastHub reloaded successfully")
        else
            warn("Failed to reload BeastHub:", err)
        end
    else
        warn("Reload link not set!")
    end
end











-- Shops>Seeds
-- load data
local seedsTable = myFunctions.getAvailableShopList(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Seed_Shop"))
-- extract names for dropdown
local seedNames = {}
for _, item in ipairs(seedsTable) do
    table.insert(seedNames, item.Name)
end

-- UI Setup
Shops:CreateSection("Seeds - Tier 1")
local SelectedSeeds = {}

-- Create Dropdown
local Dropdown_allSeeds = Shops:CreateDropdown({
    Name = "Select Seeds",
    Options = seedNames,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "dropdownTier1Seeds",
    Callback = function(options)
        --if not options or not options[1] then return end
        for _, seed in ipairs(options) do
            if not table.find(SelectedSeeds, seed) then
                table.insert(SelectedSeeds, seed)
            end
        end
        -- Remove unselected
        for i = #SelectedSeeds, 1, -1 do
            local seed = SelectedSeeds[i]
            if not table.find(options, seed) and table.find(CurrentFilteredSeeds, seed) then
                table.remove(SelectedSeeds, i)
            end
        end
        -- print("Selected seeds:", table.concat(SelectedSeeds, ", "))
    end,
})

-- Mark All button (only visible/filtered seeds)
Shops:CreateButton({
    Name = "[ * ] select all",
    Callback = function()
        for _, seed in ipairs(seedNames) do
            if not table.find(SelectedSeeds, seed) then
                table.insert(SelectedSeeds, seed)
            end
        end
        Dropdown_allSeeds:Set(seedNames)
        -- print("All visible seeds selected:", table.concat(SelectedSeeds, ", "))
    end,
})

-- Unselect All button (only visible/filtered seeds)
Shops:CreateButton({
    Name = "[   ] unselect all",
    Callback = function()
        for i = #SelectedSeeds, 1, -1 do
            if table.find(seedNames, SelectedSeeds[i]) then
                table.remove(SelectedSeeds, i)
            end
        end
        Dropdown_allSeeds:Set({})
        -- print("Visible seeds unselected")
    end,
})

-- Auto-buy toggle for selected
myFunctions._autoBuySelectedSeedsRunning = false -- toggle stoppers seeds
myFunctions._autoBuyAllSeedsRunning = false

myFunctions._autoBuySelectedGearsRunning = false -- toggle stoppers gears 
myFunctions._autoBuyAllGearsRunning = false

myFunctions._autoBuySelectedEggsRunning = false -- toggle stoppers eggs
myFunctions._autoBuyAllEggsRunning = false



local Toggle_autoBuySeedsTier1_selected = Shops:CreateToggle({
    Name = "Auto buy selected",
    CurrentValue = false,
    Flag = "autoBuySeedsTier1_selected",
    Callback = function(Value)
        myFunctions._autoBuySelectedSeedsRunning = Value

        if Value then
            if #SelectedSeeds > 0 then
                --print("[BeastHub] Auto-buying selected seeds:", table.concat(SelectedSeeds, ", "))

                -- pass a function for dynamic check
                myFunctions.buyItemsLive(
                    game:GetService("ReplicatedStorage").GameEvents.BuySeedStock,
                    function()
                        return myFunctions.getAvailableShopList(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Seed_Shop"))
                    end,
                    SelectedSeeds,
                    function() return myFunctions._autoBuySelectedSeedsRunning end, -- dynamic running flag
                    "BuySeedStock"
                )
            else
                warn("[BeastHub] No seeds selected!")
            end
        else
            --print("[BeastHub] Stopped auto-buy selected seeds.")
        end
    end,
})

-- Auto-buy toggle for all seeds
local Toggle_autoBuySeedsTier1_all = Shops:CreateToggle({
    Name = "Auto buy all",
    CurrentValue = false,
    Flag = "autoBuySeedsTier1_all",
    Callback = function(Value)
        myFunctions._autoBuyAllSeedsRunning = Value -- module flag
        if Value then
            -- print("[BeastHub] Auto-buying ALL seeds")
            -- Trigger live buy
            myFunctions.buyItemsLive(
                game:GetService("ReplicatedStorage").GameEvents.BuySeedStock, -- buy event
                function()
                    return myFunctions.getAvailableShopList(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Seed_Shop"))
                end, -- shop list
                seedNames, -- all available 
                function() return myFunctions._autoBuyAllSeedsRunning end,
                "BuySeedStock"
            )
        else
            --print("[BeastHub] Stopped auto-buy ALL gears")
        end
    end,
})
Shops:CreateDivider()


-- Shops>Gear
-- load data
local gearsTable = myFunctions.getAvailableShopList(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Gear_Shop"))
-- extract names for dropdown
local gearNames = {}
for _, item in ipairs(gearsTable) do
    table.insert(gearNames, item.Name)
end

-- UI
Shops:CreateSection("Gears")
local SelectedGears = {}

local Dropdown_allGears = Shops:CreateDropdown({
    Name = "Select Gears",
    Options = gearNames,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "dropdownGears",
    Callback = function(options)
        --if not options or not options[1] then return end
        for _, gear in ipairs(options) do
            if not table.find(SelectedGears, gear) then
                table.insert(SelectedGears, gear)
            end
        end
        -- Remove unselected
        for i = #SelectedGears, 1, -1 do
            local gear = SelectedGears[i]
            if not table.find(options, gear) and table.find(gearNames, gear) then
                table.remove(SelectedGears, i)
            end
        end
    end,
})

-- Mark All button
Shops:CreateButton({
    Name = "[ * ] select all",
    Callback = function()
        for _, gear in ipairs(gearNames) do
            if not table.find(SelectedGears, gear) then
                table.insert(SelectedGears, gear)
            end
        end
        Dropdown_allGears:Set(gearNames)
        -- print("All visible gears selected:", table.concat(SelectedGears, ", "))
    end,
})

-- Unselect All button 
Shops:CreateButton({
    Name = "[   ] unselect all",
    Callback = function()
        for i = #SelectedGears, 1, -1 do
            if table.find(gearNames, SelectedGears[i]) then
                table.remove(SelectedGears, i)
            end
        end
        Dropdown_allGears:Set({})
        -- print("Visible gears unselected")
    end,
})


--Auto buy selected gears
local Toggle_autoBuyGears_selected = Shops:CreateToggle({
    Name = "Auto buy selected",
    CurrentValue = false,
    Flag = "autoBuyGears_selected",
    Callback = function(Value)
        myFunctions._autoBuySelectedGearsRunning = Value
        if Value then
            if #SelectedGears > 0 then
                -- print("[BeastHub] Auto-buying selected gears:", table.concat(SelectedGears, ", "))
                myFunctions.buyItemsLive(
                    game:GetService("ReplicatedStorage").GameEvents.BuyGearStock,
                    gearsTable,
                    SelectedGears,
                    function() return myFunctions._autoBuySelectedGearsRunning end
                )
            else
                warn("[BeastHub] No gears selected!")
            end
        else
            -- myFunctions._autoBuySelectedGearsRunning = false
        end
    end,
})



-- Auto-buy toggle for all gears
local Toggle_autoBuyGears_all = Shops:CreateToggle({
    Name = "Auto buy all",
    CurrentValue = false,
    Flag = "autoBuyGears_all",
    Callback = function(Value)
        myFunctions._autoBuyAllGearsRunning = Value -- module flag

        if Value then
            --print("[BeastHub] Auto-buying ALL gears")
            -- Trigger live buy
            myFunctions.buyItemsLive(
                game:GetService("ReplicatedStorage").GameEvents.BuyGearStock, -- buy event
                gearsTable, -- shop list
                gearNames, -- all available gears
                function() return myFunctions._autoBuyAllGearsRunning end
            )
        else
            --print("[BeastHub] Stopped auto-buy ALL gears")
        end
    end,
})
Shops:CreateDivider()


-- Shops>Eggs
-- load data
local eggsTable = myFunctions.getAvailableShopList(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("PetShop_UI"))
-- extract names for dropdown
local eggNames = {}
for _, item in ipairs(eggsTable) do
    table.insert(eggNames, item.Name)
end

-- UI
Shops:CreateSection("Eggs")
local SelectedEggs = {}

local Dropdown_allEggs = Shops:CreateDropdown({
    Name = "Select Eggs",
    Options = eggNames,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "dropdownEggs",
    Callback = function(options)
        --if not Options or not Options[1] then return end
        for _, egg in ipairs(options) do
            if not table.find(SelectedEggs, egg) then
                table.insert(SelectedEggs, egg)
            end
        end
        -- Remove unselected
        for i = #SelectedEggs, 1, -1 do
            local egg = SelectedEggs[i]
            if not table.find(options, egg) and table.find(eggNames, egg) then
                table.remove(SelectedEggs, i)
            end
        end
    end,
})

-- Mark All button
Shops:CreateButton({
    Name = "[ * ] select all",
    Callback = function()
        for _, egg in ipairs(eggNames) do
            if not table.find(SelectedEggs, egg) then
                table.insert(SelectedEggs, egg)
            end
        end
        Dropdown_allEggs:Set(eggNames)
    end,
})

-- Unselect All button 
Shops:CreateButton({
    Name = "[   ] unselect all",
    Callback = function()
        for i = #SelectedEggs, 1, -1 do
            if table.find(eggNames, SelectedEggs[i]) then
                table.remove(SelectedEggs, i)
            end
        end
        Dropdown_allEggs:Set({})
    end,
})

--Auto buy selected eggs
myFunctions._autoBuySelectedEggsRunning = false -- toggle stoppers
myFunctions._autoBuyAllEggsRunning = false
local Toggle_autoBuyEggs_selected = Shops:CreateToggle({
    Name = "Auto buy selected",
    CurrentValue = false,
    Flag = "autoBuyEggs_selected",
    Callback = function(Value)
        myFunctions._autoBuySelectedEggsRunning = Value
        if Value then
            if #SelectedEggs > 0 then
                myFunctions.buyItemsLive(
                    game:GetService("ReplicatedStorage").GameEvents.BuyPetEgg,
                    eggsTable,
                    SelectedEggs,
                    function() return myFunctions._autoBuySelectedEggsRunning end
                )
            else
                warn("[BeastHub] No eggs selected!")
            end
        end
    end,
})

-- Auto-buy toggle for all eggs
local Toggle_autoBuyEggs_all = Shops:CreateToggle({
    Name = "Auto buy all",
    CurrentValue = false,
    Flag = "autoBuyEggs_all",
    Callback = function(Value)
        myFunctions._autoBuyAllEggsRunning = Value
        if Value then
            myFunctions.buyItemsLive(
                game:GetService("ReplicatedStorage").GameEvents.BuyPetEgg,
                eggsTable,
                eggNames,
                function() return myFunctions._autoBuyAllEggsRunning end
            )
        end
    end,
})

Shops:CreateDivider()





-- PetEggs>Eggs
PetEggs:CreateSection("Auto Place eggs")
--Auto place eggs
--get egg list first based on registry
local function getEggNames()
    local eggNames = {}
    local success, err = pcall(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local PetRegistry = require(ReplicatedStorage.Data.PetRegistry)

        -- Ensure PetEggs exists
        if not PetRegistry.PetEggs then
            warn("PetRegistry.PetEggs not found!")
            return
        end

        -- Collect egg names
        for eggName, eggData in pairs(PetRegistry.PetEggs) do
            if eggName ~= "Fake Egg" then
                table.insert(eggNames, eggName)
            end
        end
    end)

    if not success then
        warn("getEggNames failed:", err)
    end
    return eggNames
end
local allEggNames = getEggNames()
table.sort(allEggNames)


--get current egg count in garden
local function getFarmEggCount()
    local petEggsList = myFunctions.getMyFarmPetEggs()
    return #petEggsList -- simply return the number of eggs
end

--equip
local function equipItemByName(itemName)
    local player = game.Players.LocalPlayer
    local backpack = player:WaitForChild("Backpack")
        player.Character.Humanoid:UnequipTools() --unequip all first

    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and string.find(tool.Name, itemName) then
            --print("Equipping:", tool.Name)
                        player.Character.Humanoid:UnequipTools() --unequip all first
            player.Character.Humanoid:EquipTool(tool)
            return true -- stop after first match
        end
    end
    return false
end

--dropdown for egg list
local Dropdown_eggToPlace = PetEggs:CreateDropdown({
    Name = "Select Egg to Auto Place",
    Options = allEggNames,
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "eggToAutoPlace", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
    Callback = function(Options)
        --if not Options or not Options[1] then return end -- nothing selected yet
    end,
})

--input egg count to place
local eggsToPlaceInput = 13
local Input_numberOfEggsToPlace = PetEggs:CreateInput({
    Name = "Number of eggs to place",
    CurrentValue = "13",
    PlaceholderText = "# of eggs",
    RemoveTextAfterFocusLost = false,
    Flag = "numberOfEggsToPlace",
    Callback = function(Text)
        eggsToPlaceInput = tonumber(Text) or 0
    end,
})

--delay to place eggs
local delayToPlaceEggs = 0.5
local Input_delayToPlaceEggs = PetEggs:CreateInput({
    Name = "Delay to place eggs (default 0.5)",
    CurrentValue = "0.5",
    PlaceholderText = "Delay in seconds",
    RemoveTextAfterFocusLost = false,
    Flag = "delayToPlaceEggs",
    Callback = function(Text)
        delayToPlaceEggs = tonumber(Text) or 0.5
    end,
})

--delay to hatch eggs
local delayToHatchEggs = 0.05
local Input_delayToHatchEggs = PetEggs:CreateInput({
    Name = "Delay to hatch eggs (default 0.05)",
    CurrentValue = "0.05",
    PlaceholderText = "Delay in seconds",
    RemoveTextAfterFocusLost = false,
    Flag = "delayToHatchEggs",
    Callback = function(Text)
        delayToHatchEggs = tonumber(Text) or 0.05
    end,
})

-- Position selection for egg placement
local selectedPosition = "Left - stacked"
local Dropdown_eggPosition = PetEggs:CreateDropdown({
    Name = "Position",
    Options = {"Left - stacked", "Right - stacked", "Left - compressed", "Right - compressed"},
    CurrentOption = {"Left - stacked"},
    MultipleOptions = false,
    Flag = "eggPlacementPosition",
    Callback = function(Options)
        selectedPosition = Options[1] or "Left - stacked"
    end,
})

-- Listen for Notification event once for too close eggs
local tooCloseFlag = false
local petAlreadyInMachineFlag = false
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Notification = ReplicatedStorage.GameEvents.Notification
Notification.OnClientEvent:Connect(function(message)
    if typeof(message) == "string" and message:lower():find("too close to another egg") then
        tooCloseFlag = true
        --print("[DEBUG] Too close notification received, skipping increment")
    end

    if typeof(message) == "string" and message:lower():find("a pet is already in the machine!") then
        petAlreadyInMachineFlag = true
    end
end)

--=======HANDEL LOCATIONS FOR  AUTO PLACE EGG
local localPlayer = Players.LocalPlayer
-- find player's farm
local function getMyFarm()
    if not localPlayer then
        warn("[BeastHub] Local player not found!")
        return nil
    end

    local farmsFolder = workspace:WaitForChild("Farm")
    for _, farm in pairs(farmsFolder:GetChildren()) do
        if farm:IsA("Folder") or farm:IsA("Model") then
            local ownerValue = farm:FindFirstChild("Important") 
                            and farm.Important:FindFirstChild("Data") 
                            and farm.Important.Data:FindFirstChild("Owner")
            if ownerValue and ownerValue.Value == localPlayer.Name then
                return farm
            end
        end
    end

    warn("[BeastHub] Could not find your farm!")
    return nil
end

-- get farm spawn point CFrame
local function getFarmSpawnCFrame() --old code
    local myFarm = getMyFarm()
    if not myFarm then return nil end

    local spawnPoint = myFarm:FindFirstChild("Spawn_Point")
    if spawnPoint and spawnPoint:IsA("BasePart") then
        return spawnPoint.CFrame
    end

    warn("[BeastHub] Spawn_Point not found in your farm!")
    return nil
end


-- relative egg positions (local space relative to spawn point)
local eggPositionPresets = {
    ["Left - stacked"] = {
        Vector3.new(-36, 0, -18),
        Vector3.new(-27, 0, -18),
        Vector3.new(-18, 0, -18),
        Vector3.new(-9, 0, -18),

        Vector3.new(-36, 0, -33),
        Vector3.new(-27, 0, -33),
        Vector3.new(-18, 0, -33),
        Vector3.new(-9, 0, -33),

        Vector3.new(-36, 0, -48),
        Vector3.new(-27, 0, -48),
        Vector3.new(-18, 0, -48),
        Vector3.new(-9, 0, -48),

        Vector3.new(-36, 0, -63),
        Vector3.new(-27, 0, -63),
        Vector3.new(-18, 0, -63),
        Vector3.new(-9, 0, -63),
    },
    ["Right - stacked"] = {
        Vector3.new(36, 0, -18),
        Vector3.new(27, 0, -18),
        Vector3.new(18, 0, -18),
        Vector3.new(9, 0, -18),

        Vector3.new(36, 0, -33),
        Vector3.new(27, 0, -33),
        Vector3.new(18, 0, -33),
        Vector3.new(9, 0, -33),

        Vector3.new(36, 0, -48),
        Vector3.new(27, 0, -48),
        Vector3.new(18, 0, -48),
        Vector3.new(9, 0, -48),

        Vector3.new(36, 0, -63),
        Vector3.new(27, 0, -63),
        Vector3.new(18, 0, -63),
        Vector3.new(9, 0, -63),
    },
   ["Left - compressed"] = {
        Vector3.new(-18, 0, -12),
        Vector3.new(-14, 0, -12),
        Vector3.new(-10, 0, -12),
        Vector3.new(-6, 0, -12),

        Vector3.new(-18, 0, -18),
        Vector3.new(-14, 0, -18),
        Vector3.new(-10, 0, -18),
        Vector3.new(-6, 0, -18),

        Vector3.new(-18, 0, -24),
        Vector3.new(-14, 0, -24),
        Vector3.new(-10, 0, -24),
        Vector3.new(-6, 0, -24),

        Vector3.new(-18, 0, -30),
        Vector3.new(-14, 0, -30),
        Vector3.new(-10, 0, -30),
        Vector3.new(-6, 0, -30),
    },
    ["Right - compressed"] = {
        Vector3.new(18, 0, -12),
        Vector3.new(14, 0, -12),
        Vector3.new(10, 0, -12),
        Vector3.new(6, 0, -12),

        Vector3.new(18, 0, -18),
        Vector3.new(14, 0, -18),
        Vector3.new(10, 0, -18),
        Vector3.new(6, 0, -18),

        Vector3.new(18, 0, -24),
        Vector3.new(14, 0, -24),
        Vector3.new(10, 0, -24),
        Vector3.new(6, 0, -24),

        Vector3.new(18, 0, -30),
        Vector3.new(14, 0, -30),
        Vector3.new(10, 0, -30),
        Vector3.new(6, 0, -30),
    },
}

-- convert to world positions
local function getFarmEggLocations()
    local spawnCFrame = getFarmSpawnCFrame()
    if not spawnCFrame then return {} end

    local eggOffsets = eggPositionPresets[selectedPosition] or eggPositionPresets["Left - stacked"]

    local locations = {}
    for _, offset in ipairs(eggOffsets) do
        table.insert(locations, spawnCFrame:PointToWorldSpace(offset))
    end
    return locations
end

--=====================


--toggle auto place eggs
local autoPlaceEggsThread -- store the task
local autoPlaceEggsEnabled = false
local Toggle_autoPlaceEggs = PetEggs:CreateToggle({
    Name = "Auto place eggs",
    CurrentValue = false,
    Flag = "autoPlaceEggs",
    Callback = function(Value)
        -- Stop old loop if already running
        if autoPlaceEggsThread then
            autoPlaceEggsEnabled = false
            autoPlaceEggsThread = nil -- we just stop the thread by flipping the boolean
        end

        if Value then
            -- Get selected egg name
            local selectedEgg = Dropdown_eggToPlace.CurrentOption[1] or ""
            if selectedEgg == "" then
                beastHubNotify("Error", "Please select an egg type first!", 3)
                return
            end

            -- If egg type changed, recapture the original value
            if trackedEggName ~= selectedEgg then
                trackedEggName = selectedEgg
                originalEggCount = getTotalEggCount(trackedEggName)
                originalCaptured = true
            elseif not originalCaptured then
                -- First time capture
                trackedEggName = selectedEgg
                originalEggCount = getTotalEggCount(trackedEggName)
                originalCaptured = true
            end
            updateEggStatus(originalEggCount, getTotalEggCount(trackedEggName), getPlacedEggCountByName(trackedEggName))

            beastHubNotify("Auto place eggs: ON", "Max Eggs to place: "..tostring(eggsToPlaceInput), 4)
            autoPlaceEggsEnabled = true
            local autoPlaceEggLocations = getFarmEggLocations() --off setting for dynamic farm location
            autoPlaceEggsThread = task.spawn(function()
                while autoPlaceEggsEnabled do
                    local maxFarmEggs = eggsToPlaceInput
                    local currentEggsInFarm = getFarmEggCount()

                    -- Update Egg Status GUI: originalEggCount (FIXED) vs currentInventory (REAL-TIME)
                    local currentInventory = getTotalEggCount(trackedEggName)
                    local currentPlaced = getPlacedEggCountByName(trackedEggName)
                    updateEggStatus(originalEggCount, currentInventory, currentPlaced)

                    if currentEggsInFarm < maxFarmEggs then
                        for _, location in ipairs(autoPlaceEggLocations) do
                            if currentEggsInFarm >= maxFarmEggs then
                                break
                            end

                            if Dropdown_eggToPlace.CurrentOption[1] then
                                equipItemByName(Dropdown_eggToPlace.CurrentOption[1])
                            end

                            local args = { "CreateEgg", location }
                            game:GetService("ReplicatedStorage").GameEvents.PetEggService:FireServer(unpack(args))
                            --add algo here to trap 'too close to another egg and dont increment'
                            task.wait(delayToPlaceEggs)
                            if tooCloseFlag then
                                tooCloseFlag = false -- reset flag for next iteration
                                -- skip increment
                            else
                                currentEggsInFarm = currentEggsInFarm + 1
                            end

                            -- Update Egg Status GUI: originalEggCount (FIXED) vs currentInventory (REAL-TIME)
                            currentInventory = getTotalEggCount(trackedEggName)
                            currentPlaced = getPlacedEggCountByName(trackedEggName)
                            updateEggStatus(originalEggCount, currentInventory, currentPlaced)

                        end
                    end

                    task.wait(1.5)
                end
            end)
        else
            autoPlaceEggsEnabled = false
            autoPlaceEggsThread = nil
            -- Show final status: originalEggCount (FIXED) vs final inventory
            local finalInventory = getTotalEggCount(trackedEggName)
            local finalPlaced = getPlacedEggCountByName(trackedEggName)
            updateEggStatus(originalEggCount, finalInventory, finalPlaced)
            beastHubNotify("Auto place eggs: OFF", "", 2)
        end
    end,
})

--Auto hatch
PetEggs:CreateButton({
    Name = "Click to HATCH ALL",
    Callback = function()
        print("[BeastHub] Hatching eggs...")

        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local PetEggService = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetEggService")

        -- Get all PetEgg models in your farm
        local petEggs = myFunctions.getMyFarmPetEggs()
        if #petEggs == 0 then
            --print("[BeastHub] No PetEggs found in your farm!")
            return
        end

        -- Loop through all eggs and fire the hatch event
        for _, egg in ipairs(petEggs) do
            local args = {
                [1] = "HatchPet",
                [2] = egg
            }
            PetEggService:FireServer(unpack(args))
            task.wait(delayToHatchEggs)
            --print("[BeastHub] Fired hatch for:", egg.Name)
        end
    end,
})
PetEggs:CreateDivider()

--PetEggs>Auto Sell Pets
local petList = myFunctions.getPetOdds()
    -- Get names only
local petListNamesOnlyAndSorted = myFunctions.getPetList()
table.sort(petListNamesOnlyAndSorted)

    --function to auto sell
local function autoSellPets(targetPets, weightTargetBelow, onComplete)
    -- USAGE:
    -- autoSellPets({"Bunny", "Dog"}, 3, function()
    --     print("Selling complete, now do next step!")
    -- end)

    if not targetPets or #targetPets == 0 then
        warn("[BeastHub] No pets to sell!")
        return false
    end

    if not weightTargetBelow or weightTargetBelow <= 0 then
        warn("[BeastHub] Invalid weight threshold!")
        return false
    end

    local player = game.Players.LocalPlayer
    local backpack = player:WaitForChild("Backpack")
    local SellPet_RE = game:GetService("ReplicatedStorage").GameEvents.SellPet_RE
    local soldCount = 0

    -- Unequip first
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid:UnequipTools()
    end

    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") then
            local b = item:GetAttribute("b") -- pet type
            local d = item:GetAttribute("d") -- favorite

        if b == "l" and d == false then
            local petName = item.Name:match("^(.-)%s*%[") or item.Name
            petName = petName:match("^%s*(.-)%s*$") -- trim spaces

            local weightStr = item.Name:match("%[(%d+%.?%d*)%s*[Kk][Gg]%]")
            local weight = weightStr and tonumber(weightStr)

            -- Check if this is a target pet
            local isTarget = false
            for _, name in ipairs(targetPets) do
                if petName == name then
                    isTarget = true
                    break
                end
            end

            -- Sell if matches criteria
            if isTarget and weight and weight < weightTargetBelow then
                if player.Character and player.Character:FindFirstChild("Humanoid") then
                    player.Character.Humanoid:UnequipTools()
                    task.wait(0.1)
                    player.Character.Humanoid:EquipTool(item)
                    task.wait(0.2) -- ensure pet equips before selling

                    local success = pcall(function()
                        SellPet_RE:FireServer(item.Name)
                    end)

                    if success then
                        print("[BeastHub] Sold: " .. item.Name)
                        soldCount = soldCount + 1
                    end
                    task.wait(delayToSellPets)
                end
            end
        end
        end
    end

    print("[BeastHub] Auto Sell complete - Sold " .. soldCount .. " pets")

    -- Call the callback AFTER finishing all pets
    if typeof(onComplete) == "function" then
        onComplete()
    end

    return true
end



--auto sell pets UI
local selectedPets --for UI paragraph
local selectedPetsForAutoSell = {} --container for dropdown
local sealsLoady

local Paragraph_selectedPets = PetEggs:CreateParagraph({Title = "Auto Sell Pets:", Content = "No pets selected."})
local Dropdown_sealsLoadoutNum = PetEggs:CreateDropdown({
    Name = "Select 'Seals' loadout",
    Options = {"None", "1", "2", "3"},
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "sealsLoadoutNum", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
    Callback = function(Options)
        --if not Options or not Options[1] then return end
        sealsLoady = tonumber(Options[1])
    end,
})
local suggestedAutoSellList = {
    "Ostrich", "Peacock", "Capybara", "Scarlet Macaw",
    "Bat", "Bone Dog", "Spider", "Black Cat",
    "Oxpecker", "Zebra", "Giraffe", "Rhino",
    "Tree Frog", "Hummingbird", "Iguana", "Chimpanzee",
    "Robin", "Badger", "Grizzly Bear",
    "Ladybug", "Pixie", "Imp", "Glimmering Sprite",
    "Dairy Cow", "Jackalope", "Seedling",
    "Bagel Bunny", "Pancake Mole", "Sushi Bear", "Spaghetti Sloth",
    "Shiba Inu", "Nihonzaru", "Tanuki", "Tanchozuru", "Kappa",
    "Parasaurolophus", "Iguanodon", "Ankylosaurus",
    "Raptor", "Triceratops", "Stegosaurus", "Pterodactyl", 
    "Flamingo", "Toucan", "Sea Turtle", "Orangutan",
    "Wasp", "Tarantula Hawk", "Moth",
    "Bee", "Honey Bee", "Petal Bee",
    "Hedgehog", "Mole", "Frog", "Echo Frog", "Night Owl",
    "Caterpillar", "Snail", "Giant Ant", "Praying Mantis",
    "Topaz Snail", "Amethyst Beetle", "Emerald Snake", "Sapphire Macaw"
}
local Dropdown_petList = PetEggs:CreateDropdown({
    Name = "Select Pets",
    Options = petListNamesOnlyAndSorted,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "autoSellPetsSelection", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
    Callback = function(Options)
        --if not Options or not Options[1] then return end
        selectedPetsForAutoSell = Options
        -- Convert table to string for paragraph display
        local names = table.concat(Options, ", ")
        if names == "" then
            names = "No pets selected."
        end

        Paragraph_selectedPets:Set({
            Title = "Auto Sell Pets:",
            Content = names
        })    
    end,
})

--search pets
local searchDebounce = nil
local Input_petSearch = PetEggs:CreateInput({
    Name = "Search (click dropdown to load)",
    PlaceholderText = "Search Pet...",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        if searchDebounce then
            task.cancel(searchDebounce)
        end

        searchDebounce = task.delay(0.5, function()
            local results = {}
            local query = string.lower(Text)

            if query == "" then
                results = petListNamesOnlyAndSorted
            else
                for _, petName in ipairs(petListNamesOnlyAndSorted) do
                    if string.find(string.lower(petName), query, 1, true) then
                        table.insert(results, petName)
                    end
                end
            end

            Dropdown_petList:Refresh(results)

            -- Force redraw by re-setting selection (even empty table works)
            Dropdown_petList:Set(selectedPetsForAutoSell)

            -- Extra fallback: if no match, clear UI text
            if #results == 0 then
                Paragraph_selectedPets:Set({
                    Title = "Auto Sell Pets:",
                    Content = "No pets found."
                })
            end
        end)
    end,
})

PetEggs:CreateButton({
    Name = "Load Suggested List",
    Callback = function()
        Dropdown_petList:Set(suggestedAutoSellList) --Clear selection properly
        selectedPetsForAutoSell = suggestedAutoSellList
    end,
})

PetEggs:CreateButton({
    Name = "Clear selection",
    Callback = function()
        Dropdown_petList:Set({}) --Clear selection properly
        selectedPetsForAutoSell = {}
    end,
})

local sellBelow
local Dropdown_sellBelowKG = PetEggs:CreateDropdown({
    Name = "Below (KG)",
    Options = {"1","2","3"},
    CurrentOption = {"3"},
    MultipleOptions = false,
    Flag = "sellBelowKG", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
    Callback = function(Options)
        --if not Options or not Options[1] then return end
        sellBelow = tonumber(Options[1])
    end,
})

--delay to sell pets (input field to adjust delay speed)
local Input_delayToSellPets = PetEggs:CreateInput({
    Name = "Delay to sell (Default 0.05)",
    CurrentValue = "0.05",
    PlaceholderText = "Delay in seconds (lower = faster)",
    RemoveTextAfterFocusLost = false,
    Flag = "delayToSellPets",
    Callback = function(Text)
        local newDelay = tonumber(Text)
        if newDelay and newDelay > 0 then
            delayToSellPets = newDelay
            beastHubNotify("Sell Speed Updated", "Delay: " .. tostring(delayToSellPets) .. "s", 2)
        else
            beastHubNotify("Invalid Input", "Use a positive number", 3)
            delayToSellPets = 0.05
        end
    end,
})

PetEggs:CreateButton({
    Name = "Click to SELL",
    Callback = function()
        -- Validate settings
        if not selectedPetsForAutoSell or #selectedPetsForAutoSell == 0 then
            beastHubNotify("Auto Sell Error", "No pets selected!", 3)
            return
        end
        if not sellBelow then
            beastHubNotify("Auto Sell Error", "Please set KG threshold", 3)
            return
        end

        -- Switch to seals loadout if configured
        if sealsLoady and sealsLoady ~= "None" then
            print("Switching to seals loadout first")
            myFunctions.switchToLoadout(sealsLoady)
            beastHubNotify("Waiting for Seals to load", "Auto Sell", 5)
            task.wait(6)
        end

        -- Execute auto sell
        local success, err = pcall(function()
            autoSellPets(selectedPetsForAutoSell, sellBelow)
        end)

        if success then
            beastHubNotify("Auto Sell Done", "Successful", 2)
        else
            beastHubNotify("Auto Sell Error", tostring(err), 4)
            warn("Auto Sell failed: " .. tostring(err))
        end
    end,
})
PetEggs:CreateDivider()

--Pet/Eggs>SMART HATCHING
PetEggs:CreateSection("SMART Auto Hatching")
-- local Paragraph = Pets:CreateParagraph({Title = "INSTRUCTIONS:", Content = "1.) Setup your Auto place Eggs above and turn on toggle for auto place eggs. 2.) Setup your selected pets for Auto Sell above. 3.) Selected desginated loadouts below. 4.) Turn on toggle for Full Auto Hatching"})
PetEggs:CreateParagraph({
    Title = "INSTRUCTIONS:",
    Content = "1.) Setup your Auto place Eggs above and turn on toggle for auto place eggs.\n2.) Setup your selected pets for Auto Sell above.\n3.) Selected designated loadouts below.\n4.) Turn on Speedhub Egg ESP, then turn on Egg ESP support below"
})
local koiLoady
local brontoLoady
local autoBrontoAntiHatch
local incubatingLoady
local webhookRares
local webhookHuge
local webhookURL
local sessionHatchCount = 0

PetEggs:CreateDropdown({
    Name = "Incubating/Eagles Loadout",
    Options = {"None", "1", "2", "3"},
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "incubatingLoadoutNum", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
    Callback = function(Options)
        --if not Options or not Options[1] then return end
        incubatingLoady = tonumber(Options[1])
    end,
})
PetEggs:CreateDropdown({
    Name = "Koi Loadout",
    Options = {"None", "1", "2", "3"},
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "koiLoadoutNum", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
    Callback = function(Options)
        --if not Options or not Options[1] then return end
        koiLoady = tonumber(Options[1])
    end,
})
PetEggs:CreateDropdown({
    Name = "Select Bronto Loadout",
    Options = {"None", "1", "2", "3", "4", "5", "6"},
    CurrentOption = {"None"},
    MultipleOptions = false,
    Flag = "brontoLoadoutNum", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
    Callback = function(Options)
        --if not Options or not Options[1] then return end
        if Options[1] ~= "None" then
            brontoLoady = tonumber(Options[1])
        else
            brontoLoady = nil
        end
    end,
})
local skipHatchAboveKG = 0
PetEggs:CreateDropdown({
    Name = "Skip hatch Above KG (any egg):",
    Options = {"0", "2", "2.5", "2.6", "2.7", "2.8", "2.9", "3", "3.5", "4", "5"},
    CurrentOption = {"0"},
    MultipleOptions = false,
    Flag = "skipHatchAboveKG",
    Callback = function(Options)
        skipHatchAboveKG = tonumber(Options[1]) or 0
    end,
})

--Auto Bronto Anti Hatch List toggle
PetEggs:CreateToggle({
    Name = "Auto Bronto Anti Hatch List?",
    CurrentValue = false,
    Flag = "autoBrontoAntiHatch",
    Callback = function(Value)
        autoBrontoAntiHatch = Value
    end,
})

-- Anti Hatch Pets UI
local antiHatchPetsList = {}
local allPetNamesForAntiHatch = myFunctions.getPetList() or {}
table.sort(allPetNamesForAntiHatch)

local function getAntiHatchDisplayText()
    if #antiHatchPetsList == 0 then
        return "No pets selected."
    else
        return table.concat(antiHatchPetsList, ", ")
    end
end

local antiHatchParagraph = PetEggs:CreateParagraph({
    Title = "Anti Hatch Pets (HUGE by default are skipped):",
    Content = getAntiHatchDisplayText()
})

local Dropdown_antiHatchPets = PetEggs:CreateDropdown({
    Name = "Anti Hatch Pets:",
    Options = allPetNamesForAntiHatch,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "antiHatchPets",
    Callback = function(Options)
        antiHatchPetsList = Options or {}
        antiHatchParagraph:Set({
            Title = "Anti Hatch Pets (HUGE by default are skipped):",
            Content = getAntiHatchDisplayText()
        })
    end,
})

PetEggs:CreateButton({
    Name = "Clear Anti Hatch",
    Callback = function()
        antiHatchPetsList = {}
        Dropdown_antiHatchPets:Set({})
        antiHatchParagraph:Set({
            Title = "Anti Hatch Pets (HUGE by default are skipped):",
            Content = "No pets selected."
        })
        beastHubNotify("Anti Hatch Cleared", "All pets removed from anti-hatch list", 3)
    end,
})

local function isInAntiHatchList(petName)
    for _, name in ipairs(antiHatchPetsList) do
        if name == petName then
            return true
        end
    end
    return false
end

task.wait(.5) --to wait for loadout variables to load
--Only two variables needed
local smartAutoHatchingEnabled = false
local smartAutoHatchingThread = nil

local sessionHugeList = {}
local Toggle_smartAutoHatch = PetEggs:CreateToggle({
    Name = "SMART Auto Hatching",
    CurrentValue = false,
    Flag = "smartAutoHatching",
    Callback = function(Value)
        smartAutoHatchingEnabled = Value
        if(smartAutoHatchingEnabled) then
            beastHubNotify("SMART AUTO HATCH ENABLED!", "Process will begin in 8 seconds..", 5)
            beastHubNotify("5", "", 1)
            task.wait(1)
            beastHubNotify("4", "", 1)
            task.wait(1)
            beastHubNotify("3", "", 1)
            task.wait(1)
            beastHubNotify("2", "", 1)
            task.wait(1)
            beastHubNotify("1", "", 1)
            task.wait(1)
            -- task.wait(8)
            -- Check again before proceeding
            if not smartAutoHatchingEnabled then
                beastHubNotify("SMART HATCH CANCELLED!", "Toggle was turned off before start.", 5)
                return
            end

            --recheck setup
            if not koiLoady or koiLoady == "None"
            -- or not brontoLoady or brontoLoady == "None"
            or not sealsLoady or sealsLoady == "None"
            or not incubatingLoady or incubatingLoady == "None" then
                beastHubNotify("Missing setup!", "Please recheck loadouts for koi, bronto, seals and turn on EGG ESP Support", 15)
                return
            end
        end

        -- If ON, start thread (only once)
        if smartAutoHatchingEnabled and not smartAutoHatchingThread then
            smartAutoHatchingThread = task.spawn(function()
                local function isInHugeList(target)
                    for _, value in ipairs(sessionHugeList) do
                        if value == target then
                            return true
                        end
                    end
                    return false
                end

                local function notInHugeList(tbl, target)
                    for _, value in ipairs(tbl) do
                        if value == target then
                            return false  -- found → NOT allowed
                        end
                    end
                    return true  -- not found → allowed
                end



                local petOdds = myFunctions.getPetOdds()
                local rarePets = myFunctions.getRarePets(petOdds)

                while smartAutoHatchingEnabled do

                    --check eggs
                    local myPetEggs = myFunctions.getMyFarmPetEggs()
                    local readyCounter = 0

                    for _, egg in pairs(myPetEggs) do
                        if egg:IsA("Model") and egg:GetAttribute("TimeToHatch") == 0 then
                            readyCounter = readyCounter + 1
                        end
                    end

                    if #myPetEggs > 0 and #myPetEggs == readyCounter and smartAutoHatchingEnabled then
                        --all eggs ready to hatch
                        beastHubNotify("All eggs Ready!", "", 3)
                        local espFolderFound
                        local rareOrHugeFound
                        local ReplicatedStorage = game:GetService("ReplicatedStorage")
                        local PetEggService = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetEggService")


                        --all eggs now must start with koi loadout, infinite loadout has been patched 10/24/25
                        beastHubNotify("Switching to Kois", "", 8)
                        Toggle_autoPlaceEggs:Set(false)
                        myFunctions.switchToLoadout(koiLoady)
                        task.wait(12)

                        --get egg data such as pet name and size
                        --=======================================
                        for _, egg in pairs(myPetEggs) do
                            if egg:IsA("Model") then
                                --ESP access part, this is mainly for bronto hatching
                                --====
                                local espFolder = egg:FindFirstChild("BhubESP")
                                if espFolder then
                                    print("espFolder found")
                                    espFolderFound = true
                                    for _, espObj in ipairs(espFolder:GetChildren()) do
                                        -- if espObj:IsA("BoxHandleAdornment") then
                                            local billboard = espFolder:FindFirstChild("EggBillboard")
                                            if billboard then
                                                local textLabel = billboard:FindFirstChildWhichIsA("TextLabel")
                                                if textLabel then
                                                    local text = textLabel.Text
                                                    -- Get values using string match 
                                                    -- local petName = string.match(text, "0%)'>(.-)</font>")
                                                    -- local stringKG = string.match(text, ".*=%s*<font.-'>(.-)</font>")
                                                    local petName = text:match('rgb%(%s*0,%s*255,%s*0%s*%)">(.-)</font>%s*=')
                                                    local stringKG = text:match("= (%d+%.?%d*)")

                                                    -- print("petName")
                                                    -- print(petName)
                                                    -- print("stringKG")
                                                    -- print(stringKG)

                                                    local isRare
                                                    local isHuge

                                                    -- print("petName found: " .. tostring(petName))
                                                    -- print("stringKG found: "..tostring(stringKG))

                                                    if petName and stringKG and smartAutoHatchingEnabled then
                                                        -- Trim whitespace in case it grew from previous runs
                                                        stringKG = stringKG:match("^%s*(.-)%s*$") 
                                                        local playerNameWebhook = game.Players.LocalPlayer.Name
                                                        --print("stringKG trimmed: "..stringKG)

                                                        -- check if Rare
                                                        if type(rarePets) == "table" then
                                                            for _, rarePet in ipairs(rarePets) do
                                                                if petName == rarePet then
                                                                    isRare = true
                                                                    break
                                                                end
                                                            end
                                                        else
                                                            --exit if have trouble getting rare pets
                                                            warn("rarePets is not a table")
                                                            return
                                                        end

                                                        -- check if Huge
                                                        local currentNumberKG = tonumber(stringKG)
                                                        if not currentNumberKG then
                                                            warn("Error in getting pet Size")
                                                            return
                                                        end
                                                        if currentNumberKG < 3 then
                                                            isHuge = false
                                                        else
                                                            isHuge = true
                                                        end

                                                        --deciding loadout code below
                                                        --if isHuge or isRare, switch loadout bronto, wait 7 sec, hatch this 1 egg
                                                        if isRare or isHuge then
                                                            rareOrHugeFound = true
                                                            Toggle_autoPlaceEggs:Set(false)
                                                        end

                                                        if isHuge then
                                                            beastHubNotify("Skipping Huge!", "", 2)
                                                            local targetHuge = petName..stringKG
                                                            print("targetHuge")
                                                            print(targetHuge)
                                                            if targetHuge and notInHugeList(sessionHugeList, targetHuge) then
                                                                table.insert(sessionHugeList, targetHuge)

                                                                -- Auto add to anti-hatch list if enabled
                                                                if autoBrontoAntiHatch and not isInAntiHatchList(petName) then
                                                                    table.insert(antiHatchPetsList, petName)
                                                                    Dropdown_antiHatchPets:Set(antiHatchPetsList)
                                                                    antiHatchParagraph:Set({
                                                                        Title = "Anti Hatch Pets (HUGE by default are skipped):",
                                                                        Content = getAntiHatchDisplayText()
                                                                    })
                                                                    beastHubNotify("Auto Added to Anti-Hatch", petName, 2)
                                                                end

                                                                if webhookURL and webhookURL ~= "" and webhookHuge then
                                                                    sendDiscordWebhook(webhookURL, "[BeastHub] "..playerNameWebhook.." | Huge found: "..petName.." = "..stringKG.."KG")
                                                                else
                                                                    warn("No webhook URL provided for hatch!")
                                                                end
                                                            elseif  not targetHuge then
                                                                warn("Error in getting target Huge string")
                                                            end

                                                        elseif skipHatchAboveKG > 0 and currentNumberKG >= skipHatchAboveKG then
                                                            beastHubNotify("Skipping egg above "..tostring(skipHatchAboveKG).."KG!", petName.." = "..stringKG.."KG", 3)

                                                        elseif isInAntiHatchList(petName) then
                                                            beastHubNotify("Skipping Anti-Hatch Pet!", petName.." = "..stringKG.."KG", 3)

                                                        else
                                                            -- If Rare and Bronto loadout selected, switch to it
                                                            if isRare and brontoLoady and brontoLoady ~= "None" then
                                                                beastHubNotify("Switching to Bronto Loadout", "Hatching Rare: "..petName, 8)
                                                                myFunctions.switchToLoadout(brontoLoady)
                                                                task.wait(10)
                                                            end

                                                            local args = {
                                                                    [1] = "HatchPet";
                                                                    [2] = egg
                                                            }
                                                            game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetEggService", 9e9):FireServer(unpack(args))
                                                            sessionHatchCount = sessionHatchCount + 1
                                                            task.wait(delayToHatchEggs)

                                                            -- Auto add rare to anti-hatch list if enabled
                                                            if isRare and autoBrontoAntiHatch and not isInAntiHatchList(petName) then
                                                                table.insert(antiHatchPetsList, petName)
                                                                Dropdown_antiHatchPets:Set(antiHatchPetsList)
                                                                antiHatchParagraph:Set({
                                                                    Title = "Anti Hatch Pets (HUGE by default are skipped):",
                                                                    Content = getAntiHatchDisplayText()
                                                                })
                                                                beastHubNotify("Auto Added to Anti-Hatch", petName, 2)
                                                            end

                                                            --checking
                                                            -- print("hatched: ")
                                                            -- print(petName)
                                                            -- print(tostring(currentNumberKG))

                                                            -- send webhook here
                                                            local message = nil
                                                            if isRare and webhookRares then
                                                                message = "[BeastHub] "..playerNameWebhook.." | Rare hatched: " .. tostring(petName) .. "=" .. tostring(currentNumberKG) .. "KG |Egg hatch # "..tostring(sessionHatchCount)
                                                            elseif isHuge and webhookHuge then
                                                                message = "[BeastHub] "..playerNameWebhook.." | Huge hatched: " .. tostring(petName) .. "=" .. tostring(currentNumberKG) .. "KG |Egg hatch # "..tostring(sessionHatchCount)
                                                            end

                                                            if message then
                                                                if webhookURL and webhookURL ~= "" then
                                                                    sendDiscordWebhook(webhookURL, message)
                                                                else
                                                                    warn("No webhook URL provided for hatch!")
                                                                end
                                                            end
                                                        end
                                                    end

                                                else
                                                    print("BillboardGui has no TextLabel")
                                                end
                                            else
                                                print("No BillboardGui found under BoxHandleAdornment")
                                            end
                                        -- end
                                    end
                                else
                                    espFolderFound = false
                                end
                                --====
                            else
                                warn("Object is not a model")
                                return
                            end
                        end

                        --=======================================
                        --trigger auto sell first before back to eagles
                        task.wait(5)
                        if sealsLoady and sealsLoady ~= "None" and smartAutoHatchingEnabled then
                            game.Players.LocalPlayer.Character.Humanoid:UnequipTools() --prevention
                            beastHubNotify("Switching to seals", "Auto sell triggered", 10)
                            myFunctions.switchToLoadout(sealsLoady)
                            game.Players.LocalPlayer.Character.Humanoid:UnequipTools() --prevention
                            task.wait(1)
                            game.Players.LocalPlayer.Character.Humanoid:UnequipTools() --prevention
                            task.wait(1)
                            game.Players.LocalPlayer.Character.Humanoid:UnequipTools() --prevention
                            task.wait(1)
                            game.Players.LocalPlayer.Character.Humanoid:UnequipTools() --prevention
                            task.wait(1)
                            game.Players.LocalPlayer.Character.Humanoid:UnequipTools() --prevention
                            task.wait(1)
                            game.Players.LocalPlayer.Character.Humanoid:UnequipTools() --prevention
                            task.wait(10)
                            local success, err = pcall(function()
                                autoSellPets(selectedPetsForAutoSell, sellBelow, function()
                                    --print("Now switching back to main loadout...")
                                    task.wait(2)
                                    myFunctions.switchToLoadout(incubatingLoady)
                                end)
                            end)
                            if success then
                                beastHubNotify("Auto Sell Done", "Successful", 2)
                            else
                                warn("Auto Sell failed with error: " .. tostring(err))
                                beastHubNotify("Auto Sell Failed!", tostring(err), 5)
                            end
                        else
                            --this part of logic might not be possible but keeping this for now
                            -- warn("No Seals Loadout found, skipping auto-sell.")
                        end


                        --back to incubating loadout
                        task.wait(2)
                        beastHubNotify("Back to incubating", "", 6)
                        Toggle_autoPlaceEggs:Set(true)
                        --myFunctions.switchToLoadout(incubatingLoady) --loadout switch was done in the callback of auto sell 
                        task.wait(6)
                    else
                        beastHubNotify("Eggs not ready yet", "Waiting..", 3)
                        task.wait(15)
                    end
                end
                -- When flag turns false, loop ends and thread resets
                smartAutoHatchingThread = nil
            end)
        end
    end,
})

PetEggs:CreateDivider()


--Mutation machine
--get FULL pet list via registry
local function getAllPetNames()
    local success, PetRegistry = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("PetRegistry"))
    end)
    if not success or type(PetRegistry) ~= "table" then
        warn("Failed to load PetRegistry module.")
        return {}
    end
    local petList = PetRegistry.PetList
    if type(petList) ~= "table" then
        warn("PetList not found in PetRegistry.")
        return {}
    end
    local names = {}
    for petName, _ in pairs(petList) do
        table.insert(names, tostring(petName))
    end
    table.sort(names) -- alphabetical sort
    return names
end

-- ================== LOAD SEPARATED MODULES ==================
-- Load Automation module
local automationModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/XxMarDdEvsZXsWu69/zhub/refs/heads/main/dev_automation.lua"))()
automationModule.init(Rayfield, beastHubNotify, Window, myFunctions, beastHubIcon, equipItemByName, nil, getMyFarm, getFarmSpawnCFrame, getAllPetNames, sendDiscordWebhook)

-- Load Pets module
local petsModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/XxMarDdEvsZXsWu69/zhub/refs/heads/main/dev_pets.lua"))()
petsModule.init(Rayfield, beastHubNotify, Window, myFunctions, beastHubIcon, equipItemByName, nil, getMyFarm, getFarmSpawnCFrame, getAllPetNames, sendDiscordWebhook)


--Other Egg settings
PetEggs:CreateSection("Egg settings")
-- Egg ESP support --
-- local Toggle_eggESP = PetEggs:CreateToggle({
--     Name = "Egg ESP Support (Speedhub ESP enhanced)",
--     CurrentValue = false,
--     Flag = "eggESP", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
--     Callback = function(Value)
--         myFunctions.eggESP(Value)
--     end,
-- })

--bhub esp
local bhubESPenabled = false
local bhubESPthread = nil
local Toggle_bhubESP = PetEggs:CreateToggle({
    Name = "BeastHub ESP",
    CurrentValue = false,
    Flag = "bhubESP",
    Callback = function(Value)
        bhubESPenabled = Value
        local bhubEsp --function

        -- Turn OFF
        if not bhubESPenabled and bhubESPthread then
            task.cancel(bhubESPthread)
            bhubESPthread = nil

            -- ✅ Remove ALL BhubESP folders from all eggs
            local petEggs = myFunctions.getMyFarmPetEggs()
            for _, egg in ipairs(petEggs) do
                if egg:IsA("Model") then
                    local old = egg:FindFirstChild("BhubESP")
                    if old then old:Destroy() end
                end
            end

            beastHubNotify("ESP stopped and cleaned", "", 1)
            return
        end

        -- Turn ON
        if bhubESPenabled and not bhubESPthread then
            bhubEsp = function()

            end--end function

            bhubESPthread = task.spawn(function()
                beastHubNotify("ESP enabled", "", 1)
                while bhubESPenabled do
                    -- Always fetch FRESH data every iteration (no caching)
                    local eggEspData = {} --final table storage

                    -- Get all PetEgg models in your farm
                    local petEggs = myFunctions.getMyFarmPetEggs()

                    if #petEggs == 0 then
                        --print("[BeastHub] No PetEggs found in your farm!")
                        task.wait(1)
                        return
                    end

                    -- Always refresh data - don't skip even if all have ESP
                    local function getPlayerData()
                        local dataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
                        local logs = dataService:GetData()
                        return logs
                    end

                    local function getSaveSlots()
                        local playerData = getPlayerData()
                        if playerData and playerData.SaveSlots then
                            return playerData.SaveSlots
                        else
                            warn("SaveSlots not found!")
                            return nil
                        end
                    end

                    -- Fetch FRESH data on every iteration
                    local saveSlots = getSaveSlots()
                    if saveSlots then
                        local selectedSlot = saveSlots.SelectedSlot
                        local allSlots = saveSlots.AllSlots
                        if allSlots and selectedSlot then
                            for slot, slotData in pairs(allSlots) do
                                local slotNameString = tostring(slot)
                                if slotNameString == selectedSlot then
                                    local savedObjects = slotData.SavedObjects
                                    if savedObjects then
                                        for objName, ObjData in pairs(savedObjects) do
                                            local objType = ObjData.ObjectType
                                            if objType == "PetEgg" then
                                                local eggData = ObjData.Data
                                                local timeToHatch = eggData.TimeToHatch or 0
                                                -- INCLUDE ALL EGGS, ready or not (check their status)
                                                if eggData.RandomPetData then
                                                    local petName = eggData.RandomPetData.Name
                                                    local petKG = string.format("%.2f", eggData.BaseWeight * 1.1)
                                                    local entry = {
                                                        Uid = objName,
                                                        PetName = petName,
                                                        PetKG = petKG,
                                                        TimeToHatch = timeToHatch
                                                    }
                                                    table.insert(eggEspData, entry)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end

                    -- Loop through all eggs and apply ESP
                    for _, egg in ipairs(petEggs) do
                        if egg:IsA("Model") then
                            local uuid = egg:GetAttribute("OBJECT_UUID")
                            local petName = ""
                            local petKG = ""
                            local timeToHatch = -1
                            local hugeThreshold = 3
                            local isHuge = false

                            -- Find this egg's data in fresh eggEspData
                            for _, eggData in pairs(eggEspData) do 
                                if uuid == eggData.Uid then
                                    petName = eggData.PetName
                                    petKG = eggData.PetKG
                                    timeToHatch = eggData.TimeToHatch
                                    break
                                end
                            end

                            -- Only show ESP for eggs ready to hatch (timeToHatch == 0)
                            if timeToHatch == 0 and petKG ~= "" then
                                if tonumber(petKG) >= hugeThreshold then
                                    isHuge = true
                                end

                                -- Clear previous ESP if exists and recreate
                                local old = egg:FindFirstChild("BhubESP")
                                if old then old:Destroy() end

                                -- Create new ESP folder
                                local espFolder = Instance.new("Folder")
                                espFolder.Name = "BhubESP"
                                espFolder.Parent = egg

                                -- BillboardGui
                                local billboard = Instance.new("BillboardGui")
                                billboard.Name = "EggBillboard"
                                billboard.Adornee = egg
                                billboard.Size = UDim2.new(0, 150, 0, 40)
                                billboard.AlwaysOnTop = true
                                billboard.StudsOffset = Vector3.new(0, 4, 0)
                                billboard.Parent = espFolder

                                -- TextLabel inside Billboard
                                local label = Instance.new("TextLabel")
                                label.RichText = true
                                label.BackgroundTransparency = 1
                                label.Size = UDim2.new(1, 0, 1, 0)
                                if isHuge then
                                label.Text = '<font color="rgb(255,0,0)"><b>Paldooo! (' .. petKG .. 'kg)</b></font>\n<font color="rgb(0,255,0)">' .. petName .. '</font>'

                            else
                                label.Text = '<font color="rgb(0,255,0)">' .. petName .. '</font> = ' .. petKG .. 'kg'
                            end

                                label.TextColor3 = Color3.fromRGB(0, 255, 0)
                                label.TextStrokeTransparency = 0.5
                                label.TextScaled = false
                                label.TextSize = 20
                                label.Font = Enum.Font.SourceSans
                                label.Parent = billboard
                            end
                        end
                    end

                    task.wait(1)
                end
                bhubESPthread = nil
                beastHubNotify("ESP stopped cleanly", "", 3)
            end)
        end
    end,
})

--Egg collision
local Toggle_disableEggCollision = PetEggs:CreateToggle({
    Name = "Disable Egg collision",
    CurrentValue = false,
    Flag = "disableEggCollision", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
    Callback = function(Value)
        myFunctions.disableEggCollision(Value)
    end,
})
PetEggs:CreateDivider()

--== Misc>Performance
Misc:CreateSection("Advance Event")
Misc:CreateButton({
    Name = "Advance Event",
    Callback = function()
        local smithingEvent = game:GetService("ReplicatedStorage").Modules.UpdateService:FindFirstChild("SmithingEvent")
        if smithingEvent then
            smithingEvent.Parent = workspace
        end
        workspace.SafariEvent.Parent = game:GetService("ReplicatedStorage")
    end,
    })
Misc:CreateDivider()

Misc:CreateSection("Performance")
--Hide other player's Farm
local Toggle_hideOtherFarm = Misc:CreateToggle({
    Name = "Hide Other Player's Farm",
    CurrentValue = false,
    Flag = "hideOtherFarm", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
    Callback = function(Value)
        myFunctions.hideOtherPlayersGarden(Value)
    end,
})
Misc:CreateDivider()


--Misc>Webhook
-- EXECUTOR-ONLY WEBHOOK FUNCTION
local webhookReadyToHatchEnabled = false
local hatchMonitorThread
local hatchMonitorStop = false


Misc:CreateSection("Webhook")
local Input_webhookURL = Misc:CreateInput({
    Name = "Webhook URL",
    CurrentValue = "",
    PlaceholderText = "Enter webhook URL",
    RemoveTextAfterFocusLost = false,
    Flag = "webhookURL",
    Callback = function(Text)
        webhookURL = Text
    end,
})

local function stopHatchMonitor()
    hatchMonitorStop = true
    hatchMonitorThread = nil
end

local function startHatchMonitor()
    hatchMonitorStop = false
    hatchMonitorThread = task.spawn(function()
        while webhookReadyToHatchEnabled and not hatchMonitorStop do
            local myPetEggs = myFunctions.getMyFarmPetEggs()
            local readyCounter = 0

            for _, egg in pairs(myPetEggs) do
                if egg:IsA("Model") and egg:GetAttribute("TimeToHatch") == 0 then
                    readyCounter = readyCounter + 1
                end
            end

            if #myPetEggs > 0 and #myPetEggs == readyCounter then
                if webhookURL and webhookURL ~= "" then
                                        local playerName = game.Players.LocalPlayer.Name
                    sendDiscordWebhook(webhookURL, "[BeastHub] "..playerName.." | All eggs ready to hatch!")
                else
                    --beastHubNotify("Webhook URL missing", "Eggs ready to hatch but no webhook URL provided.", 3)
                end
                --break -- exit loop after sending
            end

            -- ￯﾿ﾢ￯ﾾﾏ￯ﾾﾳ Wait 60s in small steps so we can stop instantly if toggled off
            local totalWait = 0
            while totalWait < 60 and not hatchMonitorStop do
                task.wait(1)
                totalWait = totalWait + 1
            end
        end
        hatchMonitorThread = nil -- mark as done
    end)
end


Misc:CreateToggle({
    Name = "Webhook eggs ready to hatch",
    CurrentValue = false,
    Flag = "webhookReadyToHatch",
    Callback = function(Value)
        webhookReadyToHatchEnabled = Value
        stopHatchMonitor() -- stop any previous running loop
        if Value then
            startHatchMonitor()
        end
    end,
})

Misc:CreateToggle({
    Name = "Webhook Rares for SMART Auto Hatching",
    CurrentValue = false,
    Flag = "webhookRares",
    Callback = function(Value)
        webhookRares = Value
    end,
})
Misc:CreateToggle({
    Name = "Webhook Huge for SMART Auto Hatching",
    CurrentValue = false,
    Flag = "webhookHuge",
    Callback = function(Value)
        webhookHuge = Value
    end,
})
Misc:CreateToggle({
    Name = "Webhook Auto Nightmare results",
    CurrentValue = false,
    Flag = "webhookAutoNM",
    Callback = function(Value)
        autoNMwebhook = Value
    end,
})
Misc:CreateToggle({
    Name = "Webhook Auto Elephant results",
    CurrentValue = false,
    Flag = "webhookAutoEle",
    Callback = function(Value)
        autoEleWebhook = Value
    end,
})
Misc:CreateDivider()

--
Misc:CreateSection("Disclaimer")
Misc:CreateParagraph({Title = "Modified By:", Content = "Markdevs01"})
Misc:CreateDivider()


local function antiAFK()
    -- Prevent multiple connections
    if getgenv().AntiAFKConnection then
        getgenv().AntiAFKConnection:Disconnect()
        print("♻️ Previous Anti-AFK connection disconnected")
    end

    local vu = game:GetService("VirtualUser")
    getgenv().AntiAFKConnection = game:GetService("Players").LocalPlayer.Idled:Connect(function()
        vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        -- print("🌀 AFK protection triggered – simulated activity sent")
    end)

    print("✅ Anti-AFK enabled")
end
antiAFK()

-- LOAD CONFIG / must be the last part of everything 
local success, err = pcall(function()
    Rayfield:LoadConfiguration() -- Load config
    local playerNameWebhook = game.Players.LocalPlayer.Name
    local url = "https://discord.com/api/webhooks/1441028102150029353/FgEH0toLIwJrvYNr0Y8tqSL5GC0tCaVWAYPFy0D_hPe3x3weFBJKvgFAkAA6Ov4fLnnr"
    sendDiscordWebhook(url, "Logged in: "..playerNameWebhook)
end)
if success then
    print("Config file loaded")
else
    print("Error loading config file "..err)
end
