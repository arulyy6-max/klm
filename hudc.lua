local uig = require('mimgui')
local new = uig.new
local ffi = require('ffi')
local gta = ffi.load('GTASA')
local mem = require('SAMemory')
local cst = ffi.cast
local jsn = require('dkjson')
local iox = require('io')

mem.require('RenderWare')

ffi.cdef[[
    void* _Z13RwTextureReadPKcS0_(const char* name, const char* mask);

    typedef void RwStream;
    typedef struct {
        uint8_t* start;
        uint32_t length;
    } RwMemory;
    RwStream* _Z12RwStreamOpen12RwStreamType18RwStreamAccessTypePKv(int type, int accessType, const void *pData);
    void _Z13RwStreamCloseP8RwStreamPv(RwStream* stream, void* pData);
    bool _Z17RwStreamFindChunkP8RwStreamjPjS1_(RwStream* stream, uint32_t type, uint32_t* lengthOut, uint32_t* versionOut);
    RwTexDictionary* _Z25RwTexDictionaryStreamReadP8RwStream(RwStream* stream);
    RwTexture* _Z31RwTexDictionaryFindNamedTextureP15RwTexDictionaryPKc(RwTexDictionary* dict, const char* name);
]]

local RSM = 3
local RSR = 1
local RID = 0x16

local LDR = getWorkingDirectory() .. '/loader/'
local CDR = getWorkingDirectory() .. '/config'
local CFL = CDR .. '/HUDchanger.json'
os.execute('mkdir -p "' .. LDR .. '"')
os.execute('mkdir -p "' .. CDR .. '"')

local FTX = { 'fist', 'siteM16', 'radardisc' }
local RDC = 144

local DNM = {
    fist    = 'fist icon',
    siteM16 = 'crosshair',
}

local TXL = {}
local KAL = {}

local function lcf()
    local res = { textures = {}, weaponIcons = {}, fontHud = {} }
    local fil = iox.open(CFL, "r")
    if not fil then return res end
    local cnt = fil:read("*a")
    fil:close()
    if not cnt or cnt == "" then return res end
    local okk, dat = pcall(jsn.decode, cnt)
    if not okk or not dat then return res end
    if dat.Textures then
        for _, itm in ipairs(dat.Textures) do
            res.textures[itm.name] = itm.selected
        end
    end
    if dat.WeaponIcons then
        for _, itm in ipairs(dat.WeaponIcons) do
            res.weaponIcons[itm.name] = itm.fname
        end
    end
    if dat.FontHud then
        for _, itm in ipairs(dat.FontHud) do
            res.fontHud[itm.name] = itm.fname
        end
    end
    return res
end

local SCF = lcf()

local RDL = {}
local MST = { name = 'map' }

local WIL = {}
local WST = { name = 'weapon icon' }

local FHL = {}
local FST = { name = 'font hud' }

local RDD = LDR .. 'map/'
os.execute('mkdir -p "' .. RDD .. '"')

local WID = LDR .. 'weapon icon/'
os.execute('mkdir -p "' .. WID .. '"')

local FHD = LDR .. 'font hud/'
os.execute('mkdir -p "' .. FHD .. '"')

local ORD = LDR .. 'original/'
os.execute('mkdir -p "' .. ORD .. '"')

local function scf()
    local otv = { Textures = {}, WeaponIcons = {}, FontHud = {} }
    for _, ent in ipairs(TXL) do
        table.insert(otv.Textures, {
            name     = ent.name,
            selected = ent.selectedPng,
        })
    end
    for _, ent in ipairs(WIL) do
        table.insert(otv.WeaponIcons, { name = ent.name, fname = ent.fname })
    end
    for _, ent in ipairs(FHL) do
        table.insert(otv.FontHud, { name = ent.name, fname = ent.fname })
    end
    local fil = iox.open(CFL, "w")
    if fil then
        fil:write(jsn.encode(otv, { indent = true }))
        fil:close()
        return true
    end
    return false
