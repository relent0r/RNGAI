
--[[
    This started as all Softles, I wouldnt even pretend to understand it. It uses his FlowAI framework with some changes for my AI.

    This code is largely written with performance in mind over readability.
    The justification in this case is that it represents a significant amount of work, and necessarily runs before the game starts.
    Every second here is a second the players are waiting to play.
    Previous iterations of this functionality ran in ~1 min timescales on 20x20 maps, necessitating a performance oriented re-write.
    Sorry for the inlining of functions, the repetitive code blocks, and the constant localling of variables :)
  ]]
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')

local CreatePriorityQueue = import('/mods/RNGAI/lua/FlowAI/framework/utils/PriorityQueue.lua').CreatePriorityQueue
local DEFAULT_BORDER = 4
local PLAYABLE_AREA = nil
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG
function SetPlayableArea(x0,z0,x1,z1)
    -- Fields of Isis is a bad map, I hate to be the one who has to say it.
    PLAYABLE_AREA = { x0, z0, x1, z1 }
end

local AdaptiveResourceMarkerTableRNG = {}
local TARGET_MARKERS = 120000
local MIN_GAP = 5
local MAX_GRADIENT = 0.5
-- Ship and submarine clearance seem to both be for the same depths...
local SHIP_CLEARANCE = 1.5

local SQRT_2 = math.sqrt(2)

-- Changes here are not recommended (for compatibility reasons)
local LAYER_NONE = -1
local LAYER_AIR = 0
local LAYER_LAND = 1
local LAYER_NAVY = 2
local LAYER_HOVER = 3
local LAYER_AMPH = 4

local NUM_LAYERS = 4

-- Land
local function CheckLandConnectivity0(x,z,gap)
    local gMax = MAX_GRADIENT
    if GetTerrainHeight(x,z) < GetSurfaceHeight(x,z) then
        return false
    end
    for d = 1, gap do
        local g = (GetTerrainHeight(x+d-1,z) - GetTerrainHeight(x+d,z))
        if -gMax > g or g > gMax then
            return false
        end
        if GetTerrainHeight(x+d-1,z) < GetSurfaceHeight(x+d-1,z) then
            return false
        end
    end
    for d = 1, gap-1 do
        local g = (GetTerrainHeight(x+d,z) - GetTerrainHeight(x+d,z+1))
        if -gMax > g or g > gMax then
            return false
        end
        local g = (GetTerrainHeight(x+d,z) - GetTerrainHeight(x+d,z-1))
        if -gMax > g or g > gMax then
            return false
        end
    end
    return true
end
local function CheckLandConnectivity1(x,z,gap)
    local gMax = MAX_GRADIENT
    if GetTerrainHeight(x,z) < GetSurfaceHeight(x,z) then
        return false
    end
    for d = 1, gap do
        local g = (GetTerrainHeight(x,z+d-1) - GetTerrainHeight(x,z+d))
        if -gMax > g or g > gMax then
            return false
        end
        if GetTerrainHeight(x,z+d-1) < GetSurfaceHeight(x,z+d-1) then
            return false
        end
    end
    for d = 1, gap-1 do
        local g = (GetTerrainHeight(x,z+d) - GetTerrainHeight(x+1,z+d))
        if -gMax > g or g > gMax then
            return false
        end
        local g = (GetTerrainHeight(x,z+d) - GetTerrainHeight(x-1,z+d))
        if -gMax > g or g > gMax then
            return false
        end
    end
    return true
end
-- Naval / water surface
local function CheckNavalConnectivity0(x,z,gap)
    if GetTerrainHeight(x,z) >= GetSurfaceHeight(x,z)-SHIP_CLEARANCE then
        return false
    end
    for d = 1, gap do
        -- No need for gradient checks
        if GetTerrainHeight(x+d-1,z) >= GetSurfaceHeight(x+d-1,z)-SHIP_CLEARANCE then
            return false
        end
    end
    return true
end
local function CheckNavalConnectivity1(x,z,gap)
    if GetTerrainHeight(x,z) >= GetSurfaceHeight(x,z)-SHIP_CLEARANCE then
        return false
    end
    for d = 1, gap do
        -- No need for gradient checks
        if GetTerrainHeight(x,z+d-1) >= GetSurfaceHeight(x,z+d-1)-SHIP_CLEARANCE then
            return false
        end
    end
    return true
end
-- Hover
local function CheckHoverConnectivity0(x,z,gap)
    local gMax = MAX_GRADIENT
    for d = 1, gap do
        local g = (GetSurfaceHeight(x+d-1,z) - GetSurfaceHeight(x+d,z))
        if -gMax > g or g > gMax then
            return false
        end
    end
    for d = 1, gap-1 do
        local g = (GetSurfaceHeight(x+d,z) - GetSurfaceHeight(x+d,z+1))
        if -gMax > g or g > gMax then
            return false
        end
        local g = (GetSurfaceHeight(x+d,z) - GetSurfaceHeight(x+d,z-1))
        if -gMax > g or g > gMax then
            return false
        end
    end
    return true
end
local function CheckHoverConnectivity1(x,z,gap)
    local gMax = MAX_GRADIENT
    for d = 1, gap do
        local g = (GetSurfaceHeight(x,z+d-1) - GetSurfaceHeight(x,z+d))
        if -gMax > g or g > gMax then
            return false
        end
    end
    for d = 1, gap-1 do
        local g = (GetSurfaceHeight(x,z+d) - GetSurfaceHeight(x+1,z+d))
        if -gMax > g or g > gMax then
            return false
        end
        local g = (GetSurfaceHeight(x,z+d) - GetSurfaceHeight(x-1,z+d))
        if -gMax > g or g > gMax then
            return false
        end
    end
    return true
end
-- Amphibious
local function CheckAmphibiousConnectivity0(x,z,gap)
    local gMax = MAX_GRADIENT
    for d = 1, gap do
        local g = (GetTerrainHeight(x+d-1,z) - GetTerrainHeight(x+d,z))
        if -gMax > g or g > gMax then
            return false
        end
    end
    for d = 1, gap-1 do
        local g = (GetTerrainHeight(x+d,z) - GetTerrainHeight(x+d,z+1))
        if -gMax > g or g > gMax then
            return false
        end
        local g = (GetTerrainHeight(x+d,z) - GetTerrainHeight(x+d,z-1))
        if -gMax > g or g > gMax then
            return false
        end
    end
    return true
