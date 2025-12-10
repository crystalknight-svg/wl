--[[ 
    ULTIMATE TAS PLAYER - RESUME & CACHE
    Repo: crystalknight-svg/cek
    
    Fitur:
    - Resume System (Lanjut dari posisi stop)
    - Pause Button
    - Reset Button (Ulang dari awal)
    - Smart Caching
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local Plr = Players.LocalPlayer
local Char = Plr.Character or Plr.CharacterAdded:Wait()
local Root = Char:WaitForChild("HumanoidRootPart")
local Hum = Char:WaitForChild("Humanoid")

-- === KONFIGURASI ===
local REPO_USER = "crystalknight-svg"
local REPO_NAME = "cek"
local BRANCH = "main" 
local START_CP = 0    
local END_CP = 49     

-- === DATA STORAGE & STATE ===
local TASDataCache = {} 
local isCached = false  
local isPlaying = false

-- State untuk Resume
local SavedCP = START_CP    -- Menyimpan index CP terakhir
local SavedFrame = 1        -- Menyimpan index Frame terakhir

-- === GUI SETUP ===
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local StartBtn = Instance.new("TextButton")
local StopBtn = Instance.new("TextButton")
local ResetBtn = Instance.new("TextButton") -- Tombol Baru
local StatusLbl = Instance.new("TextLabel")
local ProgressBar = Instance.new("Frame")
local ProgressFill = Instance.new("Frame")
local UICorner = Instance.new("UICorner")

-- Setup GUI Visuals
ScreenGui.Name = "TAS_Resume_System"
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false

MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.Position = UDim2.new(0.5, -110, 0.5, -100)
MainFrame.Size = UDim2.new(0, 220, 0, 220) -- Sedikit lebih tinggi untuk tombol Reset
MainFrame.Active = true
MainFrame.Draggable = true
UICorner.Parent = MainFrame

Title.Parent = MainFrame
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 0, 0, 5)
Title.Size = UDim2.new(1, 0, 0, 25)
Title.Font = Enum.Font.GothamBold
Title.Text = "TAS RESUME PLAYER"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 16

StatusLbl.Parent = MainFrame
StatusLbl.BackgroundTransparency = 1
StatusLbl.Position = UDim2.new(0, 0, 0, 30)
StatusLbl.Size = UDim2.new(1, 0, 0, 20)
StatusLbl.Font = Enum.Font.Gotham
StatusLbl.Text = "Status: Ready"
StatusLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
StatusLbl.TextSize = 11

-- Progress Bar
ProgressBar.Parent = MainFrame
ProgressBar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
ProgressBar.Position = UDim2.new(0.1, 0, 0.25, 0)
ProgressBar.Size = UDim2.new(0.8, 0, 0.04, 0)
ProgressBar.BorderSizePixel = 0

ProgressFill.Parent = ProgressBar
ProgressFill.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
ProgressFill.Size = UDim2.new(0, 0, 1, 0)
ProgressFill.BorderSizePixel = 0

-- Tombol Start / Resume
StartBtn.Parent = MainFrame
StartBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113) -- Hijau
StartBtn.Position = UDim2.new(0.1, 0, 0.35, 0)
StartBtn.Size = UDim2.new(0.8, 0, 0.18, 0)
StartBtn.Font = Enum.Font.GothamBold
StartBtn.Text = "START / RESUME"
StartBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
StartBtn.TextSize = 13
Instance.new("UICorner", StartBtn).CornerRadius = UDim.new(0, 6)

-- Tombol Pause
StopBtn.Parent = MainFrame
StopBtn.BackgroundColor3 = Color3.fromRGB(241, 196, 15) -- Kuning/Orange untuk Pause
StopBtn.Position = UDim2.new(0.1, 0, 0.55, 0)
StopBtn.Size = UDim2.new(0.8, 0, 0.18, 0)
StopBtn.Font = Enum.Font.GothamBold
StopBtn.Text = "PAUSE"
StopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
StopBtn.TextSize = 13
Instance.new("UICorner", StopBtn).CornerRadius = UDim.new(0, 6)

-- Tombol Reset
ResetBtn.Parent = MainFrame
ResetBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60) -- Merah untuk Reset
ResetBtn.Position = UDim2.new(0.1, 0, 0.75, 0)
ResetBtn.Size = UDim2.new(0.8, 0, 0.18, 0)
ResetBtn.Font = Enum.Font.GothamBold
ResetBtn.Text = "RESET (KE AWAL)"
ResetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ResetBtn.TextSize = 13
Instance.new("UICorner", ResetBtn).CornerRadius = UDim.new(0, 6)

-- === FUNGSI LOGIKA ===

local function UpdateProgress(current, total)
    local percentage = current / total
    ProgressFill:TweenSize(UDim2.new(percentage, 0, 1, 0), "Out", "Quad", 0.1)
end

local function GetURL(index)
    return string.format("https://raw.githubusercontent.com/%s/%s/%s/cp_%d.json", REPO_USER, REPO_NAME, BRANCH, index)
end

local function ResetCharacter()
    if Hum then
        Hum.PlatformStand = false
        Hum.AutoRotate = true
        Hum:ChangeState(Enum.HumanoidStateType.Landed)
    end
    if Root then
        Root.AssemblyLinearVelocity = Vector3.zero
    end
end

