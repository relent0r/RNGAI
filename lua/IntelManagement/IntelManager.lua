local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
local GetMarkersRNG = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
local GetClosestPathNodeInRadiusByLayerRNG = import('/lua/AI/aiattackutilities.lua').GetClosestPathNodeInRadiusByLayerRNG
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local PlatoonExists = moho.aibrain_methods.PlatoonExists


-- pre-compute categories for performance
local CategoriesStructuresNotMex = categories.STRUCTURE - categories.TECH1 - categories.WALL - categories.MASSEXTRACTION
local CategoriesEnergy = categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3 + categories.EXPERIMENTAL)
local CategoriesDefense = categories.DEFENSE * (categories.TECH2 + categories.TECH3)
local CategoriesStrategic = categories.STRATEGIC * (categories.TECH2 + categories.TECH3 + categories.EXPERIMENTAL)
local CategoriesIntelligence = categories.INTELLIGENCE * (categories.TECH2 + categories.TECH3 + categories.EXPERIMENTAL)
local CategoriesFactory = categories.FACTORY * (categories.TECH2 + categories.TECH3 ) - categories.SUPPORTFACTORY - categories.EXPERIMENTAL - categories.CRABEGG - categories.CARRIER
local CategoriesShield = categories.SHIELD * categories.STRUCTURE

local RNGMAX = math.max
local RNGPOW = math.pow
local RNGSQRT = math.sqrt
local RNGGETN = table.getn
local RNGINSERT = table.insert
local RNGREMOVE = table.remove
local RNGSORT = table.sort
local RNGFLOOR = math.floor
local RNGCEIL = math.ceil
local RNGPI = math.pi
local RNGCAT = table.cat
local RNGCOPY = table.copy
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

