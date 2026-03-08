-- Services 
local InputService  = game:GetService("UserInputService")
local HttpService   = game:GetService("HttpService")
local GuiService    = game:GetService("GuiService")
local RunService    = game:GetService("RunService")
local CoreGui       = game:GetService("CoreGui")
local TweenService  = game:GetService("TweenService")
local Workspace     = game:GetService("Workspace")
local Players       = game:GetService("Players")

local lp            = Players.LocalPlayer
local mouse         = lp:GetMouse()

-- Short aliases
local vec2          = Vector2.new
local dim2          = UDim2.new
local dim           = UDim.new
local rect          = Rect.new
local dim_offset    = UDim2.fromOffset
local rgb           = Color3.fromRGB
local hex           = Color3.fromHex

-- Library init / globals
getgenv().External = getgenv().External or {}
local External = getgenv().External

External.Directory    = "External"
External.Folders      = {"/configs"}
External.Flags        = {}
External.ConfigFlags  = {}
External.Connections  = {}
External.DynamicTheming = {} -- Added to track dynamic toggle updates
External.Notifications= {Notifs = {}}
External.__index      = External

local Flags          = External.Flags
local ConfigFlags    = External.ConfigFlags
local Notifications  = External.Notifications

local themes = {
    preset = {
        accent       = rgb(191, 0, 255),   
        glow         = rgb(191, 0, 255),   
        
        background   = rgb(20, 6, 34),      
        section      = rgb(20, 20, 24),      
        element      = rgb(28, 28, 32),     
        
        outline      = rgb(35, 35, 40),      
        text         = rgb(245, 245, 245),   
        subtext      = rgb(140, 140, 145),  
        
        tab_active   = rgb(105, 17, 219),   
        tab_inactive = rgb(16, 16, 19), 
    },
    utility = {}
}

for property, _ in themes.preset do
    themes.utility[property] = {
        BackgroundColor3 = {}, TextColor3 = {}, ImageColor3 = {}, Color = {}, ScrollBarImageColor3 = {}
    }
end

local Keys = {
    [Enum.KeyCode.LeftShift] = "LS", [Enum.KeyCode.RightShift] = "RS",
    [Enum.KeyCode.LeftControl] = "LC", [Enum.KeyCode.RightControl] = "RC",
    [Enum.KeyCode.Insert] = "INS", [Enum.KeyCode.Backspace] = "BS",
    [Enum.KeyCode.Return] = "Ent", [Enum.KeyCode.Escape] = "ESC",
    [Enum.KeyCode.Space] = "SPC", [Enum.UserInputType.MouseButton1] = "MB1",
    [Enum.UserInputType.MouseButton2] = "MB2", [Enum.UserInputType.MouseButton3] = "MB3"
}

for _, path in External.Folders do
    pcall(function() makefolder(External.Directory .. path) end)
end

-- misc helpers
function External:Tween(Object, Properties, Info)
    if not Object then return end
    local tween = TweenService:Create(Object, Info or TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), Properties)
    tween:Play()
    return tween
end

function External:Create(instance, options)
    local ins = Instance.new(instance)
    for prop, value in options do ins[prop] = value end
    if ins:IsA("TextButton") or ins:IsA("ImageButton") then ins.AutoButtonColor = false end
    return ins
end

function External:Themify(instance, theme, property)
    if not themes.utility[theme] then return end
    table.insert(themes.utility[theme][property], instance)
    instance[property] = themes.preset[theme]
end

function External:RefreshTheme(theme, color3)
    themes.preset[theme] = color3
    for property, instances in themes.utility[theme] do
        for _, object in instances do
            object[property] = color3
        end
    end
    -- Dynamically update Toggles when you change colors
    for _, updateFunc in ipairs(External.DynamicTheming) do
        updateFunc()
    end
end

function External:Resizify(Parent)
    local UIS = game:GetService("UserInputService")
    local Resizing = External:Create("TextButton", {
        AnchorPoint = vec2(1, 1), Position = dim2(1, 0, 1, 0), Size = dim2(0, 20, 0, 20),
        BorderSizePixel = 0, BackgroundTransparency = 1, Text = "", Parent = Parent, ZIndex = 999,
    })
    
    local grip = External:Create("ImageLabel", {
        Parent = Resizing, AnchorPoint = vec2(1, 1), Position = dim2(1, -4, 1, -4), Size = dim2(0, 10, 0, 10),
        BackgroundTransparency = 1, Image = "rbxthumb://type=Asset&id=6153965706&w=150&h=150", ImageColor3 = themes.preset.accent, ImageTransparency = 0.5
    })
    External:Themify(grip, "accent", "ImageColor3")

    local IsResizing, StartInputPos, StartSize = false, nil, nil
    local MIN_SIZE = vec2(600, 450)
    local MAX_SIZE = vec2(1000, 800)

    Resizing.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            IsResizing = true; StartInputPos = input.Position; StartSize = Parent.AbsoluteSize
        end
    end)
    Resizing.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then IsResizing = false end
    end)
    UIS.InputChanged:Connect(function(input)
        if not IsResizing then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - StartInputPos
            Parent.Size = UDim2.fromOffset(math.clamp(StartSize.X + delta.X, MIN_SIZE.X, MAX_SIZE.X), math.clamp(StartSize.Y + delta.Y, MIN_SIZE.Y, MAX_SIZE.Y))
        end
    end)
end