end
local function CheckAmphibiousConnectivity1(x,z,gap)
    local gMax = MAX_GRADIENT
    for d = 1, gap do
        local g = (GetTerrainHeight(x,z+d-1) - GetTerrainHeight(x,z+d))
        if -gMax > g or g > gMax then
            return false
        end
    end
    for d = 1, gap-1 do
        local g = (GetTerrainHeight(x,z+d) - GetTerrainHeight(x+1,z+d))
        if -gMax > g or g > gMax then
            return false
        end
        local g = (GetTerrainHeight(x,z+d) - GetTerrainHeight(x-1,z+d))
        if -gMax > g or g > gMax then
            return false
        end
    end
    return true
end

GameMap = Class({
    InitMap = function(self)
        LOG('FlowAI framework: CreateMapMarkers() started!')
        local START = GetSystemTimeSecondsOnlyForProfileUse()
        self:CreateMapMarkers()
        self.zoneSets = {}
        self.numZoneSets = 0
        local END = GetSystemTimeSecondsOnlyForProfileUse()
        LOG(string.format('FlowAI framework: CreateMapMarkers() finished, runtime: %.2f seconds.', END - START ))
        local drawStuffz = false
        if drawStuffz then
            ForkThread(
                function()
                    local zoneSetCopy = self:GetZoneSet('RNGNavalResourceSet',2)
                    coroutine.yield(100)
                    while true do
                        --self:DrawLayer(2)
                        self:DrawZones(zoneSetCopy.index)
                        --zoneSetCopy:DrawZones()
                        WaitTicks(2)
                    end
                end
            )
        end
    end,

    CreateMapMarkers = function(self)
        -- Step 1: Initialise arrays of points to the correct size, and record offsets for position translation
        local area = (PLAYABLE_AREA[3]-PLAYABLE_AREA[1]) * (PLAYABLE_AREA[4]-PLAYABLE_AREA[2])
        self.gap = math.max(MIN_GAP,math.ceil(math.sqrt(area/TARGET_MARKERS)))
        self.markers = {}
        self.components = {}
        self.componentNumbers = { 0, 0, 0, 0 }
        self.componentSizes = { {}, {}, {}, {} }
        self.zones = {}
        self.xSize = math.floor((PLAYABLE_AREA[3]-PLAYABLE_AREA[1])/self.gap)
        self.zSize = math.floor((PLAYABLE_AREA[4]-PLAYABLE_AREA[2])/self.gap)
        for i = 1, self.xSize do
            self.markers[i] = {}
            self.components[i] = {}
            self.zones[i] = {}
            for j = 1, self.zSize do
                -- [(+1,0), (+1,+1), (0,+1), (-1,+1), (-1,0), (-1,-1), (0,-1), (+1,-1)]
                self.markers[i][j] = {
                    { false, false, false, false, false, false, false, false }, -- Land
                    { false, false, false, false, false, false, false, false }, -- Navy
                    { false, false, false, false, false, false, false, false }, -- Hover
                    { false, false, false, false, false, false, false, false }, -- Amphibious
                }
                -- [Land, Navy, Hover, Amphibious]
                self.components[i][j] = { 0, 0, 0, 0 }
                self.zones[i][j] = {}
            end
        end
        -- Step 2: Generate connections
        self:GenerateConnections()
        -- Step 3: Generate connected components
        self:GenerateConnectedComponents()
    end,
    GenerateConnections = function(self)
        local markers = self.markers
        local gap = self.gap
        local x0 = PLAYABLE_AREA[1]
        local z0 = PLAYABLE_AREA[2]
        local CLC0 = CheckLandConnectivity0
        local CLC1 = CheckLandConnectivity1
        local CNC0 = CheckNavalConnectivity0
        local CNC1 = CheckNavalConnectivity1
        local CHC0 = CheckHoverConnectivity0
        local CHC1 = CheckHoverConnectivity1
        local CAC0 = CheckAmphibiousConnectivity0
        local CAC1 = CheckAmphibiousConnectivity1
        -- Declare some variables now that we'll need later, save us creating lots of little local variables.
        local x = 0
        local z = 0
        local _mi = nil
        local _mi1 = nil
        local _mij = nil
        local _mi1j = nil
        local _mij1 = nil
        local _mi1j1 = nil
        local land = false
        local navy = false
        local hover = false
        local amph = false
        -- [(+1, 0), (-1, 0)]
        for i = 1, self.xSize-1 do
            x = x0 - gap + i*gap
            _mi = markers[i]
            _mi1 = markers[i+1]
            for j = 1, self.zSize do
                _mij = _mi[j]
                _mi1j = _mi1[j]
                z = z0 - gap + j*gap
                land = CLC0(x,z,gap)
                navy = CNC0(x,z,gap)
                hover = CHC0(x,z,gap)
                amph = CAC0(x,z,gap)
                _mij[LAYER_LAND][1] = land
                _mi1j[LAYER_LAND][5] = land
                _mij[LAYER_NAVY][1] = navy
                _mi1j[LAYER_NAVY][5] = navy
                _mij[LAYER_HOVER][1] = hover
                _mi1j[LAYER_HOVER][5] = hover
                _mij[LAYER_AMPH][1] = amph
                _mi1j[LAYER_AMPH][5] = amph
            end
        end
        -- [(0, +1), (0,-1)]
        for i = 1, self.xSize do
            x = x0 - gap + i*gap
            _mi = markers[i]
            for j = 1, self.zSize-1 do
                _mij = _mi[j]
                _mij1 = _mi[j+1]
                z = z0 - gap + j*gap
                land = CLC1(x,z,gap)
                navy = CNC1(x,z,gap)
                hover = CHC1(x,z,gap)
                amph = CAC1(x,z,gap)
                _mij[LAYER_LAND][3] = land
                _mij1[LAYER_LAND][7] = land
                _mij[LAYER_NAVY][3] = navy
                _mij1[LAYER_NAVY][7] = navy
                _mij[LAYER_HOVER][3] = hover
                _mij1[LAYER_HOVER][7] = hover
                _mij[LAYER_AMPH][3] = amph
                _mij1[LAYER_AMPH][7] = amph
            end
        end
        -- [(+1, -1), (-1, +1)]
        for i = 1, self.xSize-1 do
            _mi = markers[i]
            _mi1 = markers[i+1]
            for j = 2, self.zSize do
                _mij = _mi[j]
                _mi1j = _mi1[j]
                _mij1 = _mi[j-1]
                _mi1j1 = _mi1[j-1]
                land = _mij[LAYER_LAND][1] and _mij[LAYER_LAND][7] and _mi1j[LAYER_LAND][7] and _mij1[LAYER_LAND][1]
                navy = _mij[LAYER_NAVY][1] and _mij[LAYER_NAVY][7] and _mi1j[LAYER_NAVY][7] and _mij1[LAYER_NAVY][1]
                hover = _mij[LAYER_HOVER][1] and _mij[LAYER_HOVER][7] and _mi1j[LAYER_HOVER][7] and _mij1[LAYER_HOVER][1]
                amph = _mij[LAYER_AMPH][1] and _mij[LAYER_AMPH][7] and _mi1j[LAYER_AMPH][7] and _mij1[LAYER_AMPH][1]
                _mij[LAYER_LAND][8] = land
                _mi1j1[LAYER_LAND][4] = land
                _mij[LAYER_NAVY][8] = navy
                _mi1j1[LAYER_NAVY][4] = navy
                _mij[LAYER_HOVER][8] = hover
                _mi1j1[LAYER_HOVER][4] = hover
                _mij[LAYER_AMPH][8] = amph
                _mi1j1[LAYER_AMPH][4] = amph
            end
        end
        -- [(+1, +1), (-1, -1)]
        for i = 1, self.xSize-1 do
            _mi = markers[i]
            _mi1 = markers[i+1]
            for j = 1, self.zSize-1 do
                _mij = _mi[j]
                _mi1j = _mi1[j]
                _mij1 = _mi[j+1]
                _mi1j1 = _mi1[j+1]
                land = _mij[LAYER_LAND][1] and _mij[LAYER_LAND][3] and _mi1j[LAYER_LAND][3] and _mij1[LAYER_LAND][1]
                navy = _mij[LAYER_NAVY][1] and _mij[LAYER_NAVY][3] and _mi1j[LAYER_NAVY][3] and _mij1[LAYER_NAVY][1]
                hover = _mij[LAYER_HOVER][1] and _mij[LAYER_HOVER][3] and _mi1j[LAYER_HOVER][3] and _mij1[LAYER_HOVER][1]
                amph = _mij[LAYER_AMPH][1] and _mij[LAYER_AMPH][3] and _mi1j[LAYER_AMPH][3] and _mij1[LAYER_AMPH][1]
                _mij[LAYER_LAND][2] = land
                _mi1j1[LAYER_LAND][6] = land
                _mij[LAYER_NAVY][2] = navy
                _mi1j1[LAYER_NAVY][6] = navy
                _mij[LAYER_HOVER][2] = hover
                _mi1j1[LAYER_HOVER][6] = hover
                _mij[LAYER_AMPH][2] = amph
                _mi1j1[LAYER_AMPH][6] = amph
            end
        end
    end,
    GenerateConnectedComponents = function(self)
        local markers = self.markers
        -- Initialise markers that have at least one connection.  Unitialised markers have component 0, which we will ignore later.
        for i = 1, self.xSize do
            local _mi = markers[i]
            for j = 1, self.zSize do
                local _mij = _mi[j]
                for k = 1, NUM_LAYERS do
                    local _mijk = _mij[k]
                    -- Init if a connection exists
                    if _mijk[1] or _mijk[2] or _mijk[3] or _mijk[4] or _mijk[5] or _mijk[6] or _mijk[7] or _mijk[8] then
                        self.components[i][j][k] = -1
                    end
                end
            end
        end
        -- Generate a component for each uninitialised marker
        for i = 1, self.xSize do
            for j = 1, self.zSize do
                for k = 1, NUM_LAYERS do
                    if self.components[i][j][k] < 0 then
                        self.componentNumbers[k] = self.componentNumbers[k]+1
                        self.componentSizes[k][self.componentNumbers[k]] = 0
                        self:GenerateComponent(i,j,k,self.componentNumbers[k])
                    end
                end
            end
        end
    end,
    GenerateComponent = function(self,i0,j0,k,componentNumber)
        local work = {{i0,j0}}
        local workLen = 1
        local i = 0
        local j = 0
        local _mij = nil
        self.components[i0][j0][k] = componentNumber
        self.componentSizes[k][componentNumber] = self.componentSizes[k][componentNumber] + 1
        while workLen > 0 do
            i = work[workLen][1]
            j = work[workLen][2]
            workLen = workLen-1
            _mij = self.markers[i][j][k]
            -- Since diagonal connections are purely derived from square connections, I won't bother with them for component generation
            if _mij[1] and (self.components[i+1][j][k] < 0) then
                workLen = workLen+1
                work[workLen] = {i+1,j}
                self.componentSizes[k][componentNumber] = self.componentSizes[k][componentNumber] + 1
                self.components[i+1][j][k] = componentNumber
            end
            if _mij[3] and (self.components[i][j+1][k] < 0) then
                workLen = workLen+1
                work[workLen] = {i,j+1}
                self.componentSizes[k][componentNumber] = self.componentSizes[k][componentNumber] + 1
                self.components[i][j+1][k] = componentNumber
            end
            if _mij[5] and (self.components[i-1][j][k] < 0) then
                workLen = workLen+1
                work[workLen] = {i-1,j}
                self.componentSizes[k][componentNumber] = self.componentSizes[k][componentNumber] + 1
                self.components[i-1][j][k] = componentNumber
            end
            if _mij[7] and (self.components[i][j-1][k] < 0) then
                workLen = workLen+1
                work[workLen] = {i,j-1}
                self.componentSizes[k][componentNumber] = self.componentSizes[k][componentNumber] + 1
                self.components[i][j-1][k] = componentNumber
            end
        end
    end,
    CanPathTo = function(self,pos0,pos1,layer)
        local i0 = self:GetI(pos0[1])
        local j0 = self:GetJ(pos0[3])
        local i1 = self:GetI(pos1[1])
        local j1 = self:GetJ(pos1[3])
        --[[if (self.components[i0][j0][layer] > 0) and (self.components[i0][j0][layer] == self.components[i1][j1][layer]) then
            LOG('CanPathTo is true for layer '..layer)
        else
            LOG('CanPathTo is false for layer '..layer)
            LOG(' pos0 '..repr(pos0))
            LOG(' pos1 '..repr(pos1))
        end]]
        return (self.components[i0][j0][layer] > 0) and (self.components[i0][j0][layer] == self.components[i1][j1][layer])
    end,
    ToPathOrNotToPath = function(self,pos0,pos1,layer)
        --[[
            Like CanPathTo, but with a better name, and also handles certain cases better (drawback: slightly more expensive).
            In particular, this function doesn't just check the closest grid point to each pos, but also around each pos in case it is near a pathing boundary.
        ]]
        local i0 = math.min(math.max(self:GetI(pos0[1]),2),self.xSize-1)
        local j0 = math.min(math.max(self:GetJ(pos0[3]),2),self.zSize-1)
        local i1 = math.min(math.max(self:GetI(pos0[1]),2),self.xSize-1)
        local j1 = math.min(math.max(self:GetJ(pos0[3]),2),self.zSize-1)
        local pos0Components = {
            self.components[i0-1][j0+1][layer], self.components[i0][j0+1][layer], self.components[i0+1][j0+1][layer],
            self.components[i0-1][j0][layer],   self.components[i0][j0][layer],   self.components[i0+1][j0][layer],
            self.components[i0-1][j0-1][layer], self.components[i0][j0-1][layer], self.components[i0+1][j0-1][layer]
        }
        local pos1Components = {
            self.components[i1-1][j1+1][layer], self.components[i1][j1+1][layer], self.components[i1+1][j1+1][layer],
            self.components[i1-1][j1][layer],   self.components[i1][j1][layer],   self.components[i1+1][j1][layer],
            self.components[i1-1][j1-1][layer], self.components[i1][j1-1][layer], self.components[i1+1][j1-1][layer]
        }
        for i = 1, 9 do
            if pos0Components[i] < 0 then
                continue
            end
            for j = 1, 9 do
                if pos1Components[j] < 0 then
                    continue
                end
                if pos0Components[i] == pos1Components[j] then
                    return true
                end
            end
        end
        LOG('CanPathTo is false for layer '..layer)
        LOG(' pos0 '..repr(pos0))
        LOG(' pos1 '..repr(pos1))
        return false
    end,
    UnitCanPathTo = function(self,unit,pos)
        local layer = self:TranslateMovementLayer(unit:GetBlueprint().Physics.MotionType)
        if layer == LAYER_NONE then
            return false
        elseif layer == LAYER_AIR then
            return true
        else
            local unitPos = unit:GetPosition()
            return self:CanPathTo(unitPos,pos,layer)
        end
    end,
    HomieCanPathTo = function(self,unit,pos)
        local layer = self:TranslateMovementLayer(unit:GetBlueprint().Physics.MotionType)
        if layer == LAYER_NONE then
            return false
        elseif layer == LAYER_AIR then
            return true
        else
            local unitPos = unit:GetPosition()
            return self:ToPathOrNotToPath(unitPos,pos,layer)
        end
    end,
    GetMovementLayer = function(self,unit)
        return self:TranslateMovementLayer(unit:GetBlueprint().Physics.MotionType)
    end,
    TranslateMovementLayer = function(self,motionType)
        -- -1 => cannot move, 0 => air unit, otherwise chooses best matching layer index
        if (not motionType) or motionType == "RULEUMT_None" then
            return LAYER_NONE
        elseif motionType == "RULEUMT_Air" then
            return LAYER_AIR
        elseif motionType == "RULEUMT_Land" then
            return LAYER_LAND
        elseif motionType == "RULEUMT_Water" then
            return LAYER_NAVY
        elseif (motionType == "RULEUMT_Hover") or (motionType == "RULEUMT_AmphibiousFloating") then
            return LAYER_HOVER
        elseif motionType == "RULEUMT_Amphibious" then
            return LAYER_AMPH
        elseif motionType == "RULEUMT_SurfacingSub" then
            -- Use navy layer since required required water clearance is the same
            return LAYER_NAVY
        else
            WARN("Unknown layer type found in map:TranslateMovementLayer - "..tostring(motionType))
            return LAYER_NONE
        end
    end,
    GetMostRestrictiveMovementLayer = function(self, layer0, layer1)
        local minLayer = math.min(layer0, layer1)
        layer1 = math.max(layer0, layer1)
        if minLayer == LAYER_NONE then
            -- Something cannot move, so return that it cannot move
            return LAYER_NONE
        elseif minLayer == LAYER_AIR then
            -- Something is an air unit, so return the other movement layer
            return layer1
        elseif minLayer == LAYER_LAND then
            if layer1 == LAYER_NAVY then
                -- Land unit and naval unit, cannot move together
                return LAYER_NONE
            else
                -- Land unit and one of {land, hover, amphibous}, return land
                return LAYER_LAND
            end
        elseif minLayer == LAYER_NAVY then
            -- Combination of navy and one of {hover, amphibious}, return navy
            -- NOTE: POTENTIAL BUG HERE - amphibious + navy is being treated as navy, but amphibious units (seafloor units) might not be able to go to all navy areas due to terrain.
            -- Doesn't make sense to solve this by having a separate amphibious + water layer, nor does it make sense to return LAYER_NONE.
            return LAYER_NAVY
        else
            -- layers are both from {hover, amph}, return the larger
            return layer1
        end
    end,
    GetComponent = function(self,pos,layer)
        local i = self:GetI(pos[1])
        local j = self:GetJ(pos[3])
        return self.components[i][j][layer]
    end,
    GetComponentSize = function(self,component,layer)
        if component > 0 then
            return self.componentSizes[layer][component]
        else
            return 0
        end
    end,
    PaintZones = function(self,zoneList,index,layer)
        local edges = {}
        for i = 1, self.xSize do
            for j = 1, self.zSize do
                self.zones[i][j][index] = {-1,0}
            end
        end
        local work = CreatePriorityQueue()
        for _, zone in zoneList do
            local i = self:GetI(zone.pos[1])
            local j = self:GetJ(zone.pos[3])
            if self.components[i][j][layer] > 0 then
                work:Queue({priority=0, id=zone.id, i=i, j=j})
                zone.fail = false
            else
                zone.fail = true
            end
            edges[zone.id] = {}
        end
        while work:Size() > 0 do
            local item = work:Dequeue()
            local i = item.i
            local j = item.j
            local id = item.id
            if self.zones[i][j][index][1] < 0 then
                -- Update and iterate
                self.zones[i][j][index][1] = item.id
                self.zones[i][j][index][2] = item.priority
                if self.markers[i][j][layer][1] then
                    work:Queue({priority=item.priority+1,i=i+1,j=j,id=id})
                end
                if self.markers[i][j][layer][2] then
                    work:Queue({priority=item.priority+SQRT_2,i=i+1,j=j+1,id=id})
                end
                if self.markers[i][j][layer][3] then
                    work:Queue({priority=item.priority+1,i=i,j=j+1,id=id})
                end
                if self.markers[i][j][layer][4] then
                    work:Queue({priority=item.priority+SQRT_2,i=i-1,j=j+1,id=id})
                end
                if self.markers[i][j][layer][5] then
                    work:Queue({priority=item.priority+1,i=i-1,j=j,id=id})
                end
                if self.markers[i][j][layer][6] then
                    work:Queue({priority=item.priority+SQRT_2,i=i-1,j=j-1,id=id})
                end
                if self.markers[i][j][layer][7] then
                    work:Queue({priority=item.priority+1,i=i,j=j-1,id=id})
                end
                if self.markers[i][j][layer][8] then
                    work:Queue({priority=item.priority+SQRT_2,i=i+1,j=j-1,id=id})
                end
            elseif self.zones[i][j][index][1] ~= id then
                -- Add edge
                local dist = item.priority+self.zones[i][j][index][2]
                if not edges[self.zones[i][j][index][1]][id] then
                    edges[self.zones[i][j][index][1]][id] = {0, dist, i, j}
                    edges[id][self.zones[i][j][index][1]] = {0, dist, i, j}
                end
                edges[self.zones[i][j][index][1]][id][1] = edges[self.zones[i][j][index][1]][id][1] + 1
                edges[id][self.zones[i][j][index][1]][1] = edges[id][self.zones[i][j][index][1]][1] + 1
                if dist < edges[self.zones[i][j][index][1]][id][2] then
                    edges[self.zones[i][j][index][1]][id][2] = dist
                    edges[self.zones[i][j][index][1]][id][3] = i
                    edges[self.zones[i][j][index][1]][id][4] = j
                    edges[id][self.zones[i][j][index][1]][2] = dist
                    edges[id][self.zones[i][j][index][1]][3] = i
                    edges[id][self.zones[i][j][index][1]][4] = j
                end
            end
        end
        local edgeList = {}
        for id0, v0 in edges do
            for id1, v1 in v0 do
                if id0 < id1 then
                    local x = self:GetX(v1[3])
                    local z = self:GetZ(v1[4])
                    local y = nil
                    if layer < 4 then
                        y = GetSurfaceHeight(x,z)
                    else
                        y = GetTerrainHeight(x,z)
                    end
                    table.insert(edgeList,{zones={id0,id1},border=v1[1],distance=v1[2],midpoint={x, y, z}})
                end
            end
        end
        return edgeList
    end,
    GetZoneID = function(self,pos,index)
        local i = self:GetI(pos[1])
        local j = self:GetJ(pos[3])
        return self.zones[i][j][index][1]
    end,
    AddZoneSet = function(self,ZoneSetClass)
        self.numZoneSets = self.numZoneSets + 1
        local zoneSet = ZoneSetClass()
        zoneSet:Init(self.numZoneSets)
        zoneSet:GenerateZoneList()
        self.zoneSets[self.numZoneSets] = zoneSet
        local zones = zoneSet:GetZones()
        local edges = self:PaintZones(zones,self.numZoneSets,zoneSet.layer)
        zoneSet:AddEdges(edges)
        return self.numZoneSets
    end,
    GetZoneSet = function(self, name, layer)
        for _, zoneSet in self.zoneSets do
            if (zoneSet.name == name) and (zoneSet.layer == layer) then
                return self.zoneSets[zoneSet.index]:GetCopy()
            end
        end
        return nil
    end,
    GetZoneSetIndex = function(name, layer)
        for _, zoneSet in self.zoneSets do
            if (zoneSet.name == name) and (zoneSet.layer == layer) then
                return zoneSet.index
            end
        end
        return nil
    end,
    GetI = function(self,x)
        return math.min(math.max(math.floor((x - PLAYABLE_AREA[1])/self.gap + 1.5),1),self.xSize)
    end,
    GetJ = function(self,z)
        return math.min(math.max(math.floor((z - PLAYABLE_AREA[2])/self.gap + 1.5),1),self.zSize)
    end,
    GetX = function(self,i)
        return PLAYABLE_AREA[1] - self.gap + (i*self.gap)
    end,
    GetZ = function(self,j)
        return PLAYABLE_AREA[2] - self.gap + (j*self.gap)
    end,

    DrawZones = function(self,index)
        local colours = { 'aa1f77b4', 'aaff7f0e', 'aa2ca02c', 'aad62728', 'aa9467bd', 'aa8c564b', 'aae377c2', 'aa7f7f7f', 'aabcbd22', 'aa17becf' }
        local gap = self.gap
        local x0 = PLAYABLE_AREA[1] - gap
        local z0 = PLAYABLE_AREA[2] - gap
        local layer = self.zoneSets[index].layer
        for i=1,self.xSize do
            local x = x0 + (i*gap)
            for j=1,self.zSize do
                local z = z0 + (j*gap)
                for k=1,8 do
                    if self.markers[i][j][layer][k] and (self.zones[i][j][index][1] > 0) then
                        local x1 = x
                        local z1 = z
                        local draw = true
                        if k == 1 then
                            x1 = x+gap
                            draw = self.zones[i][j][index][1] == self.zones[i+1][j][index][1]
                        elseif k == 2 then
                            x1 = x+gap
                            z1 = z+gap
                            draw = self.zones[i][j][index][1] == self.zones[i+1][j+1][index][1]
                        elseif k == 3 then
                            z1 = z+gap
                            draw = self.zones[i][j][index][1] == self.zones[i][j+1][index][1]
                        elseif k == 4 then
                            x1 = x-gap
                            z1 = z+gap
                            draw = self.zones[i][j][index][1] == self.zones[i-1][j+1][index][1]
                        elseif k == 5 then
                            x1 = x-gap
                            draw = self.zones[i][j][index][1] == self.zones[i-1][j][index][1]
                        elseif k == 6 then
                            x1 = x-gap
                            z1 = z-gap
                            draw = self.zones[i][j][index][1] == self.zones[i-1][j-1][index][1]
                        elseif k == 7 then
                            z1 = z-gap
                            draw = self.zones[i][j][index][1] == self.zones[i][j-1][index][1]
                        else
                            x1 = x+gap
                            z1 = z-gap
                            draw = self.zones[i][j][index][1] == self.zones[i+1][j-1][index][1]
                        end
                        if draw then
                            DrawLine({x,GetSurfaceHeight(x,z),z},{x1,GetSurfaceHeight(x1,z1),z1},colours[math.mod(self.zones[i][j][index][1],10)+1])
                        end
                    end
                end
            end
        end
    end,
    DrawLayer = function(self,layer)
        local colours = { 'aa1f77b4', 'aaff7f0e', 'aa2ca02c', 'aad62728', 'aa9467bd', 'aa8c564b', 'aae377c2', 'aa7f7f7f', 'aabcbd22', 'aa17becf' }
        local gap = self.gap
        local x0 = PLAYABLE_AREA[1] - gap
        local z0 = PLAYABLE_AREA[2] - gap
        for i=1,self.xSize do
            local x = x0 + i*gap
            for j=1,self.zSize do
                local z = z0 + j*gap
                for k=1,8 do
                    if self.markers[i][j][layer][k] then
                        local x1 = x
                        local z1 = z
                        if k == 1 then
                            x1 = x+gap
                        elseif k == 2 then
                            x1 = x+gap
                            z1 = z+gap
                        elseif k == 3 then
                            z1 = z+gap
                        elseif k == 4 then
                            x1 = x-gap
                            z1 = z+gap
                        elseif k == 5 then
                            x1 = x-gap
                        elseif k == 6 then
                            x1 = x-gap
                            z1 = z-gap
                        elseif k == 7 then
                            z1 = z-gap
                        else
                            x1 = x+gap
                            z1 = z-gap
                        end
                        DrawLine({x,GetSurfaceHeight(x,z),z},{x1,GetSurfaceHeight(x1,z1),z1},colours[math.mod(self.components[i][j][layer],10)+1])
                    end
                end
            end
        end
    end,
})

