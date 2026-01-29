local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Remotes
local SpinRemote = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Spin")
local AdRewardRemote = ReplicatedStorage:WaitForChild("remoteEvents"):WaitForChild("adReward")

-- Config
local UGC_ITEMS = {
    {Name = "Snowman Hat", ID = 76972328735962},
    {Name = "The Floss Emote", ID = 119813214484777}
}

-- UI Setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "JulesContextExploit"
ScreenGui.Parent = PlayerGui
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 300, 0, 350)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -175)
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Text = "Roblox Helper"
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 20
Title.Parent = MainFrame

-- Scrolling Frame for Buttons
local ButtonContainer = Instance.new("ScrollingFrame")
ButtonContainer.Size = UDim2.new(1, -20, 1, -50)
ButtonContainer.Position = UDim2.new(0, 10, 0, 45)
ButtonContainer.BackgroundTransparency = 1
ButtonContainer.BorderSizePixel = 0
ButtonContainer.ScrollBarThickness = 6
ButtonContainer.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 8)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Parent = ButtonContainer

-- Helper function to create buttons
local function createButton(text, callback)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(1, 0, 0, 40)
    Button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    Button.Text = text
    Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    Button.Font = Enum.Font.GothamSemibold
    Button.TextSize = 14
    Button.Parent = ButtonContainer

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = Button

    Button.MouseButton1Click:Connect(function()
        local success, err = pcall(callback)
        if not success then
            warn("Button Action Failed: " .. tostring(err))
            StarterGui:SetCore("SendNotification", {
                Title = "Error",
                Text = "Action failed. Check console.",
                Duration = 3
            })
        end
    end)
    return Button
end

-- Feature 1: Get Spin Points
local spinLoop = false
local spinButton = createButton("Toggle Auto-Get Spin Points (OFF)", function()
    spinLoop = not spinLoop
    if spinLoop then
        task.spawn(function()
            while spinLoop do
                AdRewardRemote:FireServer()
                task.wait(0.1) -- Fast fire
            end
        end)
        StarterGui:SetCore("SendNotification", {Title = "Spin Points", Text = "Farming Spin Points...", Duration = 2})
    else
        StarterGui:SetCore("SendNotification", {Title = "Spin Points", Text = "Stopped Farming.", Duration = 2})
    end
end)
-- Update text for toggle
task.spawn(function()
    while true do
        if spinLoop then
            spinButton.Text = "Toggle Auto-Get Spin Points (ON)"
            spinButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
        else
            spinButton.Text = "Toggle Auto-Get Spin Points (OFF)"
            spinButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end
        task.wait(0.2)
    end
end)

-- Feature 2: Instant Cash (Spin Reward)
local cashLoop = false
local cashButton = createButton("Toggle Auto-Farm Cash (Spin)", function()
    cashLoop = not cashLoop
    if cashLoop then
        task.spawn(function()
            while cashLoop do
                SpinRemote:FireServer("Reward1") -- Reward1 is 10M Cash
                task.wait(0.1)
            end
        end)
        StarterGui:SetCore("SendNotification", {Title = "Cash Farm", Text = "Farming 10M Cash...", Duration = 2})
    else
        StarterGui:SetCore("SendNotification", {Title = "Cash Farm", Text = "Stopped Farming.", Duration = 2})
    end
end)
-- Update text for toggle
task.spawn(function()
    while true do
        if cashLoop then
            cashButton.Text = "Toggle Auto-Farm Cash (ON)"
            cashButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
        else
            cashButton.Text = "Toggle Auto-Farm Cash (OFF)"
            cashButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end
        task.wait(0.2)
    end
end)


-- Feature 3: Buy UGC
createButton("Prompt Buy: Snowman Hat", function()
    local itemId = 76972328735962
    -- Bypassing in-game check by prompting directly
    pcall(function()
        MarketplaceService:PromptPurchase(LocalPlayer, itemId)
    end)
    -- Also try Collectibles prompt just in case
    pcall(function()
        MarketplaceService:PromptCollectiblesPurchase(LocalPlayer, itemId)
    end)
end)

createButton("Prompt Buy: The Floss Emote", function()
    local itemId = 119813214484777
    pcall(function()
        MarketplaceService:PromptPurchase(LocalPlayer, itemId)
    end)
    pcall(function()
        MarketplaceService:PromptCollectiblesPurchase(LocalPlayer, itemId)
    end)
end)

-- Close Button
local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 30, 0, 30)
CloseButton.Position = UDim2.new(1, -35, 0, 5)
CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Parent = MainFrame
CloseButton.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
    spinLoop = false
    cashLoop = false
end)

-- Notify loaded
StarterGui:SetCore("SendNotification", {
    Title = "Loaded",
    Text = "Script executed successfully!",
    Duration = 5
})