-- window
function External:Window(properties)
    local Cfg = {
        Title = properties.Title or properties.title or properties.Prefix or "External", 
        Subtitle = properties.Subtitle or properties.subtitle or properties.Suffix or ".cc",
        Size = properties.Size or properties.size or dim2(0, 720, 0, 500), 
        TabInfo = nil, Items = {}, Tweening = false, IsSwitchingTab = false;
    }

    if External.Gui then External.Gui:Destroy() end
    if External.Other then External.Other:Destroy() end
    if External.ToggleGui then External.ToggleGui:Destroy() end

    External.Gui = External:Create("ScreenGui", { Parent = CoreGui, Name = "External", Enabled = true, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
    External.Other = External:Create("ScreenGui", { Parent = CoreGui, Name = "ExternalOther", Enabled = false, IgnoreGuiInset = true })
    
    local Items = Cfg.Items
    local uiVisible = true

    Items.Wrapper = External:Create("Frame", {
        Parent = External.Gui, Position = dim2(0.5, -Cfg.Size.X.Offset / 2, 0.5, -Cfg.Size.Y.Offset / 2),
        Size = Cfg.Size, BackgroundTransparency = 1, BorderSizePixel = 0
    })
    
    Items.Glow = External:Create("ImageLabel", {
        ImageColor3 = themes.preset.glow,
        ScaleType = Enum.ScaleType.Slice,
        ImageTransparency = 0.6499999761581421,
        BorderColor3 = rgb(0, 0, 0),
        Parent = Items.Wrapper,
        Name = "\0",
        Size = dim2(1, 40, 1, 40),
        Image = "rbxassetid://18245826428",
        BackgroundTransparency = 1,
        Position = dim2(0, -20, 0, -20),
        BackgroundColor3 = rgb(255, 255, 255),
        BorderSizePixel = 0,
        SliceCenter = rect(vec2(21, 21), vec2(79, 79)),
        ZIndex = 0
    })
    External:Themify(Items.Glow, "glow", "ImageColor3")

    Items.Window = External:Create("Frame", {
        Parent = Items.Wrapper, Position = dim2(0, 0, 0, 0), Size = dim2(1, 0, 1, 0),
        BackgroundColor3 = themes.preset.background, BorderSizePixel = 0, ZIndex = 1, ClipsDescendants = true
    })
    External:Themify(Items.Window, "background", "BackgroundColor3")
    External:Create("UICorner", { Parent = Items.Window, CornerRadius = dim(0, 6) })
    External:Themify(External:Create("UIStroke", { Parent = Items.Window, Color = themes.preset.outline, Thickness = 1 }), "outline", "Color")

    Items.Header = External:Create("Frame", { Parent = Items.Window, Size = dim2(1, 0, 0, 50), BackgroundTransparency = 1, Active = true, ZIndex = 2 })

    Items.LogoBlock = External:Create("Frame", {
        Parent = Items.Header, AnchorPoint = vec2(0, 0.5), Position = dim2(0, 20, 0.5, 0), 
        Size = dim2(0, 20, 0, 20), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4
    })
    External:Create("UICorner", { Parent = Items.LogoBlock, CornerRadius = dim(0, 4) })
    External:Themify(Items.LogoBlock, "accent", "BackgroundColor3")

    Items.LogoText = External:Create("TextLabel", {
        Parent = Items.Header, Text = Cfg.Title, TextColor3 = themes.preset.text,
        AnchorPoint = vec2(0, 0), Position = dim2(0, 20, 0, 12),
        Size = dim2(0, 0, 0, 14), AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4
    })
    External:Themify(Items.LogoText, "text", "TextColor3")

    Items.SubLogoText = External:Create("TextLabel", {
        Parent = Items.Header, Text = Cfg.Subtitle, TextColor3 = themes.preset.subtext,
        AnchorPoint = vec2(0, 0), Position = dim2(0, 20, 0, 26),
        Size = dim2(0, 0, 0, 12), AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4
    })
    External:Themify(Items.SubLogoText, "subtext", "TextColor3")

    Items.TabHolder = External:Create("Frame", { 
        Parent = Items.Header, AnchorPoint = vec2(1, 0.5), Position = dim2(1, -20, 0.5, 0),
        Size = dim2(1, -200, 1, 0), BackgroundTransparency = 1, ZIndex = 4
    })
    External:Create("UIListLayout", { Parent = Items.TabHolder, FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = dim(0, 8) })

    Items.Footer = External:Create("Frame", { 
        Parent = Items.Window, AnchorPoint = vec2(0, 1), Position = dim2(0, 0, 1, 0), 
        Size = dim2(1, 0, 0, 55), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2 
    })

    local headshot = "rbxthumb://type=AvatarHeadShot&id="..lp.UserId.."&w=48&h=48"
    Items.AvatarFrame = External:Create("Frame", {
        Parent = Items.Footer, AnchorPoint = vec2(0, 0.5), Position = dim2(0, 20, 0.5, 0), 
        Size = dim2(0, 28, 0, 28), BackgroundColor3 = themes.preset.element, BorderSizePixel = 0, ZIndex = 5
    })
    External:Themify(Items.AvatarFrame, "element", "BackgroundColor3")
    External:Create("UICorner", { Parent = Items.AvatarFrame, CornerRadius = dim(0, 6) })
    
    Items.Avatar = External:Create("ImageLabel", { 
        Parent = Items.AvatarFrame, AnchorPoint = vec2(0.5, 0.5), Position = dim2(0.5, 0, 0.5, 0), 
        Size = dim2(1, 0, 1, 0), BackgroundTransparency = 1, Image = headshot, ZIndex = 6 
    })
    External:Create("UICorner", { Parent = Items.Avatar, CornerRadius = dim(0, 6) })

    Items.Username = External:Create("TextLabel", {
        Parent = Items.Footer, Text = lp.Name, TextColor3 = themes.preset.text,
        AnchorPoint = vec2(0, 0), Position = dim2(0, 58, 0, 13), Size = dim2(0, 200, 0, 14),
        BackgroundTransparency = 1, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5
    })
    External:Themify(Items.Username, "text", "TextColor3")

    Items.Status = External:Create("TextLabel", {
        Parent = Items.Footer, Text = "Status : Premium", TextColor3 = themes.preset.subtext,
        AnchorPoint = vec2(0, 0), Position = dim2(0, 58, 0, 28), Size = dim2(0, 200, 0, 12),
        BackgroundTransparency = 1, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5
    })
    External:Themify(Items.Status, "subtext", "TextColor3")

    -- CHANGED: Moved X offset from -25 to -38 to push it a tiny bit more to the left
    Items.SettingsBtn = External:Create("ImageButton", {
        Parent = Items.Footer, AnchorPoint = vec2(1, 0.5), Position = dim2(1, -38, 0.5, 0),
        Size = dim2(0, 16, 0, 16), BackgroundTransparency = 1, Image = "rbxassetid://11293977610", ImageColor3 = themes.preset.subtext, ZIndex = 5
    })
    External:Themify(Items.SettingsBtn, "subtext", "ImageColor3")
    
    Items.SettingsBtn.MouseButton1Click:Connect(function()
        if Cfg.SettingsTabOpen then Cfg.SettingsTabOpen() end
    end)

    Items.PageHolder = External:Create("Frame", { 
        Parent = Items.Window, Position = dim2(0, 0, 0, 50), Size = dim2(1, 0, 1, -105), 
        BackgroundTransparency = 1, ClipsDescendants = true 
    })

    -- Dragging Logic
    local Dragging, DragInput, DragStart, StartPos
    Items.Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            Dragging = true; DragStart = input.Position; StartPos = Items.Wrapper.Position
        end
    end)
    Items.Header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then Dragging = false end
    end)
    InputService.InputChanged:Connect(function(input)
        if Dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - DragStart
            Items.Wrapper.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + delta.X, StartPos.Y.Scale, StartPos.Y.Offset + delta.Y)
        end
    end)
    External:Resizify(Items.Wrapper)

    function Cfg.ToggleMenu(bool)
        if Cfg.Tweening then return end
        if bool == nil then uiVisible = not uiVisible else uiVisible = bool end
        Items.Wrapper.Visible = uiVisible
    end

    if InputService.TouchEnabled then
        External.ToggleGui = External:Create("ScreenGui", { Parent = CoreGui, Name = "ExternalToggle", IgnoreGuiInset = true })
        local ToggleButton = External:Create("ImageButton", {
            Name = "ToggleButton", Parent = External.ToggleGui, Position = UDim2.new(1, -80, 0, 150), Size = UDim2.new(0, 55, 0, 55),
            BackgroundTransparency = 0.2, BackgroundColor3 = themes.preset.element, Image = "rbxassetid://99047291822954", ZIndex = 10000,
        })
        External:Create("UICorner", { Parent = ToggleButton, CornerRadius = dim(0, 12) })
        External:Themify(ToggleButton, "element", "BackgroundColor3")
        External:Themify(External:Create("UIStroke", { Parent = ToggleButton, Color = themes.preset.outline, Thickness = 1.5 }), "outline", "Color")

        local isTDrag, tDragStart, tStartPos, hasTDragged = false, nil, nil, false
        ToggleButton.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                isTDrag = true; hasTDragged = false; tDragStart = input.Position; tStartPos = ToggleButton.Position
            end
        end)
        ToggleButton.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                isTDrag = false; if not hasTDragged then Cfg.ToggleMenu() end
            end
        end)
        InputService.InputChanged:Connect(function(input)
            if isTDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - tDragStart
                if delta.Magnitude > 5 then hasTDragged = true; ToggleButton.Position = UDim2.new(tStartPos.X.Scale, tStartPos.X.Offset + delta.X, tStartPos.Y.Scale, tStartPos.Y.Offset + delta.Y) end
            end
        end)
    end

    return setmetatable(Cfg, External)
end

