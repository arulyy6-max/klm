require('sa_renderfix')
local memory  = require("memory")
local imgui   = require("mimgui")
local new     = imgui.new
local json    = require("dkjson")
local io      = require("io")
local ffi     = require("ffi")
local gta     = ffi.load("GTASA")
local mmk     = ffi.load("monetloader")
local bit = require("bit")
local widgets = require('widgets')

local CFG_DIR  = "config"
local CFG_FILE = CFG_DIR .. "/adjustable.json"
os.execute('mkdir -p ' .. CFG_DIR)

local OFF_X = 0x18
local OFF_Y = 0x1C
local OFF_W = 0x20
local OFF_H = 0x24

local defaultConfig = {
    widgets = {
        ATTACK           = {x=607,y=310,w=20.4,h=20.4,s=1.0},
        ENTER_TARGETING  = {x=607,y=310,w=20.4,h=20.4,s=1.0},
        VC_SHOOT         = {x=553,y=310,w=20.4,h=20.4,s=1.0},
        VC_SHOOT_ALT     = {x=554,y=310,w=20.4,h=20.4,s=1.0},
        SPRINT           = {x=603,y=381,w=24.65,h=24.65,s=1.0},
        ENTER_CAR        = {x=607,y=246,w=20.4,h=20.4,s=1.0},
        ACCELERATE       = {x=602,y=380,w=24.65,h=24.65,s=1.0},
        BRAKE            = {x=541,y=381,w=24.65,h=24.65,s=1.0},
        HAND_BRAKE       = {x=607,y=310,w=20.4,h=20.4,s=1.0},
        HORN             = {x=614,y=191,w=14.45,h=14.45,s=1.0},
        REPLAY           = {x=613,y=143,w=14.45,h=14.45,s=1.0},
        PLAYER_INFO      = {x=555,y=70,w=75,h=45,s=1.0},
        RADAR            = {x=50,y=70,w=45,h=45,s=1.0},
        ANALOG           = {x=120,y=348,w=120,h=100,s=1.0},
    }
}

