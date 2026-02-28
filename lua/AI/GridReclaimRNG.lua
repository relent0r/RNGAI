--******************************************************************************************************
--** File    : /mods/RNGAI/lua/AI/GridReclaimRNG.lua
--** Author  : RNG / Gemini
--** Summary : specialized Reclaim Grid for RNGAI with Zone-Awareness hooks
--******************************************************************************************************

local GridReclaim = import("/lua/ai/gridreclaim.lua").GridReclaim

---@class AIGridReclaimRNG : GridReclaim
GridReclaimRNG = Class(GridReclaim) {

    ---@param self GridReclaimRNG
    __init = function(self)
        LOG('Init GridReclaimRNG')
        GridReclaim.__init(self)
        
        -- Initialize our RNG-specific tables
        self.ZoneTotals = {}
        self.CellToZoneMap = {}
        self.ZonesMapped = false
    end,

    --- Fast-access getter for zone-based reclaim values
    ---@param self AIGridReclaimRNG
    ---@param zoneID number
    ---@return number
    GetReclaimForZone = function(self, zoneID)
        return self.ZoneTotals[zoneID] or 0
    end,
}

local GridReclaimRNGInstance = false

---@param brain AIBrain
---@return GridReclaimRNG
function Setup(brain)
    if not GridReclaimRNGInstance then
        GridReclaimRNGInstance = GridReclaimRNG()
    end

    if brain then
        GridReclaimRNGInstance:RegisterBrain(brain)
    end

    return GridReclaimRNGInstance
end