-- tabs
function External:Tab(properties)
    local Cfg = { 
        Name = properties.Name or properties.name or "Tab", 
        Icon = properties.Icon or properties.icon or "rbxassetid://11293977610", 
        Hidden = properties.Hidden or properties.hidden or false, 
        Items = {} 
    }
    if tonumber(Cfg.Icon) then Cfg.Icon = "rbxassetid://" .. tostring(Cfg.Icon) end
    local Items = Cfg.Items

    if not Cfg.Hidden then
        Items.Button = External:Create("TextButton", { 
            Parent = self.Items.TabHolder, Size = dim2(0, 30, 0, 30), 
            BackgroundColor3 = rgb(255,255,255), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 5 
        })
        
        -- Smooth Premium Gradient Background
        Items.GradientBg = External:Create("Frame", {
            Parent = Items.Button, Size = dim2(1, 0, 1, 0), BackgroundColor3 = themes.preset.accent,
            BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4
        })
        External:Themify(Items.GradientBg, "accent", "BackgroundColor3")
        External:Create("UICorner", { Parent = Items.GradientBg, CornerRadius = dim(0, 6) })
        External:Create("UIGradient", {
            Parent = Items.GradientBg, Rotation = 90,
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.65), 
                NumberSequenceKeypoint.new(1, 1)
            })
        })
        
        Items.IconImg = External:Create("ImageLabel", { 
            Parent = Items.Button, AnchorPoint = vec2(0.5, 0.5), Position = dim2(0.5, 0, 0.5, 0),
            Size = dim2(0, 16, 0, 16), BackgroundTransparency = 1, 
            Image = Cfg.Icon, ImageColor3 = themes.preset.subtext, ZIndex = 6 
        })
        External:Themify(Items.IconImg, "subtext", "ImageColor3")
    end

    Items.Pages = External:Create("CanvasGroup", { Parent = External.Other, Size = dim2(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false, GroupTransparency = 1 })
    External:Create("UIListLayout", { Parent = Items.Pages, FillDirection = Enum.FillDirection.Horizontal, Padding = dim(0, 14) })
    External:Create("UIPadding", { Parent = Items.Pages, PaddingTop = dim(0, 10), PaddingBottom = dim(0, 10), PaddingRight = dim(0, 20), PaddingLeft = dim(0, 20) })

    Items.Left = External:Create("ScrollingFrame", { 
        Parent = Items.Pages, Size = dim2(0.5, -7, 1, 0), BackgroundTransparency = 1, 
        ScrollBarThickness = 0, CanvasSize = dim2(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y
    })
    External:Create("UIListLayout", { Parent = Items.Left, Padding = dim(0, 14) })
    External:Create("UIPadding", { Parent = Items.Left, PaddingBottom = dim(0, 10) })

    Items.Right = External:Create("ScrollingFrame", { 
        Parent = Items.Pages, Size = dim2(0.5, -7, 1, 0), BackgroundTransparency = 1, 
        ScrollBarThickness = 0, CanvasSize = dim2(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y
    })
    External:Create("UIListLayout", { Parent = Items.Right, Padding = dim(0, 14) })
    External:Create("UIPadding", { Parent = Items.Right, PaddingBottom = dim(0, 10) })

    function Cfg.OpenTab()
        if self.IsSwitchingTab or self.TabInfo == Cfg.Items then return end
        local oldTab = self.TabInfo
        self.IsSwitchingTab = true
        self.TabInfo = Cfg.Items

        local buttonTween = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

        if oldTab and oldTab.Button then
            External:Tween(oldTab.GradientBg, {BackgroundTransparency = 1}, buttonTween)
            External:Tween(oldTab.IconImg, {ImageColor3 = themes.preset.subtext}, buttonTween)
        end

        if Items.Button then 
            External:Tween(Items.GradientBg, {BackgroundTransparency = 0}, buttonTween)
            External:Tween(Items.IconImg, {ImageColor3 = themes.preset.text}, buttonTween) 
        end
        
        task.spawn(function()
            if oldTab then
                External:Tween(oldTab.Pages, {GroupTransparency = 1, Position = dim2(0, 0, 0, 10)}, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
                task.wait(0.2)
                oldTab.Pages.Visible = false
                oldTab.Pages.Parent = External.Other
            end

            Items.Pages.Position = dim2(0, 0, 0, 10) 
            Items.Pages.GroupTransparency = 1
            Items.Pages.Parent = self.Items.PageHolder
            Items.Pages.Visible = true

            External:Tween(Items.Pages, {GroupTransparency = 0, Position = dim2(0, 0, 0, 0)}, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
            task.wait(0.4)
            
            Items.Pages.GroupTransparency = 0 
            self.IsSwitchingTab = false
        end)
    end

    if Items.Button then Items.Button.MouseButton1Down:Connect(Cfg.OpenTab) end
    if not self.TabInfo and not Cfg.Hidden then Cfg.OpenTab() end
    return setmetatable(Cfg, External)
end

-- sections
function External:Section(properties)
    local Cfg = { 
        Name = properties.Name or properties.name or "Section", 
        Side = properties.Side or properties.side or "Left", 
        Icon = properties.Icon or properties.icon or "rbxassetid://11293977610", 
        RightIcon = properties.RightIcon or properties.righticon or "rbxassetid://11293977610", 
        Items = {} 
    }
    Cfg.Side = (Cfg.Side:lower() == "right") and "Right" or "Left"
    local Items = Cfg.Items

    Items.Section = External:Create("Frame", { 
        Parent = self.Items[Cfg.Side], Size = dim2(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, 
        BackgroundColor3 = themes.preset.section, BorderSizePixel = 0, ClipsDescendants = true 
    })
    External:Themify(Items.Section, "section", "BackgroundColor3")
    External:Create("UICorner", { Parent = Items.Section, CornerRadius = dim(0, 6) })

    -- Clean Gradient Line Accent
    Items.AccentLine = External:Create("Frame", {
        Parent = Items.Section, Size = dim2(0, 2, 1, 0), Position = dim2(0, 0, 0, 0),
        BackgroundColor3 = themes.preset.accent, BorderSizePixel = 0, ZIndex = 2
    })
    External:Themify(Items.AccentLine, "accent", "BackgroundColor3")
    External:Create("UIGradient", {
        Parent = Items.AccentLine, Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.7, 1),
            NumberSequenceKeypoint.new(1, 1)
        })
    })

    Items.Header = External:Create("Frame", { Parent = Items.Section, Size = dim2(1, 0, 0, 36), BackgroundTransparency = 1 })
    
    Items.Icon = External:Create("ImageLabel", {
        Parent = Items.Header, Position = dim2(0, 16, 0.5, 0), AnchorPoint = vec2(0, 0.5), Size = dim2(0, 14, 0, 14),
        BackgroundTransparency = 1, Image = Cfg.Icon, ImageColor3 = themes.preset.subtext
    })
    External:Themify(Items.Icon, "subtext", "ImageColor3")

    Items.Title = External:Create("TextLabel", { 
        Parent = Items.Header, Position = dim2(0, 38, 0.5, 0), AnchorPoint = vec2(0, 0.5), Size = dim2(1, -70, 0, 14), 
        BackgroundTransparency = 1, Text = Cfg.Name, TextColor3 = themes.preset.text, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left 
    })
    External:Themify(Items.Title, "text", "TextColor3")

    Items.Chevron = External:Create("ImageLabel", {
        Parent = Items.Header, Position = dim2(1, -14, 0.5, 0), AnchorPoint = vec2(1, 0.5), Size = dim2(0, 12, 0, 12),
        BackgroundTransparency = 1, Image = Cfg.RightIcon, ImageColor3 = themes.preset.subtext, 
        Rotation = (Cfg.RightIcon == "rbxassetid://11293977610") and 180 or 0
    })
    External:Themify(Items.Chevron, "subtext", "ImageColor3")

    Items.Container = External:Create("Frame", { 
        Parent = Items.Section, Position = dim2(0, 0, 0, 36), Size = dim2(1, 0, 0, 0), 
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 
    })
    External:Create("UIListLayout", { Parent = Items.Container, Padding = dim(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
    External:Create("UIPadding", { Parent = Items.Container, PaddingBottom = dim(0, 12), PaddingLeft = dim(0, 14), PaddingRight = dim(0, 14) })

    return setmetatable(Cfg, External)
end

-- elements
function External:Toggle(properties)
    local Cfg = { 
        Name = properties.Name or properties.name or "Toggle", 
        Flag = properties.Flag or properties.flag, 
        Default = properties.Default or properties.default or false, 
        Callback = properties.Callback or properties.callback or function() end, 
        Items = {} 
    }
    local Items = Cfg.Items

    Items.Button = External:Create("TextButton", { Parent = self.Items.Container, Size = dim2(1, 0, 0, 22), BackgroundTransparency = 1, Text = "" })
    
    Items.Checkbox = External:Create("Frame", { 
        Parent = Items.Button, AnchorPoint = vec2(0, 0.5), Position = dim2(0, 6, 0.5, 0), Size = dim2(0, 14, 0, 14), 
        BackgroundColor3 = themes.preset.element, BorderSizePixel = 0 
    })
    External:Create("UICorner", { Parent = Items.Checkbox, CornerRadius = dim(0, 3) })

    Items.Hover = External:Create("Frame", { Parent = Items.Checkbox, Size = dim2(1,0,1,0), BackgroundColor3 = rgb(255,255,255), BackgroundTransparency = 1, ZIndex = 2 })
    External:Create("UICorner", {Parent = Items.Hover, CornerRadius = dim(0, 3)})

    Items.Title = External:Create("TextLabel", { 
        Parent = Items.Button, Position = dim2(0, 30, 0.5, 0), AnchorPoint = vec2(0, 0.5), Size = dim2(1, -26, 1, 0), 
        BackgroundTransparency = 1, Text = Cfg.Name, TextColor3 = themes.preset.subtext, TextSize = 13, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium), TextXAlignment = Enum.TextXAlignment.Left 
    })

    Items.Button.MouseEnter:Connect(function() External:Tween(Items.Hover, {BackgroundTransparency = 0.9}, TweenInfo.new(0.25)) end)
    Items.Button.MouseLeave:Connect(function() External:Tween(Items.Hover, {BackgroundTransparency = 1}, TweenInfo.new(0.25)) end)

    local State = false
    function Cfg.set(bool)
        State = bool
        External:Tween(Items.Checkbox, {BackgroundColor3 = State and themes.preset.accent or themes.preset.element}, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
        External:Tween(Items.Title, {TextColor3 = State and themes.preset.text or themes.preset.subtext}, TweenInfo.new(0.25))
        
        -- Satisfying Checkbox Pop Animation
        task.spawn(function()
            External:Tween(Items.Checkbox, {Size = dim2(0, 10, 0, 10)}, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
            task.wait(0.1)
            External:Tween(Items.Checkbox, {Size = dim2(0, 14, 0, 14)}, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
        end)

        if Cfg.Flag then Flags[Cfg.Flag] = State end
        Cfg.Callback(State)
    end

    table.insert(External.DynamicTheming, function()
        Items.Checkbox.BackgroundColor3 = State and themes.preset.accent or themes.preset.element
        Items.Title.TextColor3 = State and themes.preset.text or themes.preset.subtext
    end)

    Items.Button.MouseButton1Click:Connect(function() Cfg.set(not State) end)
    if Cfg.Default then Cfg.set(true) end
    if Cfg.Flag then ConfigFlags[Cfg.Flag] = Cfg.set end

    return setmetatable(Cfg, External)
end

function External:Button(properties)
    local Cfg = { 
        Name = properties.Name or properties.name or "Button", 
        Callback = properties.Callback or properties.callback or function() end, 
        Items = {} 
    }
    local Items = Cfg.Items

    Items.Button = External:Create("TextButton", { 
        Parent = self.Items.Container, Size = dim2(1, 0, 0, 30), BackgroundColor3 = themes.preset.element, 
        Text = Cfg.Name, TextColor3 = themes.preset.subtext, TextSize = 13, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium), AutoButtonColor = false 
    })
    External:Themify(Items.Button, "element", "BackgroundColor3")
    External:Themify(Items.Button, "subtext", "TextColor3")
    External:Create("UICorner", { Parent = Items.Button, CornerRadius = dim(0, 4) })

    Items.HoverOverlay = External:Create("Frame", { Parent = Items.Button, Size = dim2(1,0,1,0), BackgroundColor3 = rgb(255,255,255), BackgroundTransparency = 1, ZIndex = 2 })
    External:Create("UICorner", {Parent = Items.HoverOverlay, CornerRadius = dim(0, 4)})

    Items.Button.MouseEnter:Connect(function() External:Tween(Items.HoverOverlay, {BackgroundTransparency = 0.95}, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)) end)
    Items.Button.MouseLeave:Connect(function() External:Tween(Items.HoverOverlay, {BackgroundTransparency = 1}, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)) end)
    
    Items.Button.MouseButton1Click:Connect(function()
        External:Tween(Items.HoverOverlay, {BackgroundTransparency = 0.8}, TweenInfo.new(0.1))
        task.wait(0.1)
        External:Tween(Items.HoverOverlay, {BackgroundTransparency = 0.95}, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
        Cfg.Callback()
    end)
    return setmetatable(Cfg, External)
end

function External:Slider(properties)
    local Cfg = { 
        Name = properties.Name or properties.name or "Slider", 
        Flag = properties.Flag or properties.flag, 
        Min = properties.Min or properties.min or 0, 
        Max = properties.Max or properties.max or 100, 
        Default = properties.Default or properties.default or properties.Value or properties.value or 0, 
        Increment = properties.Increment or properties.increment or 1, 
        Suffix = properties.Suffix or properties.suffix or "", 
        Callback = properties.Callback or properties.callback or function() end, 
        Items = {} 
    }
    local Items = Cfg.Items

    Items.Container = External:Create("Frame", { Parent = self.Items.Container, Size = dim2(1, 0, 0, 38), BackgroundTransparency = 1 })
    Items.Title = External:Create("TextLabel", { Parent = Items.Container, Size = dim2(1, 0, 0, 20), BackgroundTransparency = 1, Text = "  " .. Cfg.Name, TextColor3 = themes.preset.subtext, TextSize = 13, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium), TextXAlignment = Enum.TextXAlignment.Left })
    External:Themify(Items.Title, "subtext", "TextColor3")

    Items.Val = External:Create("TextLabel", { Parent = Items.Container, Size = dim2(1, 0, 0, 20), BackgroundTransparency = 1, Text = tostring(Cfg.Default)..Cfg.Suffix, TextColor3 = themes.preset.subtext, TextSize = 13, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium), TextXAlignment = Enum.TextXAlignment.Right })
    External:Themify(Items.Val, "subtext", "TextColor3")

    Items.Track = External:Create("TextButton", { Parent = Items.Container, Position = dim2(0, 4, 0, 24), Size = dim2(1, -8, 0, 6), BackgroundColor3 = themes.preset.element, Text = "", AutoButtonColor = false })
    External:Themify(Items.Track, "element", "BackgroundColor3")
    External:Create("UICorner", { Parent = Items.Track, CornerRadius = dim(1, 0) })

    Items.Fill = External:Create("Frame", { Parent = Items.Track, Size = dim2(0, 0, 1, 0), BackgroundColor3 = themes.preset.accent })
    External:Themify(Items.Fill, "accent", "BackgroundColor3")
    External:Create("UICorner", { Parent = Items.Fill, CornerRadius = dim(1, 0) })
    
    Items.Knob = External:Create("Frame", { Parent = Items.Fill, AnchorPoint = vec2(0.5, 0.5), Position = dim2(1, 0, 0.5, 0), Size = dim2(0, 12, 0, 12), BackgroundColor3 = themes.preset.accent })
    External:Create("UICorner", { Parent = Items.Knob, CornerRadius = dim(1, 0) })
    External:Themify(Items.Knob, "accent", "BackgroundColor3")

    local Value = Cfg.Default
    function Cfg.set(val)
        Value = math.clamp(math.round(val / Cfg.Increment) * Cfg.Increment, Cfg.Min, Cfg.Max)
        Items.Val.Text = tostring(Value) .. Cfg.Suffix
        External:Tween(Items.Fill, {Size = dim2((Value - Cfg.Min) / (Cfg.Max - Cfg.Min), 0, 1, 0)}, TweenInfo.new(0.15))
        if Cfg.Flag then Flags[Cfg.Flag] = Value end
        Cfg.Callback(Value)
    end

    local Dragging = false

    Items.Track.MouseEnter:Connect(function() External:Tween(Items.Knob, {Size = dim2(0, 16, 0, 16)}, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)) end)
    Items.Track.MouseLeave:Connect(function() if not Dragging then External:Tween(Items.Knob, {Size = dim2(0, 12, 0, 12)}, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)) end end)

    Items.Track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then Dragging = true; Cfg.set(Cfg.Min + (Cfg.Max - Cfg.Min) * math.clamp((input.Position.X - Items.Track.AbsolutePosition.X) / Items.Track.AbsoluteSize.X, 0, 1)) end
    end)
    InputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then 
            if Dragging then
                Dragging = false 
                External:Tween(Items.Knob, {Size = dim2(0, 12, 0, 12)}, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
            end
        end
    end)
    InputService.InputChanged:Connect(function(input)
        if Dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            Cfg.set(Cfg.Min + (Cfg.Max - Cfg.Min) * math.clamp((input.Position.X - Items.Track.AbsolutePosition.X) / Items.Track.AbsoluteSize.X, 0, 1))
        end
    end)

    Cfg.set(Cfg.Default)
    if Cfg.Flag then ConfigFlags[Cfg.Flag] = Cfg.set end
    return setmetatable(Cfg, External)
end

function External:Textbox(properties)
    local Cfg = { 
        Name = properties.Name or properties.name or "", 
        Placeholder = properties.Placeholder or properties.placeholder or "Enter text...", 
        Default = properties.Default or properties.default or "", 
        Flag = properties.Flag or properties.flag, 
        Numeric = properties.Numeric or properties.numeric or false, 
        Callback = properties.Callback or properties.callback or function() end, 
        Items = {} 
    }
    local Items = Cfg.Items

    Items.Container = External:Create("Frame", { Parent = self.Items.Container, Size = dim2(1, 0, 0, 32), BackgroundTransparency = 1 })
    Items.Bg = External:Create("Frame", { Parent = Items.Container, Size = dim2(1, 0, 1, 0), BackgroundColor3 = themes.preset.element })
    External:Themify(Items.Bg, "element", "BackgroundColor3")
    External:Create("UICorner", { Parent = Items.Bg, CornerRadius = dim(0, 4) })

    Items.Input = External:Create("TextBox", { 
        Parent = Items.Bg, Position = dim2(0, 12, 0, 0), Size = dim2(1, -24, 1, 0), BackgroundTransparency = 1, 
        Text = Cfg.Default, PlaceholderText = Cfg.Placeholder, TextColor3 = themes.preset.text, PlaceholderColor3 = themes.preset.subtext, 
        TextSize = 13, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium), TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false 
    })
    External:Themify(Items.Input, "text", "TextColor3")

    function Cfg.set(val)
        if Cfg.Numeric and tonumber(val) == nil and val ~= "" then return end
        Items.Input.Text = tostring(val)
        if Cfg.Flag then Flags[Cfg.Flag] = val end
        Cfg.Callback(val)
    end
    
    Items.Input.FocusLost:Connect(function() Cfg.set(Items.Input.Text) end)
    if Cfg.Default ~= "" then Cfg.set(Cfg.Default) end
    if Cfg.Flag then ConfigFlags[Cfg.Flag] = Cfg.set end

    return setmetatable(Cfg, External)