end

local function fex(pth)
    local fvr = iox.open(pth, 'rb')
    if fvr then fvr:close(); return true end
    return false
end

local function tdf(nam)
    return LDR .. nam .. '/'
end

local function shp(pth)
    if not pth then return pth end
    local idx = pth:find('/loader')
    if idx then return '/' .. pth:sub(idx) end
    return pth
end

local function fpd(dir)
    local lst = {}
    local okk, hdl = pcall(iox.popen, 'ls "' .. dir .. '" 2>/dev/null')
    if not okk or not hdl then return lst end
    for fnm in hdl:lines() do
        if fnm:match('%.png$') or fnm:match('%.PNG$') then
            table.insert(lst, fnm)
        end
    end
    hdl:close()
    return lst
end

local function sst(ent, okk, msg)
    ent.statusOk   = okk
    ent.statusMsg  = msg
    ent.statusTime = os.clock()
    if not okk then print('  ' .. ent.name .. ': ' .. msg) end
end

local function gtp(nam)
    local okk, fvl = pcall(function()
        return gta._Z13RwTextureReadPKcS0_(nam, nil)
    end)
    if not okk or fvl == nil then return nil end
    local okc, tpr = pcall(cst, 'RwTexture*', fvl)
    if not okc or tpr == nil then return nil end
    return tpr
end

local function ivt(nam)
    return gtp(nam) ~= nil
end

local function cor(nam)
    local tpr = gtp(nam)
    if not tpr then return nil end
    local okk, rst = pcall(function() return tpr.raster end)
    if okk then return rst end
    return nil
end