local map = GameMap()
local zoneSets = {}

local DEFAULT_BORDER = 4
function BeginSession()
    -- TODO: Detect if a map is required (inc versioning?)
    if not PLAYABLE_AREA then
        PLAYABLE_AREA = { DEFAULT_BORDER, DEFAULT_BORDER, ScenarioInfo.size[1], ScenarioInfo.size[2] }
    end
    _ALERT("Playing area:",repr(PLAYABLE_AREA))
    -- Initialise map: do grid connections, generate components
    map:InitMap()
    -- Now load up standard zones
    local START = GetSystemTimeSecondsOnlyForProfileUse()
    local LayerZoneSet = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Zones.lua').LayerZoneSet
    for i=1, 5 do
        map:AddZoneSet(LayerZoneSet)
    end
    local END = GetSystemTimeSecondsOnlyForProfileUse()
    RNGLOG(string.format('FlowAI framework: Default zone generation finished, runtime: %.2f seconds.', END - START ))
    -- Now to attempt to load any custom zone set classes
    START = GetSystemTimeSecondsOnlyForProfileUse()
    local customZoneSets = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Zones.lua').LoadCustomZoneSets()
    if table.getn(customZoneSets) > 0 then
        -- First randomise the table order.
        -- This forces people to check the ZoneSet data rather than relying on the index being forever the same (which it might not be if more mods get loaded).
        table.sort(customZoneSets,function(a,b) return Random(0,1) == 1 end)
        RNGLOG(repr(customZoneSets))
        for _, ZoneSetClass in customZoneSets do
            map:AddZoneSet(ZoneSetClass)
        end
        END = GetSystemTimeSecondsOnlyForProfileUse()
        RNGLOG(string.format('FlowAI framework: Custom zone generation finished (%d found), runtime: %.2f seconds.', table.getn(customZoneSets), END - START ))
    else
        RNGLOG("FlowAI framework: No custom zoning classes found.")
    end