end

-- animated dropdown with clean search
function External:Dropdown(properties)
    local Cfg = { 
        Name = properties.Name or properties.name or "Dropdown", 
        Flag = properties.Flag or properties.flag, 
        Options = properties.Options or properties.options or properties.items or {}, 
        Default = properties.Default or properties.default, 
        Callback = properties.Callback or properties.callback or function() end, 
        Items = {} 
    }
    local Items = Cfg.Items
    
    Items.Container = External:Create("Frame", { Parent = self.Items.Container, Size = dim2(1, 0, 0, 46), BackgroundTransparency = 1 })
    Items.Title = External:Create("TextLabel", { Parent = Items.Container, Size = dim2(1, 0, 0, 16), BackgroundTransparency = 1, Text = "  " .. Cfg.Name, TextColor3 = themes.preset.subtext, TextSize = 13, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium), TextXAlignment = Enum.TextXAlignment.Left })
    External:Themify(Items.Title, "subtext", "TextColor3")

    Items.Main = External:Create("TextButton", { 
        Parent = Items.Container, Position = dim2(0, 0, 0, 20), Size = dim2(1, 0, 0, 26), 
        BackgroundColor3 = themes.preset.element, Text = "", AutoButtonColor = false 
    })
    External:Themify(Items.Main, "element", "BackgroundColor3")
    External:Create("UICorner", { Parent = Items.Main, CornerRadius = dim(0, 4) })

    Items.SelectedText = External:Create("TextLabel", { Parent = Items.Main, Position = dim2(0, 12, 0, 0), Size = dim2(1, -24, 1, 0), BackgroundTransparency = 1, Text = "...", TextColor3 = themes.preset.subtext, TextSize = 13, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium), TextXAlignment = Enum.TextXAlignment.Left })
    External:Themify(Items.SelectedText, "subtext", "TextColor3")
    
    Items.Icon = External:Create("ImageLabel", { Parent = Items.Main, Position = dim2(1, -20, 0.5, 0), AnchorPoint = vec2(0, 0.5), Size = dim2(0, 10, 0, 10), BackgroundTransparency = 1, Image = "rbxassetid://11293977610", ImageColor3 = themes.preset.subtext, Rotation = 180 })

    Items.DropFrame = External:Create("Frame", { 
        Parent = External.Gui, Size = dim2(1, 0, 0, 0), Position = dim2(0, 0, 0, 0), 
        BackgroundColor3 = themes.preset.element, Visible = false, ZIndex = 200, ClipsDescendants = true 
    })
    External:Themify(Items.DropFrame, "element", "BackgroundColor3")
    External:Create("UICorner", { Parent = Items.DropFrame, CornerRadius = dim(0, 4) })

    -- Search Bar setup
    Items.SearchBar = External:Create("Frame", { 
        Parent = Items.DropFrame, Size = dim2(1, -12, 0, 24), Position = dim2(0, 6, 0, 6), 
        BackgroundColor3 = themes.preset.section, BorderSizePixel = 0, ZIndex = 202, ClipsDescendants = true
    })
    External:Themify(Items.SearchBar, "section", "BackgroundColor3")
    External:Create("UICorner", { Parent = Items.SearchBar, CornerRadius = dim(0, 4) })
    External:Themify(External:Create("UIStroke", { Parent = Items.SearchBar, Color = themes.preset.outline, Thickness = 1 }), "outline", "Color")

    Items.SearchInput = External:Create("TextBox", { 
        Parent = Items.SearchBar, Size = dim2(1, -16, 1, 0), Position = dim2(0, 8, 0, 0), BackgroundTransparency = 1, 
        Text = "", PlaceholderText = "Search...", TextColor3 = themes.preset.text, PlaceholderColor3 = themes.preset.subtext, 
        TextSize = 12, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium), TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ZIndex = 203 
    })
    External:Themify(Items.SearchInput, "text", "TextColor3")

    Items.Scroll = External:Create("ScrollingFrame", { 
        Parent = Items.DropFrame, Size = dim2(1, 0, 1, -38), Position = dim2(0, 0, 0, 34), 
        BackgroundTransparency = 1, ScrollBarThickness = 2, BorderSizePixel = 0, ZIndex = 201 
    })
    External:Themify(Items.Scroll, "accent", "ScrollBarImageColor3")
    External:Create("UIListLayout", { Parent = Items.Scroll, SortOrder = Enum.SortOrder.LayoutOrder })

    local Open = false
    local isTweening = false
    local OptionBtns = {}

    function Cfg.UpdateDropdownHeight()
        local visibleCount = 0
        for _, btn in ipairs(OptionBtns) do
            if btn.Visible then visibleCount += 1 end
        end
        Items.Scroll.CanvasSize = dim2(0, 0, 0, visibleCount * 24)
        return math.clamp(visibleCount * 24 + 40, 0, 180)
    end

    local function ToggleDropdown()
        if isTweening then return end
        Open = not Open
        isTweening = true

        if Open then
            Items.SearchInput.Text = "" 
            for _, btn in ipairs(OptionBtns) do 
                btn.Visible = true 
                btn.TextTransparency = 1
            end
            
            Items.DropFrame.Visible = true
            Items.DropFrame.Position = dim2(0, Items.Main.AbsolutePosition.X, 0, Items.Main.AbsolutePosition.Y + Items.Main.AbsoluteSize.Y + 4)
            Items.DropFrame.Size = dim2(0, Items.Main.AbsoluteSize.X, 0, 0)
            
            local targetHeight = Cfg.UpdateDropdownHeight()
            External:Tween(Items.Icon, {Rotation = 0}, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
            local tw = External:Tween(Items.DropFrame, {Size = dim2(0, Items.Main.AbsoluteSize.X, 0, targetHeight)}, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
            
            task.spawn(function()
                for _, btn in ipairs(OptionBtns) do
                    if btn.Visible then
                        External:Tween(btn, {TextTransparency = 0}, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
                        task.wait(0.015)
                    end
                end
            end)

            tw.Completed:Wait()
        else
            External:Tween(Items.Icon, {Rotation = 180}, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
            for _, btn in ipairs(OptionBtns) do External:Tween(btn, {TextTransparency = 1}, TweenInfo.new(0.2)) end
            
            local tw = External:Tween(Items.DropFrame, {Size = dim2(0, Items.Main.AbsoluteSize.X, 0, 0)}, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
            tw.Completed:Wait()
            Items.DropFrame.Visible = false
        end
        isTweening = false
    end
    Items.Main.MouseButton1Click:Connect(ToggleDropdown)

    Items.SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
        if not Open then return end
        local query = Items.SearchInput.Text:lower()
        for _, btn in ipairs(OptionBtns) do
            local cleanText = btn.Text:gsub("^%s+", ""):lower()
            if cleanText:find(query) then
                btn.Visible = true
                btn.TextTransparency = 0
            else
                btn.Visible = false
            end
        end
        local targetHeight = Cfg.UpdateDropdownHeight()
        External:Tween(Items.DropFrame, {Size = dim2(0, Items.Main.AbsoluteSize.X, 0, targetHeight)}, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
    end)

    InputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if Open and not isTweening then
                local mx, my = input.Position.X, input.Position.Y
                local p0, s0 = Items.DropFrame.AbsolutePosition, Items.DropFrame.AbsoluteSize
                local p1, s1 = Items.Main.AbsolutePosition, Items.Main.AbsoluteSize
                
                if not (mx >= p0.X and mx <= p0.X + s0.X and my >= p0.Y and my <= p0.Y + s0.Y) and 
                   not (mx >= p1.X and mx <= p1.X + s1.X and my >= p1.Y and my <= p1.Y + s1.Y) then
                    ToggleDropdown()
                end
            end
        end
    end)

    function Cfg.RefreshOptions(newList)
        Cfg.Options = newList or Cfg.Options
        for _, btn in ipairs(OptionBtns) do btn:Destroy() end
        table.clear(OptionBtns)
        for _, opt in ipairs(Cfg.Options) do
            local btn = External:Create("TextButton", { 
                Parent = Items.Scroll, Size = dim2(1, 0, 0, 24), BackgroundTransparency = 1, 
                Text = "   " .. tostring(opt), TextColor3 = themes.preset.subtext, TextSize = 13, 
                FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 202 
            })
            External:Themify(btn, "subtext", "TextColor3")
            btn.MouseButton1Click:Connect(function() Cfg.set(opt); ToggleDropdown() end)
            table.insert(OptionBtns, btn)
        end
    end

    function Cfg.set(val)
        Items.SelectedText.Text = tostring(val)
        if Cfg.Flag then Flags[Cfg.Flag] = val end
        Cfg.Callback(val)
    end

    Cfg.RefreshOptions(Cfg.Options)
    if Cfg.Default then Cfg.set(Cfg.Default) end
    if Cfg.Flag then ConfigFlags[Cfg.Flag] = Cfg.set end

    RunService.RenderStepped:Connect(function() 
        if Open or isTweening then 
            Items.DropFrame.Position = dim2(0, Items.Main.AbsolutePosition.X, 0, Items.Main.AbsolutePosition.Y + Items.Main.AbsoluteSize.Y + 4)
        end 
    end)
    return setmetatable(Cfg, External)
end

function External:Label(properties)
    local Cfg = { 
        Name = properties.Name or properties.name or "Label", 
        Wrapped = properties.Wrapped or properties.wrapped or false, 
        Items = {} 
    }
    local Items = Cfg.Items
    Items.Title = External:Create("TextLabel", { 
        Parent = self.Items.Container, Size = dim2(1, 0, 0, Cfg.Wrapped and 26 or 18), BackgroundTransparency = 1, 
        Text = "  " .. Cfg.Name, TextColor3 = themes.preset.subtext, TextSize = 13, TextWrapped = Cfg.Wrapped, 
        FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium), TextXAlignment = Enum.TextXAlignment.Left, 
        TextYAlignment = Cfg.Wrapped and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center 
    })
    External:Themify(Items.Title, "subtext", "TextColor3")
    
    function Cfg.set(val) Items.Title.Text = "  " .. tostring(val) end
    return setmetatable(Cfg, External)
end

function External:Colorpicker(properties)
    local Cfg = { 
        Color = properties.Color or properties.color or rgb(255, 255, 255), 
        Callback = properties.Callback or properties.callback or function() end, 
        Flag = properties.Flag or properties.flag, 
        Items = {} 
    }
    local Items = Cfg.Items

    local btn = External:Create("TextButton", { Parent = self.Items.Title or self.Items.Button or self.Items.Container, AnchorPoint = vec2(1, 0.5), Position = dim2(1, -6, 0.5, 0), Size = dim2(0, 30, 0, 14), BackgroundColor3 = Cfg.Color, Text = "" })
    External:Create("UICorner", {Parent = btn, CornerRadius = dim(0, 4)})

    local h, s, v = Color3.toHSV(Cfg.Color)
    
    Items.DropFrame = External:Create("Frame", { Parent = External.Gui, Size = dim2(0, 150, 0, 0), BackgroundColor3 = themes.preset.element, Visible = false, ZIndex = 200, ClipsDescendants = true })
    External:Themify(Items.DropFrame, "element", "BackgroundColor3")
    External:Create("UICorner", { Parent = Items.DropFrame, CornerRadius = dim(0, 4) })

    Items.SVMap = External:Create("TextButton", { Parent = Items.DropFrame, Position = dim2(0, 8, 0, 8), Size = dim2(1, -16, 1, -38), AutoButtonColor = false, Text = "", BackgroundColor3 = Color3.fromHSV(h, 1, 1), ZIndex = 201 })
    External:Create("UICorner", { Parent = Items.SVMap, CornerRadius = dim(0, 3) })
    Items.SVImage = External:Create("ImageLabel", { Parent = Items.SVMap, Size = dim2(1, 0, 1, 0), Image = "rbxassetid://4155801252", BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 202 })
    External:Create("UICorner", { Parent = Items.SVImage, CornerRadius = dim(0, 3) })
    
    Items.SVKnob = External:Create("Frame", { Parent = Items.SVMap, AnchorPoint = vec2(0.5, 0.5), Size = dim2(0, 4, 0, 4), BackgroundColor3 = rgb(255,255,255), ZIndex = 203 })
    External:Create("UICorner", { Parent = Items.SVKnob, CornerRadius = dim(1, 0) })
    External:Create("UIStroke", { Parent = Items.SVKnob, Color = rgb(0,0,0) })

    Items.HueBar = External:Create("TextButton", { Parent = Items.DropFrame, Position = dim2(0, 8, 1, -22), Size = dim2(1, -16, 0, 14), AutoButtonColor = false, Text = "", BorderSizePixel = 0, BackgroundColor3 = rgb(255, 255, 255), ZIndex = 201 })
    External:Create("UICorner", { Parent = Items.HueBar, CornerRadius = dim(0, 3) })
    External:Create("UIGradient", { Parent = Items.HueBar, Color = ColorSequence.new({ColorSequenceKeypoint.new(0, rgb(255,0,0)), ColorSequenceKeypoint.new(0.167, rgb(255,0,255)), ColorSequenceKeypoint.new(0.333, rgb(0,0,255)), ColorSequenceKeypoint.new(0.5, rgb(0,255,255)), ColorSequenceKeypoint.new(0.667, rgb(0,255,0)), ColorSequenceKeypoint.new(0.833, rgb(255,255,0)), ColorSequenceKeypoint.new(1, rgb(255,0,0))}) })
    
    Items.HueKnob = External:Create("Frame", { Parent = Items.HueBar, AnchorPoint = vec2(0.5, 0.5), Size = dim2(0, 2, 1, 4), BackgroundColor3 = rgb(255,255,255), ZIndex = 203 })
    External:Create("UIStroke", { Parent = Items.HueKnob, Color = rgb(0,0,0) })

    local Open = false
    local isTweening = false

    local function Toggle() 
        if isTweening then return end
        Open = not Open
        isTweening = true
        
        if Open then
            Items.DropFrame.Visible = true
            local tw = External:Tween(Items.DropFrame, {Size = dim2(0, 150, 0, 140)}, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
            tw.Completed:Wait()
        else
            local tw = External:Tween(Items.DropFrame, {Size = dim2(0, 150, 0, 0)}, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
            tw.Completed:Wait()
            Items.DropFrame.Visible = false
        end
        isTweening = false
    end
    btn.MouseButton1Click:Connect(Toggle)

    InputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if Open and not isTweening then
                local mx, my = input.Position.X, input.Position.Y
                local p0, s0 = Items.DropFrame.AbsolutePosition, dim2(0, 150, 0, 140)
                local p1, s1 = btn.AbsolutePosition, btn.AbsoluteSize
                if not (mx >= p0.X and mx <= p0.X + s0.X.Offset and my >= p0.Y and my <= p0.Y + s0.Y.Offset) and not (mx >= p1.X and mx <= p1.X + s1.X and my >= p1.Y and my <= p1.Y + s1.Y) then
                    Toggle()
                end
            end
        end
    end)

    function Cfg.set(color3)
        Cfg.Color = color3
        btn.BackgroundColor3 = color3
        if Cfg.Flag then Flags[Cfg.Flag] = color3 end
        Cfg.Callback(color3)
    end

    local svDragging, hueDragging = false, false
    Items.SVMap.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then svDragging = true end end)
    Items.HueBar.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then hueDragging = true end end)
    InputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then svDragging = false; hueDragging = false end end)

    InputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if svDragging then
                local x = math.clamp((input.Position.X - Items.SVMap.AbsolutePosition.X) / Items.SVMap.AbsoluteSize.X, 0, 1)
                local y = math.clamp((input.Position.Y - Items.SVMap.AbsolutePosition.Y) / Items.SVMap.AbsoluteSize.Y, 0, 1)
                s, v = x, 1 - y
                Items.SVKnob.Position = dim2(x, 0, y, 0)
                Cfg.set(Color3.fromHSV(h, s, v))
            elseif hueDragging then
                local x = math.clamp((input.Position.X - Items.HueBar.AbsolutePosition.X) / Items.HueBar.AbsoluteSize.X, 0, 1)
                h = 1 - x
                Items.HueKnob.Position = dim2(x, 0, 0.5, 0)
                Items.SVMap.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                Cfg.set(Color3.fromHSV(h, s, v))
            end
        end
    end)

    RunService.RenderStepped:Connect(function()
        if Open or isTweening then Items.DropFrame.Position = dim2(0, btn.AbsolutePosition.X - 150 + btn.AbsoluteSize.X, 0, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y + 2) end
    end)
    
    Items.SVKnob.Position = dim2(s, 0, 1 - v, 0)
    Items.HueKnob.Position = dim2(1 - h, 0, 0.5, 0)
    
    Cfg.set(Cfg.Color)
    if Cfg.Flag then ConfigFlags[Cfg.Flag] = Cfg.set end
    return setmetatable(Cfg, External)
