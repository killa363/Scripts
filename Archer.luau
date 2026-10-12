if getgenv().Executed then 
    return
end

getgenv().Executed = true

-- LuqQ:
if not LUAQ_OBFUSCATED then
    LUAQ_INLINE = function(fn) return fn end
    LUAQ_CRASH = function() while true do end end
    LUAQ_ENCSTR = function(s) return s end
    LUAQ_NO_OBF = function(s) return s end
    LPH_NO_OBF = LUAQ_NO_OBF
    LUAQ_ENCNUM = function(n) return n end
    LUAQ_ENCFUNC = function(fn, _e, _d) return fn end
    LUAQ_NO_VIRTUALIZE = function(...) return ... end
    LUAQ_NO_UPVALUES = function(...) return ... end
    LUAQ_INDEX_TO_NUM = function(t) return t end
    LUAQ_PRECHECK = function(_check, _expectedKey) end
end

-- Locals:
local Game = game
local Workspace = workspace
local GetService = Game.GetService
local HttpGet = Game.HttpGet
local NewVector2 = Vector2.new
local NewVector3 = Vector3.new
local EmptyVector3 = NewVector3(0, 0, 0)
local NewColor3 = Color3.fromRGB
local NewCFrame = CFrame.new
local CFrameAngles = CFrame.Angles
local NewInstance = Instance.new
local NewRaycastParams = RaycastParams.new
local Max = math.max
local Min = math.min
local Ceil = math.ceil
local Abs = math.abs
local Atan2 = math.atan2
local Rad = math.rad
local Sin = math.sin
local Random = math.random
local Huge = math.huge
local Clock = os.clock
local Type = type
local Typeof = typeof
local ProtectedCall = pcall
local Require = require
local HookFunction = hookfunction
local HookMetaMethod = hookmetamethod
local NewCClosure = newcclosure
local LoadString = loadstring
local TableInsert = table.insert
local TableSort = table.sort
local Spawn = task.spawn

-- Services:
local Players = GetService(Game, "Players")
local RunService = GetService(Game, "RunService")
local UserInputService = GetService(Game, "UserInputService")
local ReplicatedStorage = GetService(Game, "ReplicatedStorage")

-- Global Constants:
local OBSIDIAN_URL = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"

local Config = {
    SilentAim = false,
    FOVSize = 180,
    FOVColor = NewColor3(255, 255, 255),
    ShowFOV = false,
    HitPart = "Head",
    MaxFlightTicks = 100,
    NoAimAnimation = false,
    FullDrawTicks = 20,
    RageBot = false,
    RageDrawTicks = 20,
    RageShotDelay = 0.1,
    FastWalk = false,
    WalkSpeed = 24,
    NoAimSlowdown = false,
    Fly = false,
    FlySpeed = 24,
    FlyMethod = "Normal",
    ThirdPerson = false,
    ThirdPersonZoom = 5,
    AntiAim = false,
    AntiAimMotion = "Continuous",
    AntiAimFacingReference = "View",
    AntiAimDirection = "Right",
    AntiAimMotionSpeed = 360,
    AntiAimChangeInterval = 0.2,
    AntiAimTurnOffset = 180,
    AntiAimSweepRange = 90,
    HighlightChams = false,
    ChamsFillColor = NewColor3(255, 0, 0),
    ChamsFillTransparency = 0.61,
    ChamsOutlineColor = NewColor3(255, 255, 255),
    ChamsOutlineTransparency = 0.21,
}

local LocalPlayer = Players.LocalPlayer
local Client = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local BowController = Require(Client:WaitForChild("BowController"))
local BowMovement = Require(Client:WaitForChild("BowMovement"))
local CombatClient = Require(Client:WaitForChild("CombatClient"))
local FirstPersonAnimationModule = Client:WaitForChild("FirstPersonAnimation")
local FirstPersonAnimation = Require(FirstPersonAnimationModule)
local TaCZMotion = Require(FirstPersonAnimationModule:WaitForChild("TaCZMotion"))
local BowMath = Require(Shared:WaitForChild("BowMath"))
local BowNet = Require(Shared:WaitForChild("BowNet"))
local BowConfig = Require(Shared:WaitForChild("BowConfig"))
local CharacterLife = Require(Shared:WaitForChild("CharacterLife"))
local EnchantEffects = Require(Shared:WaitForChild("EnchantEffects"))

-- Module:
local Archer = {}
type Archer = typeof(Archer)

local Interface = {}
type Interface = typeof(Interface)