IntelManager = Class {
    Create = function(self, brain)
        self.Brain = brain
        self.Initialized = false
        self.Debug = false
        -- Used for scout assignments to zones
        self.ZoneIntel = {
            Assignment = { }
        }
    end,

    Run = function(self)
       --RNGLOG('RNGAI : IntelManager Starting')
        self:ForkThread(self.ZoneEnemyIntelMonitorRNG)
        self:ForkThread(self.ZoneAlertThreadRNG)
        self:ForkThread(self.ZoneFriendlyIntelMonitorRNG)
        self:ForkThread(self.ConfigureResourcePointZoneID)
        self:ForkThread(self.ZoneControlMonitorRNG)
        self:ForkThread(self.ZoneIntelAssignment)
        if self.Debug then
            self:ForkThread(self.IntelDebugThread)
        end
        self.Initialized = true
    end,

    ForkThread = function(self, fn, ...)
        if fn then
            local thread = ForkThread(fn, self, unpack(arg))
            self.Brain.Trash:Add(thread)
            return thread
        else
            return nil
        end
    end,

    IntelDebugThread = function(self)
        self:WaitForZoneInitialization()
        WaitTicks(30)
        while true do
            for _, z in self.Brain.Zones.Land.zones do
                DrawCircle(z.pos,3*z.weight,'b967ff')
                if z.enemythreat > 0 then
                    DrawCircle(z.pos,math.max(20,z.enemythreat),'d62d20')
                end
                if z.friendlythreat > 0 then
                    DrawCircle(z.pos,math.max(20,z.friendlythreat),'aa44ff44')
                else
                    DrawCircle(z.pos,10,'aaffffff')
                end
                --[[if z.intel.control.enemy > 0 then
                    DrawCircle(z.pos,10*z.intel.control.enemy,'aaff4444')
                end
                for _, e in z.edges do
                    if e.zone.id < z.id then
                        local ca1 = z.intel.control.allied > z.intel.control.enemy
                        local ca2 = e.zone.intel.control.allied > e.zone.intel.control.enemy
                        local ce1 = z.intel.control.allied <= z.intel.control.enemy and z.intel.control.enemy > 0.3
                        local ce2 = e.zone.intel.control.allied <= e.zone.intel.control.enemy and e.zone.intel.control.enemy > 0.3
                        if ca1 and ca2 then
                            -- Allied edge
                            DrawLine(z.pos,e.zone.pos,'8800ff00')
                        elseif (ca1 and ce2) or (ca2 and ce1) then
                            -- Contested edge
                            DrawLine(z.pos,e.zone.pos,'88ffff00')
                        elseif ce1 and ce2 then
                            -- Enemy edge
                            DrawLine(z.pos,e.zone.pos,'88ff0000')
                        elseif (ca1 or ca2) and (not (ce1 or ce2)) then
                            -- Allied expansion edge
                            DrawLine(z.pos,e.zone.pos,'8800ffff')
                        elseif (ce1 or ce2) and (not (ca1 or ca2)) then
                            -- Enemy expansion edge
                            DrawLine(z.pos,e.zone.pos,'88ff00ff')
                        else
                            -- Nobodies edge
                            DrawLine(z.pos,e.zone.pos,'66666666')
                        end
                    end
                end]]
            end
            WaitTicks(2)
        end
    end,

    WaitForZoneInitialization = function(self)
        while not self.Brain.ZonesInitialized do
           --RNGLOG('Zones table is empty, waiting')
            coroutine.yield(20)
        end
    end,

    ZoneControlMonitorRNG = function(self)
        -- This is doing the maths stuff on understand the zone control level
        self:WaitForZoneInitialization()
        local Zones = {
            'Land',
        }
        while self.Brain.Result ~= "defeat" do
            for k, v in Zones do
                for k1, v1 in self.Brain.Zones[v].zones do
                    local resourcePoints = v1.resourcevalue
                    local control = 1
                    local tempMyControl = 0
                    local tempEnemyControl = 0
                    -- Work out our control
                    --RNGLOG('Detailed Control ')
                    if self.Brain.smanager.mex[v1.id].T1 then
                        tempMyControl = tempMyControl + self.Brain.smanager.mex[v1.id].T1
                    end
                    if self.Brain.BrainIntel.SelfThreat.AllyExtractorTable[v1.id].T1 then
                        tempMyControl = tempMyControl + self.Brain.BrainIntel.SelfThreat.AllyExtractorTable[v1.id].T1
                    end
                    if self.Brain.smanager.mex[v1.id].T2 then
                        tempMyControl = tempMyControl + self.Brain.smanager.mex[v1.id].T2
                    end
                    if self.Brain.BrainIntel.SelfThreat.AllyExtractorTable[v1.id].T2 then
                        tempMyControl = tempMyControl + self.Brain.BrainIntel.SelfThreat.AllyExtractorTable[v1.id].T2
                    end
                    if self.Brain.smanager.mex[v1.id].T3 then
                        tempMyControl = tempMyControl + self.Brain.smanager.mex[v1.id].T3
                    end
                    if self.Brain.BrainIntel.SelfThreat.AllyExtractorTable[v1.id].T3 then
                        tempMyControl = tempMyControl + self.Brain.BrainIntel.SelfThreat.AllyExtractorTable[v1.id].T3
                    end
                    --[[
                    if self.Brain.smanager.hydrocarbon[v1.id].hydrocarbon then
                        tempMyControl = tempMyControl + self.Brain.smanager.hydrocarbon[v1.id].hydrocarbon
                    end
                    ]]
                    --LOG('Total mexes in zone '..v1.id..' are'..tempMyControl)
                    --LOG('Resource Value of Zone is '..v1.resourcevalue)
                    tempMyControl = tempMyControl / v1.resourcevalue
                    --LOG('Resource Value is '..v1.resourcevalue)
                    --LOG('Control Value after calculation'..tempMyControl)
                    if tempMyControl > 0 then
                        control = control - tempMyControl
                    end
                    if self.Brain.emanager.mex[v1.id].T1 then
                        tempEnemyControl = tempEnemyControl + self.Brain.emanager.mex[v1.id].T1
                    end
                    if self.Brain.emanager.mex[v1.id].T2 then
                        tempEnemyControl = tempEnemyControl + self.Brain.emanager.mex[v1.id].T2
                    end
                    if self.Brain.emanager.mex[v1.id].T3 then
                        tempEnemyControl = tempEnemyControl + self.Brain.emanager.mex[v1.id].T3
                    end
                    --RNGLOG('Enemy Mexes in zone '..v1.id..' are '..tempMyControl)
                    --RNGLOG('Weight of zone '..v1.resourcevalue)
                    tempEnemyControl = tempEnemyControl / v1.resourcevalue
                    --LOG('Enemy Temp control value after calculation '..tempEnemyControl)
                    if tempEnemyControl > 0 then
                        control = control + tempEnemyControl
                    end
                    --LOG('Total Control of zone '..v1.id..' is '..control)
                    v1.control = control
                end
            end
            coroutine.yield(50)
        end
    end,

    SelectZoneRNG = function(self, aiBrain, platoon, type)
        -- Tricky subject. Distance + threat + percentage of zones owned. If own a high value position do we pay more attention to the edges of that zone? 
        --A multiplier to adjacent edges if you would. We know how many and of what tier extractors we have in a zone. Actually getting an engineer to expand by zone would be interesting.
       --RNGLOG('RNGAI : Zone Selection Query Received for '..platoon.BuilderName)
        if PlatoonExists(aiBrain, platoon) then
            local zoneSet = false
            local zoneSelection = 999
            local selection = false
            local enemyMexmodifier = 0.1
            local enemyX, enemyZ
            if not platoon.Zone then
                WARN('RNGAI : Select Zone platoon has no zone attribute '..platoon.PlanName)
                coroutine.yield(20)
                return false
            end
           --RNGLOG('RNGAI : Zone Selection Query Checking if Zones initialized')
            if aiBrain.ZonesInitialized then
                if platoon.MovementLayer == 'Land' or platoon.MovementLayer == 'Amphibious' then
                    zoneSet = self.Brain.Zones.Land.zones
                elseif platoon.MovementLayer == 'Air' then
                    zoneSet = self.Brain.Zones.Air.zones
                end
                if aiBrain:GetCurrentEnemy() then
                    enemyX, enemyZ = aiBrain:GetCurrentEnemy():GetArmyStartPos()
                end
                if not zoneSet then
                    WARN('No zoneSet returns, validate MovementLayer which is '..platoon.MovementLayer)
                    WARN('BuilderName is '..platoon.BuilderName)
                    WARN('Plan is '..platoon.PlanName)
                end

                if type == 'raid' then
                   --LOG('RNGAI : Zone Raid Selection Query Processing')
                    local startPosZones = {}
                    local platoonPosition = platoon:GetPlatoonPosition()
                    for k, v in aiBrain.Zones.Land.zones do
                        if not v.startpositionclose then
                            if platoonPosition then
                                local compare
                                local enemyDistanceModifier = VDist2(aiBrain.Zones.Land.zones[v.id].pos[1],aiBrain.Zones.Land.zones[v.id].pos[3],enemyX, enemyZ)
                                local zoneDistanceModifier = VDist2(aiBrain.Zones.Land.zones[v.id].pos[1],aiBrain.Zones.Land.zones[v.id].pos[3],platoonPosition[1], platoonPosition[3])
                                local enemyModifier = aiBrain.Zones.Land.zones[v.id].enemythreat
                                if not zoneSet[v.id].control then
                                   --LOG('control is nil, here is the table '..repr(zoneSet[v.id]))
                                end
                                if enemyModifier > 0 then
                                    enemyModifier = enemyModifier * 10
                                end
                               --LOG('Start Distance Calculation '..( 20000 / enemyDistanceModifier )..' Zone Distance Calculation'..(20000 / zoneDistanceModifier)..' Resource Value '..zoneSet[v.id].resourcevalue..' Control Value '..zoneSet[v.id].control)
                               --LOG('Friendly threat at zone is '..zoneSet[v.id].friendlythreat)
                                if zoneSet[v.id].control > 0.5 and zoneSet[v.id].friendlythreat < 10 then
                                    compare = (20000 / zoneDistanceModifier) + ( 20000 / enemyDistanceModifier ) * zoneSet[v.id].resourcevalue * zoneSet[v.id].control - enemyModifier
                                end
                                if compare then
                                    --RNGLOG('Compare variable '..compare)
                                end
                                if compare > 0 then
                                    if not selection or compare > selection then
                                        selection = compare
                                        zoneSelection = v.id
                                        --LOG('Zone Query Select priority 1st pass'..selection)
                                        --LOG('Zone target location is '..repr(zoneSet[v.id].pos))
                                    end
                                end
                            end
                        else
                            table.insert( startPosZones, v )
                        end
                    end
                    if selection then
                        return zoneSelection
                    else
                        for k, v in startPosZones do
                            if platoonPosition then
                                local compare
                                local enemyDistanceModifier = VDist2(aiBrain.Zones.Land.zones[v.id].pos[1],aiBrain.Zones.Land.zones[v.id].pos[3],enemyX, enemyZ)
                                local zoneDistanceModifier = VDist2(aiBrain.Zones.Land.zones[v.id].pos[1],aiBrain.Zones.Land.zones[v.id].pos[3],platoonPosition[1], platoonPosition[3])
                               --LOG('Start Distance Calculation '..( 20000 / enemyDistanceModifier )..' Zone Distance Calculation'..(20000 / zoneDistanceModifier)..' Resource Value '..zoneSet[v.id].resourcevalue..' Control Value '..zoneSet[v.id].control)
                                if zoneSet[v.zone.id].control <= 0 then
                                    compare = (20000 / zoneDistanceModifier) + ( 20000 / enemyDistanceModifier )
                                else
                                    compare = (20000 / zoneDistanceModifier) + ( 20000 / enemyDistanceModifier ) * zoneSet[v.id].resourcevalue * zoneSet[v.id].control
                                end
                                if compare then
                                    --RNGLOG('Compare variable '..compare)
                                end
                                if compare > 0 then
                                    if not selection or compare > selection then
                                        selection = compare
                                        zoneSelection = v.id
                                        --RNGLOG('Zone Query Select priority 2nd pass start locations'..selection)
                                        --LOG('Zone target location is '..repr(zoneSet[v.id].pos))
                                    end
                                end
                            end
                        end
                    end
                    if selection then
                        return zoneSelection
                    end
                elseif type == 'control' then
                    local compare = 0
                   --RNGLOG('RNGAI : Zone Control Selection Query Processing First Pass')
                    for k, v in aiBrain.Zones.Land.zones[platoon.Zone].edges do
                        local distanceModifier = VDist2(aiBrain.Zones.Land.zones[v.zone.id].pos[1],aiBrain.Zones.Land.zones[v.zone.id].pos[3],enemyX, enemyZ)
                        local enemyModifier = 1
                        if zoneSet[v.zone.id].enemythreat > 0 then
                            enemyModifier = enemyModifier + 2
                        end
                        if zoneSet[v.zone.id].friendlythreat > 0 then
                            if zoneSet[v.zone.id].enemythreat == 0 or zoneSet[v.zone.id].enemythreat < zoneSet[v.zone.id].friendlythreat then
                                enemyModifier = enemyModifier - 1
                            else
                                enemyModifier = enemyModifier + 1
                            end
                        end
                        if enemyModifier < 0 then
                            enemyModifier = 0
                        end
                        local controlValue = zoneSet[v.zone.id].control
                        if controlValue <= 0 then
                            controlValue = 0.1
                        end
                        local resourceValue = zoneSet[v.zone.id].resourcevalue
                        if resourceValue then
                           --RNGLOG('Current platoon zone '..platoon.Zone..' target zone is '..v.zone.id..' enemythreat is '..zoneSet[v.zone.id].enemythreat..' friendly threat is '..zoneSet[v.zone.id].friendlythreat)
                           --RNGLOG('Distance Calculation '..( 20000 / distanceModifier )..' Resource Value '..resourceValue..' Control Value '..controlValue..' position '..repr(zoneSet[v.zone.id].pos)..' Enemy Modifier is '..enemyModifier)
                        else
                           --LOG('No resource against zone '..v.zone.id)
                        end
                        compare = ( 20000 / distanceModifier ) * resourceValue * controlValue * enemyModifier
                       --RNGLOG('Compare variable '..compare)
                        if compare > 0 then
                            if not selection or compare > selection then
                                selection = compare
                                zoneSelection = v.zone.id
                               --RNGLOG('Zone Control Query Select priority '..selection)
                            end
                        end
                    end
                    if not selection then
                       --RNGLOG('RNGAI : Zone Control Selection Query Processing Second Pass')
                        for k, v in aiBrain.Zones.Land.zones[platoon.Zone].edges do
                            for k1, v1 in v.zone.edges do
                                local distanceModifier = VDist2(aiBrain.Zones.Land.zones[v1.zone.id].pos[1],aiBrain.Zones.Land.zones[v1.zone.id].pos[3],enemyX, enemyZ)
                                local enemyModifier = 1
                                if zoneSet[v1.zone.id].enemythreat > 0 then
                                    enemyModifier = enemyModifier + 2
                                end
                                if zoneSet[v1.zone.id].friendlythreat > 0 then
                                    if zoneSet[v1.zone.id].enemythreat < zoneSet[v1.zone.id].friendlythreat then
                                        enemyModifier = enemyModifier - 1
                                    else
                                        enemyModifier = enemyModifier + 1
                                    end
                                end
                                if enemyModifier < 0 then
                                    enemyModifier = 0
                                end
                                local controlValue = zoneSet[v1.zone.id].control
                                if controlValue <= 0 then
                                    controlValue = 0.1
                                end
                                local resourceValue = zoneSet[v1.zone.id].resourcevalue
                               --RNGLOG('Current platoon zone '..platoon.Zone..' Distance Calculation '..( 20000 / distanceModifier )..' Resource Value '..resourceValue..' Control Value '..controlValue..' position '..repr(zoneSet[v1.zone.id].pos)..' Enemy Modifier is '..enemyModifier)
                                compare = ( 20000 / distanceModifier ) * resourceValue * controlValue * enemyModifier
                                if compare > 0 then
                                    if compare > selection then
                                       --RNGLOG('Try to log zoneset')
                                        selection = compare
                                        zoneSelection = v1.zone.id
                                       --RNGLOG('Zone Control Query Select priority '..selection)
                                    end
                                end
                            end
                        end
                    end
                    if not selection then
                        for k, v in aiBrain.Zones.Land.zones do
                            if not v.startpositionclose then
                                local distanceModifier = VDist2(aiBrain.Zones.Land.zones[v.id].pos[1],aiBrain.Zones.Land.zones[v.id].pos[3],enemyX, enemyZ)
                                local enemyModifier = 1
                                if zoneSet[v.id].enemythreat > 0 then
                                    enemyModifier = enemyModifier + 2
                                end
                                if zoneSet[v.id].friendlythreat > 0 then
                                    if zoneSet[v.id].enemythreat < zoneSet[v.id].friendlythreat then
                                        enemyModifier = enemyModifier - 1
                                    else
                                        enemyModifier = enemyModifier + 1
                                    end
                                end
                                if enemyModifier < 0 then
                                    enemyModifier = 0
                                end
                                local controlValue = zoneSet[v.id].control
                                if controlValue <= 0 then
                                    controlValue = 0.1
                                end
                                local resourceValue = zoneSet[v.id].resourcevalue
                               --RNGLOG('Current platoon zone '..platoon.Zone..' Distance Calculation '..( 20000 / distanceModifier )..' Resource Value '..resourceValue..' Control Value '..controlValue..' position '..repr(zoneSet[v.zone.id].pos)..' Enemy Modifier is '..enemyModifier)
                                compare = ( 20000 / distanceModifier ) * resourceValue * controlValue * enemyModifier
                               --RNGLOG('Compare variable '..compare)
                                if compare > 0 then
                                    if not selection or compare > selection then
                                        selection = compare
                                        zoneSelection = v.id
                                       --RNGLOG('Zone Control Query Select priority '..selection)
                                    end
                                end
                            end
                        end
                    end
                    if selection then
                        return zoneSelection
                    else
                       --RNGLOG('RNGAI : Zone Control Selection Query did not select zone')
                    end
                end
            else
                WARN('RNGAI : Zones are not initialized for Select Zone query')
            end
        else
            WARN('RNGAI : PlatoonExist parameter false in Select Zone query')
        end
       --RNGLOG('RNGAI : No zone returned from Zone Query')
        return false
    end,

    ZoneAlertThreadRNG = function(self)
        local threatTypes = {
            'Land',
            'Commander',
            'Structures',
        }
        local Zones = {
            'Land',
        }
        self:WaitForZoneInitialization()
        coroutine.yield(Random(5,20))
        while self.Brain.Result ~= "defeat" do
            for k, v in Zones do
                for k1, v1 in self.Brain.Zones[v].zones do
                    if not v1.startpositionclose and v1.control < 1 and v1.enemythreat > 0 then
                       --LOG('Try create zone alert for threat')
                        self.Brain:BaseMonitorZoneThreatRNG(v1.id, v1.enemythreat)
                    end
                    coroutine.yield(5)
                end
                coroutine.yield(3)
            end
            coroutine.yield(40)
        end
    end,

    ZoneEnemyIntelMonitorRNG = function(self)
        local threatTypes = {
            'Land',
            'Commander',
            'Structures',
        }
        local Zones = {
            'Land',
        }
        local rawThreat = 0
        self:WaitForZoneInitialization()
        coroutine.yield(Random(5,20))
        while self.Brain.Result ~= "defeat" do
            for k, v in Zones do
                for k1, v1 in self.Brain.Zones[v].zones do
                    self.Brain.Zones.Land.zones[k1].enemythreat = GetThreatAtPosition(self.Brain, v1.pos, self.Brain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface')
                    coroutine.yield(1)
                end
                coroutine.yield(3)
            end
            coroutine.yield(5)
        end
    end,

    ZoneFriendlyIntelMonitorRNG = function(self)
        local Zones = {
            'Land',
        }
        self:WaitForZoneInitialization()
        coroutine.yield(Random(5,20))
        while self.Brain.Result ~= "defeat" do
            local Zones = {
                'Land',
            }
            local AlliedPlatoons = self.Brain:GetPlatoonsList()
            for k, v in Zones do
                local friendlyThreat = {}
                for k1, v1 in AlliedPlatoons do
                    if not v1.MovementLayer then
                        AIAttackUtils.GetMostRestrictiveLayerRNG(v1)
                    end
                    if not v1.Dead then
                        if v1.Zone and v1.CurrentPlatoonThreat then
                            if not friendlyThreat[v1.Zone] then
                                friendlyThreat[v1.Zone] = 0
                            end
                            friendlyThreat[v1.Zone] = friendlyThreat[v1.Zone] + v1.CurrentPlatoonThreat
                        end
                    end
                end
                for k2, v2 in self.Brain.Zones[v].zones do
                    for k3, v3 in friendlyThreat do
                        if k2 == k3 then
                            self.Brain.Zones[v].zones[k2].friendlythreat = v3
                        end
                    end
                end
            end
            coroutine.yield(20)
        end
    end,

    ConfigureResourcePointZoneID = function(self)
        -- This will set the zoneid on resource markers
        -- note this logic exist in the calculate mass markers function as well so that things like crazy rush will update.
        self:WaitForZoneInitialization()
        coroutine.yield(Random(5,20))
        local markerTable = GetMarkersRNG()
        for _, v in markerTable do
            if not v.zoneid and self.ZonesInitialized then
                if RUtils.PositionOnWater(v.position[1], v.position[3]) then
                    -- tbd define water based zones
                    v.zoneid = water
                else
                    v.zoneid = MAP:GetZoneID(v.position,self.Zones.Land.index)
                end
            end
        end
    end,

    AssignIntelUnit = function(self, unit)
        local ALLBPS = __blueprints
        local intelRadius = ALLBPS[unit.UnitId].Intel.RadarRadius * ALLBPS[unit.UnitId].Intel.RadarRadius
        local radarPosition = unit:GetPosition()
        if ALLBPS[unit.UnitId].CategoriesHash.RADAR then
           --LOG('Zone set for radar that has been built '..unit.UnitId)
            unit.zoneid = MAP:GetZoneID(radarPosition,self.Brain.Zones.Land.index)
            if unit.zoneid then
                for k, v in self.ZoneIntel.Assignment do
                    if VDist2Sq(radarPosition[1], radarPosition[3], v.Position[1], v.Position[3]) < intelRadius then
                       --LOG('Radar coverage has been set true for zone '..unit.zoneid)
                        RNGINSERT(v.RadarUnits, unit)
                        v.RadarCoverage = true
                    end
                end
            else
                WARN('No ZoneID for Radar, unable to set coverage area')
            end
        end
    end,

    UnassignIntelUnit = function(self, unit)
        local ALLBPS = __blueprints
        if ALLBPS[unit.UnitId].CategoriesHash.RADAR then
           --LOG('Unassigning Radar Unit')
            for k, v in self.ZoneIntel.Assignment do
                for c, b in v.RadarUnits do
                    if b == unit then
                       --LOG('Found Radar that was covering zone '..k..' removing')
                        RNGREMOVE(v.RadarUnits, c)
                    end
                end
                if v.RadarCoverage and RNGGETN(v.RadarUnits) == 0 then
                   --LOG('No Radars in range for zone '..k..' setting radar coverage to false')
                    v.RadarCoverage = false
                end
            end
        end
    end,

    ZoneIntelAssignment = function(self)
        -- Will setup table for scout assignment to zones
        -- I did this because I didn't want to assign units directly to the zones since it makes it hard to troubleshoot
        -- replaces the previous expansion scout assignment so that all mass points can be monitored
        -- Will also set data for intel based scout production.
        local ALLBPS = __blueprints
        
        self:WaitForZoneInitialization()
        coroutine.yield(Random(5,20))
        local Zones = {
            'Land',
        }
        for k, v in Zones do
            for k1, v1 in self.Brain.Zones[v].zones do
                RNGINSERT(self.ZoneIntel.Assignment, { Zone = k1, Position = v1.pos, RadarCoverage = false, RadarUnits = { }, ScoutUnit = false, StartPosition = v1.startpositionclose})
            end
        end
       --LOG('Zone Intel Assignment Complete')
       --LOG('Initial Zone Assignment Table '..repr(self.ZoneIntel.Assignment))
    end,

}

local im 

function CreateIntelManager(brain)
    im = IntelManager()
    im:Create(brain)
    return im
end


function GetIntelManager()
    return im
end

function AIConfigureExpansionWatchTableRNG(aiBrain)
    coroutine.yield(5)
    
    local VDist2Sq = VDist2Sq
    local markerList = {}
    local armyStarts = {}
    local expansionMarkers = Scenario.MasterChain._MASTERCHAIN_.Markers
    local massPointValidated = false
    local myArmy = ScenarioInfo.ArmySetup[aiBrain.Name]
    --RNGLOG('Run ExpansionWatchTable Config')

    for i = 1, 16 do
        local army = ScenarioInfo.ArmySetup['ARMY_' .. i]
        local startPos = ScenarioUtils.GetMarker('ARMY_' .. i).position
        if army and startPos then
            table.insert(armyStarts, startPos)
        end
    end
    --RNGLOG(' Army Starts'..repr(armyStarts))

    if expansionMarkers then
        --RNGLOG('Initial expansionMarker list is '..repr(expansionMarkers))
        for k, v in expansionMarkers do
            local startPosUsed = false
            if v.type == 'Expansion Area' or v.type == 'Large Expansion Area' or v.type == 'Blank Marker' then
                for _, p in armyStarts do
                    if p == v.position then
                        --RNGLOG('Position Taken '..repr(v)..' and '..repr(v.position))
                        startPosUsed = true
                        break
                    end
                end
                if not startPosUsed then
                    if v.MassSpotsInRange then
                        massPointValidated = true
                        table.insert(markerList, {Name = k, Position = v.position, Type = v.type, TimeStamp = 0, MassPoints = v.MassSpotsInRange, Land = 0, Structures = 0, Commander = 0, PlatoonAssigned = false, ScoutAssigned = false, Zone = false, Radar = false})
                    else
                        table.insert(markerList, {Name = k, Position = v.position, Type = v.type, TimeStamp = 0, MassPoints = 0, Land = 0, Structures = 0, Commander = 0, PlatoonAssigned = false, ScoutAsigned = false, Zone = false, Radar = false})
                    end
                end
            end
        end
    end
    if not massPointValidated then
        markerList = CalculateMassValue(markerList)
    end
    --RNGLOG('Army Setup '..repr(ScenarioInfo.ArmySetup))
    local startX, startZ = aiBrain:GetArmyStartPos()
    table.sort(markerList,function(a,b) return VDist2Sq(a.Position[1],a.Position[3],startX, startZ)>VDist2Sq(b.Position[1],b.Position[3],startX, startZ) end)
    aiBrain.BrainIntel.ExpansionWatchTable = markerList
    --RNGLOG('ExpansionWatchTable is '..repr(markerList))
end

ExpansionIntelScanRNG = function(aiBrain)
    --RNGLOG('Pre-Start ExpansionIntelScan')
    AIConfigureExpansionWatchTableRNG(aiBrain)
    coroutine.yield(Random(30,70))
    if RNGGETN(aiBrain.BrainIntel.ExpansionWatchTable) == 0 then
        --RNGLOG('ExpansionWatchTable not ready or is empty')
        return
    end
    local threatTypes = {
        'Land',
        'Commander',
        'Structures',
    }
    local rawThreat = 0
    if ScenarioInfo.Options.AIDebugDisplay == 'displayOn' then
        aiBrain:ForkThread(RUtils.RenderBrainIntelRNG)
    end
    local GetClosestPathNodeInRadiusByLayer = import('/lua/AI/aiattackutilities.lua').GetClosestPathNodeInRadiusByLayer
    --RNGLOG('Starting ExpansionIntelScan')
    while aiBrain.Result ~= "defeat" do
        for k, v in aiBrain.BrainIntel.ExpansionWatchTable do
            if v.PlatoonAssigned.Dead then
                v.PlatoonAssigned = false
            end
            if v.ScoutAssigned.Dead then
                v.ScoutAssigned = false
            end
            if not v.Zone then
                --[[
                    This is the information available in the Path Node currently. subject to change 7/13/2021
                    info: Check for position {
                    info:   GraphArea="LandArea_133",
                    info:   RNGArea="Land15-24",
                    info:   adjacentTo="Land19-11 Land20-11 Land20-12 Land20-13 Land18-11",
                    info:   armydists={ ARMY_1=209.15859985352, ARMY_2=218.62866210938 },
                    info:   bestarmy="ARMY_1",
                    info:   bestexpand="Expansion Area 6",
                    info:   color="fff4a460",
                    info:   expanddists={
                    info:     ARMY_1=209.15859985352,
                    info:     ARMY_2=218.62866210938,
                    info:     ARMY_3=118.64562988281,
                    info:     ARMY_4=290.41003417969,
                    info:     ARMY_5=270.42752075195,
                    info:     ARMY_6=125.28052520752,
                    info:     Expansion Area 1=354.38958740234,
                    info:     Expansion Area 2=354.2922668457,
                    info:     Expansion Area 5=222.54640197754,
                    info:     Expansion Area 6=0
                    info:   },
                    info:   graph="DefaultLand",
                    info:   hint=true,
                    info:   orientation={ 0, 0, 0 },
                    info:   position={ 312, 16.21875, 200, type="VECTOR3" },
                    info:   prop="/env/common/props/markers/M_Path_prop.bp",
                    info:   type="Land Path Node"
                    info: }
                ]]
                local expansionNode = Scenario.MasterChain._MASTERCHAIN_.Markers[GetClosestPathNodeInRadiusByLayer(v.Position, 60, 'Land').name]
                --RNGLOG('Check for position '..repr(expansionNode))
                if expansionNode then
                    aiBrain.BrainIntel.ExpansionWatchTable[k].Zone = expansionNode.RNGArea
                else
                    aiBrain.BrainIntel.ExpansionWatchTable[k].Zone = false
                end
            end
            if v.MassPoints > 2 then
                for _, t in threatTypes do
                    rawThreat = GetThreatAtPosition(aiBrain, v.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, t)
                    if rawThreat > 0 then
                        --RNGLOG('Threats as ExpansionWatchTable for type '..t..' threat is '..rawThreat)
                        --RNGLOG('Expansion is '..v.Name)
                        --RNGLOG('Position is '..repr(v.Position))
                    end
                    aiBrain.BrainIntel.ExpansionWatchTable[k][t] = rawThreat
                end
            elseif v.MassPoints == 2 then
                rawThreat = GetThreatAtPosition(aiBrain, v.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'Structures')
                aiBrain.BrainIntel.ExpansionWatchTable[k]['Structures'] = rawThreat
            end
            if aiBrain.BuilderManagers[v.Name].EngineerManager then
                if aiBrain.BuilderManagers[v.Name].EngineerManager.ConsumptionUnits.Intel.Count > 0 then
                    --LOG('Radar Present')
                    v.Radar = true
                else
                    v.Radar = false
                end
            else
                v.Radar = false
            end
        end
        coroutine.yield(50)
        -- don't do this, it might have a platoon inside it--RNGLOG('Current Expansion Watch Table '..repr(aiBrain.BrainIntel.ExpansionWatchTable))
    end
end



function InitialNavalAttackCheck(aiBrain)
    -- This function will check if there are mass markers that can be hit by frigates. This can trigger faster naval factory builds initially.
    -- points = number of points around the extractor, doesn't need to have too many.
    -- radius = the radius that the points will be, be set this a little lower than a frigates max weapon range
    -- center = the x,y values for the position of the mass extractor. e.g {x = 0, y = 0} 
    local function DrawCirclePoints(points, radius, center)
        local extractorPoints = {}
        local slice = 2 * math.pi / points
        for i=1, points do
            local angle = slice * i
            local newX = center[1] + radius * math.cos(angle)
            local newY = center[3] + radius * math.sin(angle)
            table.insert(extractorPoints, { newX, 0 , newY})
        end
        return extractorPoints
    end
    local frigateRaidMarkers = {}
    local markers = GetMarkersRNG()
    if markers then
        local markerCount = 0
        local markerCountNotBlocked = 0
        local markerCountBlocked = 0
        for _, v in markers do 
            local checkPoints = DrawCirclePoints(6, 26, v.position)
            if checkPoints then
                for _, m in checkPoints do
                    if RUtils.PositionInWater(m) then
                       --RNGLOG('Location '..repr({m[1], m[3]})..' is in water for extractor'..repr({v.position[1], v.position[3]}))
                       --RNGLOG('Surface Height at extractor '..GetSurfaceHeight(v.position[1], v.position[3]))
                       --RNGLOG('Surface height at position '..GetSurfaceHeight(m[1], m[3]))
                        local pointSurfaceHeight = GetSurfaceHeight(m[1], m[3]) + 0.36
                       --RNGLOG('Adjusted checkpoint surface height '..pointSurfaceHeight)
                        markerCount = markerCount + 1
                        if not aiBrain:CheckBlockingTerrain({m[1], pointSurfaceHeight, m[3]}, v.position, 'low') then
                           --RNGLOG('This marker is not blocked '..repr(v.position))
                            markerCountNotBlocked = markerCountNotBlocked + 1
                            table.insert( frigateRaidMarkers, { Position=v.position, Name=v.name } )
                        else
                           --RNGLOG('This marker is blocked '..repr(v.position))
                            markerCountBlocked = markerCountBlocked + 1
                        end
                        break
                    end
                end
            end
        end
       --RNGLOG('There are potentially '..markerCount..' markers that are in range for frigates')
       --RNGLOG('There are '..markerCountNotBlocked..' markers NOT blocked by terrain')
       --RNGLOG('There are '..markerCountBlocked..' markers that ARE blocked')
        --RNGLOG('Markers that frigates can try and raid '..repr(frigateRaidMarkers))
        if markerCountNotBlocked > 8 then
            aiBrain.EnemyIntel.FrigateRaid = true
            --RNGLOG('Frigate Raid is true')
            aiBrain.EnemyIntel.FrigateRaidMarkers = frigateRaidMarkers
        end
    end
end

function CalculateMassValue(expansionMarkers)
    local markerTable = GetMarkersRNG()
    local MassMarker = {}
    local VDist2Sq = VDist2Sq
    if not expansionMarkers then
        WARN('No Expansion Markers Passed to calcuatemassvalue')
    end
    for _, v in markerTable do
        if v.type == 'Mass' then
            table.insert(MassMarker, {Position = v.position})
        end
    end
    for k, v in expansionMarkers do
        local masscount = 0
        for k2, v2 in MassMarker do
            if VDist2Sq(v.Position[1], v.Position[3], v2.Position[1], v2.Position[3]) > 6400 then
                continue
            end
            masscount = masscount + 1
        end        
        -- insert mexcount into marker
        v.MassPoints = masscount
        --SPEW('* AI-RNG: CreateMassCount: Node: '..v.Type..' - MassSpotsInRange: '..v.MassPoints)
    end
    return expansionMarkers
end

function QueryExpansionTable(aiBrain, location, radius, movementLayer, threat, type)
    -- Should be a multipurpose Expansion query that can provide units, acus a place to go
    if not aiBrain.BrainIntel.ExpansionWatchTable then
        WARN('No ExpansionWatchTable. Maybe it hasnt been created yet or something is broken')
        coroutine.yield(50)
        return false
    end
    

    local MainPos = aiBrain.BuilderManagers.MAIN.Position
    if VDist2Sq(location[1], location[3], MainPos[1], MainPos[3]) > 3600 then
        return false
    end
    local positionNode = Scenario.MasterChain._MASTERCHAIN_.Markers[GetClosestPathNodeInRadiusByLayerRNG(location, radius, movementLayer).name]
    local centerPoint = aiBrain.MapCenterPoint
    local mainBaseToCenter = VDist2Sq(MainPos[1], MainPos[3], centerPoint[1], centerPoint[3])
    local bestExpansions = {}
    local options = {}
    local currentGameTime = GetGameTimeSeconds()
    -- Note, the expansions zones are land only. Need to fix this to include amphib zone.
    if positionNode.RNGArea then
        for k, expansion in aiBrain.BrainIntel.ExpansionWatchTable do
            if expansion.Zone == positionNode.RNGArea then
                local expansionDistance = VDist2Sq(location[1], location[3], expansion.Position[1], expansion.Position[3])
                --RNGLOG('Distance to expansion '..expansionDistance)
                --LOG('Expansion position is '..repr(expansion.Position))
                -- Check if this expansion has been staged already in the last 30 seconds unless there is land threat present
                --RNGLOG('Expansion last visited timestamp is '..expansion.TimeStamp)
                if currentGameTime - expansion.TimeStamp > 45 or expansion.Land > 0 or type == 'acu' then
                    if expansionDistance < radius * radius then
                       --RNGLOG('Expansion Zone is within radius')
                        if type == 'acu' or VDist2Sq(MainPos[1], MainPos[3], expansion.Position[1], expansion.Position[3]) < (VDist2Sq(MainPos[1], MainPos[3], centerPoint[1], centerPoint[3]) + 900) then
                           --RNGLOG('Expansion has '..expansion.MassPoints..' mass points')
                           --RNGLOG('Expansion is '..expansion.Name..' at '..repr(expansion.Position))
                            if expansion.MassPoints > 1 then
                                -- Lets ponder this a bit more, the acu is strong, but I don't want him to waste half his hp on civilian PD's
                                if type == 'acu' and GetThreatAtPosition( aiBrain, expansion.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface') > 5 then
                                   --RNGLOG('Threat at location too high for easy building')
                                    continue
                                end
                                if type == 'acu' and GetNumUnitsAroundPoint(aiBrain, categories.MASSEXTRACTION, expansion.Position, 30, 'Ally') >= expansion.MassPoints then
                                   --RNGLOG('ACU Location has enough masspoints to indicate its already taken')
                                    continue
                                end
                                RNGINSERT(options, {Expansion = expansion, Value = expansion.MassPoints * expansion.MassPoints, Key = k, Distance = expansionDistance})
                            end
                        else
                           --RNGLOG('Expansion is beyond the center point')
                           --RNGLOG('Distance from main base to expansion '..VDist2Sq(MainPos[1], MainPos[3], expansion.Position[1], expansion.Position[3]))
                           --RNGLOG('Should be less than ')
                           --RNGLOG('Distance from main base to center point '..VDist2Sq(MainPos[1], MainPos[3], centerPoint[1], centerPoint[3]))
                        end
                    end
                else
                   --RNGLOG('This expansion has already been checked in the last 45 seconds')
                end
            end
        end
       --RNGLOG('Number of options from first cycle '..table.getn(options))
        local optionCount = 0
        
        for k, withinRadius in options do
            if mainBaseToCenter > VDist2Sq(withinRadius.Expansion.Position[1], withinRadius.Expansion.Position[3], centerPoint[1], centerPoint[3]) then
                --RNGLOG('Expansion has high mass value at location '..withinRadius.Expansion.Name..' at position '..repr(withinRadius.Expansion.Position))
                RNGINSERT(bestExpansions, withinRadius)
            else
                --RNGLOG('Expansion is behind the main base , position '..repr(withinRadius.Expansion.Position))
            end
        end
    else
        WARN('No RNGArea in path node, either its not created yet or the marker analysis hasnt happened')
    end
    --RNGLOG('We have '..RNGGETN(bestExpansions)..' expansions to pick from')
    if RNGGETN(bestExpansions) > 0 then
        if type == 'acu' then
            local bestOption = false
            local secondBestOption = false
            local bestValue = 9999999999
            for _, v in options do
                if VDist2Sq(MainPos[1], MainPos[3], v.Expansion.Position[1], v.Expansion.Position[3]) > 10000 then
                    local alreadySecure = false
                    for k, b in aiBrain.BuilderManagers do
                        if k == v.Expansion.Name and RNGGETN(aiBrain.BuilderManagers[k].FactoryManager.FactoryList) > 0 then
                           --RNGLOG('Already a builder manager with factory present, set')
                            alreadySecure = true
                            break
                        end
                    end
                    if alreadySecure then
                       --RNGLOG('Position already secured, ignore and move to next expansion')
                        continue
                    end
                    local expansionValue = v.Distance * v.Distance / v.Value
                    if expansionValue < bestValue then
                        secondBestOption = bestOption
                        bestOption = v
                        bestValue = expansionValue
                    end
                end
            end
            if secondBestOption and bestOption then
                local acuOptions = { bestOption, secondBestOption }
               --RNGLOG('ACU is having a random expansion returned')
                return acuOptions[Random(1,2)]
            end
           --RNGLOG('ACU is having the best expansion returned')

            return bestOption
        else
            return bestExpansions[Random(1,RNGGETN(bestExpansions))] 
        end
    end
    return false
end

CreateReclaimGrid = function(aiBrain)
    coroutine.yield(Random(30,70))
    -- by default, 16x16 iMAP
    local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
    --LOG('playableArea is '..repr(playableArea))
    local n = 16 
    local mx = ScenarioInfo.size[1]
    local mz = ScenarioInfo.size[2]
    local GetTerrainHeight = GetTerrainHeight

    -- smaller maps have a 8x8 iMAP
    if mx == mz and mx == 5 then 
        n = 8
    end
    
    local reclaimGrid = {}
    
    -- distance per cell
    local fx = 1 / n * mx 
    local fz = 1 / n * mz 

    -- draw iMAP information
    for z = 1, n do 
        for x = 1, n do 
            local cx = fx * (x - 0.5)
            local cz = fz * (z - 0.5)
            if cx < playableArea[1] or cz < playableArea[2] or cx > playableArea[3] or cz > playableArea[4] then
                continue
            end
            table.insert(reclaimGrid, { Position = {cx, GetTerrainHeight(cx, cz), cz}, Size = { sx = fx, sz = fz}, TotalReclaim = 0, AirThreat = 0, SurfaceThreat = 0, NavalThreat = 0, LastUpdate = 0 })
        end
    end
    aiBrain.MapReclaimTable = reclaimGrid
end

--[[
    info:   { table: 26D1E5A0 
    info:     AirThreat=0,
    info:     LastUpdate=1556.7000732422,
    info:     NavalThreat=0,
    info:     Position={ table: 26D1EE88  304, 22.96875, 112 },
    info:     Size={ table: 26D1EAA0  sx=32, sz=32 },
    info:     SurfaceThreat=0,
    info:     TotalReclaim=105.40800476074
    info:   },
]]

MapReclaimAnalysis = function(aiBrain)
    -- Loops through map grid squares that roughly match IMAP 
    CreateReclaimGrid(aiBrain)
    coroutine.yield(50)
    while not aiBrain.defeat do
        if aiBrain.ReclaimEnabled then
            local currentGameTime = GetGameTimeSeconds()
            for k, square in aiBrain.MapReclaimTable do
                local reclaimTotal = 0
                local reclaimRaw = GetReclaimablesInRect(square.Position[1] - (square.Size.sx / 2), square.Position[3] - (square.Size.sz / 2), square.Position[1] + (square.Size.sx / 2), square.Position[3] + (square.Size.sz / 2))
                if reclaimRaw and table.getn(reclaimRaw) > 0 then
                    for k,v in reclaimRaw do
                        if not IsProp(v) then continue end
                        if v.MaxMassReclaim and v.MaxMassReclaim > 0 then
                            reclaimTotal = reclaimTotal + v.MaxMassReclaim
                        end
                    end
                end
                square.TotalReclaim = reclaimTotal
                square.LastUpdate = currentGameTime
                coroutine.yield(1)
            end
            local startReclaim = 0
            for k, square in aiBrain.MapReclaimTable do
                if VDist2Sq(aiBrain.BrainIntel.StartPos[1], aiBrain.BrainIntel.StartPos[2], square.Position[1], square.Position[3]) < 14400 then
                    startReclaim = startReclaim + square.TotalReclaim
                end
            end
            aiBrain.StartReclaimCurrent = startReclaim
            --LOG('Current Starting Reclaim is'..aiBrain.StartReclaimCurrent)
        end
        coroutine.yield(300)
    end
end

local LookupAirThreat = { }
local LookupLandThreat = { }

local function GetShieldRadiusAboveGroundSquaredRNG(shield)
    local BP = shield:GetBlueprint().Defense.Shield
    local width = BP.ShieldSize
    local height = BP.ShieldVerticalOffset

    return width * width - height * height
end

local function ShieldProtectingTargetRNG(aiBrain, targetUnit, shields)

    -- if no target unit, then we can skip
    if not targetUnit then
        return false
    end

    -- defensive programming
    shields = shields or GetUnitsAroundPoint(aiBrain, CategoriesShield, targetUnit:GetPosition(), 50, 'Enemy')

    -- determine if target unit is part of some shield
    local tPos = targetUnit:GetPosition()
    for _, shield in shields do
        if not shield.Dead then
            local shieldPos = shield:GetPosition()
            local shieldSizeSq = GetShieldRadiusAboveGroundSquaredRNG(shield)
            if VDist2Sq(tPos[1], tPos[3], shieldPos[1], shieldPos[3]) < shieldSizeSq then
                return true
            end
        end
    end
    return false
end

TacticalThreatAnalysisRNG = function(aiBrain)
    local ALLBPS = __blueprints

    --LOG("Started analysis for: " .. aiBrain.Nickname)
    local startedAnalysisAt = GetSystemTimeSecondsOnlyForProfileUse()

    aiBrain.EnemyIntel.DirectorData = {
        DefenseCluster = {},
        Strategic = {},
        Energy = {},
        Intel = {},
        Defense = {},
        Factory = {},
        Mass = {},
        Combat = {},
    }

    local energyUnits = {}
    local strategicUnits = {}
    local defensiveUnits = {}
    local intelUnits = {}
    local factoryUnits = {}
    local gameTime = GetGameTimeSeconds()
    local scanRadius = 0
    local IMAPSize = 0
    local maxmapdimension = RNGMAX(ScenarioInfo.size[1],ScenarioInfo.size[2])
    aiBrain.EnemyIntel.EnemyFireBaseDetected = false
    aiBrain.EnemyIntel.EnemyAirFireBaseDetected = false
    aiBrain.EnemyIntel.EnemyFireBaseTable = {}

    if maxmapdimension == 256 then
        scanRadius = 11.5
        IMAPSize = 16
    elseif maxmapdimension == 512 then
        scanRadius = 22.5
        IMAPSize = 32
    elseif maxmapdimension == 1024 then
        scanRadius = 45.0
        IMAPSize = 64
    elseif maxmapdimension == 2048 then
        scanRadius = 89.5
        IMAPSize = 128
    else
        scanRadius = 180.0
        IMAPSize = 256
    end

    local v = Vector(0, 0, 0)

    if next(aiBrain.EnemyIntel.EnemyThreatLocations) then

        local LookupAirThreat = { }
        local LookupLandThreat = { }

        -- pre-process all threat to populate lookup tables for anti air and land
        for k, threat in aiBrain.EnemyIntel.EnemyThreatLocations do
            if threat.ThreatType == "AntiAir" then 
                LookupAirThreat[threat.Position[1]] = LookupAirThreat[threat.Position[1]] or { }
                LookupAirThreat[threat.Position[1]][threat.Position[2]] = threat.Threat
            elseif threat.ThreatType == "Land" then 
                LookupLandThreat[threat.Position[1]] = LookupLandThreat[threat.Position[1]] or { }
                LookupLandThreat[threat.Position[1]][threat.Position[2]] = threat.Threat
            end
        end

        for k, threat in aiBrain.EnemyIntel.EnemyThreatLocations do

            -- INFO: threat = { table: 22C1FF50 
            -- INFO:   EnemyBaseRadius=true,
            -- INFO:   InsertTime=676.10003662109,
            -- INFO:   Position={ table: 22C1F168  400, 400 },
            -- INFO:   PositionOnWater=false,
            -- INFO:   Threat=159,
            -- INFO:   ThreatType="StructuresNotMex"
            -- INFO: }

            if (gameTime - threat.InsertTime) < 25 and threat.ThreatType == 'StructuresNotMex' then

                -- position format as used by the engine
                v[1] = threat.Position[1]
                v[2] = 0 
                v[3] = threat.Position[2]

                -- retrieve units and shields that are in or overlap with the iMAP cell
                local unitsAtLocation = GetUnitsAroundPoint(aiBrain, CategoriesStructuresNotMex, v, scanRadius, 'Enemy')
                local shieldsAtLocation = GetUnitsAroundPoint(aiBrain, CategoriesShield, v, 50 + scanRadius, 'Enemy')

                for s, unit in unitsAtLocation do
                    local unitIndex = unit:GetAIBrain():GetArmyIndex()
                    if not ArmyIsCivilian(unitIndex) then
                        if EntityCategoryContains( CategoriesEnergy, unit) then
                            --RNGLOG('Inserting Enemy Energy Structure '..unit.UnitId)
                            RNGINSERT(energyUnits, {
                                EnemyIndex = unitIndex, 
                                Value = ALLBPS[unit.UnitId].Defense.EconomyThreatLevel * 2, 
                                HP = unit:GetHealth(), 
                                Object = unit, 
                                Shielded = ShieldProtectingTargetRNG(aiBrain, unit, shieldsAtLocation), 
                                IMAP = threat.Position, 
                                Air = LookupAirThreat[threat.Position[1]][threat.Position[2]] or 0, 
                                Land = LookupLandThreat[threat.Position[1]][threat.Position[2]] or 0 
                            })
                        elseif EntityCategoryContains( CategoriesDefense, unit) then
                            --RNGLOG('Inserting Enemy Defensive Structure '..unit.UnitId)
                            RNGINSERT(
                                defensiveUnits, { 
                                EnemyIndex = unitIndex, 
                                Value = ALLBPS[unit.UnitId].Defense.EconomyThreatLevel, 
                                HP = unit:GetHealth(), 
                                Object = unit, 
                                Shielded = ShieldProtectingTargetRNG(aiBrain, unit, shieldsAtLocation), 
                                IMAP = threat.Position, 
                                Air = LookupAirThreat[threat.Position[1]][threat.Position[2]] or 0, 
                                Land = LookupLandThreat[threat.Position[1]][threat.Position[2]] or 0 
                            })
                        elseif EntityCategoryContains( CategoriesStrategic, unit) then
                            --RNGLOG('Inserting Enemy Strategic Structure '..unit.UnitId)
                            RNGINSERT(strategicUnits, {
                                EnemyIndex = unitIndex, 
                                Value = ALLBPS[unit.UnitId].Defense.EconomyThreatLevel, 
                                HP = unit:GetHealth(), 
                                Object = unit, 
                                Shielded = ShieldProtectingTargetRNG(aiBrain, unit, shieldsAtLocation), 
                                IMAP = threat.Position, 
                                Air = LookupAirThreat[threat.Position[1]][threat.Position[2]] or 0, 
                                Land = LookupLandThreat[threat.Position[1]][threat.Position[2]] or 0 
                            })
                        elseif EntityCategoryContains( CategoriesIntelligence, unit) then
                            --RNGLOG('Inserting Enemy Intel Structure '..unit.UnitId)
                            RNGINSERT(intelUnits, {
                                EnemyIndex = unitIndex, 
                                Value = ALLBPS[unit.UnitId].Defense.EconomyThreatLevel, 
                                HP = unit:GetHealth(), 
                                Object = unit, 
                                Shielded = ShieldProtectingTargetRNG(aiBrain, unit, shieldsAtLocation), 
                                IMAP = threat.Position, 
                                Air = LookupAirThreat[threat.Position[1]][threat.Position[2]] or 0, 
                                Land = LookupLandThreat[threat.Position[1]][threat.Position[2]] or 0 
                            })
                        elseif EntityCategoryContains( CategoriesFactory, unit) then
                            --RNGLOG('Inserting Enemy Intel Structure '..unit.UnitId)
                            RNGINSERT(factoryUnits, {
                                EnemyIndex = unitIndex, 
                                Value = ALLBPS[unit.UnitId].Defense.EconomyThreatLevel, 
                                HP = unit:GetHealth(), 
                                Object = unit, 
                                Shielded = ShieldProtectingTargetRNG(aiBrain, unit, shieldsAtLocation), 
                                IMAP = threat.Position, 
                                Air = LookupAirThreat[threat.Position[1]][threat.Position[2]] or 0, 
                                Land = LookupLandThreat[threat.Position[1]][threat.Position[2]] or 0 
                            })
                        end
                    end
                end
            end
        end
    end

    if next(defensiveUnits) then
        for k, unit in defensiveUnits do
            for q, threat in aiBrain.EnemyIntel.EnemyThreatLocations do
                if not threat.LandDefStructureCount then
                    threat.LandDefStructureCount = 0
                end
                if not threat.AirDefStructureCount then
                    threat.AirDefStructureCount = 0
                end
                if table.equal(unit.IMAP,threat.Position) and threat.ThreatType == 'AntiAir' then 
                    unit.Air = threat.Threat
                elseif table.equal(unit.IMAP,threat.Position) and threat.ThreatType == 'Land' then
                    unit.Land = threat.Threat
                elseif table.equal(unit.IMAP,threat.Position) and threat.ThreatType == 'StructuresNotMex' then
                    if ALLBPS[unit.Object.UnitId].Defense.SurfaceThreatLevel > 0 then
                        threat.LandDefStructureCount = threat.LandDefStructureCount + 1
                    elseif ALLBPS[unit.Object.UnitId].Defense.AirThreatLevel > 0 then
                        threat.AirDefStructureCount = threat.AirDefStructureCount + 1
                    end
                    if threat.LandDefStructureCount + threat.AirDefStructureCount > 5 then
                        aiBrain.EnemyIntel.EnemyFireBaseDetected = true
                    end
                    if aiBrain.EnemyIntel.EnemyFireBaseDetected then
                        if not aiBrain.EnemyIntel.EnemyFireBaseTable[q] then
                            aiBrain.EnemyIntel.EnemyFireBaseTable[q] = {}
                            aiBrain.EnemyIntel.EnemyFireBaseTable[q] = { 
                                EnemyIndex = unit.EnemyIndex, 
                                Location = {unit.IMAP[1], 0, unit.IMAP[2]}, 
                                Shielded = unit.Shielded, 
                                Air = GetThreatAtPosition(aiBrain, { unit.IMAP[1], 0, unit.IMAP[2] }, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir'), 
                                Land = GetThreatAtPosition(aiBrain, { unit.IMAP[1], 0, unit.IMAP[2] }, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface')
                                }
                        end
                    end
                end
                --LOG('Enemy Threat Location '..q..' Have Land Defensive Structure Count of '..aiBrain.EnemyIntel.EnemyThreatLocations[q].LandDefStructureCount)
                --LOG('Enemy Threat Location '..q..' Have Air Defensive Structure Count of '..aiBrain.EnemyIntel.EnemyThreatLocations[q].AirDefStructureCount)
            end
            --RNGLOG('Enemy Defense Structure has '..unit.Air..' air threat and '..unit.Land..' land threat'..' belonging to energy index '..unit.EnemyIndex)
        end

        local firebaseTable = {}
        for q, threat in aiBrain.EnemyIntel.EnemyThreatLocations do
            local tableEntry = { Position = threat.Position, Land = { Count = 0 }, Air = { Count = 0 }, aggX = 0, aggZ = 0, weight = 0, validated = false}
            if threat.LandDefStructureCount > 0 then
                --LOG('Enemy Threat Location with ID '..q..' has '..threat.LandDefStructureCount..' at imap position '..repr(threat.Position))
                tableEntry.Land = { Count = threat.LandDefStructureCount }
            end
            if threat.AirDefStructureCount > 0 then
                --LOG('Enemy Threat Location with ID '..q..' has '..threat.AirDefStructureCount..' at imap position '..repr(threat.Position))
                tableEntry.Air = { Count = threat.AirDefStructureCount }
            end
            RNGINSERT(firebaseTable, tableEntry)
        end
        local firebaseaggregation = 0
        firebaseaggregationTable = {}
        local complete = RNGGETN(firebaseTable) == 0
        --LOG('Firebase table '..repr(firebaseTable))
        while not complete do
            complete = true
            --LOG('firebase aggregation loop number '..firebaseaggregation)
            for _, v1 in firebaseTable do
                v1.weight = 1
                v1.aggX = v1.Position[1]
                v1.aggZ = v1.Position[2]
            end
            for _, v1 in firebaseTable do
                if not v1.validated then
                    for _, v2 in firebaseTable do
                        if not v2.validated and VDist2Sq(v1.Position[1], v1.Position[2], v2.Position[1], v2.Position[2]) < 3600 then
                            v1.weight = v1.weight + 1
                            v1.aggX = v1.aggX + v2.Position[1]
                            v1.aggZ = v1.aggZ + v2.Position[2]
                        end
                    end
                end
            end
            local best = nil
            for _, v in firebaseTable do
                if (not v.validated) and ((not best) or best.weight < v.weight) then
                    best = v
                end
            end
            local defenseGroup = {Land = best.Land.Count, Air = best.Air.Count}
            best.validated = true
            local x = best.aggX/best.weight
            local z = best.aggZ/best.weight
            for _, v in firebaseTable do
                if (not v.validated) and VDist2Sq(v.Position[1], v.Position[2], best.Position[1], best.Position[2]) < 3600 then
                    defenseGroup.Land = defenseGroup.Land + v.Land.Count
                    defenseGroup.Air = defenseGroup.Air + v.Air.Count
                    v.validated = true
                elseif not v.validated then
                    complete = false
                end
            end
            firebaseaggregation = firebaseaggregation + 1
            RNGINSERT(firebaseaggregationTable, {aggx = x, aggz = z, DefensiveCount = defenseGroup.Land + defenseGroup.Air})
        end

        --LOG('firebaseTable '..repr(firebaseTable))
        for k, v in firebaseaggregationTable do
            if v.DefensiveCount > 5 then
                aiBrain.EnemyIntel.EnemyFireBaseDetected = true
                break
            else
                aiBrain.EnemyIntel.EnemyFireBaseDetected = false
            end
        end
        --LOG('firebaseaggregationTable '..repr(firebaseaggregationTable))
        if aiBrain.EnemyIntel.EnemyFireBaseDetected then
            --LOG('Firebase Detected')
            --LOG('Firebase Table '..repr(self.EnemyIntel.EnemyFireBaseTable))
        end
        aiBrain.EnemyIntel.DirectorData.Defense = defensiveUnits
    end

    -- populate the director
    aiBrain.EnemyIntel.DirectorData.Strategic = strategicUnits
    aiBrain.EnemyIntel.DirectorData.Intel = intelUnits
    aiBrain.EnemyIntel.DirectorData.Factory = factoryUnits
    aiBrain.EnemyIntel.DirectorData.Energy = energyUnits

    --LOG("Finished analysis for: " .. aiBrain.Nickname)
    local finishedAnalysisAt = GetSystemTimeSecondsOnlyForProfileUse()
    --LOG("Time of analysis: " .. (finishedAnalysisAt - startedAnalysisAt))
end