end

function External:Keybind(properties)
    local Cfg = { 
        Name = properties.Name or properties.name or "Keybind", 
        Flag = properties.Flag or properties.flag, 
        Default = properties.Default or properties.default or Enum.KeyCode.Unknown, 
        Callback = properties.Callback or properties.callback or function() end, 
        Items = {} 
    }
    local KeyBtn = External:Create("TextButton", { Parent = self.Items.Title or self.Items.Container, AnchorPoint = vec2(1, 0.5), Position = dim2(1, -6, 0.5, 0), Size = dim2(0, 40, 0, 16), BackgroundColor3 = themes.preset.element, TextColor3 = themes.preset.subtext, Text = Keys[Cfg.Default] or "None", TextSize = 12, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium), })
    External:Themify(KeyBtn, "element", "BackgroundColor3")
    External:Themify(KeyBtn, "subtext", "TextColor3")

    External:Create("UICorner", {Parent = KeyBtn, CornerRadius = dim(0, 4)})
    
    local binding = false
    KeyBtn.MouseButton1Click:Connect(function() binding = true; KeyBtn.Text = "..." end)
    
    InputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed and not binding then return end
        if binding then
            if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
                binding = false; Cfg.set(input.KeyCode)
            elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
                binding = false; Cfg.set(input.UserInputType)
            end
        elseif (input.KeyCode == Cfg.Default or input.UserInputType == Cfg.Default) and not binding then
            Cfg.Callback()
        end
    end)
    
    function Cfg.set(val)
        if not val or type(val) == "boolean" then return end
        Cfg.Default = val
        local keyName = Keys[val] or (typeof(val) == "EnumItem" and val.Name) or tostring(val)
        KeyBtn.Text = keyName
        if Cfg.Flag then Flags[Cfg.Flag] = val end
    end
    
    Cfg.set(Cfg.Default)
    if Cfg.Flag then ConfigFlags[Cfg.Flag] = Cfg.set end
    return setmetatable(Cfg, External)