end

function GetMap()
    return map
end

function GetPlayableAreaRNG()
    return PLAYABLE_AREA
end

local ResourceMarkerCount = 1
function CreateMarkerRNG(t,x,y,z,size)
    AdaptiveResourceMarkerTableRNG['Resource'..ResourceMarkerCount] = {type=t, name='Resource'..ResourceMarkerCount, position={x,y,z}, zoneid=false, Water=GetTerrainHeight(x, z) < GetSurfaceHeight(x, z)}
    ResourceMarkerCount = ResourceMarkerCount + 1
end

function GetMarkersRNG()
    return AdaptiveResourceMarkerTableRNG
end

function SetMarkerInformation(aiBrain)
    RNGLOG('Display Marker Adjacency Running')
    while not aiBrain.ZonesInitialized do
        LOG('Waiting for Zones to Initialize')
        coroutine.yield(20)
    end
    local expansionMarkers = Scenario.MasterChain._MASTERCHAIN_.Markers
    local VDist3Sq = VDist3Sq
    aiBrain.RNGAreas={}
    aiBrain.armyspots={}
    aiBrain.expandspots={}
    for k,marker in expansionMarkers do
        local node=false
        local expand=false
        local mass=false
        --RNGLOG(repr(k)..' marker type is '..repr(marker.type))
        for i, v in STR_GetTokens(marker.type,' ') do
            if v=='Node' then
                node=true
                break
            end
            if v=='Expansion' then
                expand=true
                break
            end
        end
        if node and not marker.RNGArea then
            aiBrain.RNGAreas[k]={}
            InfectMarkersRNG(aiBrain,marker,k)
        end
        if expand then
            table.insert(aiBrain.expandspots,{marker,k})
        end
        if not node and not expand and not mass then
            for _,v in STR_GetTokens(k,'_') do
                if v=='ARMY' then
                    table.insert(aiBrain.armyspots,{marker,k})
                    table.insert(aiBrain.expandspots,{marker,k})
                end
            end
        end
    end
    --WaitSeconds(10)
    --RNGLOG('colortable is'..repr(tablecolors))
    local bases=false
    if bases then
        for _,army in aiBrain.armyspots do
            local closestpath=Scenario.MasterChain._MASTERCHAIN_.Markers[AIAttackUtils.GetClosestPathNodeInRadiusByLayer(army[1].position,25,'Land').name]
            --RNGLOG('closestpath is '..repr(closestpath))
            aiBrain.renderthreadtracker=ForkThread(DoArmySpotDistanceInfect,aiBrain,closestpath,army[2])
        end
    else
        for i,v in ArmyBrains do
            if ArmyIsCivilian(v:GetArmyIndex()) or v.Result=="defeat" then continue end
            local astartX, astartZ = v:GetArmyStartPos()
            local army = {position={astartX, GetTerrainHeight(astartX, astartZ), astartZ},army=i,brain=v}
            table.sort(aiBrain.expandspots,function(a,b) return VDist3Sq(a[1].position,army.position)<VDist3Sq(b[1].position,army.position) end)
            local closestpath=Scenario.MasterChain._MASTERCHAIN_.Markers[AIAttackUtils.GetClosestPathNodeInRadiusByLayer(aiBrain.expandspots[1][1].position,25,'Land').name]
            --RNGLOG('closestpath is '..repr(closestpath))
            aiBrain.renderthreadtracker=ForkThread(DoArmySpotDistanceInfect,aiBrain,closestpath,aiBrain.expandspots[1][2])
        end
    end
    local expands=true
    while aiBrain.renderthreadtracker do
        coroutine.yield(2)
    end
    if expands then
        --tablecolors=GenerateDistinctColorTable(RNGGETN(aiBrain.expandspots))
        RNGLOG('Running Expansion spot checks for rngarea')
        for _,expand in aiBrain.expandspots do
            local closestpath=Scenario.MasterChain._MASTERCHAIN_.Markers[AIAttackUtils.GetClosestPathNodeInRadiusByLayer(expand[1].position,25,'Land').name]
            --RNGLOG('closestpath is '..repr(closestpath))
            aiBrain.renderthreadtracker=ForkThread(DoExpandSpotDistanceInfect,aiBrain,closestpath,expand[2])
        end
    end
    RNGLOG('renderthreadtracker for expansions')
    while aiBrain.renderthreadtracker do
        coroutine.yield(2)
    end
    local massPointCount = 0
    RNGLOG('Running mass spot checks for rngarea')
    for _, mass in AdaptiveResourceMarkerTableRNG do
        if mass.type == 'Mass' then
            massPointCount = massPointCount + 1
            local closestpath=Scenario.MasterChain._MASTERCHAIN_.Markers[AIAttackUtils.GetClosestPathNodeInRadiusByLayer(mass.position,25,'Land').name]
            aiBrain.renderthreadtracker=ForkThread(DoMassPointInfect,aiBrain,closestpath,mass.name)
        end
    end
    aiBrain.BrainIntel.MassMarker = massPointCount
    while aiBrain.renderthreadtracker do
        coroutine.yield(2)
    end
    --RNGLOG('RNGAreas:')
    --for k,v in aiBrain.RNGAreas do
    --    RNGLOG(repr(k)..' has '..repr(RNGGETN(v))..' nodes')
    --end
    if aiBrain.GraphZones.FirstRun then
        aiBrain.GraphZones.FirstRun = false
    end
    --RNGLOG('Dump MarkerChain '..repr(Scenario.MasterChain._MASTERCHAIN_.Markers))
    --RNGLOG('Dump Resource MarkerChain '..repr(AdaptiveResourceMarkerTableRNG))
    ScenarioInfo.MarkersInfectedRNG = true
