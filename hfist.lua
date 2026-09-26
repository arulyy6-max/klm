script_author("Deprau")

local f = require("ffi")
local samem = require("SAMemory")
local j = require("json")

samem.require("CPed")
samem.require("CPlayerData")
samem.require("CWeaponInfo")
samem.require("CCamera")

local cam = samem.camera
local g = f.load("GTASA")

f.cdef[[
unsigned long* _Z13FindPlayerPedi(int);
unsigned char _ZN4CPed14GetWeaponSkillEv(unsigned long*);
CWeaponInfo* _ZN11CWeaponInfo13GetWeaponInfoE11eWeaponTypea(int,unsigned char);
]]

local cf = "config/hfist.json"

local hf, fm = false, false
local fs, lp, sp, lw = false, false, 0, 0
local wa, at = false, 0

local function aim()
    local md = cam.aCams[0].nMode
    return md == 7 or md == 8 or md == 51 or md == 53
end

local function gi()
    if not doesCharExist(PLAYER_PED) then return end
    local p = g._Z13FindPlayerPedi(-1)
    if not p then return end

    local w = getCurrentCharWeapon(PLAYER_PED)
    if type(w) == "table" then w = w[2] end
    w = tonumber(w) or 0

    local st = g._ZN4CPed14GetWeaponSkillEv(p)
    return g._ZN11CWeaponInfo13GetWeaponInfoE11eWeaponTypea(w, st)
end

local function sv()
    local file = io.open(cf, "w+")
    if file then file:write(j.encode({hf = hf, fm = fm})) file:close() end
end

local function ld()
    local file = io.open(cf, "r")
    if not file then return end
    local d = j.decode(file:read("*a"))
    file:close()
    if type(d) ~= "table" then return end
    hf, fm = d.hf or false, d.fm or false
end

function main()
    repeat wait(100) until isSampAvailable()

    sampRegisterChatCommand("hfist", function()
        hf = not hf
        printStyledString(hf and "HEAVY FIST ~y~ON!" or "HEAVY FIST ~r~OFF!", 2000, 6)
        sv()
    end)

    sampRegisterChatCommand("alf", function()
        fm = not fm
        printStyledString(fm and "AUTO LIFE FOOT ~y~ON!" or "AUTO LIFE FOOT ~r~OFF!", 2000, 6)
        sv()
    end)

    ld()

    while true do
        wait(0)

        local ped = samem.player_ped[0]
        local isAiming = aim()
        local active = isAiming
        local expired = false

        if ped ~= samem.nullptr then
            local nw = os.clock()

            if isAiming then
                ped.fHeadingChangeRate = 50.0
                wa = true
                at = 0
            else
                if wa then
                    wa = false
                    at = nw
                end

                if at > 0 then
                    active = true

                    if (nw - at) >= 0.3 then
                        ped.fHeadingChangeRate = 12.0
                        at = 0
                        active = false
                        expired = true
                    end
                end
            end
        end

        local it = gi()
        if it then it.nFlags.bHeavy = (hf and active) and 1 or 0 end

if fm and active then
    local wp = getCurrentCharWeapon(PLAYER_PED)

    if isWidgetPressedEx(0xA0, 0) then
        if not lp and wp ~= 0 then fs, sp, lw = true, os.clock() + 0.35, wp end
        lp = true
    else lp = false end

    if fs then
        if os.clock() < sp then setCurrentCharWeapon(PLAYER_PED, 0) else fs = false end
    end

    if lw > 0 and getCurrentCharWeapon(PLAYER_PED) == 0 then
        setCurrentCharWeapon(PLAYER_PED, lw)
    end
else
    lp = false
    fs = false

    if expired and fm and lw > 0 then
        setCurrentCharWeapon(PLAYER_PED, lw)
    end
        end
    end
end