do
    local ActiveRelease = nil
    local ActivePreview = nil
    local ActiveDrawingController = nil
    local CachedDraws = setmetatable({}, {__mode = "k"})
    local RageState = nil
    local NextRageShot = 0
    local HiddenShots = {}
    local HiddenArrows = {}
    local ChamsHighlights = {}
    local FlyHumanoid = nil
    local FlyRoot = nil
    local FlyPlatformStand = nil
    local FlyAutoRotate = nil
    local FlyAttachment = nil
    local FlyVelocity = nil
    local FlyOrientation = nil
    local FlyCollisions = {}
    local MobileControls = nil
    local RawCamera = nil
    local RawCameraCFrame = nil
    local ShiftedCameraCFrame = nil
    local AntiAimHumanoid = nil
    local AntiAimAutoRotate = nil
    local AntiAimMode = nil
    local AntiAimAngle = 0
    local AntiAimTimer = 0
    local AntiAimStep = 0
    local AntiAimSign = 1
    local AntiAimRandom = 0
    local AntiAimLastShot = 0
    local AntiAimShotDirection = nil
    local TripleSteps = {0, 120, 240}
    local FiveSteps = {0, 72, 144, 216, 288}

    -- Private Methods:
    local function IsMobile()
        return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    end

    local function AimScreenPosition()
        local Camera = Workspace.CurrentCamera
        return if IsMobile() and Camera
            then Camera.ViewportSize / 2
            else UserInputService:GetMouseLocation()
    end

    local function TargetPart(Character, Player, InfectionMode, PartName)
        if not Character or Character.Name == "DeathModel" then
            return nil
        end
        if InfectionMode then
            local RoleSource = Player or Character
            if RoleSource:GetAttribute("InfectionRole") ~= "Zombie" then
                return nil
            end
        end
        if Player and Player:GetAttribute("MatchStatus") == "Dead" then
            return nil
        end

        local Humanoid = Character:FindFirstChildOfClass("Humanoid")
        if not Humanoid
            or CharacterLife.isDead(Humanoid)
            or Humanoid:GetState() == Enum.HumanoidStateType.Dead
        then
            return nil
        end

        local Part = Character:FindFirstChild(PartName or Config.HitPart)
        if Part and Part:IsA("BasePart") then
            return Part
        end
        return nil
    end

    local UpdateChamsEntity = LUAQ_NO_VIRTUALIZE(function(Entity, Character, Player)
        local Visible = Config.HighlightChams
            and Character
            and Character:IsDescendantOf(Workspace)
            and TargetPart(Character, Player, false, "HumanoidRootPart") ~= nil
        local Highlight = ChamsHighlights[Entity]

        if not Visible then
            if Highlight then
                Highlight.Enabled = false
                Highlight.Adornee = nil
                Highlight.Parent = nil
            end
            return
        end

        if not Highlight then
            Highlight = NewInstance("Highlight")
            Highlight.Name = "\0"
            Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            ChamsHighlights[Entity] = Highlight
        end

        Highlight.FillColor = Config.ChamsFillColor
        Highlight.FillTransparency = Config.ChamsFillTransparency
        Highlight.OutlineColor = Config.ChamsOutlineColor
        Highlight.OutlineTransparency = Config.ChamsOutlineTransparency
        Highlight.Adornee = Character
        Highlight.Parent = Workspace
        Highlight.Enabled = true
    end)

    local UpdateChams = LUAQ_NO_VIRTUALIZE(function()
        local Seen = {}
        for _, Player in Players:GetPlayers() do
            if Player ~= LocalPlayer then
                Seen[Player] = true
                UpdateChamsEntity(Player, Player.Character, Player)
            end
        end

        local Bots = Workspace:FindFirstChild("Bots")
        if Bots then
            for _, Bot in Bots:GetChildren() do
                if Bot:IsA("Model") then
                    Seen[Bot] = true
                    UpdateChamsEntity(Bot, Bot, nil)
                end
            end
        end

        for Entity, Highlight in ChamsHighlights do
            if not Seen[Entity] then
                Highlight:Destroy()
                ChamsHighlights[Entity] = nil
            end
        end
    end)

    local FindTarget = LUAQ_NO_VIRTUALIZE(function()
        local Camera = Workspace.CurrentCamera
        if not Camera then
            return nil
        end

        local Mouse = AimScreenPosition()
        local BestPart = nil
        local BestDistance = Config.FOVSize
        local InfectionMode = LocalPlayer:GetAttribute("MatchMode") == "Infection"

        local function Consider(Character, Player)
            local Part = TargetPart(Character, Player, InfectionMode)
            if not Part then
                return
            end

            local Screen = Camera:WorldToViewportPoint(Part.Position)
            if Screen.Z <= 0 then
                return
            end

            local Distance = (NewVector2(Screen.X, Screen.Y) - Mouse).Magnitude
            if Distance >= BestDistance then
                return
            end

            BestDistance = Distance
            BestPart = Part
        end

        for _, Player in Players:GetPlayers() do
            if Player == LocalPlayer then
                continue
            end

            Consider(Player.Character, Player)
        end

        local Bots = Workspace:FindFirstChild("Bots")
        if Bots then
            for _, Bot in Bots:GetChildren() do
                if not Bot:IsA("Model") then
                    continue
                end

                Consider(Bot)
            end
        end

        return BestPart
    end)

    local function PathClear(Part, Origin, Params)
        local Direction = Part.Position - Origin
        if Direction.Magnitude <= 0 then
            return false, nil
        end

        local Hit = Workspace:Raycast(Origin, Direction, Params)
        return Hit == nil, Hit and Hit.Instance
    end

    local function RageRaycastParams()
        local Params = NewRaycastParams()
        Params.FilterType = Enum.RaycastFilterType.Exclude
        Params.IgnoreWater = true
        Params.RespectCanCollide = true
        return Params
    end

    local function FindRageTarget(Controller, Origin)
        Origin = Origin or Controller:launchPoint()
        local Params = RageRaycastParams()
        local Choices = {}

        local function Consider(Character, Player)
            local Root = TargetPart(Character, Player, false, "HumanoidRootPart")
            if not Root then
                return
            end

            local Distance = (Root.Position - Origin).Magnitude
            local Parts = {Root}
            local Torso = Character:FindFirstChild("UpperTorso") or Character:FindFirstChild("Torso")
            local Head = Character:FindFirstChild("Head")
            if Torso and Torso:IsA("BasePart") then
                TableInsert(Parts, 1, Torso)
            end
            if Head and Head:IsA("BasePart") then
                TableInsert(Parts, Head)
            end

            Params.FilterDescendantsInstances = {LocalPlayer.Character, Controller.effects, Character}
            local Visible = false
            for Priority, Candidate in Parts do
                local Clear = PathClear(Candidate, Origin, Params)
                if Clear then
                    Visible = true
                    TableInsert(Choices, {Part = Candidate, Distance = Distance, Priority = Priority})
                end
            end

            if not Visible then
                return
            end

        end

        for _, Player in Players:GetPlayers() do
            if Player ~= LocalPlayer then
                Consider(Player.Character, Player)
            end
        end

        local Bots = Workspace:FindFirstChild("Bots")
        if Bots then
            for _, Bot in Bots:GetChildren() do
                if Bot:IsA("Model") then
                    Consider(Bot)
                end
            end
        end

        TableSort(Choices, function(Left, Right)
            if Left.Distance == Right.Distance then
                return Left.Priority < Right.Priority
            end
            return Left.Distance < Right.Distance
        end)
        local Closest = Choices[1]
        return Closest and Closest.Part, Choices
    end

    local function StopRage(Delay, CancelDraw)
        local State = RageState
        RageState = nil
        NextRageShot = Clock() + Delay

        if CancelDraw and State and State.Stage ~= "AwaitRelease" then
            State.Controller.network:send("Cancel")
        end
    end

    local function SolveDirection(Controller, Origin, ChargeTicks, Target, DrawId, Effects)
        local Seed = Controller.network and Controller.network.bowSeed
        DrawId = DrawId or Controller.drawId
        local Character = LocalPlayer.Character
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")
        if not Seed or not DrawId or not Root or not Target or ChargeTicks == nil then
            return nil, "missing seed, draw ID, character root, target, or charge"
        end

        local Power = BowMath.powerTicks(ChargeTicks)
        if Power < 0.1 then
            return nil, "draw charge is below launch threshold"
        end

        Effects = Effects or Controller.drawEffects
        local SpeedBonus = 1 + (Effects and Effects.ArrowSpeedBonus or 0)
        local Speed = BowMath.f32(Power * 3 * SpeedBonus)
        if Speed <= 0 then
            return nil, "launch speed is zero"
        end

        local Spread = BowMath.launchSpread(BowNet.random(Seed, DrawId))
        local Source = BowMath.fromWorld(BowNet.clampVelocity(Root.AssemblyLinearVelocity) * BowConfig.Tick)
        local OriginBlocks = BowMath.fromWorld(Origin)
        local TargetRoot = Target.Parent and Target.Parent:FindFirstChild("HumanoidRootPart")
        local TargetVelocity = if TargetRoot and TargetRoot:IsA("BasePart")
            then TargetRoot.AssemblyLinearVelocity
            else Target.AssemblyLinearVelocity
        local Drag = BowMath.AirInertia

        local function Candidate(Ticks)
            local Sum = (1 - Drag ^ Ticks) / (1 - Drag)
            local GravityDrop = 0.05 * (Ticks - Sum) / (1 - Drag)
            local Future = Target.Position + TargetVelocity * (Ticks * BowConfig.Tick)
            local Destination = BowMath.fromWorld(Future)
            local Delta = NewVector3(
                Destination.x - OriginBlocks.x,
                Destination.y - OriginBlocks.y,
                Destination.z - OriginBlocks.z
            )
            local RequiredVelocity = NewVector3(
                Delta.X / Sum,
                (Delta.Y + GravityDrop) / Sum,
                Delta.Z / Sum
            )
            local Aim = NewVector3(
                (RequiredVelocity.X - Source.x) / Speed - Spread.x,
                RequiredVelocity.Y / Speed - Spread.y,
                (RequiredVelocity.Z - Source.z) / Speed - Spread.z
            )
            return Aim, Aim.Magnitude - 1
        end

        local PreviousTicks = 0.25
        local _, PreviousError = Candidate(PreviousTicks)
        local BestAim = nil
        local BestTicks = nil
        local BestError = Huge

        for Ticks = 0.5, Config.MaxFlightTicks, 0.5 do
            local Aim, Error = Candidate(Ticks)
            if Abs(Error) < BestError then
                BestAim = Aim
                BestTicks = Ticks
                BestError = Abs(Error)
            end

            if PreviousError > 0 and Error <= 0 then
                local Low, High = PreviousTicks, Ticks
                for _ = 1, 18 do
                    local Mid = (Low + High) * 0.5
                    local _, MidError = Candidate(Mid)
                    if MidError > 0 then
                        Low = Mid
                    else
                        High = Mid
                    end
                end
                Aim = Candidate((Low + High) * 0.5)
                if Aim.Magnitude > 0 then
                    return Aim.Unit, nil, {
                        FlightTicks = (Low + High) * 0.5,
                        Power = Power,
                        Speed = Speed,
                        Spread = Spread,
                        Source = Source,
                        Fallback = false,
                    }
                end
                return nil, "aim vector is zero"
            end

            PreviousTicks = Ticks
            PreviousError = Error
        end

        if not BestAim or BestAim.Magnitude <= 0 then
            return nil, "no usable trajectory"
        end

        return BestAim.Unit, nil, {
            FlightTicks = BestTicks,
            Power = Power,
            Speed = Speed,
            Spread = Spread,
            Source = Source,
            Fallback = true,
            Residual = BestError,
        }
    end

    local function TrajectoryClear(Controller, Origin, Target, Velocity, FlightTicks)
        local Params = RageRaycastParams()
        Params.FilterDescendantsInstances = {LocalPlayer.Character, Controller.effects, Target.Parent}

        local Position = BowMath.fromWorld(Origin)
        for Tick = 1, Ceil(FlightTicks) do
            local Fraction = Min(1, FlightTicks - Tick + 1)
            local Start = BowMath.toWorld(Position)
            local Segment = BowMath.toWorld(Velocity) * Fraction
            local Hit = Workspace:Raycast(Start, Segment, Params)
            if Hit then
                return false, Hit.Instance
            end
            Position, Velocity = BowMath.arrowStep(Position, Velocity)
        end

        return true, nil
    end

    local function ThirdPersonActive(Camera)
        local Controller = BowController.active
        return Config.ThirdPerson
            and Config.ThirdPersonZoom > 0
            and Controller
            and Controller.inMatch
            and Controller.camera == Camera
            and not Controller.cinematicHidden
            and not (Controller.ragdollPrediction and Controller.ragdollPrediction.deathCamera.active)
    end

    local function RestoreFlyCollisions()
        for Part, CanCollide in FlyCollisions do
            if Part.Parent then
                Part.CanCollide = CanCollide
            end
            FlyCollisions[Part] = nil
        end
    end

    local function RestoreFly()
        RestoreFlyCollisions()
        if FlyOrientation then
            FlyOrientation:Destroy()
        end
        if FlyVelocity then
            FlyVelocity:Destroy()
        end
        if FlyAttachment then
            FlyAttachment:Destroy()
        end
        if FlyHumanoid and FlyHumanoid.Parent then
            FlyHumanoid.PlatformStand = FlyPlatformStand
            FlyHumanoid.AutoRotate = FlyAutoRotate
            if FlyHumanoid.Health > 0
                and FlyHumanoid:GetState() == Enum.HumanoidStateType.Physics
            then
                FlyHumanoid:ChangeState(if FlyPlatformStand
                    then Enum.HumanoidStateType.PlatformStanding
                    else Enum.HumanoidStateType.GettingUp)
            end
        end
        FlyHumanoid = nil
        FlyRoot = nil
        FlyPlatformStand = nil
        FlyAutoRotate = nil
        FlyAttachment = nil
        FlyVelocity = nil
        FlyOrientation = nil
    end

    local UpdateFly = LUAQ_NO_VIRTUALIZE(function()
        local Character = LocalPlayer.Character
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")
        local Camera = Workspace.CurrentCamera
        if not Config.Fly
            or not Humanoid
            or not Root
            or not Camera
            or Humanoid.Health <= 0
            or Humanoid.SeatPart
            or Root.Anchored
            or CharacterLife.isDead(Humanoid)
        then
            RestoreFly()
            return
        end

        if FlyHumanoid ~= Humanoid
            or FlyRoot ~= Root
            or not FlyAttachment or not FlyAttachment.Parent
            or not FlyVelocity or not FlyVelocity.Parent
            or not FlyOrientation or not FlyOrientation.Parent
        then
            RestoreFly()
            FlyHumanoid = Humanoid
            FlyRoot = Root
            FlyPlatformStand = Humanoid.PlatformStand
            FlyAutoRotate = if AntiAimHumanoid == Humanoid and AntiAimAutoRotate ~= nil
                then AntiAimAutoRotate else Humanoid.AutoRotate

            FlyAttachment = NewInstance("Attachment")
            FlyAttachment.Name = "ArcherFlyAttachment"
            FlyAttachment.Parent = Root

            FlyVelocity = NewInstance("LinearVelocity")
            FlyVelocity.Name = "ArcherFlyVelocity"
            FlyVelocity.Attachment0 = FlyAttachment
            FlyVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
            FlyVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
            FlyVelocity.ForceLimitsEnabled = true
            FlyVelocity.ForceLimitMode = Enum.ForceLimitMode.Magnitude
            FlyVelocity.MaxForce = Max(10000, Root.AssemblyMass * Workspace.Gravity * 8)
            FlyVelocity.VectorVelocity = EmptyVector3
            FlyVelocity.Parent = Root

            FlyOrientation = NewInstance("AlignOrientation")
            FlyOrientation.Name = "ArcherFlyOrientation"
            FlyOrientation.Attachment0 = FlyAttachment
            FlyOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
            FlyOrientation.Responsiveness = 60
            FlyOrientation.MaxTorque = Max(10000, Root.AssemblyMass * 10000)
            FlyOrientation.CFrame = Root.CFrame.Rotation
            FlyOrientation.Parent = Root

            Root.AssemblyLinearVelocity = EmptyVector3
            Root.AssemblyAngularVelocity = EmptyVector3
        end

        Humanoid.AutoRotate = false
        if Humanoid:GetState() ~= Enum.HumanoidStateType.Physics then
            Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        end

        local CameraCFrame = Camera.CFrame
        local Look = CameraCFrame.LookVector
        local Right = CameraCFrame.RightVector
        local Direction = EmptyVector3
        local Mobile = IsMobile()
        if Mobile then
            local Move = MobileControls and MobileControls.inputMoveVector or Humanoid.MoveDirection
            if Typeof(Move) == "Vector3" then
                local FlatLook = NewVector3(Look.X, 0, Look.Z)
                local FlatRight = NewVector3(Right.X, 0, Right.Z)
                if FlatLook.Magnitude > 0.001 and FlatRight.Magnitude > 0.001 then
                    Direction = Look * Move:Dot(FlatLook.Unit) + Right * Move:Dot(FlatRight.Unit)
                else
                    Direction = Move
                end
            end
        else
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                Direction += Look
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                Direction -= Look
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                Direction -= Right
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                Direction += Right
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                Direction += NewVector3(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                Direction -= NewVector3(0, 1, 0)
            end
        end
        if Direction.Magnitude > 0 then
            local Speed = Min(Config.FlySpeed, 30)
            Direction = if Mobile then Direction / Max(1, Direction.Magnitude) * Speed else Direction.Unit * Speed
        end
        FlyVelocity.VectorVelocity = Direction

        if Config.FlyMethod == "Noclip" then
            for _, Part in Character:GetDescendants() do
                if Part:IsA("BasePart") and Part.CanCollide then
                    FlyCollisions[Part] = true
                    Part.CanCollide = false
                end
            end
        else
            RestoreFlyCollisions()
        end

        local FlatLook = NewVector3(Look.X, 0, Look.Z)
        if FlatLook.Magnitude <= 0.001 then
            local RootLook = Root.CFrame.LookVector
            FlatLook = NewVector3(RootLook.X, 0, RootLook.Z)
        end
        if FlatLook.Magnitude > 0.001 and AntiAimHumanoid ~= Humanoid then
            FlyOrientation.CFrame = NewCFrame(EmptyVector3, FlatLook.Unit)
        end
    end)

    local function SetAntiAimFacing(Root, Facing)
        if Config.Fly and FlyRoot == Root and FlyOrientation and FlyOrientation.Parent then
            FlyOrientation.CFrame = Facing.Rotation
        else
            Root.CFrame = Facing
        end
    end

    local function RestoreAntiAim()
        if AntiAimHumanoid and AntiAimHumanoid.Parent and FlyHumanoid ~= AntiAimHumanoid then
            AntiAimHumanoid.AutoRotate = AntiAimAutoRotate
        end
        AntiAimHumanoid = nil
        AntiAimAutoRotate = nil
    end

    local UpdateAntiAim = LUAQ_NO_VIRTUALIZE(function(Delta)
        local Character = LocalPlayer.Character
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")
        local Controller = BowController.active
        local Camera = Workspace.CurrentCamera
        if not Config.AntiAim
            or not Controller
            or not Controller.inMatch
            or not Camera
            or not Root
            or not Humanoid
            or Humanoid.Health <= 0
            or CharacterLife.isDead(Humanoid)
        then
            RestoreAntiAim()
            return
        end

        if AntiAimHumanoid ~= Humanoid then
            RestoreAntiAim()
            AntiAimHumanoid = Humanoid
            AntiAimAutoRotate = Humanoid.AutoRotate
        end
        Humanoid.AutoRotate = false

        if Clock() - AntiAimLastShot < 0.12 and AntiAimShotDirection then
            local Direction = AntiAimShotDirection
            local Flat = NewVector3(Direction.X, 0, Direction.Z)
            if Flat.Magnitude > 0.001 then
                SetAntiAimFacing(Root, NewCFrame(Root.Position, Root.Position + Flat.Unit))
                return
            end
        end

        local Mode = Config.AntiAimMotion
        if Mode ~= AntiAimMode then
            AntiAimMode = Mode
            AntiAimAngle = 0
            AntiAimTimer = 0
            AntiAimStep = 0
            AntiAimSign = 1
            AntiAimRandom = 0
        end

        local BaseYaw = nil
        if Config.AntiAimFacingReference == "Current Target" then
            local Target = RageState and RageState.Target or FindTarget()
            if Target and Target.Parent then
                local Direction = Target.Position - Root.Position
                local Flat = NewVector3(Direction.X, 0, Direction.Z)
                if Flat.Magnitude > 0.001 then
                    BaseYaw = Atan2(-Flat.X, -Flat.Z)
                end
            end
        end
        if not BaseYaw then
            local Look = Camera.CFrame.LookVector
            BaseYaw = Atan2(-Look.X, -Look.Z)
        end

        local Speed = Rad(Config.AntiAimMotionSpeed)
        local Interval = Config.AntiAimChangeInterval
        local Offset = 0
        if Mode == "Continuous" then
            local Direction = if Config.AntiAimDirection == "Left" then -1 else 1
            AntiAimAngle = (AntiAimAngle + Delta * Speed * Direction) % (math.pi * 2)
            Offset = AntiAimAngle
        elseif Mode == "Switch" then
            AntiAimTimer += Delta
            if AntiAimTimer >= Interval then
                AntiAimTimer %= Interval
                AntiAimSign *= -1
            end
            Offset = AntiAimSign * Rad(Config.AntiAimTurnOffset)
        elseif Mode == "Fixed Turn" then
            Offset = Rad(Config.AntiAimTurnOffset)
        elseif Mode == "Triple Step" or Mode == "Five Step" then
            local Steps = if Mode == "Triple Step" then TripleSteps else FiveSteps
            AntiAimTimer += Delta
            if AntiAimTimer >= Interval then
                AntiAimTimer %= Interval
                AntiAimStep = (AntiAimStep + 1) % #Steps
            end
            Offset = Rad(Steps[AntiAimStep + 1])
        elseif Mode == "Sweep" then
            AntiAimAngle = (AntiAimAngle + Delta * Speed) % (math.pi * 2)
            Offset = Rad(Config.AntiAimSweepRange) * Sin(AntiAimAngle)
        elseif Mode == "Randomize" then
            AntiAimTimer += Delta
            if AntiAimTimer >= Interval then
                AntiAimTimer %= Interval
                AntiAimRandom = Random() * math.pi * 2
            end
            Offset = AntiAimRandom
        end

        SetAntiAimFacing(Root, NewCFrame(Root.Position) * CFrameAngles(0, BaseYaw + Offset, 0))
    end)

    -- Public Methods:
    function Archer.Init(self: Archer)
        if UserInputService.TouchEnabled then
            Spawn(function()
                local PlayerModule = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")
                local Success, Controls = ProtectedCall(function()
                    return Require(PlayerModule):GetControls()
                end)
                if Success then
                    MobileControls = Controls
                end
            end)
        end

        Players.PlayerRemoving:Connect(function(Player)
            local Highlight = ChamsHighlights[Player]
            if Highlight then
                Highlight:Destroy()
                ChamsHighlights[Player] = nil
            end
        end)
        RunService.Heartbeat:Connect(UpdateChams)
        RunService.Heartbeat:Connect(UpdateAntiAim)
        RunService.PreRender:Connect(function()
            UpdateFly()
            UpdateAntiAim(0)
        end)

        local OldNewIndex
        OldNewIndex = HookMetaMethod(Game, "__newindex", NewCClosure(function(Self, Key, Value)
            if Self == Workspace.CurrentCamera and Key == "CFrame" and Typeof(Value) == "CFrame" then
                if ThirdPersonActive(Self) then
                    RawCamera = Self
                    RawCameraCFrame = Value
                    Value = Value * NewCFrame(0, 0, Config.ThirdPersonZoom)
                    ShiftedCameraCFrame = Value
                else
                    RawCamera = nil
                    RawCameraCFrame = nil
                    ShiftedCameraCFrame = nil
                end
            end
            return OldNewIndex(Self, Key, Value)
        end))

        local OldMovementTick
        OldMovementTick = HookFunction(BowMovement.tick, function(Movement, Drawing, Melee, Tool, ...)
            local Result = OldMovementTick(Movement, Drawing, Melee, Tool, ...)
            local Humanoid = Movement.humanoid
            if Movement.active and Humanoid and Humanoid:IsA("Humanoid") then
                if (Config.FastWalk or Config.Fly) and Movement.sprinting then
                    Movement.sprinting = false
                    Movement.speedAttribute /= BowConfig.SprintMultiplier
                    Humanoid.WalkSpeed /= BowConfig.SprintMultiplier
                end
                if Config.NoAimSlowdown and Drawing then
                    local Effects = EnchantEffects.fromTool(Tool)
                    local Fraction = Effects.DrawWalkFraction or BowConfig.BowWalkMultiplier
                    if Fraction > 0 and Fraction < 1 then
                        Humanoid.WalkSpeed /= Fraction
                    end
                end
                if Config.FastWalk then
                    Humanoid.WalkSpeed = Min(Config.WalkSpeed, 30)
                end
            end
            if Config.FastWalk or Config.Fly then
                Movement.sprinting = false
            end
            return Result
        end)

        if IsMobile() then
            local FOVGui = NewInstance("ScreenGui")
            FOVGui.Name = "ArcherFOV"
            FOVGui.IgnoreGuiInset = true
            FOVGui.ResetOnSpawn = false
            FOVGui.DisplayOrder = 1000
            FOVGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

            local FOVCircle = NewInstance("Frame")
            FOVCircle.Name = "Circle"
            FOVCircle.AnchorPoint = NewVector2(0.5, 0.5)
            FOVCircle.Position = UDim2.fromScale(0.5, 0.5)
            FOVCircle.Size = UDim2.fromOffset(Config.FOVSize * 2, Config.FOVSize * 2)
            FOVCircle.BackgroundTransparency = 1
            FOVCircle.Visible = Config.SilentAim and Config.ShowFOV
            FOVCircle.Parent = FOVGui

            local Corner = NewInstance("UICorner")
            Corner.CornerRadius = UDim.new(1, 0)
            Corner.Parent = FOVCircle

            local Stroke = NewInstance("UIStroke")
            Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            Stroke.Color = Config.FOVColor
            Stroke.Thickness = 2
            Stroke.Parent = FOVCircle

            RunService.PreRender:Connect(function()
                FOVCircle.Visible = Config.SilentAim and Config.ShowFOV
                FOVCircle.Size = UDim2.fromOffset(Config.FOVSize * 2, Config.FOVSize * 2)
                Stroke.Color = Config.FOVColor
            end)
        elseif Drawing and Type(Drawing.new) == "function" then
            local FOVCircle = Drawing.new("Circle")
            FOVCircle.Position = AimScreenPosition()
            FOVCircle.Visible = Config.SilentAim and Config.ShowFOV
            FOVCircle.Color = Config.FOVColor
            FOVCircle.Radius = Config.FOVSize
            FOVCircle.Transparency = 1
            FOVCircle.Filled = false
            FOVCircle.NumSides = 64

            RunService.PreRender:Connect(function()
                FOVCircle.Position = AimScreenPosition()
                FOVCircle.Visible = Config.SilentAim and Config.ShowFOV
                FOVCircle.Color = Config.FOVColor
                FOVCircle.Radius = Config.FOVSize
            end)
        end

        local OldChargeTicks
        OldChargeTicks = HookFunction(BowNet.chargeTicks, function(...)
            local Ticks = OldChargeTicks(...)
            if ActiveRelease then
                ActiveRelease.ChargeTicks = Ticks
            end
            return Ticks
        end)

        local OldRandom
        OldRandom = HookFunction(BowNet.random, function(Seed, DrawId)
            local Controller = ActivePreview
            if not Controller or (Type(Seed) == "number" and Type(DrawId) == "number") then
                return OldRandom(Seed, DrawId)
            end

            local Cached = CachedDraws[Controller]
            local CurrentId = Controller.drawId
            if Type(CurrentId) ~= "number" and Cached then
                CurrentId = Cached.Id
            end

            if Type(Seed) == "number" and Type(CurrentId) == "number" then
                DrawId = CurrentId
                Controller.previewDrawId = DrawId
                return OldRandom(Seed, DrawId)
            end

            Controller.trajectory:hide()
            return function()
                return 0.5
            end
        end)

        local OldPreviewTrajectory
        OldPreviewTrajectory = HookFunction(BowController.previewTrajectory, function(Controller, ...)
            if Controller.drawing and (not Controller.network or Type(Controller.network.bowSeed) ~= "number") then
                Controller.trajectory:hide()
                return
            end

            if Controller.drawing and Type(Controller.drawId) ~= "number" then
                local Cached = CachedDraws[Controller]
                if Cached and Type(Cached.Id) == "number" then
                    Controller.drawId = Cached.Id
                else
                    Controller.trajectory:hide()
                    return
                end
            end

            local Previous = ActivePreview
            ActivePreview = Controller
            local Result = OldPreviewTrajectory(Controller, ...)
            ActivePreview = Previous
            return Result
        end)

        local OldLaunchPoint
        OldLaunchPoint = HookFunction(BowController.launchPoint, function(Controller, ...)
            local Origin, Direction = OldLaunchPoint(Controller, ...)
            if ThirdPersonActive(Controller.camera)
                and RawCamera == Controller.camera
                and Controller.camera.CFrame == ShiftedCameraCFrame
                and RawCameraCFrame
            then
                Origin = RawCameraCFrame.Position - NewVector3(0, 1, 0) * (0.1 * BowConfig.StudsPerBlock)
                Direction = RawCameraCFrame.LookVector
            end
            if not Config.SilentAim then
                return Origin, Direction
            end

            local State = ActiveRelease
            local IsRelease = State and State.Controller == Controller
            local IsPreview = ActivePreview == Controller and Controller.drawing
            if not IsRelease and not IsPreview then
                return Origin, Direction
            end

            local Target = FindTarget()
            if not Target then
                return Origin, Direction
            end

            local ChargeTicks = if IsRelease then State.ChargeTicks else Controller.previewTicks
            local Aim = SolveDirection(Controller, Origin, ChargeTicks, Target)
            if Aim then
                if IsRelease then
                    State.Direction = Aim
                    State.Origin = Origin
                end
                return Origin, Aim
            end
            return Origin, Direction
        end)

        local OldModelLaunchPoint
        OldModelLaunchPoint = HookFunction(BowController.modelLaunchPoint, function(Controller, ...)
            if ThirdPersonActive(Controller.camera) then
                local Origin = Controller:launchPoint()
                return Origin
            end
            return OldModelLaunchPoint(Controller, ...)
        end)

        local OldSend
        OldSend = HookFunction(CombatClient.send, function(Network, Action, Params)
            local State = ActiveRelease
            local Matched = Action == "Release" and State and State.Controller.network == Network
            if Matched and State.Direction then
                Params.direction = State.Direction
                Params.origin = State.Origin
            end
            if Config.AntiAim and Action == "Release" and Params and Typeof(Params.direction) == "Vector3" then
                AntiAimShotDirection = Params.direction
                AntiAimLastShot = Clock()
                local Character = LocalPlayer.Character
                local Root = Character and Character:FindFirstChild("HumanoidRootPart")
                local Flat = NewVector3(Params.direction.X, 0, Params.direction.Z)
                if Root and Flat.Magnitude > 0.001 then
                    SetAntiAimFacing(Root, NewCFrame(Root.Position, Root.Position + Flat.Unit))
                end
            end
            local Result = OldSend(Network, Action, Params)
            if Action == "Draw" and Network.controller then
                CachedDraws[Network.controller] = {Id = Result}
            end
            return Result
        end)

        local OldReceive
        OldReceive = HookFunction(CombatClient.receive, function(Network, Action, Params, ...)
            if Params then
                if Action == "ArrowSpawn" and Params.userId == LocalPlayer.UserId and HiddenShots[Params.seq] then
                    HiddenArrows[Params.id] = Clock() + 75
                    return
                elseif Action == "ArrowHit" and (HiddenShots[Params.seq] or HiddenArrows[Params.id]) then
                    return
                elseif Action == "ArrowRemove" and HiddenArrows[Params.id] then
                    HiddenArrows[Params.id] = nil
                    return
                end
            end

            local Pending = Action == "Result" and Params and Network.pending[Params.seq]
            local Result = OldReceive(Network, Action, Params, ...)
            local State = RageState
            if not State or State.Controller.network ~= Network or not Pending then
                return Result
            end

            if Pending.action == "Draw" and Params.seq == State.DrawId then
                if Params.ok then
                    State.DrawStarted = Params.drawTime or State.DrawTime
                    State.Stage = "Charging"
                    State.StartedAt = Clock()
                else
                    StopRage(1, false)
                end
            elseif Pending.action == "Release" and Params.seq == State.ReleaseId then
                StopRage(if Params.ok then Config.RageShotDelay else Max(1, Config.RageShotDelay), false)
            end

            return Result
        end)

        local OldBeginDraw
        OldBeginDraw = HookFunction(BowController.beginDraw, function(Controller, ...)
            local WasDrawing = Controller.drawing
            local Result = OldBeginDraw(Controller, ...)
            if WasDrawing or not Controller.drawing then
                return Result
            end

            ActiveDrawingController = Controller
            return Result
        end)

        local OldAnimationUpdate
        OldAnimationUpdate = HookFunction(FirstPersonAnimation.update, function(Animation, Delta, Slot, Drawing, DrawTicks, ...)
            local Controller = ActiveDrawingController
            if Config.NoAimAnimation
                and Controller
                and Controller.firstPersonAnimation == Animation
                and Drawing
                and Slot == 1
            then
                DrawTicks = Max(DrawTicks, Config.FullDrawTicks)
            end

            return OldAnimationUpdate(Animation, Delta, Slot, Drawing, DrawTicks, ...)
        end)

        local OldMotionUpdate
        OldMotionUpdate = HookFunction(TaCZMotion.update, function(Motion, Delta, Drawing, DrawTicks, ...)
            local Result = OldMotionUpdate(Motion, Delta, Drawing, DrawTicks, ...)
            local Controller = ActiveDrawingController
            if Config.NoAimAnimation
                and Controller
                and Controller.firstPersonAnimation.tacz == Motion
                and Drawing
                and Motion.key == "tb23"
            then
                local Track = Motion.adsTrack
                if Track and Track.name == "pull_in" then
                    Track.start = Min(Track.start, Motion.clock - 0.2)
                end
            end

            return Result
        end)

        local OldRelease
        OldRelease = HookFunction(BowController.release, function(Controller, ...)
            local Previous = ActiveRelease
            local State = {Controller = Controller}
            ActiveRelease = State
            local Result = OldRelease(Controller, ...)
            ActiveRelease = Previous
            return Result
        end)

        RunService.Heartbeat:Connect(function()
            local Now = Clock()
            for Id, ExpiresAt in HiddenShots do
                if Now >= ExpiresAt then
                    HiddenShots[Id] = nil
                end
            end
            for Id, ExpiresAt in HiddenArrows do
                if Now >= ExpiresAt then
                    HiddenArrows[Id] = nil
                end
            end

            if not Config.RageBot then
                if RageState then
                    StopRage(0, true)
                end
                return
            end

            local Controller = BowController.active
            if not Controller
                or Controller.selectedSlot ~= 1
                or not Controller:alive()
                or not Controller.camera
                or not Controller.network
                or Type(Controller.network.bowSeed) ~= "number"
            then
                if RageState then
                    StopRage(Config.RageShotDelay, true)
                end
                return
            end

            local State = RageState
            if not State then
                if Now < NextRageShot or Controller.drawing then
                    return
                end

                local Character = LocalPlayer.Character
                local Root = Character and Character:FindFirstChild("HumanoidRootPart")
                local Target
                if Root then
                    Target = FindRageTarget(Controller)
                end
                if not Target then
                    return
                end

                State = {
                    Controller = Controller,
                    Stage = "AwaitDraw",
                    StartedAt = Now,
                    DrawTime = Workspace:GetServerTimeNow(),
                    DrawEffects = EnchantEffects.fromTool(Controller.equippedTool),
                }
                RageState = State
                State.DrawId = Controller.network:send("Draw", {time = State.DrawTime})
                if Type(State.DrawId) ~= "number" then
                    StopRage(Config.RageShotDelay, false)
                end
                return
            end

            if State.Controller ~= Controller then
                StopRage(Config.RageShotDelay, false)
                return
            end
            if Controller.drawing then
                StopRage(Config.RageShotDelay, false)
                return
            end
            if State.Stage == "AwaitDraw" then
                if Now - State.StartedAt > 2.5 then
                    StopRage(Config.RageShotDelay, true)
                end
                return
            end
            if State.Stage == "AwaitRelease" then
                if Now - State.StartedAt > 2.5 then
                    StopRage(Config.RageShotDelay, false)
                end
                return
            end
            if State.Stage ~= "Charging" then
                return
            end

            local DrawSpeed = 1 + (State.DrawEffects and State.DrawEffects.DrawSpeedBonus or 0)
            local ChargeTicks = BowNet.chargeTicks(State.DrawStarted, Workspace:GetServerTimeNow(), DrawSpeed)
            if ChargeTicks < Config.RageDrawTicks then
                return
            end

            local Origin = Controller:launchPoint()
            local _, Choices = FindRageTarget(Controller, Origin)
            if #Choices == 0 then
                StopRage(Config.RageShotDelay, true)
                return
            end

            local Root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not Root then
                StopRage(Config.RageShotDelay, true)
                return
            end

            local SourceVelocity = BowNet.clampVelocity(Root.AssemblyLinearVelocity)
            local Source = BowMath.fromWorld(SourceVelocity * BowConfig.Tick)
            local SpeedBonus = 1 + (State.DrawEffects and State.DrawEffects.ArrowSpeedBonus or 0)
            local Target, Direction
            for _, Choice in Choices do
                local Candidate = Choice.Part
                if not Candidate.Parent then
                    continue
                end
                local Aim, _, Solution = SolveDirection(
                    Controller, Origin, ChargeTicks, Candidate, State.DrawId, State.DrawEffects
                )
                if not Aim or not Solution or Solution.Fallback then
                    continue
                end

                local Velocity = BowMath.launch(
                    Aim,
                    ChargeTicks,
                    Source,
                    BowNet.random(Controller.network.bowSeed, State.DrawId),
                    SpeedBonus
                )
                if not Velocity then
                    continue
                end

                local Clear = TrajectoryClear(Controller, Origin, Candidate, Velocity, Solution.FlightTicks)
                if not Clear then
                    continue
                end
                
                Target = Candidate
                Direction = Aim
                break
            end

            if not Target then
                if Now - State.StartedAt > 4 then
                    StopRage(Config.RageShotDelay, true)
                end
                return
            end

            State.Stage = "AwaitRelease"
            State.StartedAt = Now
            State.Target = Target
            State.ReleaseId = Controller.network:send("Release", {
                drawId = State.DrawId,
                direction = Direction,
                origin = Origin,
                time = Workspace:GetServerTimeNow(),
                sourceVelocity = SourceVelocity,
                mobile = IsMobile(),
            })
            if State.ReleaseId then
                HiddenShots[State.ReleaseId] = Now + 75
            end
            if RageState == State and not State.ReleaseId then
                StopRage(Config.RageShotDelay, false)
            end
        end)
    end
end

do
    -- Public Methods:
    function Interface.Init(self: Interface)
        local Library = LoadString(HttpGet(Game, OBSIDIAN_URL))()
        local Window = Library:CreateWindow({
            Title = "Archer",
            Footer = "",
            AutoShow = true,
            Center = true,
        })

        local Main = Window:AddTab("Main", "crosshair")
        local CombatGroup = Main:AddGroupbox({Side = "Left", Name = "Combat"})
        local AntiAimGroup = Main:AddGroupbox({Side = "Left", Name = "Anti Aim"})
        local ESPGroup = Main:AddGroupbox({Side = "Right", Name = "ESP"})
        local MiscGroup = Main:AddGroupbox({Side = "Right", Name = "Misc"})

        CombatGroup:AddToggle("RageBot", {
            Text = "Auto Kill",
            Default = Config.RageBot,
            Callback = function(Value)
                Config.RageBot = Value
            end,
        })

        CombatGroup:AddToggle("SilentAim", {
            Text = "Silent Aim",
            Default = Config.SilentAim,
            Callback = function(Value)
                Config.SilentAim = Value
            end,
        })

        CombatGroup:AddToggle("ShowFOV", {
            Text = "Show FOV",
            Default = Config.ShowFOV,
            Callback = function(Value)
                Config.ShowFOV = Value
            end,
        })

        CombatGroup:AddSlider("FOVSize", {
            Text = "FOV Size",
            Default = Config.FOVSize,
            Min = 25,
            Max = 600,
            Rounding = 0,
            Suffix = "px",
            Callback = function(Value)
                Config.FOVSize = Value
            end,
        })

        CombatGroup:AddLabel("FOV Color"):AddColorPicker("FOVColor", {
            Default = Config.FOVColor,
            Title = "FOV Color",
            Callback = function(Value)
                Config.FOVColor = Value
            end,
        })

        CombatGroup:AddDropdown("HitPart", {
            Text = "Hit Part",
            Values = {"Head", "HumanoidRootPart"},
            Default = Config.HitPart,
            Callback = function(Value)
                Config.HitPart = Value
            end,
        })

        MiscGroup:AddToggle("NoAimAnimation", {
            Text = "No Aim Animation",
            Tooltip = "Visual draw animation only; charge is still determined by the game.",
            Default = Config.NoAimAnimation,
            Callback = function(Value)
                Config.NoAimAnimation = Value
            end,
        })

        MiscGroup:AddToggle("NoAimSlowdown", {
            Text = "No Aim Slowdown",
            Default = Config.NoAimSlowdown,
            Callback = function(Value)
                Config.NoAimSlowdown = Value
            end,
        })

        MiscGroup:AddToggle("FastWalk", {
            Text = "Fast Walk",
            Default = Config.FastWalk,
            Callback = function(Value)
                Config.FastWalk = Value
            end,
        })

        MiscGroup:AddSlider("WalkSpeed", {
            Text = "Walk Speed",
            Default = Config.WalkSpeed,
            Min = 16,
            Max = 30,
            Rounding = 0,
            Suffix = " studs/s",
            Callback = function(Value)
                Config.WalkSpeed = Value
            end,
        })

        MiscGroup:AddToggle("Fly", {
            Text = "Fly",
            Default = Config.Fly,
            Callback = function(Value)
                Config.Fly = Value
            end,
        })

        MiscGroup:AddSlider("FlySpeed", {
            Text = "Fly Speed",
            Default = Config.FlySpeed,
            Min = 1,
            Max = 30,
            Rounding = 0,
            Suffix = " studs/s",
            Callback = function(Value)
                Config.FlySpeed = Value
            end,
        })

        MiscGroup:AddDropdown("FlyMethod", {
            Text = "Fly Method",
            Values = {"Normal", "Noclip"},
            Default = Config.FlyMethod,
            Callback = function(Value)
                Config.FlyMethod = Value
            end,
        })

        MiscGroup:AddToggle("ThirdPerson", {
            Text = "Third Person",
            Default = Config.ThirdPerson,
            Callback = function(Value)
                Config.ThirdPerson = Value
            end,
        })

        MiscGroup:AddSlider("ThirdPersonZoom", {
            Text = "Zoom Out",
            Default = Config.ThirdPersonZoom,
            Min = 0,
            Max = 10,
            Rounding = 1,
            Suffix = " studs",
            Callback = function(Value)
                Config.ThirdPersonZoom = Value
            end,
        })

        AntiAimGroup:AddToggle("AntiAim", {
            Text = "Spin Bot",
            Default = Config.AntiAim,
            Callback = function(Value)
                Config.AntiAim = Value
            end,
        })

        AntiAimGroup:AddDropdown("AntiAimMotion", {
            Text = "Motion",
            Values = {"Continuous", "Switch", "Fixed Turn", "Triple Step", "Five Step", "Sweep", "Randomize"},
            Default = Config.AntiAimMotion,
            Callback = function(Value)
                Config.AntiAimMotion = Value
            end,
        })

        AntiAimGroup:AddDropdown("AntiAimFacingReference", {
            Text = "Facing Reference",
            Values = {"View", "Current Target"},
            Default = Config.AntiAimFacingReference,
            Callback = function(Value)
                Config.AntiAimFacingReference = Value
            end,
        })

        AntiAimGroup:AddDropdown("AntiAimDirection", {
            Text = "Direction",
            Values = {"Right", "Left"},
            Default = Config.AntiAimDirection,
            Callback = function(Value)
                Config.AntiAimDirection = Value
            end,
        })

        AntiAimGroup:AddSlider("AntiAimMotionSpeed", {
            Text = "Motion Speed",
            Default = Config.AntiAimMotionSpeed,
            Min = 1,
            Max = 1080,
            Rounding = 0,
            Suffix = " deg/s",
            Callback = function(Value)
                Config.AntiAimMotionSpeed = Value
            end,
        })

        AntiAimGroup:AddSlider("AntiAimChangeInterval", {
            Text = "Change Interval",
            Default = Config.AntiAimChangeInterval,
            Min = 0.01,
            Max = 1,
            Rounding = 2,
            Suffix = "s",
            Callback = function(Value)
                Config.AntiAimChangeInterval = Value
            end,
        })

        AntiAimGroup:AddSlider("AntiAimTurnOffset", {
            Text = "Turn Offset",
            Default = Config.AntiAimTurnOffset,
            Min = 0,
            Max = 360,
            Rounding = 0,
            Suffix = "°",
            Callback = function(Value)
                Config.AntiAimTurnOffset = Value
            end,
        })

        AntiAimGroup:AddSlider("AntiAimSweepRange", {
            Text = "Sweep Range",
            Default = Config.AntiAimSweepRange,
            Min = 0,
            Max = 180,
            Rounding = 0,
            Suffix = "°",
            Callback = function(Value)
                Config.AntiAimSweepRange = Value
            end,
        })

        ESPGroup:AddToggle("HighlightChams", {
            Text = "Highlight Chams",
            Default = Config.HighlightChams,
            Callback = function(Value)
                Config.HighlightChams = Value
            end,
        })

        ESPGroup:AddLabel("Fill Color"):AddColorPicker("ChamsFillColor", {
            Default = Config.ChamsFillColor,
            Title = "Fill Color",
            Callback = function(Value)
                Config.ChamsFillColor = Value
            end,
        })

        ESPGroup:AddSlider("ChamsFillTransparency", {
            Text = "Fill Transparency",
            Default = Config.ChamsFillTransparency * 100,
            Min = 0,
            Max = 100,
            Rounding = 0,
            Suffix = "%",
            Callback = function(Value)
                Config.ChamsFillTransparency = Value / 100
            end,
        })

        ESPGroup:AddLabel("Outline Color"):AddColorPicker("ChamsOutlineColor", {
            Default = Config.ChamsOutlineColor,
            Title = "Outline Color",
            Callback = function(Value)
                Config.ChamsOutlineColor = Value
            end,
        })

        ESPGroup:AddSlider("ChamsOutlineTransparency", {
            Text = "Outline Transparency",
            Default = Config.ChamsOutlineTransparency * 100,
            Min = 0,
            Max = 100,
            Rounding = 0,
            Suffix = "%",
            Callback = function(Value)
                Config.ChamsOutlineTransparency = Value / 100
            end,
        })

        Library.ToggleKeybind = Enum.KeyCode.RightShift
    end
end

Archer:Init()
Interface:Init()