end

-- notifs
function Notifications:RefreshNotifications()
    local offset = 50
    for _, v in ipairs(Notifications.Notifs) do
        local ySize = math.max(v.AbsoluteSize.Y, 36)
        External:Tween(v, {Position = dim_offset(20, offset)}, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
        offset += (ySize + 10)
    end
end

function Notifications:Create(properties)
    local Cfg = { 
        Name = properties.Name or properties.name or "Notification"; 
        Lifetime = properties.LifeTime or properties.lifetime or 2.5; 
        Items = {}; 
    }
    local Items = Cfg.Items
   
    Items.Outline = External:Create("Frame", { Parent = External.Gui; Position = dim_offset(-500, 50); Size = dim2(0, 300, 0, 0); AutomaticSize = Enum.AutomaticSize.Y; BackgroundColor3 = themes.preset.background; BorderSizePixel = 0; ZIndex = 300, ClipsDescendants = true })
    External:Themify(Items.Outline, "background", "BackgroundColor3")
    External:Create("UICorner", { Parent = Items.Outline, CornerRadius = dim(0, 4) })
   
    Items.Name = External:Create("TextLabel", {
        Parent = Items.Outline; Text = Cfg.Name; TextColor3 = themes.preset.text; FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium);
        BackgroundTransparency = 1; Size = dim2(1, 0, 1, 0); AutomaticSize = Enum.AutomaticSize.None; TextWrapped = true; TextSize = 13; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 302
    })
    External:Themify(Items.Name, "text", "TextColor3")
   
    External:Create("UIPadding", { Parent = Items.Name; PaddingTop = dim(0, 10); PaddingBottom = dim(0, 10); PaddingRight = dim(0, 12); PaddingLeft = dim(0, 12); })
   
    Items.TimeBar = External:Create("Frame", { Parent = Items.Outline, AnchorPoint = vec2(0, 1), Position = dim2(0, 0, 1, 0), Size = dim2(1, 0, 0, 2), BackgroundColor3 = themes.preset.accent, BorderSizePixel = 0, ZIndex = 303 })
    External:Themify(Items.TimeBar, "accent", "BackgroundColor3")
    table.insert(Notifications.Notifs, Items.Outline)
   
    task.spawn(function()
        RunService.RenderStepped:Wait()
        Items.Outline.Position = dim_offset(-Items.Outline.AbsoluteSize.X - 20, 50)
        Notifications:RefreshNotifications()
        External:Tween(Items.TimeBar, {Size = dim2(0, 0, 0, 2)}, TweenInfo.new(Cfg.Lifetime, Enum.EasingStyle.Linear))
        task.wait(Cfg.Lifetime)
        External:Tween(Items.Outline, {Position = dim_offset(-Items.Outline.AbsoluteSize.X - 50, Items.Outline.Position.Y.Offset)}, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In))
        task.wait(0.4)
        local idx = table.find(Notifications.Notifs, Items.Outline)
        if idx then table.remove(Notifications.Notifs, idx) end
        Items.Outline:Destroy()
        task.wait(0.05)
        Notifications:RefreshNotifications()
    end)