local function ltd(pth)
    local fvr = iox.open(pth, 'rb')
    if not fvr then return nil, 'txd not found: ' .. pth end
    local cnt = fvr:read('*a')
    fvr:close()

    if not cnt or #cnt < 12 then
        return nil, 'txd file too small'
    end

    local buf = ffi.new('uint8_t[?]', #cnt)
    ffi.copy(buf, cnt, #cnt)
    local rwm = ffi.new('RwMemory', { buf, #cnt })

    local stm = gta._Z12RwStreamOpen12RwStreamType18RwStreamAccessTypePKv(RSM, RSR, rwm)
    if stm == nil then return nil, 'RwStreamOpen failed' end

    local lgo = ffi.new('uint32_t[1]')
    local vro = ffi.new('uint32_t[1]')
    local fnd = gta._Z17RwStreamFindChunkP8RwStreamjPjS1_(stm, RID, lgo, vro)
    if not fnd then
        gta._Z13RwStreamCloseP8RwStreamPv(stm, nil)
        return nil, 'txd chunk 0x16 not found'
    end

    local dct = gta._Z25RwTexDictionaryStreamReadP8RwStream(stm)
    gta._Z13RwStreamCloseP8RwStreamPv(stm, nil)
    if dct == nil then return nil, 'RwTexDictionaryStreamRead failed' end

    return cst('RwTexDictionary*', dct), nil
end

local function fti(dct, nam)
    if dct == nil then return nil end
    local okk, tex = pcall(function()
        return gta._Z31RwTexDictionaryFindNamedTextureP15RwTexDictionaryPKc(dct, nam)
    end)
    if not okk or tex == nil then return nil end
    return cst('RwTexture*', tex)
end

local function lor(nam)
    local txp = ORD .. nam .. '.txd'
    if not fex(txp) then return nil, nil, 'original txd not found: ' .. shp(txp) end

    local dct, err = ltd(txp)
    if dct == nil then return nil, nil, err end

    local tex = fti(dct, nam)
    if tex == nil then return nil, dct, 'texture "' .. nam .. '" not found in original txd' end

    local okr, rst = pcall(function() return tex.raster end)
    if not okr or rst == nil then return nil, dct, 'failed to read raster from original txd' end

    return rst, dct, nil
end

local function are(ent)
    local txp = RDD .. ent.fname
    if not fex(txp) then
        ent.status = 'txd not found'
        return
    end

    local tpr = gtp(ent.name)
    if not tpr then
        ent.status = 'texture not found'
        return
    end

    if not ent.origRaster then
        local oko, orr = pcall(function() return tpr.raster end)
        if oko then ent.origRaster = orr end
    end

    local okd, dct, err = pcall(ltd, txp)
    if not okd or dct == nil then
        ent.status = err or 'failed to load txd'
        return
    end
    ent.dict = dct

    local okt, tex = pcall(fti, ent.dict, ent.name)
    if not okt or tex == nil then
        ent.status = 'texture "' .. ent.name .. '" not found in txd'
        return
    end

    local okr, rst = pcall(function() return tex.raster end)
    if not okr or rst == nil then
        ent.status = 'failed to read raster from txd'
        return
    end

    local oka = pcall(function() tpr.raster = rst end)
    if not oka then
        ent.status = 'assign failed'
        return
    end

    ent.enabled = true
    ent.status = 'applied'
end

local function rvr()
    for _, ent in ipairs(RDL) do
        local tpr = gtp(ent.name)
        if tpr then
            local rst, dct, err = lor(ent.name)
            if rst then
                pcall(function() tpr.raster = rst end)
                ent.origDict = dct
            elseif ent.origRaster then
                pcall(function() tpr.raster = ent.origRaster end)
            end
        end
    end
    RDL = {}
    sst(MST, true, 'reverted')
    scf()
end

local function rlr()
    local fnd = {}
    local okk, hdl = pcall(iox.popen, 'ls "' .. RDD .. '" 2>/dev/null')
    if not okk or not hdl then return end

    for fnm in hdl:lines() do
        local ids = fnm:match('^radar(%d+)%.txd$') or fnm:match('^radar(%d+)%.TXD$')
        if ids then
            local inm = tonumber(ids)
            if inm and inm >= 0 and inm < RDC then
                local nam = string.format('radar%02d', inm)
                fnd[nam] = fnm
            end
        end
    end
    hdl:close()

    local exs = {}
    for _, ent in ipairs(RDL) do exs[ent.name] = ent end

    for nam, fnm in pairs(fnd) do
        if ivt(nam) then
            local ent = exs[nam]
            if not ent then
                ent = { name = nam }
                table.insert(RDL, ent)
                exs[nam] = ent
            end
            ent.fname = fnm
            are(ent)
        end
    end

    for inm = #RDL, 1, -1 do
        if not fnd[RDL[inm].name] then
            table.remove(RDL, inm)
        end
    end

    table.sort(RDL, function(aav, bbv) return aav.name < bbv.name end)

    if #RDL > 0 then
        sst(MST, true, #RDL .. ' tiles loaded')
    else
        sst(MST, false, 'no txd found')
    end

    scf()
end

local function ref(ent)
    local dir = tdf(ent.name)
    os.execute('mkdir -p "' .. dir .. '"')

    ent.pngFiles = fpd(dir)
    ent.thumbTex = ent.thumbTex or {}

    for _, fnm in ipairs(ent.pngFiles) do
        if not ent.thumbTex[fnm] then
            local pth = dir .. fnm
            local okk, tex = pcall(renderLoadTextureFromFile, pth)
            if okk and tex then
                ent.thumbTex[fnm] = tex
                KAL[tex] = true
            end
        end
    end

    if #ent.pngFiles == 0 then
        sst(ent, false, 'no png')
    end

    if ent.selectedPng then
        local stx = false
        for _, fnm in ipairs(ent.pngFiles) do
            if fnm == ent.selectedPng then stx = true; break end
        end
        if not stx then ent.selectedPng = nil end
    end

    scf()
end

local function apt(ent)
    if not ent.selectedPng then
        sst(ent, false, 'no png selected')
        return
    end

    local dir = tdf(ent.name)
    local ppt = dir .. ent.selectedPng

    if not fex(ppt) then
        sst(ent, false, 'png not found: ' .. shp(ppt))
        return
    end

    local tpr = gtp(ent.name)
    if not tpr then
        sst(ent, false, 'invalid texture name: ' .. ent.name)
        return
    end

    if not ent.origRaster then
        local oko, orr = pcall(function() return tpr.raster end)
        if oko then ent.origRaster = orr end
    end

    local ntx = ent.thumbTex and ent.thumbTex[ent.selectedPng]
    if not ntx then
        local okt, ldd = pcall(renderLoadTextureFromFile, ppt)
        if not okt or not ldd then
            sst(ent, false, 'failed to load png: ' .. shp(ppt))
            return
        end
        ntx = ldd
        ent.thumbTex = ent.thumbTex or {}
        ent.thumbTex[ent.selectedPng] = ntx
    end
    KAL[ntx] = true

    local okr, nrs = pcall(function()
        return cst('RwTexture*', ntx).raster
    end)
    if not okr or nrs == nil then
        sst(ent, false, 'failed to read raster')
        return
    end

    local oka = pcall(function() tpr.raster = nrs end)
    if not oka then
        return
    end

    scf()
end

local function rvt(ent)
    local tpr = gtp(ent.name)
    if not tpr then
        sst(ent, false, 'invalid texture name: ' .. ent.name)
        return
    end

    local rst, dct, err = lor(ent.name)
    if rst then
        local oka = pcall(function() tpr.raster = rst end)
        if not oka then
            sst(ent, false, 'revert failed')
            return
        end
        ent.origDict = dct
        ent.selectedPng = nil
        sst(ent, true, 'reverted to original txd')
        scf()
        return
    end

    if ent.origRaster then
        local oka = pcall(function() tpr.raster = ent.origRaster end)
        if not oka then
            sst(ent, false, 'revert failed')
            return
        end
        ent.selectedPng = nil
        sst(ent, true, 'reverted (cached raster)')
        scf()
        return
    end

    sst(ent, false, err or 'no original source to revert')
end

local function ift()
    TXL = {}
    for _, nam in ipairs(FTX) do
        local ent = { name = nam, thumbTex = {} }

        local oko, org = pcall(cor, nam)
        if oko then ent.origRaster = org end

        ref(ent)

        local svs = SCF.textures[nam]
        if svs then
            for _, fnm in ipairs(ent.pngFiles or {}) do
                if fnm == svs then ent.selectedPng = svs; break end
            end
        end

        table.insert(TXL, ent)
        if ent.selectedPng then
            apt(ent)
        end

        wait(0)
    end
    scf()
end

local function fte(nam)
    for _, ent in ipairs(TXL) do
        if ent.name == nam then return ent end
    end
    return nil
end

local function awe(ent)
    local tpr = gtp(ent.name)
    if not tpr then
        ent.status = 'texture not found'
        return
    end

    if not ent.origRaster then
        local oko, orr = pcall(function() return tpr.raster end)
        if oko then ent.origRaster = orr end
    end

    if not ent.tex then
        local okt, ldd = pcall(renderLoadTextureFromFile, ent.path)
        if not okt or not ldd then
            ent.status = 'failed to load png'
            return
        end
        ent.tex = ldd
        KAL[ldd] = true
    end

    local okr, nrs = pcall(function()
        return cst('RwTexture*', ent.tex).raster
    end)
    if not okr or nrs == nil then
        ent.status = 'failed to read raster'
        return
    end

    local oka = pcall(function() tpr.raster = nrs end)
    if not oka then
        ent.status = 'assign failed'
        return
    end

    ent.enabled = true
    ent.status = 'applied'
end

local function rwi()
    for _, ent in ipairs(WIL) do
        local tpr = gtp(ent.name)
        if tpr then
            local rst, dct = lor(ent.name)
            if rst then
                pcall(function() tpr.raster = rst end)
                ent.origDict = dct
            elseif ent.origRaster then
                pcall(function() tpr.raster = ent.origRaster end)
            end
        end
    end
    WIL = {}
    sst(WST, true, 'reverted')
    scf()
end

local function rli()
    local pgf = fpd(WID)
    local fnd = {}
    for _, fnm in ipairs(pgf) do
        local nam = fnm:gsub('%.png$', ''):gsub('%.PNG$', '')
        fnd[nam] = fnm
    end

    local exs = {}
    for _, ent in ipairs(WIL) do exs[ent.name] = ent end

    for nam, fnm in pairs(fnd) do
        if ivt(nam) then
            local ent = exs[nam]
            if not ent then
                ent = { name = nam }
                table.insert(WIL, ent)
                exs[nam] = ent
            end
            ent.fname = fnm
            ent.path  = WID .. fnm
            ent.tex   = nil
            awe(ent)
        end
    end

    for inm = #WIL, 1, -1 do
        if not fnd[WIL[inm].name] then
            table.remove(WIL, inm)
        end
    end

    table.sort(WIL, function(aav, bbv) return aav.name < bbv.name end)

    if #WIL > 0 then
        sst(WST, true, #WIL .. ' icon applied')
    else
        sst(WST, false, 'no png found')
    end

    scf()
end

local function afh(ent)
    local tpr = gtp(ent.name)
    if not tpr then
        ent.status = 'texture not found'
        return
    end

    if not ent.origRaster then
        local oko, orr = pcall(function() return tpr.raster end)
        if oko then ent.origRaster = orr end
    end

    if not ent.tex then
        local okt, ldd = pcall(renderLoadTextureFromFile, ent.path)
        if not okt or not ldd then
            ent.status = 'failed to load png'
            return
        end
        ent.tex = ldd
        KAL[ldd] = true
    end

    local okr, nrs = pcall(function()
        return cst('RwTexture*', ent.tex).raster
    end)
    if not okr or nrs == nil then
        ent.status = 'failed to read raster'
        return
    end

    local oka = pcall(function() tpr.raster = nrs end)
    if not oka then
        ent.status = 'assign failed'
        return
    end

    ent.enabled = true
    ent.status = 'applied'
end

local function rfh()
    for _, ent in ipairs(FHL) do
        local tpr = gtp(ent.name)
        if tpr then
            local rst, dct = lor(ent.name)
            if rst then
                pcall(function() tpr.raster = rst end)
                ent.origDict = dct
            elseif ent.origRaster then
                pcall(function() tpr.raster = ent.origRaster end)
            end
        end
    end
    FHL = {}
    sst(FST, true, 'reverted')
    scf()
end

local function rlf()
    local pgf = fpd(FHD)
    local fnd = {}
    for _, fnm in ipairs(pgf) do
        local nam = fnm:gsub('%.png$', ''):gsub('%.PNG$', '')
        fnd[nam] = fnm
    end

    local exs = {}
    for _, ent in ipairs(FHL) do exs[ent.name] = ent end

    for nam, fnm in pairs(fnd) do
        if ivt(nam) then
            local ent = exs[nam]
            if not ent then
                ent = { name = nam }
                table.insert(FHL, ent)
                exs[nam] = ent
            end
            ent.fname = fnm
            ent.path  = FHD .. fnm
            ent.tex   = nil
            afh(ent)
        end
    end

    for inm = #FHL, 1, -1 do
        if not fnd[FHL[inm].name] then
            table.remove(FHL, inm)
        end
    end

    table.sort(FHL, function(aav, bbv) return aav.name < bbv.name end)

    if #FHL > 0 then
        sst(FST, true, #FHL .. ' font applied')
    else
        sst(FST, false, 'no png found')
    end

    scf()
end

local dpi = MONET_DPI_SCALE or 1
local MDS = dpi * 1.0

local WIW = 315 * MDS
local WIH = 300 * MDS

local COL = 5
local TGP = 9 * MDS
local TSZ = 48 * MDS

local ACC = uig.ImVec4(0.35, 0.55, 1.0, 1)
local ACD = uig.ImVec4(0.35, 0.55, 1.0, 0.35)
local BGD = uig.ImVec4(0.07, 0.08, 0.11, 0.97)
local BGC = uig.ImVec4(0.10, 0.11, 0.15, 1)
local BGH = uig.ImVec4(0.14, 0.16, 0.22, 1)
local BHH = uig.ImVec4(0.20, 0.24, 0.34, 1)

local function hdt()
    local sty = uig.GetStyle()

    sty.Alpha             = 1
    sty.WindowMinSize     = uig.ImVec2(32 * MDS, 32 * MDS)
    sty.WindowTitleAlign  = uig.ImVec2(0.5, 0.5)
    sty.ChildRounding     = 14 * MDS
    sty.ChildBorderSize   = 1 * MDS
    sty.PopupRounding     = 12 * MDS
    sty.PopupBorderSize   = 1 * MDS
    sty.FrameRounding     = 8 * MDS
    sty.FrameBorderSize   = 0 * MDS
    sty.GrabMinSize       = 10 * MDS
    sty.GrabRounding      = 6 * MDS
    sty.ScrollbarSize     = 15 * MDS
    sty.ScrollbarRounding = 10 * MDS
    sty.TabRounding       = 10 * MDS
end

uig.OnInitialize(function()
    local iov = uig.GetIO()
    local sty = uig.GetStyle()
    iov.IniFilename = nil
    iov.FontGlobalScale = MDS
    sty:ScaleAllSizes(MDS)
    hdt()
end)

local win = new.bool(false)

local function gts(tex)
    local okk, wdt, hgt = pcall(function() return tex:GetSize() end)
    if okk and wdt and hgt and wdt > 0 and hgt > 0 then return wdt, hgt end
    return nil, nil
end

local function dtb(idd, tex, ise)
    local dlt = uig.GetWindowDrawList()
    local scp = uig.GetCursorScreenPos()

    local bgc = ise and uig.ImVec4(ACC.x, ACC.y, ACC.z, 0.30)
                     or uig.ImVec4(1, 1, 1, 0.05)
    local bgv = uig.ColorConvertFloat4ToU32(bgc)
    dlt:AddRectFilled(
        scp,
        uig.ImVec2(scp.x + TSZ, scp.y + TSZ),
        bgv, 6 * MDS
    )

    local iwd, iht = gts(tex)
    local dwv, dhv = TSZ, TSZ
    if iwd and iht then
        local scl = math.min(TSZ / iwd, TSZ / iht)
        dwv, dhv = iwd * scl, iht * scl
    end
    local ofx = (TSZ - dwv) / 2
    local ofy = (TSZ - dhv) / 2
    local imn = uig.ImVec2(scp.x + ofx, scp.y + ofy)
    local imx = uig.ImVec2(imn.x + dwv, imn.y + dhv)
    dlt:AddImage(tex, imn, imx)

    return uig.InvisibleButton(idd, uig.ImVec2(TSZ, TSZ))
end

local function dte(ent, idx, dfo)
    local dnv = DNM[ent.name] or ent.name
    local flg = dfo and uig.TreeNodeFlags.DefaultOpen or 0
    if uig.CollapsingHeader((dnv .. '##' .. idx), flg) then
        uig.TextDisabled(shp(tdf(ent.name)))

        if ent.statusMsg and os.clock() - (ent.statusTime or 0) < 4 then
            local col = ent.statusOk and uig.ImVec4(0.4, 0.9, 0.5, 1) or uig.ImVec4(1, 0.45, 0.45, 1)
            uig.TextColored(col, ent.statusMsg)
        end

        if ent.pngFiles and #ent.pngFiles > 0 then
            for inr, fnm in ipairs(ent.pngFiles) do
                local ise = (fnm == ent.selectedPng)
                local tex = ent.thumbTex[fnm]

                if tex then
                    if dtb(('##thumb%d_%d'):format(idx, inr), tex, ise) then
                        ent.selectedPng = fnm
                        apt(ent)
                    end

                    if (inr % COL) ~= 0 and inr ~= #ent.pngFiles then
                        uig.SameLine(0, TGP)
                    end
                end
            end
        else
            uig.TextDisabled('no png yet')
        end

        if uig.Button('reload texture##' .. idx) then
            ref(ent)
        end
        uig.SameLine()
        if uig.Button('reset##' .. idx) then rvt(ent) end
    end
end

local function dms()
    if uig.CollapsingHeader('radar map') then
        uig.TextDisabled(shp(RDD))
        if uig.IsItemHovered() then
            uig.SetTooltip('place radar0.txd to radar143.txd inside the loader/map folder, then press load')
        end

        if MST.statusMsg and os.clock() - (MST.statusTime or 0) < 4 then
            local col = MST.statusOk and uig.ImVec4(0.4, 0.9, 0.5, 1) or uig.ImVec4(1, 0.45, 0.45, 1)
            uig.TextColored(col, MST.statusMsg)
        end

        if uig.Button('load texture##map') then
            rlr()
        end
        uig.SameLine()
        if uig.Button('reset##map') then rvr() end
    end
end

local function dwi()
    if uig.CollapsingHeader('weapon icon') then
        uig.TextDisabled(shp(WID))
        if uig.IsItemHovered() then
            uig.SetTooltip('put pngs named exactly like the ingame texture inside this folder, then press load')
        end

        if WST.statusMsg and os.clock() - (WST.statusTime or 0) < 4 then
            local col = WST.statusOk and uig.ImVec4(0.4, 0.9, 0.5, 1) or uig.ImVec4(1, 0.45, 0.45, 1)
            uig.TextColored(col, WST.statusMsg)
        end

        if uig.Button('load texture##wicon') then
            rli()
        end
        uig.SameLine()
        if uig.Button('reset##wicon') then rwi() end
    end
end

local function dfh()
    if uig.CollapsingHeader('font hud') then
        uig.TextDisabled(shp(FHD))
        if uig.IsItemHovered() then
            uig.SetTooltip('put pngs named font1 / font2 inside this folder, then press load')
        end

        if FST.statusMsg and os.clock() - (FST.statusTime or 0) < 4 then
            local col = FST.statusOk and uig.ImVec4(0.4, 0.9, 0.5, 1) or uig.ImVec4(1, 0.45, 0.45, 1)
            uig.TextColored(col, FST.statusMsg)
        end

        if uig.Button('load texture##fhud') then
            rlf()
        end
        uig.SameLine()
        if uig.Button('reset##fhud') then rfh() end
    end
end

local WFL = uig.WindowFlags.NoCollapse
          + uig.WindowFlags.NoResize
          + uig.WindowFlags.NoScrollbar
          + uig.WindowFlags.NoScrollWithMouse

uig.OnFrame(function() return win[0] end, function()
    uig.SetNextWindowSize(uig.ImVec2(WIW, WIH), uig.Cond.Always)

    if uig.Begin('Deprau - Hud Changer', win, WFL) then
        if uig.BeginChild('##HudList', uig.ImVec2(0, 0), true) then
            local fsw = fte('fist')
            if fsw then dte(fsw, 1, true) end

            dwi()

            local smx = fte('siteM16')
            if smx then dte(smx, 3) end

            local rdx = fte('radardisc')
            if rdx then dte(rdx, 2) end

            dms()
            dfh()
        end
        uig.EndChild()
    end
    uig.End()
end)

function main()
    rli()
    ift()
    rli()
    rlf()
    rlr()
    wait(2000)
    rli()

    sampRegisterChatCommand('hudc', function()
        win[0] = not win[0]
    end)

    wait(0)
end