end
function InfectMarkersRNG(aiBrain,marker,graphname)
    if marker then
        marker.RNGArea=graphname
        table.insert(aiBrain.RNGAreas[graphname],marker)
        for i, node in STR_GetTokens(marker.adjacentTo or '', ' ') do
            if not Scenario.MasterChain._MASTERCHAIN_.Markers[node].RNGArea then
                InfectMarkersRNG(aiBrain,Scenario.MasterChain._MASTERCHAIN_.Markers[node],graphname)
            end
        end
    else
        WARN('Marker provided for infection is nil')
    end
end
function DoArmySpotDistanceInfect(aiBrain,marker,army)
    aiBrain.renderthreadtracker=CurrentThread()
    coroutine.yield(1)
    --DrawCircle(marker.position,5,'FF'..aiBrain.analysistablecolors[army])
    if not marker then RNGLOG('No Marker sent to army distance check') return end
    if not marker.armydists then
        marker.armydists={}
    end
    if not marker.armydists[army] then
        marker.armydists[army]=0
    end
    local potentialdists={}
    for i, node in STR_GetTokens(marker.adjacentTo or '', ' ') do
        if node=='' then continue end
        local adjnode=Scenario.MasterChain._MASTERCHAIN_.Markers[node]
        local skip=false
        local bestdist=nil
        local adjdist=VDist3(marker.position,adjnode.position)
        if adjnode.armydists then
            for k,v in adjnode.armydists do
                --[[if not bestdist or v<bestdist then
                    bestdist=v
                end
                if k~=army and v<marker.armydists[army] then
                    skip=true
                end]]
                if not potentialdists[k] or potentialdists[k]>v then
                    potentialdists[k]=v+adjdist
                end
            end
        end
        if not adjnode.armydists then adjnode.armydists={} end
        if not adjnode.armydists[army] then
            adjnode.armydists[army]=adjdist+marker.armydists[army]
            
            --table.insert(aiBrain.renderlines,{marker.position,Scenario.MasterChain._MASTERCHAIN_.Markers[node].position,marker.type,army})
            ForkThread(DoArmySpotDistanceInfect,aiBrain,adjnode,army)
        elseif adjnode.armydists[army]>adjdist+marker.armydists[army] then
            adjnode.armydists[army]=adjdist+marker.armydists[army]
            adjnode.bestarmy=army
            ForkThread(DoArmySpotDistanceInfect,aiBrain,adjnode,army)
        end
    end
    for k,v in marker.armydists do
        if potentialdists[k]<v then
            v=potentialdists[k]
        end
    end
    for k,v in marker.armydists do
        if not marker.bestarmy or marker.armydists[marker.bestarmy]>v then
            marker.bestarmy=k
        end
    end
    coroutine.yield(1)
    if aiBrain.renderthreadtracker==CurrentThread() then
        aiBrain.renderthreadtracker=nil
    end