local function loadConfig()
    local file = io.open(CFG_FILE, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    if not content or content == "" then return nil end
    local data = json.decode(content)
    if not data or not data.widgets then return nil end
    return data
end

local saveStatusTimer = 0
local saveStatusText = ""

local function saveConfig()
    local out = { widgets = {} }
    for k,v in pairs(widgets) do
        out.widgets[k] = { x=v.x[0], y=v.y[0], w=v.w[0], h=v.h[0], s=v.s[0] }
    end
    local file = io.open(CFG_FILE, "w")
    if file then
        file:write(json.encode(out, { indent = true }))
        file:close()
        saveStatusText = "Tersimpan!"
    else
        saveStatusText = "Gagal menyimpan!"
    end
    saveStatusTimer = os.clock()
end

local loaded = loadConfig()
local configExisted = loaded ~= nil
local config = loaded or defaultConfig

local function newWidget(name,data,needsCapture)
    return {
        name = name,
        x = imgui.new.float(data.x or 200),
        y = imgui.new.float(data.y or 200),
        w = imgui.new.float(data.w or 100),
        h = imgui.new.float(data.h or 100),
        s = imgui.new.float(data.s or 1.0),
        ptr = 0,
        captured = not needsCapture,
        origX = nil, origY = nil, origW = nil, origH = nil,
    }
end

widgets = {}
for k,v in pairs(defaultConfig.widgets) do
    local data = (config.widgets and config.widgets[k]) or v
    widgets[k] = newWidget(k, data, not configExisted)
end

local dpi = MONET_DPI_SCALE or 1
local MDS = dpi * 1.0

imgui.OnInitialize(function()
    local io_ = imgui.GetIO()
    local style = imgui.GetStyle()
    io_.IniFilename = nil
    io_.FontGlobalScale = MDS
    style:ScaleAllSizes(MDS)
end)

local window = imgui.new.bool(false)
local currentTab = "OnFoot"

local widgetLabels = {
    ATTACK          = "Adjust Attack",
    ENTER_TARGETING = "Adjust Enter Targeting",
    VC_SHOOT        = "Adjust VC Shoot",
    VC_SHOOT_ALT    = "Adjust VC Shoot Alt",
    SPRINT          = "Adjust Sprint",
    ENTER_CAR       = "Adjust Enter Car",
    ACCELERATE      = "Adjust Accelerate",
    BRAKE           = "Adjust Brake",
    HAND_BRAKE      = "Adjust Hand Brake",
    HORN            = "Adjust Horn",
    REPLAY          = "Adjust Replay",
    PLAYER_INFO     = "Adjust Player Info",
    RADAR           = "Adjust Radar",
    ANALOG          = "Adjust Analog",
}

local function resetWidget(w)
    if w.origX then w.x[0] = w.origX end
    if w.origY then w.y[0] = w.origY end
    if w.origW then w.w[0] = w.origW end
    if w.origH then w.h[0] = w.origH end
    w.s[0] = 1.0
end

local function drawWidget(w)
    local label = widgetLabels[w.name] or w.name
    local style0 = imgui.GetStyle()
    local headerPadY = 10
    local oldHeaderPad = style0.FramePadding
    style0.FramePadding = imgui.ImVec2(oldHeaderPad.x, headerPadY)
    local headerOpen = imgui.CollapsingHeader(label)
    style0.FramePadding = oldHeaderPad
    if headerOpen then
        local step = 0.06
        local scaleStep = 0.01
        local repeatInterval = 0.01
        if w.buttonTimeX == nil then w.buttonTimeX=0 end
        if w.buttonTimeY == nil then w.buttonTimeY=0 end
        if w.buttonTimeW == nil then w.buttonTimeW=0 end
        if w.buttonTimeH == nil then w.buttonTimeH=0 end
        if w.buttonTimeS == nil then w.buttonTimeS=0 end

        local btnSize = 40
        local style = imgui.GetStyle()
        local spacing = style.ItemSpacing.x
        local sliderWidth = imgui.GetContentRegionAvail().x - (btnSize*2) - (spacing*2)
        local lineH = imgui.GetTextLineHeight()
        local padY = (btnSize - lineH) / 2
        local oldPad = style.FramePadding

        local function slider(id, val, minV, maxV, fmt)
            imgui.SetNextItemWidth(sliderWidth)
            style.FramePadding = imgui.ImVec2(8, padY)
            imgui.SliderFloat(id, val, minV, maxV, fmt)
            style.FramePadding = oldPad
        end

        if imgui.Button("-##x"..w.name,imgui.ImVec2(btnSize,btnSize))then w.x[0]=w.x[0]-step w.buttonTimeX=os.clock() end
        if imgui.IsItemActive()and os.clock()-w.buttonTimeX>=repeatInterval then w.x[0]=w.x[0]-step w.buttonTimeX=os.clock() end
        imgui.SameLine()
        slider("##x"..w.name, w.x, 0, 1000, "Pos X = %.0f")
        imgui.SameLine()
        if imgui.Button("+##x"..w.name,imgui.ImVec2(btnSize,btnSize))then w.x[0]=w.x[0]+step w.buttonTimeX=os.clock() end
        if imgui.IsItemActive()and os.clock()-w.buttonTimeX>=repeatInterval then w.x[0]=w.x[0]+step w.buttonTimeX=os.clock() end

        if imgui.Button("-##y"..w.name,imgui.ImVec2(btnSize,btnSize))then w.y[0]=w.y[0]-step w.buttonTimeY=os.clock() end
        if imgui.IsItemActive()and os.clock()-w.buttonTimeY>=repeatInterval then w.y[0]=w.y[0]-step w.buttonTimeY=os.clock() end
        imgui.SameLine()
        slider("##y"..w.name, w.y, 0, 1000, "Pos Y = %.0f")
        imgui.SameLine()
        if imgui.Button("+##y"..w.name,imgui.ImVec2(btnSize,btnSize))then w.y[0]=w.y[0]+step w.buttonTimeY=os.clock() end
        if imgui.IsItemActive()and os.clock()-w.buttonTimeY>=repeatInterval then w.y[0]=w.y[0]+step w.buttonTimeY=os.clock() end

        if imgui.Button("-##w"..w.name,imgui.ImVec2(btnSize,btnSize))then w.w[0]=w.w[0]-step w.buttonTimeW=os.clock() end
        if imgui.IsItemActive()and os.clock()-w.buttonTimeW>=repeatInterval then w.w[0]=w.w[0]-step w.buttonTimeW=os.clock() end
        imgui.SameLine()
        slider("##w"..w.name, w.w, 1, 500, "Width = %.0f")
        imgui.SameLine()
        if imgui.Button("+##w"..w.name,imgui.ImVec2(btnSize,btnSize))then w.w[0]=w.w[0]+step w.buttonTimeW=os.clock() end
        if imgui.IsItemActive()and os.clock()-w.buttonTimeW>=repeatInterval then w.w[0]=w.w[0]+step w.buttonTimeW=os.clock() end

        if imgui.Button("-##h"..w.name,imgui.ImVec2(btnSize,btnSize))then w.h[0]=w.h[0]-step w.buttonTimeH=os.clock() end
        if imgui.IsItemActive()and os.clock()-w.buttonTimeH>=repeatInterval then w.h[0]=w.h[0]-step w.buttonTimeH=os.clock() end
        imgui.SameLine()
        slider("##h"..w.name, w.h, 1, 500, "Height = %.0f")
        imgui.SameLine()
        if imgui.Button("+##h"..w.name,imgui.ImVec2(btnSize,btnSize))then w.h[0]=w.h[0]+step w.buttonTimeH=os.clock() end
        if imgui.IsItemActive()and os.clock()-w.buttonTimeH>=repeatInterval then w.h[0]=w.h[0]+step w.buttonTimeH=os.clock() end

        if imgui.Button("-##s"..w.name,imgui.ImVec2(btnSize,btnSize))then w.s[0]=w.s[0]-scaleStep w.buttonTimeS=os.clock() end
        if imgui.IsItemActive()and os.clock()-w.buttonTimeS>=repeatInterval then w.s[0]=w.s[0]-scaleStep w.buttonTimeS=os.clock() end
        imgui.SameLine()
        slider("##s"..w.name, w.s, 0.1, 5, "Scale = %.2f")
        imgui.SameLine()
        if imgui.Button("+##s"..w.name,imgui.ImVec2(btnSize,btnSize))then w.s[0]=w.s[0]+scaleStep w.buttonTimeS=os.clock() end
        if imgui.IsItemActive()and os.clock()-w.buttonTimeS>=repeatInterval then w.s[0]=w.s[0]+scaleStep w.buttonTimeS=os.clock() end

        local resetBtnWidth = sliderWidth+100
local resetBtnHeight = 36
if imgui.Button("Reset Default##"..w.name, imgui.ImVec2(resetBtnWidth, resetBtnHeight)) then
    resetWidget(w)
        end
    end
end


local autoHeight = imgui.new.float(300)
local onFootWidgets = {"ATTACK","ANALOG","VC_SHOOT_ALT","VC_SHOOT","ENTER_TARGETING","SPRINT","RADAR","PLAYER_INFO"}
local inCarWidgets = {"HORN","ACCELERATE","ENTER_CAR","BRAKE","HAND_BRAKE","REPLAY"}

local function tabButton(label, tabName, tabWidth)
    local active = currentTab == tabName
    if active then
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.20,0.45,0.85,1))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.20,0.45,0.85,1))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.20,0.45,0.85,1))
    end
    if imgui.Button(label, imgui.ImVec2(tabWidth,36)) then
        currentTab = tabName
    end
    if active then
        imgui.PopStyleColor(3)
    end