-- === STEP 1: DOWNLOADER ===
local function DownloadData()
    local totalFiles = (END_CP - START_CP) + 1
    local count = 0
    
    StatusLbl.Text = "Caching Data..."
    StartBtn.Text = "DOWNLOADING..."
    
    for i = START_CP, END_CP do
        if not isPlaying then return false end 

        if not TASDataCache[i] then
            local url = GetURL(i)
            local success, response = pcall(function() return game:HttpGet(url) end)
            
            if success then
                TASDataCache[i] = HttpService:JSONDecode(response)
            else
                warn("Gagal download CP_" .. i)
                TASDataCache[i] = {}
            end
        end
        
        count = count + 1
        UpdateProgress(count, totalFiles)
        StatusLbl.Text = string.format("Cached: %d / %d", count, totalFiles)
        task.wait() 
    end
    
    isCached = true
    return true
end

-- === STEP 2: PLAYER (WITH RESUME) ===
local function RunPlayback()
    StartBtn.Text = "PLAYING..."
    StatusLbl.Text = "Status: Playing..."
    
    Root.Anchored = false
    Hum.PlatformStand = false 
    Hum.AutoRotate = false
    
    -- Loop CP dimulai dari SavedCP (Bukan dari START_CP)
    for i = SavedCP, END_CP do
        if not isPlaying then break end
        
        SavedCP = i -- Update Tracker CP
        local data = TASDataCache[i]
        
        if not data then continue end
        
        StatusLbl.Text = string.format("Playing: CP_%d (Frame: %d)", i, SavedFrame)
        
        -- Loop Frame dimulai dari SavedFrame (Bukan dari 1)
        -- Kita pakai loop numeric agar bisa start dari index tertentu
        for f = SavedFrame, #data do
            if not isPlaying then break end
            
            SavedFrame = f -- Update Tracker Frame
            
            local frame = data[f]
            if not Char or not Root then isPlaying = false break end

            -- 1. HipHeight
            if frame.HIP then Hum.HipHeight = frame.HIP end

            -- 2. CFrame
            local posX, posY, posZ = frame.POS.x, frame.POS.y, frame.POS.z
            local rotY = frame.ROT or 0
            Root.CFrame = CFrame.new(posX, posY, posZ) * CFrame.Angles(0, rotY, 0)

            -- 3. Velocity
            if frame.VEL then
                local vel = Vector3.new(frame.VEL.x, frame.VEL.y, frame.VEL.z)
                Root.AssemblyLinearVelocity = vel
                if Vector3.new(vel.X, 0, vel.Z).Magnitude > 0.1 then
                    Hum:Move(vel, false)
                end
            end

            -- 4. Animation State
            if frame.STA then
                local s = frame.STA
                if s == "Jumping" then Hum:ChangeState(Enum.HumanoidStateType.Jumping) Hum.Jump = true
                elseif s == "Freefall" then Hum:ChangeState(Enum.HumanoidStateType.Freefall)
                elseif s == "Landed" then Hum:ChangeState(Enum.HumanoidStateType.Landed)
                elseif s == "Running" then Hum:ChangeState(Enum.HumanoidStateType.Running)
                end
            end

            RunService.Heartbeat:Wait()
        end
        
        -- PENTING: Jika loop CP ini selesai (tidak di-pause),
        -- Reset SavedFrame ke 1 agar CP berikutnya mulai dari awal frame.
        if isPlaying then
            SavedFrame = 1
        end
        
        RunService.Heartbeat:Wait()
    end
    
    if isPlaying then
        -- Jika loop selesai sampai akhir tanpa pause
        isPlaying = false
        StartBtn.Text = "REPLAY"
        StatusLbl.Text = "Playback Selesai."
        
        -- Reset Tracker ke awal
        SavedCP = START_CP
        SavedFrame = 1
        
        ResetCharacter()
    else
        -- Jika berhenti karena tombol Pause
        StatusLbl.Text = string.format("Paused at CP_%d | Fr_%d", SavedCP, SavedFrame)
        StartBtn.Text = "RESUME"
    end
end

-- === CONTROL LOGIC ===

-- 1. TOMBOL START / RESUME
StartBtn.MouseButton1Click:Connect(function()
    if isPlaying then return end
    isPlaying = true
    
    task.spawn(function()
        -- Download dulu jika belum cache
        if not isCached then
            local downloadSuccess = DownloadData()
            if not downloadSuccess then 
                isPlaying = false 
                StatusLbl.Text = "Download Cancelled"
                StartBtn.Text = "RETRY"
                return 
            end
        end
        
        -- Jalankan Player
        RunPlayback()
    end)
end)

-- 2. TOMBOL PAUSE
StopBtn.MouseButton1Click:Connect(function()
    if isPlaying then
        isPlaying = false -- Ini akan menghentikan loop, tapi SavedCP & SavedFrame tersimpan
        ResetCharacter()
        -- Status update diurus di akhir fungsi RunPlayback
    end
end)

-- 3. TOMBOL RESET (Hapus progress resume)
ResetBtn.MouseButton1Click:Connect(function()
    isPlaying = false
    task.wait(0.1)
    
    SavedCP = START_CP
    SavedFrame = 1
    
    ResetCharacter()
    
    StatusLbl.Text = "Reset to CP_0"
    StartBtn.Text = "START NEW"
    UpdateProgress(0, 1)
end)

Notify("TAS Resume System Loaded!")