end
function DoExpandSpotDistanceInfect(aiBrain,marker,expand)
    aiBrain.renderthreadtracker=CurrentThread()
    coroutine.yield(1)
    --DrawCircle(marker.position,4,'FF'..aiBrain.analysistablecolors[expand])
    if not marker then aiBrain.renderthreadtracker=nil return end
    if not marker.expanddists then
        marker.expanddists={}
    end
    if not marker.expanddists[expand] then
        marker.expanddists[expand]=0
    end
    local potentialdists={}
    for i, node in STR_GetTokens(marker.adjacentTo or '', ' ') do
        if node=='' then continue end
        local adjnode=Scenario.MasterChain._MASTERCHAIN_.Markers[node]
        local skip=false
        local bestdist=nil
        local adjdist=VDist3(marker.position,adjnode.position)
        if adjnode.expanddists then
            for k,v in adjnode.expanddists do
                --[[if not bestdist or v<bestdist then
                    bestdist=v
                end
                if k~=expand and v<marker.expanddists[expand] then
                    skip=true
                end]]
                if not potentialdists[k] or potentialdists[k]>v then
                    potentialdists[k]=v+adjdist
                end
            end
        end
        if not adjnode.expanddists then adjnode.expanddists={} end
        if not adjnode.expanddists[expand] then
            adjnode.expanddists[expand]=adjdist+marker.expanddists[expand]
            --table.insert(aiBrain.renderlines,{marker.position,Scenario.MasterChain._MASTERCHAIN_.Markers[node].position,marker.type,expand})
            ForkThread(DoExpandSpotDistanceInfect,aiBrain,adjnode,expand)
        elseif adjnode.expanddists[expand]>adjdist+marker.expanddists[expand] then
            adjnode.expanddists[expand]=adjdist+marker.expanddists[expand]
            adjnode.bestexpand=expand
            ForkThread(DoExpandSpotDistanceInfect,aiBrain,adjnode,expand)
        end
    end
    for k,v in marker.expanddists do
        if potentialdists[k]<v then
            v=potentialdists[k]
        end
    end
    for k,v in marker.expanddists do
        if not marker.bestexpand or marker.expanddists[marker.bestexpand]>v then
            marker.bestexpand=k
            -- Important. Extension to chps logic to add RNGArea to expansion markers so we can tell if we own expansions on islands etc
            if not Scenario.MasterChain._MASTERCHAIN_.Markers[k].RNGArea then
                Scenario.MasterChain._MASTERCHAIN_.Markers[k].RNGArea = marker.RNGArea
                --RNGLOG('ExpansionMarker '..repr(Scenario.MasterChain._MASTERCHAIN_.Markers[k]))
            end
        end
    end
    coroutine.yield(1)
    if aiBrain.renderthreadtracker==CurrentThread() then
        aiBrain.renderthreadtracker=nil
    end