end

imgui.OnFrame(function() return window[0] end,function()
darkgreentheme()
    local winWidth = 460*MDS
    local winHeight = 370*MDS
    imgui.SetNextWindowSize(imgui.ImVec2(winWidth, winHeight), imgui.Cond.Always)
    if imgui.Begin("Deprau - Customizable Widget Controller", window, bit.bor(imgui.WindowFlags.NoCollapse, imgui.WindowFlags.NoResize)) then

        if imgui.Button("save") then
            saveConfig()
        end

        if saveStatusText ~= "" and os.clock()-saveStatusTimer < 2 then
            imgui.SameLine()
            imgui.TextColored(imgui.ImVec4(0.3,1,0.3,1), saveStatusText)
        end

        local tabWidth = (imgui.GetContentRegionAvail().x - 10) / 2
        tabButton("OnFoot", "OnFoot", tabWidth)
        imgui.SameLine()
        tabButton("InVehicle", "InVehicle", tabWidth)

        local childHeight = imgui.GetWindowSize().y - imgui.GetCursorPosY() - imgui.GetStyle().WindowPadding.y

        imgui.BeginChild("TabContent", imgui.ImVec2(0,childHeight), true)
        local list = currentTab == "OnFoot" and onFootWidgets or inCarWidgets
        for _,name in ipairs(list) do drawWidget(widgets[name]) end
        imgui.EndChild()
    end
    imgui.End()
end)