end

-- save and load stuff
function External:GetConfig()
    local g = {}
    for Idx, Value in Flags do g[Idx] = Value end
    return HttpService:JSONEncode(g)
end

function External:LoadConfig(JSON)
    local g = HttpService:JSONDecode(JSON)
    for Idx, Value in g do
        if Idx == "config_Name_list" or Idx == "config_Name_text" then continue end
        local Function = ConfigFlags[Idx]
        if Function then Function(Value) end
    end
end

-- configs and server menu 
local ConfigHolder
function External:UpdateConfigList()
    if not ConfigHolder then return end
    local List = {}
    for _, file in listfiles(External.Directory .. "/configs") do
        local Name = file:gsub(External.Directory .. "/configs\\", ""):gsub(".cfg", ""):gsub(External.Directory .. "\\configs\\", "")
        List[#List + 1] = Name
    end
    ConfigHolder.RefreshOptions(List)
end

function External:Configs(window)
    local Text

    local Tab = window:Tab({ Name = "", Hidden = true })
    window.SettingsTabOpen = Tab.OpenTab

    local Section = Tab:Section({Name = "Configs", Side = "Left"})

    ConfigHolder = Section:Dropdown({
        Name = "Available Configs",
        Options = {},
        Callback = function(option) if Text then Text.set(option) end end,
        Flag = "config_Name_list"
    })

    External:UpdateConfigList()

    Text = Section:Textbox({ Name = "Config Name:", Flag = "config_Name_text", Default = "" })

    Section:Button({
        Name = "Save Config",
        Callback = function()
            if Flags["config_Name_text"] == "" then return end
            writefile(External.Directory .. "/configs/" .. Flags["config_Name_text"] .. ".cfg", External:GetConfig())
            External:UpdateConfigList()
            Notifications:Create({Name = "Saved Config: " .. Flags["config_Name_text"]})
        end
    })

    Section:Button({
        Name = "Load Config",
        Callback = function()
            if Flags["config_Name_text"] == "" then return end
            External:LoadConfig(readfile(External.Directory .. "/configs/" .. Flags["config_Name_text"] .. ".cfg"))
            External:UpdateConfigList()
            Notifications:Create({Name = "Loaded Config: " .. Flags["config_Name_text"]})
        end
    })

    Section:Button({
        Name = "Delete Config",
        Callback = function()
            if Flags["config_Name_text"] == "" then return end
            delfile(External.Directory .. "/configs/" .. Flags["config_Name_text"] .. ".cfg")
            External:UpdateConfigList()
            Notifications:Create({Name = "Deleted Config: " .. Flags["config_Name_text"]})
        end
    })

    local UISection = Tab:Section({Name = "UI Settings", Side = "Left"})

    UISection:Toggle({
        Name = "Streamer Mode (Hide User)",
        Flag = "ui_streamer_mode",
        Default = false,
        Callback = function(state)
            if state then
                window.Items.Username.Text = "Hidden"
                window.Items.Avatar.Image = "rbxthumb://type=AvatarHeadShot&id=1&w=48&h=48" 
            else
                window.Items.Username.Text = lp.Name
                window.Items.Avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. lp.UserId .. "&w=48&h=48"
            end
        end
    })

    local SectionRight = Tab:Section({Name = "Theme Settings", Side = "Right"})

    SectionRight:Label({Name = "Accent Color"}):Colorpicker({ Callback = function(color3) External:RefreshTheme("accent", color3) end, Color = themes.preset.accent })
    SectionRight:Label({Name = "Glow Color"}):Colorpicker({ Callback = function(color3) External:RefreshTheme("glow", color3) end, Color = themes.preset.glow })
    SectionRight:Label({Name = "Background Color"}):Colorpicker({ Callback = function(color3) External:RefreshTheme("background", color3) end, Color = themes.preset.background })
    SectionRight:Label({Name = "Section Color"}):Colorpicker({ Callback = function(color3) External:RefreshTheme("section", color3) end, Color = themes.preset.section })
    SectionRight:Label({Name = "Element Color"}):Colorpicker({ Callback = function(color3) External:RefreshTheme("element", color3) end, Color = themes.preset.element })
    SectionRight:Label({Name = "Text Color"}):Colorpicker({ Callback = function(color3) External:RefreshTheme("text", color3) end, Color = themes.preset.text })

    window.Tweening = true
    SectionRight:Label({Name = "Menu Bind"}):Keybind({
        Name = "Menu Bind",
        Callback = function(bool) if window.Tweening then return end window.ToggleMenu(bool) end,
        Default = Enum.KeyCode.RightShift
    })

    task.delay(1, function() window.Tweening = false end)

    local ServerSection = Tab:Section({Name = "Server", Side = "Right"})

    ServerSection:Button({ Name = "Rejoin Server", Callback = function() game:GetService("TeleportService"):Teleport(game.PlaceId, Players.LocalPlayer) end })

    ServerSection:Button({
        Name = "Server Hop",
        Callback = function()
            local servers, cursor = {}, ""
            repeat
                local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100" .. (cursor ~= "" and "&cursor=" .. cursor or "")
                local data = HttpService:JSONDecode(game:HttpGet(url))
                for _, server in ipairs(data.data) do
                    if server.id ~= game.JobId and server.playing < server.maxPlayers then table.insert(servers, server) end
                end
                cursor = data.nextPageCursor
            until not cursor or #servers > 0
            if #servers > 0 then game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)].id, Players.LocalPlayer) end
        end
    })

    ServerSection:Button({
        Name = "Join Lowest Server",
        Callback = function()
            local lowestServer, cursor = nil, ""
            repeat
                local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100" .. (cursor ~= "" and "&cursor=" .. cursor or "")
                local data = HttpService:JSONDecode(game:HttpGet(url))
                for _, server in ipairs(data.data) do
                    if server.id ~= game.JobId and server.playing > 0 and server.playing < server.maxPlayers then
                        lowestServer = server.id
                        break
                    end
                end
                cursor = data.nextPageCursor
            until lowestServer or not cursor
            if lowestServer then game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, lowestServer, Players.LocalPlayer) end
        end
    })
end

return External