end

function DoMassPointInfect(aiBrain,marker,masspoint)
    aiBrain.renderthreadtracker=CurrentThread()
    coroutine.yield(1)
    --DrawCircle(marker.position,4,'FF'..aiBrain.analysistablecolors[expand])
    if not marker then aiBrain.renderthreadtracker=nil return end
    if not AdaptiveResourceMarkerTableRNG[masspoint].RNGArea then
        AdaptiveResourceMarkerTableRNG[masspoint].RNGArea = marker.RNGArea
        --RNGLOG('MassMarker '..repr(Scenario.MasterChain._MASTERCHAIN_.Markers[masspoint]))
    end
    if not AdaptiveResourceMarkerTableRNG[masspoint].zoneid then
        if GetTerrainHeight(marker.position[1], marker.position[3]) < GetSurfaceHeight(marker.position[1], marker.position[3]) then
            local zone = map:GetZoneID(AdaptiveResourceMarkerTableRNG[masspoint].position,aiBrain.Zones.Naval.index)
            if zone then
                --LOG('Zone found, adding zone to naval mass marker '..zone)
                AdaptiveResourceMarkerTableRNG[masspoint].zoneid = zone
            else
                WARN('No zone returned for mass point marker during initial infection, this should have been a naval zone')
            end
        else
            local zone = map:GetZoneID(AdaptiveResourceMarkerTableRNG[masspoint].position,aiBrain.Zones.Land.index)
            if zone then
                --LOG('Zone found, adding zone to land mass marker '..zone)
                AdaptiveResourceMarkerTableRNG[masspoint].zoneid = zone
            else
                WARN('No zone returned for mass point marker during initial infection, this should have been a land zone')
            end
        end
    end

    coroutine.yield(1)
    if aiBrain.renderthreadtracker==CurrentThread() then
        aiBrain.renderthreadtracker=nil
    end
end