local function apply(w, ptr)
    w.ptr = ptr or 0
    if ptr==0 or ptr==nil then return end

    if w.origX == nil then
        local ox = memory.getfloat(ptr+OFF_X,false)
        local oy = memory.getfloat(ptr+OFF_Y,false)
        local ow = memory.getfloat(ptr+OFF_W,false)
        local oh = memory.getfloat(ptr+OFF_H,false)
        if ox then w.origX = ox end
        if oy then w.origY = oy end
        if ow then w.origW = ow end
        if oh then w.origH = oh end
    end

    if not w.captured then
        if w.origX then w.x[0] = w.origX end
        if w.origY then w.y[0] = w.origY end
        if w.origW then w.w[0] = w.origW end
        if w.origH then w.h[0] = w.origH end
        w.s[0] = 1.0
        w.captured = true
        return
    end

    memory.setfloat(ptr+OFF_X,w.x[0],false)
    memory.setfloat(ptr+OFF_Y,w.y[0],false)
    memory.setfloat(ptr+OFF_W,w.w[0]*w.s[0],false)
    memory.setfloat(ptr+OFF_H,w.h[0]*w.s[0],false)
end

local map = {
    {1,widgets.ATTACK},
    {19,widgets.ENTER_TARGETING},{20,widgets.ENTER_TARGETING},
    {21,widgets.VC_SHOOT},{22,widgets.VC_SHOOT_ALT},
    {31,widgets.SPRINT},
    {0,widgets.ENTER_CAR},
    {2,widgets.ACCELERATE},{3,widgets.BRAKE},
    {4,widgets.HAND_BRAKE},
    {7,widgets.HORN},
    {18,widgets.REPLAY},
    {160,widgets.PLAYER_INFO},
    {161,widgets.RADAR},
    {167,widgets.ANALOG},
}

imgui.OnFrame(function() return true end, function()
    local base = memory.getuint64(MONET_GTASA_BASE + 0x850910, false)
    if base == 0 or base == nil then return end
    for _,v in pairs(map) do
        local ptr = memory.getuint64(base+v[1]*8,false)
        apply(v[2],ptr)
    end
end)

function main()
    repeat wait(100) until isSampAvailable()
    sampRegisterChatCommand("adjust",function() 
    window[0]=not window[0] 
    print("", window[0])
end)
    wait(-1)
end

function darkgreentheme()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    style.Alpha = 1
    style.WindowPadding = imgui.ImVec2(15, 15)
    style.WindowRounding = 15
    style.WindowBorderSize = 1
    style.WindowMinSize = imgui.ImVec2(32, 32)
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ChildRounding = 15
    style.ChildBorderSize = 4
    style.PopupRounding = 14
    style.PopupBorderSize = 1
    style.FramePadding = imgui.ImVec2(10, 2)
    style.FrameRounding = 6
    style.FrameBorderSize = 0
    style.ItemSpacing = imgui.ImVec2(10, 10)
    style.ItemInnerSpacing = imgui.ImVec2(6, 6)
    style.GrabMinSize = 8
    style.GrabRounding = 4
    style.ScrollbarSize = 18
    style.ScrollbarRounding = 10
    style.TabRounding = 12
end