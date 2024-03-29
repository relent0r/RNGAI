local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local NavUtils = import('/lua/sim/NavUtils.lua')
local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
local GetMarkersRNG = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
local GetClosestPathNodeInRadiusByLayerRNG = import('/lua/AI/aiattackutilities.lua').GetClosestPathNodeInRadiusByLayerRNG
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetThreatBetweenPositions = moho.aibrain_methods.GetThreatBetweenPositions
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetListOfUnits = moho.aibrain_methods.GetListOfUnits
local PlatoonExists = moho.aibrain_methods.PlatoonExists
local MapIntelGridSize = 32


-- pre-compute categories for performance
local CategoriesStructuresNotMex = categories.STRUCTURE - categories.TECH1 - categories.WALL - categories.MASSEXTRACTION
local CategoriesEnergy = categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3 + categories.EXPERIMENTAL)
local CategoriesDefense = categories.DEFENSE * categories.STRUCTURE - categories.WALL - categories.SILO
local CategoriesStrategic = categories.STRATEGIC * (categories.TECH2 + categories.TECH3 + categories.EXPERIMENTAL)
local CategoriesIntelligence = categories.INTELLIGENCE * (categories.TECH2 + categories.TECH3 + categories.EXPERIMENTAL)
local CategoriesFactory = categories.FACTORY * (categories.TECH2 + categories.TECH3 ) - categories.SUPPORTFACTORY - categories.EXPERIMENTAL - categories.CRABEGG - categories.CARRIER
local CategoriesShield = categories.DEFENSE * categories.SHIELD * categories.STRUCTURE
local CategoriesLandDefense = categories.STRUCTURE * categories.DEFENSE * categories.DIRECTFIRE
local CategoriesSMD = categories.TECH3 * categories.ANTIMISSILE * categories.SILO

local ALLBPS = __blueprints

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
local RNGTableEmpty = table.empty
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
        self.MapIntelGridXRes = 0
        self.MapIntelGridZRes = 0
        self.MapIntelGridSize = 0
        self.MapIntelGrid = false
        self.MapIntelStats = {
            ScoutLocationsBuilt = false,
            IntelCoverage = 0,
            MustScoutArea = false,
            PerimeterExpired = false
        }
        self.StrategyFlags = {
            T3BomberRushActivated = false,
            EnemyAirSnipeThreat = false
        }
        self.UnitStats = {
            Land = {
                Deaths = {
                    Total = {
                        Air = 0,
                        Defense = 0,
                        Land = 0,
                        Naval = 0,
                        Experimental = 0,
                        Structure = 0,
                        ACU = 0
                    },
                    OverTime = {
                        Air = 0,
                        Defense = 0,
                        Land = 0,
                        Naval = 0,
                        Experimental = 0,
                        Structure = 0,
                        ACU = 0
                    }
                },
                Kills = {}
            },
            Gunship = {
                Deaths = {
                    Mass = 0
                },
                Kills = {
                    Mass = 0
                },
                Built = {
                    Mass = 0
                },
                Efficiency = 0

            },
            Air = {
                Deaths = {
                    Total = {
                        Air = 0,
                        Defense = 0,
                        Land = 0,
                        Naval = 0,
                        Experimental = 0,
                        Structure = 0,
                        ACU = 0
                    },
                    OverTime = {
                        Air = 0,
                        Defense = 0,
                        Land = 0,
                        Naval = 0,
                        Experimental = 0,
                        Structure = 0,
                        ACU = 0
                    }
                },
                Kills = {}
            },
            Naval = {
                Deaths = {
                    Total = {
                        Air = 0,
                        Defense = 0,
                        Land = 0,
                        Naval = 0,
                        Experimental = 0,
                        Structure = 0,
                        ACU = 0
                    },
                    OverTime = {
                        Air = 0,
                        Defense = 0,
                        Land = 0,
                        Naval = 0,
                        Experimental = 0,
                        Structure = 0,
                        ACU = 0
                    }
                },
                Kills = {}
            },
            Structure = {
                Deaths = {
                    Total = {
                        Air = 0,
                        Defense = 0,
                        Land = 0,
                        Naval = 0,
                        Experimental = 0,
                        Structure = 0,
                        ACU = 0
                    },
                    OverTime = {
                        Air = 0,
                        Defense = 0,
                        Land = 0,
                        Naval = 0,
                        Experimental = 0,
                        Structure = 0,
                        ACU = 0
                    }
                },
                Kills = {}
            },
            Experimental = {
                Deaths = {
                    Total = {
                        Air = 0,
                        Defense = 0,
                        Land = 0,
                        Naval = 0,
                        Experimental = 0,
                        Structure = 0,
                        ACU = 0
                    },
                    OverTime = {
                        Air = 0,
                        Defense = 0,
                        Land = 0,
                        Naval = 0,
                        Experimental = 0,
                        Structure = 0,
                        ACU = 0
                    }
                },
                Kills = {}
            }
        }
        self.EnemyBuildStrength = {
            Total = {
                AirPower = 0,
                LandPower = 0,
                BuildPower = 0
            }
        }
    end,

    Run = function(self)
        --LOG('RNGAI : IntelManager Starting')
        self:ForkThread(self.ZoneEnemyIntelMonitorRNG)
        self:ForkThread(self.ZoneAlertThreadRNG)
        self:ForkThread(self.ZoneFriendlyIntelMonitorRNG)
        self:ForkThread(self.ConfigureResourcePointZoneID)
        self:ForkThread(self.ZoneControlMonitorRNG)
        self:ForkThread(self.ZoneIntelAssignment)
        self:ForkThread(self.EnemyPositionAngleAssignment)
        self:ForkThread(self.IntelGridThread, self.Brain)
        self:ForkThread(self.TacticalIntelCheck)
        if self.Debug then
            self:ForkThread(self.IntelDebugThread)
        end

        --LOG('RNGAI : IntelManager Started')
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

    RebuildTable = function(self, oldtable)
        local temptable = {}
        for k, v in oldtable do
            if v ~= nil then
                if type(k) == 'string' then
                    temptable[k] = v
                else
                    table.insert(temptable, v)
                end
            end
        end
        return temptable
    end,

    IntelDebugThread = function(self)
        self:WaitForZoneInitialization()
        WaitTicks(30)
        while true do
            for _, z in self.Brain.Zones.Land.zones do
                DrawCircle(z.pos,3*z.weight,'b967ff')
                if z.enemylandthreat > 0 then
                    DrawCircle(z.pos,math.max(20,z.enemylandthreat),'d62d20')
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

    WaitForMarkerInfection = function(self)
        --RNGLOG('Wait for marker infection at '..GetGameTimeSeconds())
        while not ScenarioInfo.MarkersInfectedRNG do
            coroutine.yield(20)
        end
        --RNGLOG('Markers infection completed at '..GetGameTimeSeconds())
    end,

    ZoneControlMonitorRNG = function(self)
        -- This is doing the maths stuff on understand the zone control level
        -- The higher the control the more the enemy owns it, the lower the more we do.
        -- So 0 control means we own it, 2 means the enemy owns it
        self:WaitForZoneInitialization()
        local Zones = {
            'Land',
        }
        while self.Brain.Status ~= "Defeat" do
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
                    tempMyControl = tempMyControl / resourcePoints
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
                    tempEnemyControl = tempEnemyControl / resourcePoints
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

    GetClosestZone = function(self, aiBrain, platoon, controlRequired)
        local control = 1
        if PlatoonExists(aiBrain, platoon) then
            local zoneSet = false
            if aiBrain.ZonesInitialized then
                if platoon.MovementLayer == 'Land' or platoon.MovementLayer == 'Amphibious' then
                    zoneSet = self.Brain.Zones.Land.zones
                elseif platoon.MovementLayer == 'Air' then
                    zoneSet = self.Brain.Zones.Air.zones
                end
                local startPosZones = {}
                local platoonPosition = platoon:GetPlatoonPosition()
                local bestZoneDist
                local bestZone
                for k, v in zoneSet do
                    if controlRequired then
                        control = v.control
                    end
                    local dx = platoonPosition[1] - v.pos[1]
                    local dz = platoonPosition[3] - v.pos[3]
                    local zoneDist = dx * dx + dz * dz
                    if (not bestZoneDist or zoneDist < bestZoneDist) and NavUtils.CanPathTo(platoon.MovementLayer, platoonPosition, v.pos) then
                        if controlRequired then
                            if control < 1 then
                                bestZoneDist = zoneDist
                                bestZone = v.id
                            end
                        else
                            bestZoneDist = zoneDist
                            bestZone = v.id
                        end
                    end
                end
                if bestZone then
                    return bestZone
                end
            else
                WARN('Mapping Zones are not initialized, unable to query zone information')
            end
        end
    end,

    SelectZoneRNG = function(self, aiBrain, platoon, type)
        -- Tricky subject. Distance + threat + percentage of zones owned. If own a high value position do we pay more attention to the edges of that zone? 
        --A multiplier to adjacent edges if you would. We know how many and of what tier extractors we have in a zone. Actually getting an engineer to expand by zone would be interesting.
       --RNGLOG('RNGAI : Zone Selection Query Received for '..platoon.BuilderName)
        if PlatoonExists(aiBrain, platoon) then
            local zoneSet
            local zoneSelection = 999
            local selection
            local enemyMexmodifier = 0.1
            local enemyDanger = 1.0
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
                elseif platoon.MovementLayer == 'Water' then
                    zoneSet = self.Brain.Zones.Naval.zones
                end
                if aiBrain:GetCurrentEnemy() then
                    enemyX, enemyZ = aiBrain:GetCurrentEnemy():GetArmyStartPos()
                end
                if not zoneSet then
                    WARN('No zoneSet returns, validate MovementLayer which is '..platoon.MovementLayer)
                    WARN('BuilderName is '..platoon.BuilderName)
                    WARN('Plan is '..platoon.PlanName)
                    coroutine.yield(20)
                    return false
                end

                if type == 'raid' then
                    --RNGLOG('RNGAI : Zone Raid Selection Query Processing')
                    local startPosZones = {}
                    local platoonPosition = platoon:GetPlatoonPosition()
                    for k, v in aiBrain.Zones.Land.zones do
                        if not v.startpositionclose then
                            if platoonPosition then
                                local compare
                                local enemyDistanceModifier = VDist2(aiBrain.Zones.Land.zones[v.id].pos[1],aiBrain.Zones.Land.zones[v.id].pos[3],enemyX, enemyZ)
                                local zoneDistanceModifier = VDist2(aiBrain.Zones.Land.zones[v.id].pos[1],aiBrain.Zones.Land.zones[v.id].pos[3],platoonPosition[1], platoonPosition[3])
                                local enemyModifier = aiBrain.Zones.Land.zones[v.id].enemylandthreat
                                if not zoneSet[v.id].control then
                                    --RNGLOG('control is nil, here is the table '..repr(zoneSet[v.id]))
                                end
                                if enemyModifier > 0 then
                                    enemyModifier = enemyModifier * 10
                                end
                                --RNGLOG('Start Distance Calculation '..( 20000 / enemyDistanceModifier )..' Zone Distance Calculation'..(20000 / zoneDistanceModifier)..' Resource Value '..zoneSet[v.id].resourcevalue..' Control Value '..zoneSet[v.id].control)
                                --RNGLOG('Friendly threat at zone is '..zoneSet[v.id].friendlythreat)
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
                                        --RNGLOG('Zone Query Select priority 1st pass'..selection)
                                        --RNGLOG('Zone target location is '..repr(zoneSet[v.id].pos))
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
                                --RNGLOG('Start Distance Calculation '..( 20000 / enemyDistanceModifier )..' Zone Distance Calculation'..(20000 / zoneDistanceModifier)..' Resource Value '..zoneSet[v.id].resourcevalue..' Control Value '..zoneSet[v.id].control)
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
                                        --RNGLOG('Zone target location is '..repr(zoneSet[v.id].pos))
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
                    for k, v in aiBrain.Zones.Land.zones do
                        local distanceModifier = VDist3(aiBrain.Zones.Land.zones[v.id].pos,aiBrain.BrainIntel.StartPos)
                        local enemyModifier = 1
                        local startPos = 1
                        local antiairdesire = 1
                        if zoneSet[v.id].enemylandthreat > 0 then
                            enemyModifier = enemyModifier + 2
                        end
                        if zoneSet[v.id].friendlythreat > 0 then
                            if zoneSet[v.id].enemylandthreat == 0 or zoneSet[v.id].enemylandthreat < zoneSet[v.id].friendlythreat then
                                enemyModifier = enemyModifier - 1
                            else
                                enemyModifier = enemyModifier + 1
                            end
                        end
                        if enemyModifier < 0 then
                            enemyModifier = 0.5
                        end
                        local controlValue = zoneSet[v.id].control
                        if controlValue <= 0 then
                            controlValue = 0.5
                        end
                        local resourceValue = zoneSet[v.id].resourcevalue or 1
                        if resourceValue then
                           --RNGLOG('Current platoon zone '..platoon.Zone..' target zone is '..v.zone.id..' enemythreat is '..zoneSet[v.zone.id].enemylandthreat..' friendly threat is '..zoneSet[v.zone.id].friendlythreat)
                           --RNGLOG('Distance Calculation '..( 20000 / distanceModifier )..' Resource Value '..resourceValue..' Control Value '..controlValue..' position '..repr(zoneSet[v.zone.id].pos)..' Enemy Modifier is '..enemyModifier)
                        else
                            --RNGLOG('No resource against zone '..v.zone.id)
                        end
                        if zoneSet[v.id].startpositionclose then
                            startPos = 0.7
                        end
                        if zoneSet[v.id].enemylandthreat > zoneSet[v.id].friendlythreat then
                            if platoon.CurrentPlatoonThreat and platoon.CurrentPlatoonThreat < zoneSet[v.id].enemylandthreat then
                                enemyDanger = 0.4
                            end
                        end
                        if  zoneSet[v.id].friendlyantiairthreat > 5 then
                            antiairdesire = 0.5
                        end
                       --[[ if aiBrain.RNGDEBUG then
                            if distanceModifier and resourceValue and controlValue and enemyModifier then
                                RNGLOG('distanceModifier '..distanceModifier)
                                RNGLOG('resourceValue '..resourceValue)
                                RNGLOG('controlValue '..controlValue)
                                RNGLOG('enemyModifier '..enemyModifier)
                            end
                        end]]
                        compare = ( 20000 / distanceModifier ) * resourceValue * controlValue * enemyModifier * startPos * enemyDanger * antiairdesire
                        if aiBrain.RNGDEBUG and compare then
                            --RNGLOG('Compare variable '..compare)
                        end
                        if compare > 0 then
                            if not selection or compare > selection then
                                selection = compare
                                zoneSelection = v.id
                               --RNGLOG('Zone Control Query Select priority '..selection)
                            end
                        end
                    end
                    if not selection then
                        for k, v in aiBrain.Zones.Land.zones do
                            if not v.startpositionclose then
                                local distanceModifier = VDist2(aiBrain.Zones.Land.zones[v.id].pos[1],aiBrain.Zones.Land.zones[v.id].pos[3],enemyX, enemyZ)
                                local enemyModifier = 1
                                if zoneSet[v.id].enemylandthreat > 0 then
                                    enemyModifier = enemyModifier + 2
                                end
                                if zoneSet[v.id].friendlythreat > 0 then
                                    if zoneSet[v.id].enemylandthreat < zoneSet[v.id].friendlythreat then
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
                                local resourceValue = zoneSet[v.id].resourcevalue or 1
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
                elseif type == 'aadefense' then
                    --local selfThreat = aiBrain.BrainIntel.SelfThreat
                    --local enemyThreat = aiBrain.EnemyIntel.EnemyThreatCurrent
                    --local zoneCount = aiBrain.BuilderManagers['MAIN'].PathableZones.PathableZoneCount
                    --local totalMobileAARequired = math.ceil(zoneCount * (enemyThreat.Air / selfThreat.AirNow)) or 1
                    --local threatRequired
                    local compare = 0
                   --RNGLOG('RNGAI : Zone Control Selection Query Processing First Pass')
                    for k, v in aiBrain.Zones.Land.zones do
                        local distanceModifier = VDist3(aiBrain.Zones.Land.zones[v.id].pos, aiBrain.BrainIntel.StartPos)
                        local enemyModifier = 1
                        local startPos = 1
            
                        if zoneSet[v.id].friendlythreat > 0 and zoneSet[v.id].enemylandthreat > zoneSet[v.id].friendlythreat then
                            enemyModifier = enemyModifier + 0.5
                        end
                        enemyModifier = math.max(enemyModifier, 1.0)  -- Ensure enemyModifier is not less than 1
                        local controlValue = math.min(math.max(zoneSet[v.id].control, 0), 1.75)  -- Clamp controlValue between 0 and 1.75
                        local resourceValue = zoneSet[v.id].resourcevalue or 1
                        if zoneSet[v.id].startpositionclose then
                            startPos = 0.7
                        end
                
                        if zoneSet[v.id].enemylandthreat > zoneSet[v.id].friendlythreat then
                            enemyDanger = 0.4
                        end
                
                        if platoon.Zone == v.id and zoneSet[v.id].enemyairthreat == 0 then
                            enemyDanger = 0
                        end
                
                        compare = (20000 / distanceModifier) * resourceValue * controlValue * enemyModifier * startPos * enemyDanger
                
                        if compare > selection then
                            selection = compare
                            zoneSelection = v.id
                        end
                    end
                    if zoneSelection then
                        return zoneSelection
                    else
                        RNGLOG('RNGAI: Zone Control Defense Selection Query did not select zone')
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
        while self.Brain.Status ~= "Defeat" do
            for k, v in Zones do
                for k1, v1 in self.Brain.Zones[v].zones do
                    if not v1.startpositionclose and v1.control < 1 and v1.enemylandthreat > 0 then
                        --RNGLOG('Try create zone alert for threat')
                        self.Brain:BaseMonitorZoneThreatRNG(v1.id, v1.enemylandthreat)
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
        while self.Brain.Status ~= "Defeat" do
            for k, v in Zones do
                for k1, v1 in self.Brain.Zones[v].zones do
                    self.Brain.Zones.Land.zones[k1].enemylandthreat = GetThreatAtPosition(self.Brain, v1.pos, self.Brain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface')
                    self.Brain.Zones.Land.zones[k1].enemyantiairthreat = GetThreatAtPosition(self.Brain, v1.pos, self.Brain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
                    self.Brain.Zones.Land.zones[k1].enemyairthreat = GetThreatAtPosition(self.Brain, v1.pos, self.Brain.BrainIntel.IMAPConfig.Rings, true, 'Air')
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
        while self.Brain.Status ~= "Defeat" do
            local Zones = {
                'Land',
            }
            local AlliedPlatoons = self.Brain:GetPlatoonsList()
            for k, v in Zones do
                local friendlyThreat = {}
                local friendlyantiairthreat = {}
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
                        if v1.Zone and v1.CurrentPlatoonThreatAntiAir then
                            if not friendlyantiairthreat[v1.Zone] then
                                friendlyantiairthreat[v1.Zone] = 0
                            end
                            friendlyantiairthreat[v1.Zone] = friendlyantiairthreat[v1.Zone] + v1.CurrentPlatoonThreatAntiAir
                        end
                    end
                end
                for k2, v2 in self.Brain.Zones[v].zones do
                    for k3, v3 in friendlyThreat do
                        if k2 == k3 then
                            self.Brain.Zones[v].zones[k2].friendlythreat = v3
                        end
                    end
                    for k3, v3 in friendlyantiairthreat do
                        if k2 == k3 then
                            self.Brain.Zones[v].zones[k2].friendlyantiairthreat = v3
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
        local intelRadius = unit.Blueprint.Intel.RadarRadius * unit.Blueprint.Intel.RadarRadius
        local radarPosition = unit:GetPosition()
        if unit.Blueprint.CategoriesHash.RADAR then
            --RNGLOG('Zone set for radar that has been built '..unit.UnitId)
            unit.zoneid = MAP:GetZoneID(radarPosition,self.Brain.Zones.Land.index)
            if unit.zoneid then
                for k, v in self.ZoneIntel.Assignment do
                    if VDist3Sq(radarPosition, v.Position) < intelRadius then
                        --RNGLOG('Radar coverage has been set true for zone '..unit.zoneid)
                        RNGINSERT(v.RadarUnits, unit)
                        v.RadarCoverage = true
                    end
                end
            else
                WARN('No ZoneID for Radar, unable to set coverage area')
            end
            local gridSearch = math.floor(unit.Blueprint.Intel.RadarRadius / MapIntelGridSize)
            --RNGLOG('GridSearch for IntelCoverage is '..gridSearch)
            self:InfectGridPosition(radarPosition, gridSearch, 'Radar', 'IntelCoverage', true, unit)
        end
    end,

    UnassignIntelUnit = function(self, unit)
        local radarPosition = unit:GetPosition()
        if unit.Blueprint.CategoriesHash.RADAR then
            --RNGLOG('Unassigning Radar Unit')
            for k, v in self.ZoneIntel.Assignment do
                for c, b in v.RadarUnits do
                    if b == unit then
                        --RNGLOG('Found Radar that was covering zone '..k..' removing')
                        RNGREMOVE(v.RadarUnits, c)
                    end
                end
                if v.RadarCoverage and RNGGETN(v.RadarUnits) == 0 then
                    --RNGLOG('No Radars in range for zone '..k..' setting radar coverage to false')
                    v.RadarCoverage = false
                end
            end
            local gridSearch = math.floor(unit.Blueprint.Intel.RadarRadius / MapIntelGridSize)
            self:DisinfectGridPosition(radarPosition, gridSearch, 'Radar', 'IntelCoverage', false, unit)
        end
    end,

    TacticalIntelCheck = function(self)
        coroutine.yield(300)
        while self.Brain.Status ~= "Defeat" do
            coroutine.yield(50)
            self:ForkThread(self.AdaptiveProductionThread, 'AirAntiSurface',false, 20)
            self:ForkThread(self.AdaptiveProductionThread, 'DefensiveAntiSurface')
            self:ForkThread(self.AdaptiveProductionThread, 'LandAntiSurface')
            self:ForkThread(self.AdaptiveProductionThread, 'AirAntiNaval',false,  20)
            self:ForkThread(self.AdaptiveProductionThread, 'MobileAntiAir',false,  20)
        end
    end,

    ZoneIntelAssignment = function(self)
        -- Will setup table for scout assignment to zones
        -- I did this because I didn't want to assign units directly to the zones since it makes it hard to troubleshoot
        -- replaces the previous expansion scout assignment so that all mass points can be monitored
        -- Will also set data for intel based scout production.
        
        self:WaitForZoneInitialization()
        coroutine.yield(Random(5,20))
        local Zones = {
            'Land',
        }
        for k, v in Zones do
            for k1, v1 in self.Brain.Zones[v].zones do
                self.ZoneIntel.Assignment[k1] = { Zone = k1, Position = v1.pos, RadarCoverage = false, RadarUnits = { }, ScoutUnit = false, StartPosition = v1.startpositionclose}
            end
        end
        RNGLOG('Zone Intel Assignment Complete')
        --RNGLOG('Initial Zone Assignment Table '..repr(self.ZoneIntel.Assignment))
    end,

    EnemyPositionAngleAssignment = function(self)
        self:WaitForZoneInitialization()
        self:WaitForMarkerInfection()
        WaitTicks(100)
        self:SetTeamDistanceCheck()
        if not RNGTableEmpty(self.Brain.Zones.Land.zones) then
            if not RNGTableEmpty(self.Brain.EnemyIntel.EnemyStartLocations) then
                for k, v in self.Brain.EnemyIntel.EnemyStartLocations do
                    for c, b in self.Brain.Zones.Land.zones do
                        b.enemystartdata[v.Index] = { }
                        b.enemystartdata[v.Index].startangle = RUtils.GetAngleToPosition(v.Position, b.pos)
                        b.enemystartdata[v.Index].startdistance = VDist3Sq(v.Position, b.pos)
                        
                    end
                end
            end
            if not RNGTableEmpty(self.Brain.BrainIntel.AllyStartLocations) then
                for k, v in self.Brain.BrainIntel.AllyStartLocations do
                    for c, b in self.Brain.Zones.Land.zones do
                        b.allystartdata[v.Index] = { }
                        b.allystartdata[v.Index].startangle = RUtils.GetAngleToPosition(v.Position, b.pos)
                        b.allystartdata[v.Index].startdistance = VDist3Sq(v.Position, b.pos)
                    end
                end
            end
        end
        
        if self.Brain.RNGDEBUG then
            for c, b in self.Brain.Zones.Land.zones do
                RNGLOG('-- Zone Angle Loop --')
                RNGLOG('Zone Position : '..repr(b.pos))
                for v, n in b.enemystartdata do
                    RNGLOG('Player Index '..v)
                    RNGLOG('Start Angle : '..repr(n.startangle))
                    RNGLOG('Start Distance : '..repr(n.startdistance))
                end
                RNGLOG('---------------------')
            end
        end
    end,

    SetTeamDistanceCheck = function(self)
        local furtherestPlayer = false
        local selfIndex = self.Brain:GetArmyIndex()
        if self.Brain.BrainIntel.AllyCount > 2 and self.Brain.EnemyIntel.EnemyCount > 0 then
            local closestIndex
            local closestDistance
            local furtherestPlayerDistance
            --LOG('EnemyStartLocations'..repr(self.Brain.EnemyIntel.EnemyStartLocations))

            for _, b in self.Brain.EnemyIntel.EnemyStartLocations do
                if not closestIndex or b.Distance < closestDistance then
                    --LOG('No index or distance is closer '..repr(b))
                    closestDistance = b.Distance
                    closestIndex = b.Index
                end
            end
            --RNGLOG('Closest enemy is index '..repr(closestIndex)..' at '..repr(closestDistance))
            for _, v in self.Brain.BrainIntel.AllyStartLocations do
                if v.Index ~= selfIndex and (not furtherestPlayerDistance or closestDistance > furtherestPlayerDistance) then
                    furtherestPlayerDistance = VDist3Sq(v.Position, self.Brain.EnemyIntel.EnemyStartLocations[closestIndex].Position)
                end
            end
            if closestDistance and furtherestPlayerDistance and closestDistance > furtherestPlayerDistance then
                if math.sqrt(closestDistance) - math.sqrt(furtherestPlayerDistance) > 50 then
                    --RNGLOG('We are the futherest') 
                    --RNGLOG('The difference between positions is '..(math.sqrt(closestDistance) - math.sqrt(furtherestPlayerDistance)))
                    furtherestPlayer = true
                    self.Brain.BrainIntel.AirPlayer = true
                end
            end
            if not furtherestPlayer then
                --RNGLOG('We are not the furtherest, start position is '..repr(self.Brain.BrainIntel.StartPos))
                --RNGLOG('The difference between positions is '..(closestDistance - furtherestPlayerDistance))
            end
        end
    end,

    IntelGridThread = function(self, aiBrain)
        while not self.MapIntelGrid do
            coroutine.yield(30)
        end
        while aiBrain.Status ~= "Defeat" do
            coroutine.yield(20)
            local intelCoverage = 0
            local mapOwnership = 0
            local mustScoutPresent = false
            local perimeterExpired = false
            for i=self.MapIntelGridXMin, self.MapIntelGridXMax do
                local time = GetGameTimeSeconds()
                for k=self.MapIntelGridZMin, self.MapIntelGridZMax do
                    if self.MapIntelGrid[i][k].MustScout and (not self.MapIntelGrid[i][k].ScoutAssigned or self.MapIntelGrid[i][k].ScoutAssigned.Dead) then
                        --RNGLOG('mustScoutPresent in '..i..k)
                        --RNGLOG(repr(self.MapIntelGrid[i][k]))
                        mustScoutPresent = true
                    end
                    if self.MapIntelGrid[i][k].Enabled and not self.MapIntelGrid[i][k].Water then
                        self.MapIntelGrid[i][k].TimeScouted = time - self.MapIntelGrid[i][k].LastScouted
                        if self.MapIntelGrid[i][k].IntelCoverage or (self.MapIntelGrid[i][k].ScoutPriority > 0 and self.MapIntelGrid[i][k].TimeScouted ~= 0 and self.MapIntelGrid[i][k].TimeScouted < 120) then
                            intelCoverage = intelCoverage + 1
                        end
                    end
                    if self.MapIntelGrid[i][k].Perimeter == 'Restricted' and self.MapIntelGrid[i][k].TimeScouted > 180 and self.MapIntelGrid[i][k].Graphs['MAIN'].Land then
                        perimeterExpired = true
                    end
                    if not table.empty(self.MapIntelGrid[i][k].EnemyUnits) then
                        for c,b in self.MapIntelGrid[i][k].EnemyUnits do
                            if (b.object and b.object.Dead) then
                                self.MapIntelGrid[i][k].EnemyUnits[c]=nil
                            elseif time-b.time>120 or (time-b.time>15 and GetNumUnitsAroundPoint(aiBrain,categories.MOBILE,b.Position,20,'Ally')>3) then
                                self.MapIntelGrid[i][k].EnemyUnits[c].recent=false
                            end
                        end
                    end
                    local cellStatus = self.Brain.GridPresence:GetInferredStatus(self.MapIntelGrid[i][k].Position)
                    if cellStatus == 'Allied' then
                        mapOwnership = mapOwnership + 1
                    end
                end
                coroutine.yield(1)
            end
            self.MapIntelStats.IntelCoverage = intelCoverage / (self.MapIntelGridXRes * self.MapIntelGridZRes) * 100
            self.MapIntelStats.MustScoutArea = mustScoutPresent
            self.MapIntelStats.PerimeterExpired = perimeterExpired
            self.Brain.BrainIntel.MapOwnership = mapOwnership / self.Brain.IntelManager.CellCount * 100
            if aiBrain.RNGDEBUG then
                if mustScoutPresent then
                    RNGLOG('mustScoutPresent is true after loop')
                else
                    RNGLOG('mustScoutPresent is false after loop')
                end
                if perimeterExpired then
                    RNGLOG('perimeterExpired is true after loop')
                else
                    RNGLOG('perimeterExpired is false after loop')
                end
            end
            --LOG('Current Map ownership '..self.Brain.BrainIntel.MapOwnership)
        end
    end,

    IntelGridSetGraph = function(self, locationType, x, z, startPos, endPos)
        if (not startPos) or (not endPos) then
            WARN('IntelGridSetGraph start or end position was nil')
            return
        end
        if not self.MapIntelGrid[x][z].Graphs[locationType] then
            self.MapIntelGrid[x][z].Graphs[locationType] = { GraphChecked = false, Land = false, Amphibious = false, NoGraph = false}
        end
        if not self.MapIntelGrid[x][z].Graphs[locationType].GraphChecked then
            --[[
            local success, reason = navutils.CanPathTo('land', startPos, endPos)
            if success then
                RNGLOG('NavUtils CanPathTo returned true '..repr(endPos))
            else
                RNGLOG('NavUtils CanPathTo returned false '..repr(endPos))
                RNGLOG('Reason is '..reason)
            end]]

            if NavUtils.CanPathTo('Land', startPos, endPos) then
                self.MapIntelGrid[x][z].Graphs[locationType].Land = true
                self.MapIntelGrid[x][z].Graphs[locationType].Amphibious = true
                self.MapIntelGrid[x][z].Graphs[locationType].GraphChecked = true
            elseif NavUtils.CanPathTo('Amphibious', startPos, endPos) then
                self.MapIntelGrid[x][z].Graphs[locationType].Amphibious = true
                self.MapIntelGrid[x][z].Graphs[locationType].GraphChecked = true
            else
                self.MapIntelGrid[x][z].Graphs[locationType].NoGraph = true
                self.MapIntelGrid[x][z].Graphs[locationType].GraphChecked = true
            end
        end
    end,

    DrawInfection = function(self, position)
        --RNGLOG('Draw Target Radius points')
        local counter = 0
        while counter < 60 do
            DrawCircle(position, 10, 'cc0000')
            counter = counter + 1
            coroutine.yield( 2 )
        end
    end,

    InfectGridPosition = function (self, position, gridSize, type, property, value, unit)
        local gridX, gridZ = self:GetIntelGrid(position)
        local gridsSet = 0
        --RNGLOG('Infecting Grid Positions, grid size is '..gridSize)
        if type == 'Radar' then
            self.MapIntelGrid[gridX][gridZ].Radars[unit.EntityId] = {}
            self.MapIntelGrid[gridX][gridZ].Radars[unit.EntityId] = unit
            self.MapIntelGrid[gridX][gridZ].IntelCoverage = true
            --self.Brain:ForkThread(self.DrawInfection, self.MapIntelGrid[gridX][gridZ].Position)
            gridsSet = gridsSet + 1
        end
        for x = math.max(self.MapIntelGridXMin, gridX - gridSize), math.min(self.MapIntelGridXMax, gridX + gridSize), 1 do
            for z = math.max(self.MapIntelGridZMin, gridZ - gridSize), math.min(self.MapIntelGridZMax, gridZ + gridSize), 1 do
                self.MapIntelGrid[x][z][property] = value
                if type == 'Radar' then
                    self.MapIntelGrid[x][z].Radars[unit.EntityId] = {}
                    self.MapIntelGrid[x][z].Radars[unit.EntityId] = unit
                end
                --self.Brain:ForkThread(self.DrawInfection, self.MapIntelGrid[x][z].Position)
                gridsSet = gridsSet + 1
            end
        end
        --RNGLOG('Number of grids set '..gridsSet..'with property '..property..' with the value '..repr(value))
    end,

    DisinfectGridPosition = function (self, position, gridSize, type, property, value, unit)
        local gridX, gridZ = self:GetIntelGrid(position)
        local gridsSet = 0
        local intelRadius
        local needSort = false
        --RNGLOG('Disinfecting Grid Positions, grid size is '..gridSize)
        if type == 'Radar' then
            self.MapIntelGrid[gridX][gridZ].Radars[unit.EntityId] = nil
            needSort = true
            local radarCoverage = false
            for k, v in self.MapIntelGrid[gridX][gridZ].Radars do
                if v and not v.Dead then
                    radarCoverage = true
                    break
                end
            end
            if needSort then
                self.MapIntelGrid[gridX][gridZ].Radars = self:RebuildTable(self.MapIntelGrid[gridX][gridZ].Radars)
            end
            if not radarCoverage then
                self.MapIntelGrid[gridX][gridZ][property] = value
            end
            --self.Brain:ForkThread(self.DrawInfection, self.MapIntelGrid[gridX][gridZ].Position)
            gridsSet = gridsSet + 1
        end
        for x = math.max(1, gridX - gridSize), math.min(self.MapIntelGridXRes, gridX + gridSize) do
            for z = math.max(1, gridZ - gridSize), math.min(self.MapIntelGridZRes, gridZ + gridSize) do
                if type == 'Radar' then
                    --RNGLOG('Check for another radar and then confirm radius is same or greater?')
                    local radarCoverage = false
                    for k, v in self.MapIntelGrid[x][z].Radars do
                        if v and not v.Dead then
                            --RNGLOG('Found another radar, dont set this grid to false')
                            radarCoverage = true
                            break
                        end
                    end
                    if not radarCoverage then
                        self.MapIntelGrid[x][z][property] = value
                    end
                end
                --self.Brain:ForkThread(self.DrawInfection, self.MapIntelGrid[x][z].Position)
                gridsSet = gridsSet + 1
            end
        end
        --RNGLOG('Number of grids set '..gridsSet..'with property '..property..' with the value '..repr(value))
    end,

    GetIntelGrid = function(self, Position)
        --Base level segment numbers
        if Position[1] then
            --RNGLOG('GetIntelGrid Position is '..repr(Position))
            local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
            --LOG('Temp log for GetPathingSegmentFromPosition: tPosition='..repru((tPosition or {'nil'}))..'; rPlayableArea='..repru((rPlayableArea or {'nil'})))
            --LOG('iBaseSegmentSize='..(iBaseSegmentSize or 'nil'))
            --RNGLOG('Grid Size '..MapIntelGridSize)
            local gridx = math.floor((Position[1] - playableArea[1]) / MapIntelGridSize) + 1
            local gridy = math.floor((Position[3] - playableArea[2]) / MapIntelGridSize) + 1
            --RNGLOG('Grid return X '..gridx..' Y '..gridy)
            --RNGLOG('Unit Position '..repr(Position))
            --RNGLOG('Attempt to return grid location '..repr(self.MapIntelGrid[gridx][gridy]))
    
            return math.floor( (Position[1] - playableArea[1]) / MapIntelGridSize) + self.MapIntelGridXMin, math.floor((Position[3] - playableArea[2]) / MapIntelGridSize) + self.MapIntelGridZMin
        end
        return false, false
    end,

    AdaptiveProductionThread = function(self, type, desiredStrikeDamage, threatMax)
        local baseRestrictedArea = self.Brain.OperatingAreas['BaseRestrictedArea']
        local baseMilitaryArea = self.Brain.OperatingAreas['BaseMilitaryArea']
        local Zones = {
            'Land',
        }
        local factionIndex = self.Brain:GetFactionIndex()
        local gameTime = GetGameTimeSeconds()
        local threatType
        local minimumExtractorTier
        local desiredStrikeDamage = 0
        local potentialStrikes = {}
        local minThreatRisk = 0
        local abortZone = true
        if type == 'AirAntiSurface' then
            threatType = 'AntiAir'
            minimumExtractorTier = 2
        end
        if type == 'AirAntiNaval' then
            threatType = 'AntiAir'
            minimumExtractorTier = 2
        end
        -- note to self. When dividing using vdist3sq the division also needs to be squared. e.g instead of divide by 3, divide by 9.
        if type == 'AirAntiSurface' then
            --RNGLOG('self.Brain.BrainIntel.SelfThreat.AirNow '..self.Brain.BrainIntel.SelfThreat.AirNow)
            --RNGLOG('self.Brain.EnemyIntel.EnemyThreatCurrent.Air '..self.Brain.EnemyIntel.EnemyThreatCurrent.Air)
            if self.Brain.BrainIntel.SelfThreat.AirNow > self.Brain.EnemyIntel.EnemyThreatCurrent.Air * 1.5 then
                minThreatRisk = 80
            elseif self.Brain.BrainIntel.SelfThreat.AirNow > self.Brain.EnemyIntel.EnemyThreatCurrent.Air then
                minThreatRisk = 50
            elseif self.Brain.BrainIntel.SelfThreat.AirNow * 1.5 > self.Brain.EnemyIntel.EnemyThreatCurrent.Air then
                minThreatRisk = 25
            end
            if minThreatRisk > 0 then
                for k, v in self.Brain.EnemyIntel.ACU do
                    if (not v.Unit.Dead) and (not v.Ally) and v.HP ~= 0 and v.Position[1] and v.LastSpotted + 120 > gameTime then
                        if v.HP < 12000 and minThreatRisk >= 50 and VDist3Sq(v.Position, self.Brain.BrainIntel.StartPos) < (self.Brain.EnemyIntel.ClosestEnemyBase / 4.84) then
                            if GetThreatBetweenPositions(self.Brain, self.Brain.BrainIntel.StartPos, v.Position, nil, threatType) < 5 then
                                --RNGLOG('ACU ClosestEnemy base distance is '..(self.Brain.EnemyIntel.ClosestEnemyBase /2))
                                --RNGLOG('ACU Distance from start position '..VDist3Sq(v.Position, self.Brain.BrainIntel.StartPos))
                                local gridX, gridZ = self:GetIntelGrid(v.Position)
                                local scoutRequired = true
                                if self.MapIntelGrid[gridX][gridZ].MustScout and self.MapIntelGrid[gridX][gridZ].ACUIndexes[k] then
                                    scoutRequired = false
                                end
                                if scoutRequired then
                                    self.MapIntelGrid[gridX][gridZ].MustScout = true
                                    self.MapIntelGrid[gridX][gridZ].ACUIndexes[k] = true
                                    --RNGLOG('ScoutRequired for EnemyIntel.ACU '..repr(self.MapIntelGrid[gridX][gridY]))
                                end
                                if v.HP < 6000 then
                                    desiredStrikeDamage = desiredStrikeDamage + v.HP + 1000
                                else
                                    desiredStrikeDamage = desiredStrikeDamage + 6000
                                end
                                --RNGLOG('Adding ACU to potential strike target')
                                table.insert( potentialStrikes, { GridID = {GridX = gridX, GridZ = gridZ}, Position = self.MapIntelGrid[gridX][gridZ].Position, Type = 'ACU', Index = k} )
                            end
                        elseif v.HP < 7000 and self.Brain.BrainIntel.AirPhase == 3 then
                            local gridX, gridZ = self:GetIntelGrid(v.Position)
                            local scoutRequired = true
                            if self.MapIntelGrid[gridX][gridZ].MustScout and self.MapIntelGrid[gridX][gridZ].ACUIndexes[k] then
                                scoutRequired = false
                            end
                            if scoutRequired then
                                self.MapIntelGrid[gridX][gridZ].MustScout = true
                                self.MapIntelGrid[gridX][gridZ].ACUIndexes[k] = true
                                --RNGLOG('ScoutRequired for EnemyIntel.ACU '..repr(self.MapIntelGrid[gridX][gridY]))
                            end
                            if v.HP < 6000 then
                                desiredStrikeDamage = desiredStrikeDamage + v.HP + 1000
                            else
                                desiredStrikeDamage = desiredStrikeDamage + 6000
                            end
                            --RNGLOG('Adding ACU to potential strike target')
                            table.insert( potentialStrikes, { GridID = {GridX = gridX, GridZ = gridZ}, Position = self.MapIntelGrid[gridX][gridZ].Position, Type = 'ACU', Index = k} )
                        end
                    end
                end
                   
                for k, v in Zones do
                    for k1, v1 in self.Brain.Zones[v].zones do
                        if minimumExtractorTier >= 2 then
                            if self.Brain.emanager.mex[v1.id].T2 > 0 or self.Brain.emanager.mex[v1.id].T3 > 0 then
                                --RNGLOG('Enemy has T2+ mexes in zone')
                                --RNGLOG('Enemystartdata '..repr(v1.enemystartdata))
                                if type == 'AirAntiSurface' then
                                    if minThreatRisk < 60 then
                                        for c, b in v1.enemystartdata do
                                            if b.startdistance > baseRestrictedArea * baseRestrictedArea then
                                                abortZone = false
                                            end
                                        end
                                    end
                                    if not abortZone then
                                        if v1.enemyantiairthreat < threatMax then
                                            --RNGLOG('Zone air threat level below max')
                                            if GetThreatBetweenPositions(self.Brain, self.Brain.BrainIntel.StartPos, v1.pos, nil, threatType) < threatMax * 2 then
                                                --RNGLOG('Zone air threat between points below max')
                                                --RNGLOG('Adding zone as potential strike target')
                                                table.insert( potentialStrikes, { ZoneID = v1.id, Position = v1.pos, Type = 'Zone'} )
                                                desiredStrikeDamage = desiredStrikeDamage + (v1.resourcevalue * 200)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        coroutine.yield(1)
                    end
                end
            end
        elseif type == 'DefensiveAntiSurface' then
            local defensiveUnitsFound = false
            local defensiveUnitThreat = 0
            if not RNGTableEmpty(self.Brain.EnemyIntel.DirectorData.Defense) then
                for k, v in self.Brain.EnemyIntel.DirectorData.Defense do
                    if v.Object and not v.Object.Dead then
                        --RNGLOG('Found Defensive unit in directordata defense table '..v.Object.UnitId)
                        --RNGLOG('Table entry '..repr(v))
                        --RNGLOG('Land threat at position '..self.Brain:GetThreatAtPosition(v.IMAP, 0, true, 'Land'))
                        --RNGLOG('AntiSurface threat at position '..self.Brain:GetThreatAtPosition(v.IMAP, 0, true, 'AntiSurface'))
                        if v.AntiSurface > 0 then
                            local gridXID, gridZID = self:GetIntelGrid(v.IMAP)
                            self.MapIntelGrid[gridXID][gridZID].DefenseThreat = self.MapIntelGrid[gridXID][gridZID].DefenseThreat + v.AntiSurface
                            if not self.MapIntelGrid[gridXID][gridZID].Graphs.MAIN.GraphChecked then
                                if NavUtils.CanPathTo('Land', self.Brain.BuilderManagers['MAIN'].Position, self.MapIntelGrid[gridXID][gridZID].Position) then
                                    self.MapIntelGrid[gridXID][gridZID].Graphs.MAIN.GraphChecked = true
                                    self.MapIntelGrid[gridXID][gridZID].Graphs.MAIN.Land = true
                                elseif NavUtils.CanPathTo('Amphibious', self.Brain.BuilderManagers['MAIN'].Position, self.MapIntelGrid[gridXID][gridZID].Position) then
                                    self.MapIntelGrid[gridXID][gridZID].Graphs.MAIN.GraphChecked = true
                                    self.MapIntelGrid[gridXID][gridZID].Graphs.MAIN.Amphibious = true
                                else
                                    self.MapIntelGrid[gridXID][gridZID].Graphs.MAIN.GraphChecked = true
                                    self.MapIntelGrid[gridXID][gridZID].Graphs.MAIN.NoGraph = true
                                end
                            end
                            if self.MapIntelGrid[gridXID][gridZID].Graphs.MAIN.GraphChecked and self.MapIntelGrid[gridXID][gridZID].Graphs.MAIN.Land 
                                and (not v.Object.Blueprint.CategoriesHash.SHIELD) then
                                defensiveUnitsFound = true
                                defensiveUnitThreat = defensiveUnitThreat + v.AntiSurface
                            end
                        end
                    end
                    if defensiveUnitThreat > 80 then
                        break
                    end
                end
            end
            if self.Brain.RNGDEBUG then
                if defensiveUnitsFound then
                    RNGLOG('directordata defensiveUnitsFound is true')
                end
                if defensiveUnitThreat then
                    RNGLOG('defensiveUnitThreat is '..defensiveUnitThreat)
                end
            end
            if defensiveUnitsFound and defensiveUnitThreat > 0 then
                local numberRequired = math.max(math.ceil(defensiveUnitThreat / 8), 8)
                if self.Brain.amanager.Demand.Land.T2.mml < numberRequired then
                    self.Brain.amanager.Demand.Land.T2.mml = numberRequired
                    --RNGLOG('Directordata Increasing mml production count by '..numberRequired)
                end
                --[[
                -- need to figure out how to get t3 arty to fire correctly
                if self.Brain.amanager.Demand.Land.T3.arty < numberRequired / 2 then
                    self.Brain.amanager.Demand.Land.T3.arty = numberRequired / 2
                    --RNGLOG('Directordata Increasing mml production count by '..numberRequired)
                end]]
                self.Brain.amanager.Ratios[factionIndex]['Land']['T1']['arty'] = 20
            end

            if not defensiveUnitsFound then
                self.Brain.amanager.Demand.Land.T2.mml = 0
                self.Brain.amanager.Demand.Land.T3.arty = 0
                self.Brain.amanager.Ratios[factionIndex]['Land']['T1']['arty'] = 5
            end
            --RNGLOG('Directordata current mml production count '..self.Brain.amanager.Demand.Land.T2.mml)
            
        elseif type == 'LandAntiSurface' then
            for k, v in self.Brain.EnemyIntel.ACU do
                --if v.Position[1] then
                --    RNGLOG('Current Distance '..VDist3Sq(v.Position, self.Brain.BrainIntel.StartPos))
                --end
                
                if (not v.Unit.Dead) and (not v.Ally) and v.Position[1] and v.HP ~= 0 and v.LastSpotted + 120 > gameTime then
                    if VDist3Sq(v.Position, self.Brain.BrainIntel.StartPos) < (self.Brain.EnemyIntel.ClosestEnemyBase / 9) then
                        local gridX, gridZ = self:GetIntelGrid(v.Position)
                        if v.HP < 4000 then
                            desiredStrikeDamage = desiredStrikeDamage + v.HP
                        else
                            desiredStrikeDamage = desiredStrikeDamage + 4000
                        end
                        desiredStrikeDamage = desiredStrikeDamage + 4000
                        if self.Brain.RNGDEBUG then
                            RNGLOG('Setting up antisurface acu snipe')
                            RNGLOG('Closest enemy base '..self.Brain.EnemyIntel.ClosestEnemyBase)
                            RNGLOG('Distance required is '..(self.Brain.EnemyIntel.ClosestEnemyBase / 9))
                            RNGLOG('Distance is '..VDist3Sq(v.Position, self.Brain.BrainIntel.StartPos))
                        end
                        table.insert( potentialStrikes, { GridID = {GridX = gridX, GridZ = gridZ}, Position = self.MapIntelGrid[gridX][gridZ].Position, Type = 'ACU', Index = k} )
                    end
                end
            end
        elseif type == 'AirAntiNaval' then
            --RNGLOG(self.Brain.Nickname)
            --RNGLOG('self.Brain.BrainIntel.SelfThreat.AirNow '..self.Brain.BrainIntel.SelfThreat.AirNow)
            --RNGLOG('ally air threat is '..self.Brain.BrainIntel.SelfThreat.AllyAirThreat)
            --RNGLOG('self.Brain.EnemyIntel.EnemyThreatCurrent.Air '..self.Brain.EnemyIntel.EnemyThreatCurrent.Air)
            if self.Brain.BrainIntel.SelfThreat.AirNow + (self.Brain.BrainIntel.SelfThreat.AllyAirThreat / 2) > self.Brain.EnemyIntel.EnemyThreatCurrent.Air * 1.5 then
                minThreatRisk = 80
            elseif self.Brain.BrainIntel.SelfThreat.AirNow + (self.Brain.BrainIntel.SelfThreat.AllyAirThreat / 2) > self.Brain.EnemyIntel.EnemyThreatCurrent.Air then
                minThreatRisk = 50
            elseif self.Brain.BrainIntel.SelfThreat.AirNow + (self.Brain.BrainIntel.SelfThreat.AllyAirThreat / 2) * 1.5 > self.Brain.EnemyIntel.EnemyThreatCurrent.Air then
                minThreatRisk = 25
            end
            if minThreatRisk > 0 then
                for k, v in self.Brain.EnemyIntel.ACU do
                    if (not v.Unit.Dead) and (not v.Ally) and v.HP ~= 0 and v.Position[1] then
                        if minThreatRisk >= 50 and VDist3Sq(v.Position, self.Brain.BrainIntel.StartPos) < (self.Brain.EnemyIntel.ClosestEnemyBase / 4) then
                            if RUtils.PositionInWater(v.Position) then
                                if GetThreatBetweenPositions(self.Brain, self.Brain.BrainIntel.StartPos, v.Position, nil, threatType) < threatMax * 2 then
                                    --RNGLOG('ACU ClosestEnemy base distance is '..(self.Brain.EnemyIntel.ClosestEnemyBase /2))
                                    --RNGLOG('ACU Distance from start position '..VDist3Sq(v.Position, self.Brain.BrainIntel.StartPos))
                                    local gridX, gridZ = self:GetIntelGrid(v.Position)
                                    local scoutRequired = true
                                    if self.MapIntelGrid[gridX][gridZ].MustScout and self.MapIntelGrid[gridX][gridZ].ACUIndexes[k] then
                                        scoutRequired = false
                                    end
                                    if scoutRequired then
                                        self.MapIntelGrid[gridX][gridZ].MustScout = true
                                        self.MapIntelGrid[gridX][gridZ].ACUIndexes[k] = true
                                        --RNGLOG('ScoutRequired for EnemyIntel.ACU '..repr(self.MapIntelGrid[gridX][gridY]))
                                    end
                                    if v.HP < 4000 then
                                        desiredStrikeDamage = desiredStrikeDamage + v.HP
                                    else
                                        desiredStrikeDamage = desiredStrikeDamage + 4000
                                    end
                                    --RNGLOG('Adding ACU to potential strike target')
                                    table.insert( potentialStrikes, { GridID = {GridX = gridX, GridZ = gridZ}, Position = self.MapIntelGrid[gridX][gridZ].Position, Type = 'ACU', Index = k} )
                                end
                            end
                        end
                    end
                end
                for k, v in self.Brain.BasePerimeterMonitor do
                    if v.NavalUnits > 0 then
                        local gridX, gridZ = self:GetIntelGrid(self.Brain.BuilderManagers[k].FactoryManager.Location)
                        desiredStrikeDamage = desiredStrikeDamage + (v.NavalThreat * 120)
                        --RNGLOG('Naval Threat detected at base, requesting torps for '..desiredStrikeDamage..' strike damage')
                        --RNGLOG('Naval threat at base is '..v.NavalThreat)
                        table.insert( potentialStrikes, { GridID = {GridX = gridX, GridZ = gridZ}, Position = self.MapIntelGrid[gridX][gridZ].Position, Type = 'AntiNavy'} )
                    end
                end
                if minThreatRisk > 25 then
                    for _, x in self.Brain.EnemyIntel.EnemyThreatLocations do
                        for _, z in x do
                            if z['Naval'] and z['Naval'] > 0 and (gameTime - z.UpdateTime) < 45 then
                                --RNGLOG('Enemy Threat Locations has a NavalThreat table')
                                -- position format as used by the engine
                                local gridX, gridZ = self:GetIntelGrid(z.Position)
                                --RNGLOG('Enemy Threat Locations distance to naval threat grid is '..self.MapIntelGrid[gridX][gridZ].DistanceToMain)
                                if self.MapIntelGrid[gridX][gridZ].DistanceToMain < baseMilitaryArea then
                                    desiredStrikeDamage = desiredStrikeDamage + (z['Naval'] * 120)
                                    --RNGLOG('Strike Damage request is '..desiredStrikeDamage)
                                    table.insert( potentialStrikes, { GridID = {GridX = gridX, GridZ = gridZ}, Position = self.MapIntelGrid[gridX][gridZ].Position, Type = 'AntiNavy'} )
                                end
                            end
                        end
                    end
                else
                    --RNGLOG('Enemy air threat too high, no looking for naval threat to activate torpedo bombers')
                end
            end
        end
        
        --RNGLOG('CheckStrikPotential')
        --RNGLOG('ThreatRisk is '..minThreatRisk)
        if type == 'AirAntiSurface' then
            if not self.StrategyFlags.T3BomberRushActivated then
                if self.Brain.BrainIntel.AirPhase == 3 and self.Brain.EnemyIntel.AirPhase < 3 then
                    self.Brain.amanager.Demand.Air.T3.bomber = 1
                end
                if self.Brain.amanager.Current['Air']['T3']['bomber'] > 0 then
                    self.StrategyFlags.T3BomberRushActivated = true
                    self.Brain.amanager.Demand.Air.T3.bomber = 0
                end
            end
            local disableGunship = true
            if self.Brain.BrainIntel.AirPhase < 2 then
                if self.Brain.BrainIntel.SelfThreat.AntiAirNow > 5 then
                    local gunshipMassKilled = self.Brain.IntelManager.UnitStats['Gunship'].Kills.Mass
                    local gunshipMassBuilt = self.Brain.IntelManager.UnitStats['Gunship'].Built.Mass
                    if self.Brain.amanager.Current['Air']['T1']['gunship'] < 2 then
                        self.Brain.amanager.Demand.Air.T1.gunship = 2
                        disableGunship = false
                    end
                    if gunshipMassKilled > 0 and gunshipMassBuilt > 0 and math.min(gunshipMassKilled / gunshipMassBuilt, 2) > 1.2 then
                        self.Brain.amanager.Demand.Air.T1.gunship = self.Brain.amanager.Current['Air']['T1']['gunship'] + 1
                        disableGunship = false
                    end

                end
            elseif self.Brain.BrainIntel.AirPhase < 3 then
                if self.Brain.BrainIntel.SelfThreat.AntiAirNow > 20 then
                    local gunshipMassKilled = self.Brain.IntelManager.UnitStats['Gunship'].Kills.Mass
                    local gunshipMassBuilt = self.Brain.IntelManager.UnitStats['Gunship'].Built.Mass
                    if self.Brain.amanager.Current['Air']['T2']['gunship'] < 2 then
                        self.Brain.amanager.Demand.Air.T2.gunship = 2
                        disableGunship = false
                    end
                    if gunshipMassKilled > 0 and gunshipMassBuilt > 0 and math.min(gunshipMassKilled / gunshipMassBuilt, 2) > 1.2 then
                        self.Brain.amanager.Demand.Air.T2.gunship = self.Brain.amanager.Current['Air']['T2']['gunship'] + 1
                        disableGunship = false
                    end

                end
            elseif self.Brain.BrainIntel.AirPhase > 2 then
                if self.Brain.BrainIntel.SelfThreat.AntiAirNow > 60 then
                    local gunshipMassKilled = self.Brain.IntelManager.UnitStats['Gunship'].Kills.Mass
                    local gunshipMassBuilt = self.Brain.IntelManager.UnitStats['Gunship'].Built.Mass
                    if self.Brain.amanager.Current['Air']['T3']['gunship'] < 2 then
                        self.Brain.amanager.Demand.Air.T3.gunship = 2
                        disableGunship = false
                    end
                    if gunshipMassKilled > 0 and gunshipMassBuilt > 0 and math.min(gunshipMassKilled / gunshipMassBuilt, 2) > 1.2 then
                        self.Brain.amanager.Demand.Air.T3.gunship = self.Brain.amanager.Current['Air']['T3']['gunship'] + 1
                        disableGunship = false
                    end
                end
            end
            if disableGunship and self.Brain.amanager.Current['Air']['T1']['gunship'] > 1 then
                self.Brain.amanager.Demand.Air.T1.gunship = 0
            end
            if disableGunship and self.Brain.amanager.Current['Air']['T2']['gunship'] > 1 then
                self.Brain.amanager.Demand.Air.T2.gunship = 0
            end
            if disableGunship and self.Brain.amanager.Current['Air']['T3']['gunship'] > 2 then
                self.Brain.amanager.Demand.Air.T3.gunship = 0
            end
            --LOG('Current T2 Gunship demand '..self.Brain.amanager.Demand.Air.T2.gunship)
            --LOG('Current T3 Gunship demand '..self.Brain.amanager.Demand.Air.T3.gunship)
            if not table.empty(potentialStrikes) then
                local count = math.ceil(desiredStrikeDamage / 1000)
                local acuSnipe = false
                local acuIndex = false
                local zoneAttack = false
                for k, v in potentialStrikes do
                    if v.Type == 'ACU' then
                        acuSnipe = true
                        acuIndex = v.Index
                    elseif v.Type == 'Zone' then
                        zoneAttack = true
                    end
                end
                --RNGLOG('Number of T2 Bombers wanted '..count)
                if acuSnipe then
                    --RNGLOG('Setting acuSnipe mission for air units')
                    --RNGLOG('Set game time '..gameTime)
                    self.Brain.TacticalMonitor.TacticalMissions.ACUSnipe[acuIndex]['AIR'] = { GameTime = gameTime, CountRequired = count }
                    self.Brain.amanager.Demand.Air.T2.bomber = count
                    --maybe one day they'll put the Mercy back to a sniping unit, until then the build logic is disabled
                    --self.Brain.amanager.Demand.Air.T2.mercy = count
                    self.Brain.EngineerAssistManagerFocusSnipe = true
                end
                if zoneAttack then
                    if self.Brain.BrainIntel.AirPhase < 3 then
                        self.Brain.amanager.Demand.Air.T2.bomber = count
                    end
                end
            else
                local disableBomb = true
                for k, v in self.Brain.TacticalMonitor.TacticalMissions.ACUSnipe do
                    if v.AIR then
                        if v.AIR.GameTime and v.AIR.GameTime + 300 < gameTime then
                            disableBomb = false
                        end
                    end
                end
                if disableBomb and self.Brain.amanager.Demand.Air.T2.mercy > 0 then
                    --RNGLOG('No mercy snipe missions, disable demand')
                    self.Brain.amanager.Demand.Air.T2.mercy = 0
                    self.Brain.EngineerAssistManagerFocusSnipe = false
                end
                if disableBomb and self.Brain.amanager.Demand.Air.T2.bomber > 0 then
                    --RNGLOG('No t2 bomber missions, disable demand')
                    self.Brain.amanager.Demand.Air.T2.bomber = 0
                    self.Brain.EngineerAssistManagerFocusSnipe = false
                end
            end
        elseif type == 'LandAntiSurface' then
            local acuSnipe = false
            if not table.empty(potentialStrikes) then
                local count = math.ceil(desiredStrikeDamage / 1000)
                local acuIndex = false
                for k, v in potentialStrikes do
                    if v.Type == 'ACU' then
                        acuSnipe = true
                        acuIndex = v.Index
                    end
                end
                --RNGLOG('Number of T2 Bombs wanted '..count)
                if acuSnipe then
                    --RNGLOG('Setting acuSnipe mission for land units')
                    --RNGLOG('Set game time '..gameTime)
                    self.Brain.TacticalMonitor.TacticalMissions.ACUSnipe[acuIndex]['LAND'] = { GameTime = gameTime, CountRequired = count }
                    self.Brain.amanager.Demand.Land.T2.mobilebomb = count
                    self.Brain.EngineerAssistManagerFocusSnipe = true
                end
            else
                local disableBomb = true
                for k, v in self.Brain.TacticalMonitor.TacticalMissions.ACUSnipe do
                    if v.LAND then
                        if v.LAND.GameTime and v.LAND.GameTime + 300 < gameTime then
                            disableBomb = false
                        end
                    end
                end
                if disableBomb and self.Brain.amanager.Demand.Land.T2.mobilebomb > 0 then
                    --RNGLOG('No mobile bomb missions, disable demand')
                    self.Brain.amanager.Demand.Land.T2.mobilebomb = 0
                    self.Brain.EngineerAssistManagerFocusSnipe = false
                end
            end
        elseif type == 'AirAntiNaval' then
            if not table.empty(potentialStrikes) then
                --RNGLOG('potentialStrikes for navy '..repr(potentialStrikes))
                local count = math.ceil(desiredStrikeDamage / 1000)
                local acuSnipe = false
                local acuIndex = false
                local navalAttack = false
                for k, v in potentialStrikes do
                    if v.Type == 'ACU' then
                        acuSnipe = true
                        acuIndex = v.Index
                    elseif v.Type == 'Zone' or v.Type == 'AntiNavy' then
                        navalAttack = true
                    end

                end
                --RNGLOG('Number of T2 pos wanted '..count)
                if acuSnipe then
                    --RNGLOG('Setting acuSnipe mission for air torpedo units')
                    --RNGLOG('Set game time '..gameTime)
                    self.Brain.TacticalMonitor.TacticalMissions.ACUSnipe[acuIndex]['AIRANTINAVY'] = { GameTime = gameTime, CountRequired = count }
                    self.Brain.amanager.Demand.Air.T2.torpedo = count
                    self.Brain.EngineerAssistManagerFocusSnipe = true
                end
                if navalAttack then
                    --RNGLOG(self.Brain.Nickname)
                    --RNGLOG('numer of navalAttack torps required '..count)
                    self.Brain.amanager.Demand.Air.T2.torpedo = count
                end
            else
                local disableStrike = true
                for k, v in self.Brain.TacticalMonitor.TacticalMissions.ACUSnipe do
                    if v.AIRANTINAVY then
                        if v.AIRANTINAVY.GameTime and v.AIRANTINAVY.GameTime + 300 < gameTime then
                            disableStrike = false
                        end
                    end
                end
                if disableStrike and self.Brain.amanager.Demand.Air.T2.torpedo > 0 then
                    --RNGLOG('No mercy snipe missions, disable demand')
                    self.Brain.amanager.Demand.Air.T2.torpedo = 0
                    self.Brain.EngineerAssistManagerFocusSnipe = false
                end
            end
            --RNGLOG('Current T2 torpcount is '..self.Brain.amanager.Demand.Air.T2.torpedo)
        elseif type == 'MobileAntiAir' then
            local selfThreat = self.Brain.BrainIntel.SelfThreat
            local enemyThreat = self.Brain.EnemyIntel.EnemyThreatCurrent
            if selfThreat.LandNow * 1.5 > enemyThreat.Land and selfThreat.AntiAirNow < enemyThreat.Air then
                local zoneCount = self.Brain.BuilderManagers['MAIN'].PathableZones.PathableZoneCount
                -- We are going to look at the threat in the pathable zones and see which ones are in our territory and make sure we have a theoretical number of air units there
                -- I want to do this on a per base method, but I realised I'm not keeping information.
                local totalMobileAARequired = math.ceil(zoneCount * (enemyThreat.Air / selfThreat.AirNow)) or 0
                --LOG('Enemy Air Threat '..enemyThreat.Air)
                --LOG('Self Air Threat '..selfThreat.AirNow)
                --LOG('totalMobileAARequired '..totalMobileAARequired)
                if self.BrainIntel.LandPhase == 1 then
                    self.Brain.amanager.Demand.Land.T1.aa = totalMobileAARequired
                elseif self.BrainIntel.LandPhase == 2 then
                    self.Brain.amanager.Demand.Land.T2.aa = totalMobileAARequired
                elseif self.BrainIntel.LandPhase == 3 then
                    self.Brain.amanager.Demand.Land.T3.aa = totalMobileAARequired
                end

                --[[
                -- I thought I could set requirements per base but I don't have the structure yet.
                for k, v in self.Brain.BuilderManagers do
                    if v.PathableZones > 0 then
                        
                    end
                end
                ]]
                --for k, v in self.Brain.EnemyIntel.EnemyStartLocations
                --b.enemystartdata[v.Index].startangle
                --b.enemystartdata[v.Index].startdistance
            else
                self.Brain.amanager.Demand.Land.T1.aa = 0
                self.Brain.amanager.Demand.Land.T2.aa = 0
                self.Brain.amanager.Demand.Land.T2.aa = 0
            end
        end
    end,
}

function CreateIntelManager(brain)
    local im 
    im = IntelManager()
    im:Create(brain)
    return im
end


function GetIntelManager(brain)
    return brain.IntelManager
end

function ProcessSourceOnKilled(targetUnit, sourceUnit)
    --RNGLOG('We are going to do stuff here')
    --RNGLOG('Target '..targetUnit.UnitId)
    --RNGLOG('Source '..sourceUnit.UnitId)
    local data = {
        targetcat = false,
        sourcecat = false
    }
    
    if sourceUnit.GetAIBrain then
        local sourceBrain = sourceUnit:GetAIBrain()
        if sourceBrain.RNG then
            local valueGained
            local sourceCat = sourceUnit.Blueprint.CategoriesHash
            if sourceCat.EXPERIMENTAL then
                data.sourcecat = 'Experimental'
            elseif sourceCat.AIR then
                if sourceCat.GROUNDATTACK then
                    data.sourcecat = 'Gunship'
                    if targetUnit.Blueprint.Economy.BuildCostMass then
                        valueGained = targetUnit.Blueprint.Economy.BuildCostMass or 0
                    end
                else
                    data.sourcecat = 'Air'
                end
            elseif sourceCat.LAND then
                data.sourcecat = 'Land'
            elseif sourceCat.STRUCTURE then
                data.sourcecat = 'Structure'
            end
            if valueGained then
                local unitStats = sourceBrain.IntelManager.UnitStats
                unitStats[data.sourcecat].Kills.Mass = unitStats[data.sourcecat].Kills.Mass + valueGained
                if valueGained then
                    --LOG('Gunship killed')
                    --LOG('Target Unit '..targetUnit.UnitId)
                    local gained
                    local built
                    if unitStats[data.sourcecat].Kills.Mass > 0 then
                        gained = unitStats[data.sourcecat].Kills.Mass
                    else
                        gained = 0.1
                    end
                    if unitStats[data.sourcecat].Built.Mass > 0 then
                        built = unitStats[data.sourcecat].Built.Mass
                    else
                        built = 0.1
                    end
                    --LOG('Current Gunship Efficiency '..(math.min(gained / built, 2)))
                end
            end
        end
    end
    --[[
    if targetUnit.GetAIBrain then
        --LOG('lost unit')
        local targetBrain = targetUnit:GetAIBrain()
        if targetBrain.RNG then
            --LOG('rng lost unit')
            local valueLost
            local targetCat = targetUnit.Blueprint.CategoriesHash
            if targetCat.EXPERIMENTAL then
                data.targetcat = 'Experimental'
            elseif targetCat.AIR then
                if targetCat.SCOUT then
                    RecordUnitDeath(targetUnit, 'SCOUT')
                elseif targetCat.GROUNDATTACK then
                    --LOG('RNG gunship was lost')
                    data.targetcat = 'Gunship'
                    if targetUnit.Blueprint.Economy.BuildCostMass then
                        valueLost = targetUnit.Blueprint.Economy.BuildCostMass
                    end
                else
                    data.targetcat = 'Air'
                end
            elseif targetCat.LAND then
                data.targetcat = 'Land'
            elseif targetCat.STRUCTURE then
                data.targetcat = 'Structure'
            end
            if valueLost then
                local unitStats = targetBrain.IntelManager.UnitStats
                unitStats[data.targetcat].Deaths.Mass = unitStats[data.targetcat].Deaths.Mass + valueLost
                if valueLost then
                    --LOG('Gunship died')
                    --LOG('Target Unit '..targetUnit.UnitId)
                    local gained
                    local lost
                    if unitStats[data.targetcat].Kills.Mass > 0 then
                        gained = unitStats[data.targetcat].Kills.Mass
                    else
                        gained = 0.1
                    end
                    if unitStats[data.targetcat].Deaths.Mass > 0 then
                        lost = unitStats[data.targetcat].Kills.Mass
                    else
                        lost = 0.1
                    end
                    --LOG('Current Gunship Efficiency '..(math.min(gained / lost, 2)))
                end
            end
        end
    end
    ]]
end

function ProcessSourceOnDeath(targetUnit)
    local data = {
        targetcat = false,
        sourcecat = false
    }

    if targetUnit.GetAIBrain then
        local targetBrain = targetUnit:GetAIBrain()
        if targetBrain.RNG then
            local valueLost
            local targetCat = targetUnit.Blueprint.CategoriesHash
            if targetCat.EXPERIMENTAL then
                data.targetcat = 'Experimental'
            elseif targetCat.AIR then
                if targetCat.SCOUT then
                    RecordUnitDeath(targetUnit, 'SCOUT')
                elseif targetCat.GROUNDATTACK then
                    data.targetcat = 'Gunship'
                    if targetUnit.Blueprint.Economy.BuildCostMass then
                        valueLost = targetUnit.Blueprint.Economy.BuildCostMass
                    end
                else
                    data.targetcat = 'Air'
                end
            elseif targetCat.LAND then
                data.targetcat = 'Land'
            elseif targetCat.STRUCTURE then
                data.targetcat = 'Structure'
            end
            if valueLost then
                local unitStats = targetBrain.IntelManager.UnitStats
                unitStats[data.targetcat].Deaths.Mass = unitStats[data.targetcat].Deaths.Mass + valueLost
                if valueLost then
                    --LOG('Gunship died')
                    --LOG('Target Unit '..targetUnit.UnitId)
                    local gained
                    local lost
                    if unitStats[data.targetcat].Kills.Mass > 0 then
                        gained = unitStats[data.targetcat].Kills.Mass
                    else
                        gained = 0.1
                    end
                    if unitStats[data.targetcat].Deaths.Mass > 0 then
                        lost = unitStats[data.targetcat].Deaths.Mass
                    else
                        lost = 0.1
                    end
                    --LOG('Current Gunship Efficiency '..(math.min(gained / lost, 2)))
                end
            end
        end
    end
end

RebuildTable = function(oldtable)
    local temptable = {}
    for k, v in oldtable do
        if v ~= nil then
            if type(k) == 'string' then
                temptable[k] = v
            else
                table.insert(temptable, v)
            end
        end
    end
    return temptable
end

function RecordUnitDeath(targetUnit, type)
    local im = GetIntelManager(targetUnit:GetAIBrain())
    if type == 'SCOUT' then
        local gridXID, gridZID = im:GetIntelGrid(targetUnit:GetPosition())
        im.MapIntelGrid[gridXID][gridZID].RecentScoutDeaths = im.MapIntelGrid[gridXID][gridZID].RecentScoutDeaths + 1
    end

end

function AIConfigureExpansionWatchTableRNG(aiBrain)
    coroutine.yield(5)
    
    local VDist2Sq = VDist2Sq
    local markerList = {}
    local markerTypes = {'Expansion Area', 'Large Expansion Area', 'Spawn'}
    local MarkerUtils = import("/lua/sim/MarkerUtilities.lua")
    local massPointsNeedsValidation = false
    --RNGLOG(' Army Starts'..repr(armyStarts))
    for c, t in markerTypes do
        local markers = MarkerUtils.GetMarkersByType(t)
        for _, b in markers do
            if b.type == 'Expansion Area' or b.type == 'Large Expansion Area' or b.type == 'Blank Marker' then
                local startPosUsed = false
                if b.type == 'Blank Marker' and b.IsOccupied then
                    startPosUsed = true
                end
                local expansionZone
                local expansionLayer
                if b.position[1] > 0 and b.position[3] > 0 then
                    local label, reason
                    if RUtils.PositionInWater(b.position) then
                        label, reason = NavUtils.GetLabel('Water', b.position)
                        if not label then
                            WARN('No expansion water label returned reason '..reason)
                            WARN('Water label failure position was '..repr(b.position))
                        else
                            expansionZone = label
                            expansionLayer = 'Water'
                            --RNGLOG('Expansion Marker has had label added '..repr(b))
                        end
                    else
                        label, reason = NavUtils.GetLabel('Land', b.position)
                        if not label then
                            WARN('No expansion land label returned reason '..reason)
                            WARN('Land label failure position was '..repr(b.position))
                        else
                            expansionZone = label
                            expansionLayer = 'Land'
                            --RNGLOG('Expansion Marker has had label added '..repr(b))
                        end
                    end
                end
                if expansionZone and not startPosUsed then
                    if b.Extractors then
                        table.insert(markerList, {Name = b.Name, Position = b.position, Type = b.type, TimeStamp = 0, MassPoints = RNGGETN(b.Extractors), Land = 0, Structures = 0, Commander = 0, PlatoonAssigned = false, ScoutAssigned = false, Zone = expansionZone, Radar = false, RNGLayer = expansionLayer})
                    else
                        massPointsNeedsValidation = true
                        table.insert(markerList, {Name = b.Name, Position = b.position, Type = b.type, TimeStamp = 0, MassPoints = 0, Land = 0, Structures = 0, Commander = 0, PlatoonAssigned = false, ScoutAssigned = false, Zone = expansionZone, Radar = false, RNGLayer = expansionLayer})
                    end
                end
            end
        end
    end
    if massPointsNeedsValidation then
        markerList = CalculateMassValue(markerList)
    end
    --RNGLOG('Army Setup '..repr(ScenarioInfo.ArmySetup))
    local startX, startZ = aiBrain:GetArmyStartPos()
    table.sort(markerList,function(a,b) return VDist2Sq(a.Position[1],a.Position[3],startX, startZ)>VDist2Sq(b.Position[1],b.Position[3],startX, startZ) end)
    aiBrain.BrainIntel.ExpansionWatchTable = markerList
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
    local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
    --RNGLOG('Starting ExpansionIntelScan')
    while aiBrain.Status ~= "Defeat" do
        for k, v in aiBrain.BrainIntel.ExpansionWatchTable do
            if v.PlatoonAssigned.Dead then
                v.PlatoonAssigned = false
            end
            if v.ScoutAssigned.Dead then
                v.ScoutAssigned = false
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
                    --RNGLOG('Radar Present')
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
    
    aiBrain.IntelManager:WaitForMarkerInfection()
    if aiBrain.MapWaterRatio > 0 then
        LOG('Map Water Ratio is '..aiBrain.MapWaterRatio)
        local navalMarkers = {}
        local markers = GetMarkersRNG()
        local maxRadius = 30
        local unitTable = {
            Frigate = { Template = 'T1SeaFrigate', UnitID = 'ues0103',Range = 0 },
            Destroyer = { Template = 'T2SeaDestroyer', UnitID = 'ues0201',Range = 0 },
            Cruiser = { Template = 'T2SeaCruiser', UnitID = 'ues0202',Range = 0 },
            BattleShip = { Template = 'T3SeaBattleship', UnitID = 'ues0302',Range = 0 },
            MissileShip = { Template = 'T3MissileBoat', UnitID = 'xas0306',Range = 0 }
        }
        
        for _, v in unitTable do
            v.Range = ALLBPS[v.UnitID].Weapon[1].MaxRadius
            if not maxRadius or v.Range > maxRadius then
                maxRadius = v.Range
            end
        end
        LOG('Max Radius is '..maxRadius)


        if markers then
            local markerCount = 0
            local markerCountNotBlocked = 0
            local markerCountBlocked = 0
            local totalMarkerValue = 0
            for _, v in markers do 
                markerCount = markerCount + 1
                local markerValue = 0
                local valueValidated = false
                local checkPoints = NavUtils.GetPositionsInRadius('Water', v.position, maxRadius, 6)
                if checkPoints then
                    for _, m in checkPoints do
                        local dx = v.position[1] - m[1]
                        local dz = v.position[3] - m[3]
                        local posDist = dx * dx + dz * dz
                        if not valueValidated then
                            for _, b in unitTable do
                                if b.Range > 0 and posDist <= b.Range * b.Range then
                                    markerValue = markerValue + 1000 / b.Range
                                    valueValidated = true
                                end
                            end
                        end
                        if valueValidated then
                            if not aiBrain:CheckBlockingTerrain({m[1], GetSurfaceHeight(m[1], m[3]), m[3]}, v.position, 'low') then
                                markerCountNotBlocked = markerCountNotBlocked + 1
                                table.insert( navalMarkers, { Position=v.position, Name=v.name, RaidPosition={m[1], m[2], m[3]}, Distance = posDist, MarkerValue = markerValue } )
                                totalMarkerValue = totalMarkerValue + markerValue
                            else
                                markerCountBlocked = markerCountBlocked + 1
                            end
                            break
                        end
                        
                    end
                end
            end
            if true then
                RNGLOG('There are potentially '..markerCount..' markers that are in range for frigates')
                RNGLOG('There are '..markerCountNotBlocked..' markers NOT blocked by terrain')
                RNGLOG('There are '..markerCountBlocked..' markers that ARE blocked')
                LOG('Total Map marker value is '..(markerCount/totalMarkerValue))
                RNGLOG('Markers that frigates can try and raid '..repr(navalMarkers))
                LOG('Naval Value = '..totalMarkerValue)
            end
            if markerCountNotBlocked > 8 then
                aiBrain.EnemyIntel.FrigateRaid = true
                aiBrain.EnemyIntel.FrigateRaidMarkers = navalMarkers
            end
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
        SPEW('* AI-RNG: CreateMassCount: Node: '..v.Type..' - MassSpotsInRange: '..v.MassPoints)
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
    local label, reason = NavUtils.GetLabel('Land', location)
    if not label then
        WARN('No water label returned reason '..reason)
        WARN('Water label failure position was '..repr(location))
    end
    local centerPoint = aiBrain.MapCenterPoint
    local mainBaseToCenter = VDist2Sq(MainPos[1], MainPos[3], centerPoint[1], centerPoint[3])
    local bestExpansions = {}
    local options = {}
    local currentGameTime = GetGameTimeSeconds()
    -- Note, the expansions zones are land only. Need to fix this to include amphib zone.
    if label then
        for k, expansion in aiBrain.BrainIntel.ExpansionWatchTable do
            if expansion.Zone == label then
                local expansionDistance = VDist2Sq(location[1], location[3], expansion.Position[1], expansion.Position[3])
                --RNGLOG('Distance to expansion '..expansionDistance)
                --RNGLOG('Expansion position is '..repr(expansion.Position))
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
                                if type == 'acu' and GetNumUnitsAroundPoint(aiBrain, categories.MASSEXTRACTION, expansion.Position, 30, 'Ally') >= (expansion.MassPoints / 2) then
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
    if not table.empty(bestExpansions) then
        if type == 'acu' then
            local bestOption = false
            local secondBestOption = false
            local bestValue = 9999999999
            for _, v in options do
                if VDist2Sq(MainPos[1], MainPos[3], v.Expansion.Position[1], v.Expansion.Position[3]) > 10000 then
                    local alreadySecure = false
                    for k, b in aiBrain.BuilderManagers do
                        if k == v.Expansion.Name and not table.empty(aiBrain.BuilderManagers[k].FactoryManager.FactoryList) then
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
            if aiBrain.BrainIntel.AllyCount < 2 and secondBestOption and bestOption then
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


CreateIntelGrid = function(aiBrain)
    coroutine.yield(Random(30,70))
    -- by default, 16x16 iMAP
    local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
    --LOG('playableArea is '..repr(playableArea))
    local n = 16 
    local mx = ScenarioInfo.size[1]
    local mz = ScenarioInfo.size[2]
    local GetTerrainHeight = GetTerrainHeight
    local cellCount = 0
    if aiBrain.RNGDEBUG then
        RNGLOG('Intel Grid MapSize X : '..mx..' Z: '..mz)
    end

    -- smaller maps have a 8x8 iMAP
    if mx == mz and mx == 256 then 
        n = 8
    end
    
    local intelGrid = {}
    
    -- distance per cell
    local fx = 1 / n * mx 
    local fz = 1 / n * mz 

    -- draw iMAP information
    local startingGridx = 256
    local endingGridx = 1
    local startingGridz = 256
    local endingGridz = 1
    for x = 1, n do 
        intelGrid[x] = {}
        for z = 1, n do 
            intelGrid[x][z] = { }
            intelGrid[x][z].Position = { }
            intelGrid[x][z].Radars = { }
            intelGrid[x][z].Size = { }
            intelGrid[x][z].DistanceToMain = 0
            intelGrid[x][z].AssignedScout = false
            intelGrid[x][z].LastScouted = 0
            intelGrid[x][z].RecentScoutDeaths = 0
            intelGrid[x][z].TimeScouted = 0
            intelGrid[x][z].LastThreatCheck = 0
            intelGrid[x][z].Enabled = false
            intelGrid[x][z].MustScout = false
            intelGrid[x][z].ScoutPriority = 0
            intelGrid[x][z].Perimeter = false
            intelGrid[x][z].IntelCoverage = false
            intelGrid[x][z].LandThreat = 0
            intelGrid[x][z].DefenseThreat = 0
            intelGrid[x][z].AirThreat = 0
            intelGrid[x][z].AntiSurfaceThreat = 0
            intelGrid[x][z].ACUIndexes = { }
            intelGrid[x][z].ACUThreat = 0
            intelGrid[x][z].AdjacentGrids = {}
            intelGrid[x][z].Graphs = { }
            intelGrid[x][z].EnemyUnits = { }
            intelGrid[x][z].EnemyUnitsDanger = 0
            intelGrid[x][z].Graphs.MAIN = { GraphChecked = false, Land = false, Amphibious = false, NoGraph = false }
            local cx = fx * (x - 0.5)
            local cz = fz * (z - 0.5)
            if cx < playableArea[1] or cz < playableArea[2] or cx > playableArea[3] or cz > playableArea[4] then
                continue
            end
            cellCount = cellCount + 1
            startingGridx = math.min(x, startingGridx)
            startingGridz = math.min(z, startingGridz)
            endingGridx = math.max(x, endingGridx)
            endingGridz = math.max(z, endingGridz)
            intelGrid[x][z].Position = {cx, GetTerrainHeight(cx, cz), cz}
            intelGrid[x][z].DistanceToMain = VDist3(intelGrid[x][z].Position, aiBrain.BrainIntel.StartPos) 
            intelGrid[x][z].Water = GetTerrainHeight(cx, cz) < GetSurfaceHeight(cx, cz)
            intelGrid[x][z].Size = { sx = fx, sz = fz}
            intelGrid[x][z].Enabled = true
        end
    end
    aiBrain.IntelManager.MapIntelGrid = intelGrid
    MapIntelGridSize = fx
    aiBrain.IntelManager.CellCount = cellCount
    aiBrain.IntelManager.MapIntelGridXMin = startingGridx
    aiBrain.IntelManager.MapIntelGridXMax = endingGridx
    aiBrain.IntelManager.MapIntelGridZMin = startingGridz
    aiBrain.IntelManager.MapIntelGridZMax = endingGridz
    local gridSizeX, gridSizeZ = aiBrain.IntelManager:GetIntelGrid({playableArea[3] - 16, 0, playableArea[4] - 16})
    aiBrain.IntelManager.MapIntelGridXRes = gridSizeX
    aiBrain.IntelManager.MapIntelGridZRes = gridSizeZ
    if aiBrain.RNGDEBUG then
        RNGLOG('MapIntelGridXRes '..repr(aiBrain.IntelManager.MapIntelGridXRes))
        RNGLOG('MapIntelGridZRes '..repr(aiBrain.IntelManager.MapIntelGridZRes))
        RNGLOG('aiBrain.IntelManager.MapIntelGridXMin '..aiBrain.IntelManager.MapIntelGridXMin)
        RNGLOG('aiBrain.IntelManager.MapIntelGridXMax '..aiBrain.IntelManager.MapIntelGridXMax)
        RNGLOG('aiBrain.IntelManager.MapIntelGridZMin '..aiBrain.IntelManager.MapIntelGridZMin)
        RNGLOG('aiBrain.IntelManager.MapIntelGridZMax '..aiBrain.IntelManager.MapIntelGridZMax)
        RNGLOG('Map Intel Grid '..repr(aiBrain.IntelManager.MapIntelGrid))
    end
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


TacticalThreatAnalysisRNG = function(aiBrain)

    --RNGLOG("Started analysis for: " .. aiBrain.Nickname)
    --local startedAnalysisAt = GetSystemTimeSecondsOnlyForProfileUse()

    aiBrain.EnemyIntel.DirectorData = {
        DefenseCluster = {},
        Strategic = {},
        Energy = {},
        Intel = {},
        Defense = {},
        Factory = {},
        Experimental = {},
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
    --aiBrain.EnemyIntel.EnemyFireBaseTable = {}

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

    if not RNGTableEmpty(aiBrain.EnemyIntel.EnemyThreatLocations) then
        for _, x in aiBrain.EnemyIntel.EnemyThreatLocations do
            for _, z in x do
                if z['StructuresNotMex'] and (gameTime - z.UpdateTime) < 25 then
                    --RNGLOG('Enemy Threat Locations has a StructuresNotMex table')
                    -- position format as used by the engine
                    v = z.Position
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
                                    Value = unit.Blueprint.Defense.EconomyThreatLevel * 2, 
                                    HP = unit:GetHealth(), 
                                    Object = unit, 
                                    Shielded = RUtils.ShieldProtectingTargetRNG(aiBrain, unit, shieldsAtLocation), 
                                    IMAP = v, 
                                    Air = z['AntiAir'] or 0, 
                                    Land = z['Land'] or 0,
                                    AntiSurface = z['AntiSurface'] or 0
                                })
                            elseif EntityCategoryContains( CategoriesDefense, unit) then
                                --RNGLOG('Inserting Enemy Defensive Structure '..unit.UnitId)
                                RNGINSERT(
                                    defensiveUnits, { 
                                    EnemyIndex = unitIndex, 
                                    Value = unit.Blueprint.Defense.EconomyThreatLevel, 
                                    HP = unit:GetHealth(), 
                                    Object = unit, 
                                    Shielded = RUtils.ShieldProtectingTargetRNG(aiBrain, unit, shieldsAtLocation), 
                                    IMAP = v, 
                                    Air = z['AntiAir'] or 0, 
                                    Land = z['Land'] or 0,
                                    AntiSurface = z['AntiSurface'] or 0
                                })
                            elseif EntityCategoryContains( CategoriesStrategic, unit) then
                                --RNGLOG('Inserting Enemy Strategic Structure '..unit.UnitId)
                                RNGINSERT(strategicUnits, {
                                    EnemyIndex = unitIndex, 
                                    Value = unit.Blueprint.Defense.EconomyThreatLevel, 
                                    HP = unit:GetHealth(), 
                                    Object = unit, 
                                    Shielded = RUtils.ShieldProtectingTargetRNG(aiBrain, unit, shieldsAtLocation), 
                                    IMAP = v, 
                                    Air = z['AntiAir'] or 0, 
                                    Land = z['Land'] or 0,
                                    AntiSurface = z['AntiSurface'] or 0
                                })
                            elseif EntityCategoryContains( CategoriesIntelligence, unit) then
                                --RNGLOG('Inserting Enemy Intel Structure '..unit.UnitId)
                                RNGINSERT(intelUnits, {
                                    EnemyIndex = unitIndex, 
                                    Value = unit.Blueprint.Defense.EconomyThreatLevel, 
                                    HP = unit:GetHealth(), 
                                    Object = unit, 
                                    Shielded = RUtils.ShieldProtectingTargetRNG(aiBrain, unit, shieldsAtLocation), 
                                    IMAP = v, 
                                    Air = z['AntiAir'] or 0, 
                                    Land = z['Land'] or 0,
                                    AntiSurface = z['AntiSurface'] or 0
                                })
                            elseif EntityCategoryContains( CategoriesFactory, unit) then
                                --RNGLOG('Inserting Enemy Factory Structure '..unit.UnitId)
                                
                                RNGINSERT(factoryUnits, {
                                    EnemyIndex = unitIndex, 
                                    Value = unit.Blueprint.Defense.EconomyThreatLevel, 
                                    HP = unit:GetHealth(), 
                                    Object = unit, 
                                    Shielded = RUtils.ShieldProtectingTargetRNG(aiBrain, unit, shieldsAtLocation), 
                                    IMAP = v, 
                                    Air = z['AntiAir'] or 0, 
                                    Land = z['Land'] or 0,
                                    AntiSurface = z['AntiSurface'] or 0
                                })
                            end
                        end
                    end
                end
            end
        end
    
    if not RNGTableEmpty(defensiveUnits) then
        for k, unit in defensiveUnits do
            if not aiBrain.EnemyIntel.EnemyThreatLocations[unit.IMAP[1]][unit.IMAP[3]].LandDefStructureCount then
                aiBrain.EnemyIntel.EnemyThreatLocations[unit.IMAP[1]][unit.IMAP[3]].LandDefStructureCount = 0
                aiBrain.EnemyIntel.EnemyThreatLocations[unit.IMAP[1]][unit.IMAP[3]].LandDefStructureMaxRange = 0
            end
            if not aiBrain.EnemyIntel.EnemyThreatLocations[unit.IMAP[1]][unit.IMAP[3]].AirDefStructureCount then
                aiBrain.EnemyIntel.EnemyThreatLocations[unit.IMAP[1]][unit.IMAP[3]].AirDefStructureCount = 0
            end
            if aiBrain.EnemyIntel.EnemyThreatLocations[unit.IMAP[1]][unit.IMAP[3]]['StructuresNotMex'] then
                    if unit.Object.Blueprint.Defense.SurfaceThreatLevel > 0 then
                        aiBrain.EnemyIntel.EnemyThreatLocations[unit.IMAP[1]][unit.IMAP[3]].LandDefStructureCount = aiBrain.EnemyIntel.EnemyThreatLocations[unit.IMAP[1]][unit.IMAP[3]].LandDefStructureCount + 1
                        if unit.Object.Blueprint.Weapon[1].MaxRadius and unit.Object.Blueprint.Weapon[1].MaxRadius > aiBrain.EnemyIntel.EnemyThreatLocations[unit.IMAP[1]][unit.IMAP[3]].LandDefStructureMaxRange then
                            aiBrain.EnemyIntel.EnemyThreatLocations[unit.IMAP[1]][unit.IMAP[3]].LandDefStructureMaxRange = unit.Object.Blueprint.Weapon[1].MaxRadius
                        end
                    elseif unit.Object.Blueprint.Defense.AirThreatLevel > 0 then
                        aiBrain.EnemyIntel.EnemyThreatLocations[unit.IMAP[1]][unit.IMAP[3]].AirDefStructureCount = aiBrain.EnemyIntel.EnemyThreatLocations[unit.IMAP[1]][unit.IMAP[3]].AirDefStructureCount + 1
                    end
                    if aiBrain.EnemyIntel.EnemyThreatLocations[unit.IMAP[1]][unit.IMAP[3]].LandDefStructureCount + aiBrain.EnemyIntel.EnemyThreatLocations[unit.IMAP[1]][unit.IMAP[3]].AirDefStructureCount > 5 then
                        aiBrain.EnemyIntel.EnemyFireBaseDetected = true
                    end
                end
                --LOG('Enemy Threat Location '..q..' Have Land Defensive Structure Count of '..aiBrain.EnemyIntel.EnemyThreatLocations[q].LandDefStructureCount)
                --LOG('Enemy Threat Location '..q..' Have Air Defensive Structure Count of '..aiBrain.EnemyIntel.EnemyThreatLocations[q].AirDefStructureCount)
            end
            --RNGLOG('Enemy Defense Structure has '..unit.Air..' air threat and '..unit.Land..' land threat'..' belonging to energy index '..unit.EnemyIndex)
        end

        local firebaseTable = {}
        for _, x in aiBrain.EnemyIntel.EnemyThreatLocations do
            for _, z in x do
                if z.LandDefStructureCount > 0 or z.AirDefStructureCount > 0 then
                    local tableEntry = { Position = z.Position, Land = { Count = 0 }, Air = { Count = 0 }, aggX = 0, aggZ = 0, weight = 0, maxRangeLand = 0, validated = false}
                    if z.LandDefStructureCount > 0 then
                        --LOG('Enemy Threat Location with ID '..q..' has '..threat.LandDefStructureCount..' at imap position '..repr(threat.Position))
                        tableEntry.maxRangeLand = z.LandDefStructureMaxRange
                        --LOG('Firebase max range set to '..tableEntry.maxRangeLand)
                        tableEntry.Land = { Count = z.LandDefStructureCount }
                    end
                    if z.AirDefStructureCount > 0 then
                        --LOG('Enemy Threat Location with ID '..q..' has '..threat.AirDefStructureCount..' at imap position '..repr(threat.Position))
                        tableEntry.Air = { Count = z.AirDefStructureCount }
                    end
                    RNGINSERT(firebaseTable, tableEntry)
                end
            end
        end
        local firebaseaggregation = 0
        local firebaseaggregationTable = {}
        local complete = RNGGETN(firebaseTable) == 0
        --LOG('Firebase table '..repr(firebaseTable))
        while not complete do
            complete = true
            --LOG('firebase aggregation loop number '..firebaseaggregation)
            for _, v1 in firebaseTable do
                v1.weight = 1
                v1.aggX = v1.Position[1]
                v1.aggZ = v1.Position[3]
            end
            for _, v1 in firebaseTable do
                if not v1.validated then
                    for _, v2 in firebaseTable do
                        if not v2.validated and VDist3Sq(v1.Position, v2.Position) < 3600 then
                            v1.weight = v1.weight + 1
                            v1.aggX = v1.aggX + v2.Position[1]
                            v1.aggZ = v1.aggZ + v2.Position[3]
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
            local defenseGroup = {Land = best.Land.Count, Air = best.Air.Count, MaxLandRange = best.maxRangeLand or 0}
            best.validated = true
            local x = best.aggX/best.weight
            local z = best.aggZ/best.weight
            for _, v in firebaseTable do
                if (not v.validated) and VDist3Sq(v.Position, best.Position) < 3600 then
                    defenseGroup.Land = defenseGroup.Land + v.Land.Count
                    defenseGroup.Air = defenseGroup.Air + v.Air.Count
                    v.validated = true
                elseif not v.validated then
                    complete = false
                end
            end
            firebaseaggregation = firebaseaggregation + 1
            RNGINSERT(firebaseaggregationTable, {aggx = x, aggz = z, DefensiveCount = defenseGroup.Land + defenseGroup.Air, MaxLandRange = defenseGroup.MaxLandRange})
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
        --[[
            This is what a firebase table looks like 
            A total count of units and the center position.
            {
                DefensiveCount: 16
                aggx: 467.55554199219
                aggz: 268.44445800781
            }
        ]]
        aiBrain.EnemyIntel.DirectorData.DefenseCluster = firebaseaggregationTable
        if aiBrain.EnemyIntel.EnemyFireBaseDetected then
            --LOG('Firebase Detected')
            --LOG('Firebase Table '..repr(aiBrain.EnemyIntel.EnemyFireBaseTable))
        end
        
    end

    if not RNGTableEmpty(aiBrain.EnemyIntel.TML) then
        --LOG('EnemyIntelTML table it not empty')
        local needSort = false
        for k, v in aiBrain.EnemyIntel.TML do
            if not v.object.Dead then 
                if not v.validated then
                    --LOG('EnemyIntelTML unit has not been validated')
                    local extractors = GetListOfUnits(aiBrain, categories.STRUCTURE * categories.MASSEXTRACTION - categories.EXPERIMENTAL - categories.TECH1, false, false)
                    for c, b in extractors do
                        if VDist3Sq(b:GetPosition(), v.position) < v.range * v.range then
                            --LOG('EnemyIntelTML there is an extractor that is in range')
                            if not b.TMLInRange then
                                b.TMLInRange = {}
                            end
                            b.TMLInRange[v.object.EntityId] = v.object
                            --LOG('EnemyIntelTML added TML unit '..repr(b.TMLInRange))
                        end
                    end
                    v.validated = true
                end
            else
                aiBrain.EnemyIntel.TML[k] = nil
                needSort = true
            end
        end
        if needSort then
            aiBrain.EnemyIntel.TML = RebuildTable(aiBrain.EnemyIntel.TML)
         end
    end

    if not RNGTableEmpty(factoryUnits) then
        for k, unit in factoryUnits do
            if aiBrain.EnemyIntel.AirPhase < 2 and unit.Object.Blueprint.CategoriesHash.AIR and unit.Object.Blueprint.CategoriesHash.TECH2 then
                aiBrain.EnemyIntel.AirPhase = 2
            elseif aiBrain.EnemyIntel.AirPhase < 3 and unit.Object.Blueprint.CategoriesHash.AIR and unit.Object.Blueprint.CategoriesHash.TECH3 then
                aiBrain.EnemyIntel.AirPhase = 3
            end
            if aiBrain.EnemyIntel.LandPhase < 2 and unit.Object.Blueprint.CategoriesHash.LAND and unit.Object.Blueprint.CategoriesHash.TECH2 then
                aiBrain.EnemyIntel.LandPhase = 2
            elseif aiBrain.EnemyIntel.LandPhase < 3 and unit.Object.Blueprint.CategoriesHash.LAND and unit.Object.Blueprint.CategoriesHash.TECH3 then
                aiBrain.EnemyIntel.LandPhase = 3
            end
            if aiBrain.EnemyIntel.NavalPhase < 2 and unit.Object.Blueprint.CategoriesHash.NAVAL and unit.Object.Blueprint.CategoriesHash.TECH2 then
                aiBrain.EnemyIntel.NavalPhase = 2
            elseif aiBrain.EnemyIntel.NavalPhase < 3 and unit.Object.Blueprint.CategoriesHash.NAVAL and unit.Object.Blueprint.CategoriesHash.TECH3 then
                aiBrain.EnemyIntel.NavalPhase = 3
            end
        end
    end
    if aiBrain.EnemyIntel.AirPhase > 1 and aiBrain.EnemyIntel.EnemyThreatCurrent.AirSurface > 75 then
        --LOG('Enemy Air Snipe Threat high')
        --LOG('Current enemy air threat is '..aiBrain.EnemyIntel.EnemyThreatCurrent.AirSurface)
        aiBrain.IntelManager.StrategyFlags.EnemyAirSnipeThreat = true
    else
        --LOG('Enemy Air Snipe Threat low')
        aiBrain.IntelManager.StrategyFlags.EnemyAirSnipeThreat = false
    end

    -- populate the director
    aiBrain.EnemyIntel.DirectorData.Strategic = strategicUnits
    aiBrain.EnemyIntel.DirectorData.Intel = intelUnits
    aiBrain.EnemyIntel.DirectorData.Factory = factoryUnits
    aiBrain.EnemyIntel.DirectorData.Energy = energyUnits
    aiBrain.EnemyIntel.DirectorData.Defense = defensiveUnits

    --RNGLOG("Finished analysis for: " .. aiBrain.Nickname)
    --local finishedAnalysisAt = GetSystemTimeSecondsOnlyForProfileUse()
    --RNGLOG("Time of analysis: " .. (finishedAnalysisAt - startedAnalysisAt))
end

LastKnownThread = function(aiBrain)
    local unitCat
    local im = GetIntelManager(aiBrain)
    
    local enemyBuildStrength = {
        Total = {
            EngineerBuildPower = 0,
            LandBuildPower = 0,
            AirBuildPower = 0,
            NavalBuildPower = 0,
        }
        

    }
    aiBrain.lastknown={}
    --aiBrain:ForkThread(RUtils.ShowLastKnown)
    --aiBrain:ForkThread(ShowPrirotyKnown)
    aiBrain:ForkThread(TruePlatoonPriorityDirector)
    while not im.MapIntelGrid do
        RNGLOG('Waiting for MapIntelGrid to exist...')
        coroutine.yield(20)
    end
    local sm = import('/mods/RNGAI/lua/StructureManagement/StructureManager.lua').GetStructureManager(aiBrain)
    while not aiBrain.emanager.enemies do coroutine.yield(20) end
    while aiBrain.Status ~= "Defeat" do
        local time=GetGameTimeSeconds()
        for _=0,10 do
            local enemyMexes = {}
            local mexcount = 0
            local enemyGunshipThreat = 0
            local enemyBomberThreat = 0
            local eunits=aiBrain:GetUnitsAroundPoint((categories.AIR + categories.LAND + categories.STRUCTURE) - categories.INSIGNIFICANTUNIT, {0,0,0}, math.max(ScenarioInfo.size[1],ScenarioInfo.size[2])*1.5, 'Enemy')
            for _,v in eunits do
                if not v or v.Dead then continue end
                if ArmyIsCivilian(v:GetArmy()) then continue end
                if v.Army and not enemyBuildStrength[v.Army] then
                    enemyBuildStrength[v.Army] = {}
                end
                unitCat = v.Blueprint.CategoriesHash
                local id=v.EntityId
                local unitPosition = table.copy(v:GetPosition())
                local gridXID, gridZID = im:GetIntelGrid(unitPosition)
                if not gridXID or not gridZID then
                    --LOG('no grid id returned for a unit position')
                end
                if im.MapIntelGrid[gridXID][gridZID] then
                    if not im.MapIntelGrid[gridXID][gridZID].EnemyUnits then
                        im.MapIntelGrid[gridXID][gridZID].EnemyUnits = {}
                        im.MapIntelGrid[gridXID][gridZID].EnemyUnitsDanger = 0
                    end
                    if not unitCat.UNTARGETABLE then
                        if unitCat.MASSEXTRACTION then
                            if not im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id] or im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].time > 10 then
                                im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id]={}
                                im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].object=v
                                im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].Position=unitPosition
                                im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].time=time
                                im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].recent=true
                                im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].type='mex'
                            end
                            mexcount = mexcount + 1
                            if not v.zoneid and aiBrain.ZonesInitialized then
                                if RUtils.PositionOnWater(unitPosition[1], unitPosition[3]) then
                                    -- tbd define water based zones
                                    v.zoneid = MAP:GetZoneID(unitPosition,aiBrain.Zones.Naval.index)
                                else
                                    v.zoneid = MAP:GetZoneID(unitPosition,aiBrain.Zones.Land.index)
                                end
                            end
                            if not enemyMexes[v.zoneid] then
                                enemyMexes[v.zoneid] = {T1 = 0,T2 = 0,T3 = 0,}
                            end
                            if unitCat.TECH1 then
                                enemyMexes[v.zoneid].T1 = enemyMexes[v.zoneid].T1 + 1
                            elseif unitCat.TECH2 then
                                enemyMexes[v.zoneid].T2 = enemyMexes[v.zoneid].T2 + 1
                            else
                                enemyMexes[v.zoneid].T3 = enemyMexes[v.zoneid].T3 + 1
                            end
                        end
                        if not im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id] or im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].time + 10 < time then
                            if not im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id] then
                                im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id]={}
                                if unitCat.MOBILE then
                                    if unitCat.COMMAND then
                                        im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].type='acu'
                                    end
                                    if unitCat.LAND then
                                        if unitCat.ENGINEER and not unitCat.COMMAND then
                                            if v.Army and v.Blueprint.Economy.BuildRate then
                                                local buildPower = v.Blueprint.Economy.BuildRate
                                                enemyBuildStrength.Total.EngineerBuildPower = enemyBuildStrength.Total.EngineerBuildPower + buildPower
                                                if not enemyBuildStrength[v.Army].EngineerBuildPower then
                                                    enemyBuildStrength[v.Army].EngineerBuildPower = 0
                                                end
                                                enemyBuildStrength[v.Army].EngineerBuildPower = enemyBuildStrength[v.Army].EngineerBuildPower + buildPower
                                            end
                                            im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].type='eng'
                                        elseif unitCat.EXPERIMENTAL and not unitCat.UNTARGETABLE then
                                            if not aiBrain.EnemyIntel.Experimental[id] then
                                                aiBrain.EnemyIntel.Experimental[id] = {object = v, position=unitPosition }
                                            end
                                        elseif unitCat.ANTIAIR then
                                            im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].type='aa'
                                        elseif unitCat.DIRECTFIRE then
                                            im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].type='tank'
                                        elseif unitCat.INDIRECTFIRE then
                                            im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].type='arty'
                                        end
                                    elseif unitCat.AIR then
                                        if unitCat.EXPERIMENTAL then
                                            if not aiBrain.EnemyIntel.Experimental[id] then
                                                aiBrain.EnemyIntel.Experimental[id] = {object = v, position=unitPosition }
                                            end
                                        end
                                    end
                                elseif unitCat.STRUCTURE then
                                    if unitCat.RADAR then
                                        im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].type='radar'
                                    elseif unitCat.TACTICALMISSILEPLATFORM then
                                        im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].type='tml'
                                        if not aiBrain.EnemyIntel.TML[id] then
                                            local angle = RUtils.GetAngleToPosition(aiBrain.BuilderManagers['MAIN'].Position, unitPosition)
                                            aiBrain.EnemyIntel.TML[id] = {object = v, position=unitPosition, validated=false, range=v.Blueprint.Weapon[1].MaxRadius }
                                            ForkThread(sm.ValidateTML, sm, aiBrain, aiBrain.EnemyIntel.TML[id])
                                            aiBrain.BasePerimeterMonitor['MAIN'].RecentTMLAngle = angle
                                        end
                                    elseif unitCat.TECH3 and unitCat.ANTIMISSILE and unitCat.SILO then
                                        im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].type='smd'
                                        if not aiBrain.EnemyIntel.SMD[id] then
                                            aiBrain.EnemyIntel.SMD[id] = {object = v, Position=unitPosition, Detected=GetGameTimeSeconds() }
                                        end
                                    elseif unitCat.FACTORY then
                                        if unitCat.LAND then
                                            if v.Army and v.Blueprint.Economy.BuildRate then
                                                local buildPower = v.Blueprint.Economy.BuildRate
                                                enemyBuildStrength.Total.LandBuildPower = enemyBuildStrength.Total.LandBuildPower + buildPower
                                                if not enemyBuildStrength[v.Army].LandBuildPower then
                                                    enemyBuildStrength[v.Army].LandBuildPower = 0
                                                end
                                                enemyBuildStrength[v.Army].LandBuildPower = enemyBuildStrength[v.Army].LandBuildPower + buildPower
                                            end
                                        elseif unitCat.AIR then
                                            if v.Army and v.Blueprint.Economy.BuildRate then
                                                local buildPower = v.Blueprint.Economy.BuildRate
                                                enemyBuildStrength.Total.AirBuildPower = enemyBuildStrength.Total.AirBuildPower + buildPower
                                                if not enemyBuildStrength[v.Army].AirBuildPower then
                                                    enemyBuildStrength[v.Army].AirBuildPower = 0
                                                end
                                                enemyBuildStrength[v.Army].AirBuildPower = enemyBuildStrength[v.Army].AirBuildPower + buildPower
                                            end
                                        elseif unitCat.NAVAL then
                                            if v.Army and v.Blueprint.Economy.BuildRate then
                                                local buildPower = v.Blueprint.Economy.BuildRate
                                                enemyBuildStrength.Total.NavalBuildPower = enemyBuildStrength.Total.NavalBuildPower + buildPower
                                                if not enemyBuildStrength[v.Army].NavalBuildPower then
                                                    enemyBuildStrength[v.Army].NavalBuildPower = 0
                                                end
                                                enemyBuildStrength[v.Army].NavalBuildPower = enemyBuildStrength[v.Army].NavalBuildPower + buildPower
                                            end
                                        end
                                    end
                                end
                            end
                            im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].object=v
                            im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].Position=unitPosition
                            im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].time=time
                            im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].recent=true
                        end
                    end
                end
            end
            aiBrain.emanager.mex = enemyMexes
            im.EnemyBuildStrength = enemyBuildStrength
            coroutine.yield(20)
            time=GetGameTimeSeconds()
        end
    end
end

TruePlatoonPriorityDirector = function(aiBrain)
    --RNGLOG('Starting TruePlatoonPriorityDirector')
    aiBrain.prioritypoints={}
    aiBrain.prioritypointshighvalue={}
    local im = GetIntelManager(aiBrain)
    while not im.MapIntelGrid do
        coroutine.yield(30)
    end
    local baseRestrictedArea = aiBrain.OperatingAreas['BaseRestrictedArea']
    local playableSize = aiBrain.MapPlayableSize or math.max(ScenarioInfo.size[1],ScenarioInfo.size[2])
    local distanceExponent = 55
    local maxPriority = 1000
    if not aiBrain.GridPresence then
        WARN('Grid Presence is not running')
    end
    while aiBrain.Status ~= "Defeat" do
        local unitAddedCount = 0
        local needSort = false
        local timeStamp = GetGameTimeSeconds()
        --RNGLOG('Check Expansion table in priority directo')
        if aiBrain.BrainIntel.ExpansionWatchTable then
            for k, v in aiBrain.BrainIntel.ExpansionWatchTable do
                if v.Land > 0 or v.Structures > 0 then
                    local priority=0
                    local acuPresent = false
                    if v.Structures > 0 then
                        -- We divide by 100 because of mexes being 1000 and greater threat. If they ever fix the threat numbers of mexes then this can change
                        priority = priority + v.Structures
                        --RNGLOG('Structure Priority is '..priority)
                    end
                    if v.Land > 0 then 
                        priority = priority + 50
                    end
                    if v.PlatoonAssigned then
                        priority = priority - 20
                    end
                    if v.MassPoints >= 3 then
                        priority = priority + 50
                    elseif v.MassPoints >= 2 then
                        priority = priority + 30
                    end
                    if v.Commander > 0 then
                        acuPresent = true
                    end
                    unitAddedCount = unitAddedCount + 1
                    aiBrain.prioritypoints[k]={type='raid',Position=v.Position,priority=priority,danger=RUtils.GrabPosDangerRNG(aiBrain,v.Position,30, true, false, false).enemy,unit=v.object, ACUPresent=acuPresent, time=timeStamp}
                else
                    local acuPresent = false
                    local priority=0
                    if v.MassPoints >= 2 then
                        priority = priority + 30
                    end
                    if v.Commander > 0 then
                        acuPresent = true
                    end
                    unitAddedCount = unitAddedCount + 1
                    aiBrain.prioritypoints[k]={type='raid',Position=v.Position,priority=priority,danger=0,unit=v.object, ACUPresent=acuPresent,time=timeStamp}
                end
            end
            coroutine.yield(10)
        end
        --RNGLOG('Check lastknown')
        
        for i=im.MapIntelGridXMin, im.MapIntelGridXMax do
            for k=im.MapIntelGridZMin, im.MapIntelGridZMax do
                if not table.empty(im.MapIntelGrid[i][k].EnemyUnits) then
                    local scaledPriority
                    local anglePriority
                    local position = im.MapIntelGrid[i][k].Position
                    local distanceToMain = im.MapIntelGrid[i][k].DistanceToMain
                    local gridPointAngle = RUtils.GetAngleToPosition(aiBrain.BrainIntel.StartPos, position)
                    local angleOfEnemyUnits = math.abs(gridPointAngle - aiBrain.BrainIntel.CurrentIntelAngle)
                    local basePriority = math.ceil((angleOfEnemyUnits * 60) / (distanceToMain / 2))
                    --LOG('basePriority '..basePriority)
                    local normalizedDistance = distanceToMain / playableSize
                    local distanceFactor = (1 - normalizedDistance) * 200
                    --LOG('basePriority * '..(1 + distanceFactor * distanceExponent / maxPriority))
                    scaledPriority = basePriority * (1 + distanceFactor * distanceExponent / maxPriority)
                    local statusModifier = 1
                    --RNGLOG('angle of enemy units '..angleOfEnemyUnits)
                    --RNGLOG('distance to main '..im.MapIntelGrid[i][k].DistanceToMain)
                    im.MapIntelGrid[i][k].EnemyUnitDanger = RUtils.GrabPosDangerRNG(aiBrain,position,30, true, false, false).enemy
                    if aiBrain.GridPresence and aiBrain.GridPresence:GetInferredStatus(position) == 'Allied' then
                        statusModifier = 1.8
                    end
                    anglePriority = scaledPriority * statusModifier
                    --RNGLOG('Priority of angle and distance '..anglePriority)
                    for c, b in im.MapIntelGrid[i][k].EnemyUnits do
                        local priority = 0
                        if b.recent and not b.object.Dead then
                            if b.type then
                                if b.type=='eng' then
                                    priority=anglePriority + 50
                                elseif b.type=='mex' then
                                    priority=anglePriority + 40
                                elseif b.type=='radar' then
                                    priority=anglePriority + 100
                                elseif b.type=='arty' then
                                    priority=anglePriority + 30
                                elseif b.type=='tank' then
                                    priority=anglePriority + 30
                                else
                                    priority=anglePriority + 20
                                end
                            end
                            priority = priority * statusModifier
                            unitAddedCount = unitAddedCount + 1
                            aiBrain.prioritypoints[c..i..k]={type='raid',Position=b.Position,priority=priority,danger=im.MapIntelGrid[i][k].EnemyUnitDanger,unit=b.object,time=b.time}
                            --LOG('Added priority point of id '..c..i..k)
                            if im.MapIntelGrid[i][k].DistanceToMain < baseRestrictedArea or priority > 250 then
                                if b.type == 'tank' or b.type == 'arty' then
                                    priority = priority + 100
                                end
                                aiBrain.prioritypointshighvalue[c..i..k]={type='raid',Position=b.Position,priority=priority,danger=im.MapIntelGrid[i][k].EnemyUnitDanger,unit=b.object,time=b.time}
                                --RNGLOG('HighPriority target added '..repr(aiBrain.prioritypointshighvalue[c..i..k]))
                                --RNGLOG('Unit is '..b.object.UnitId)
                            end
                        end
                        --RNGLOG('Added prioritypoints entry of '..repr(aiBrain.prioritypoints[c]))
                        --RNGLOG('Angle Priority was '..anglePriority)
                        --RNGLOG('Distance to main was '..im.MapIntelGrid[i][k].DistanceToMain)
                        --RNGLOG('EnemyUnitGrid Danger is '..im.MapIntelGrid[i][k].EnemyUnitDanger)
                    end
                end
            end
        end
        if aiBrain.CDRUnit.Active then
            --[[
                local minpri=300
                local dangerpri=500
                local healthcutoff=5000
                local dangerfactor = cdr.CurrentEnemyThreat/cdr.CurrentFriendlyThreat
                Danger factor doesn't quite fit in yet. More work.
                local healthdanger = minpri + (dangerpri - minpri) * healthcutoff / aiBrain.CDRUnit:GetHealth() * dangerfactor
            ]]
            local healthdanger = 2500000 / aiBrain.CDRUnit.Health 
           --RNGLOG('CDR health is '..aiBrain.CDRUnit.Health)
           --RNGLOG('Health Danger is '..healthdanger)
            local enemyThreat
            local friendlyThreat
            if aiBrain.CDRUnit.CurrentEnemyThreat > 0 then
                enemyThreat = aiBrain.CDRUnit.CurrentEnemyThreat
            else
                enemyThreat = 1
            end


            if aiBrain.CDRUnit.CurrentFriendlyThreat > 0 then
                friendlyThreat = aiBrain.CDRUnit.CurrentFriendlyThreat
            else
                friendlyThreat = 1
            end
           --RNGLOG('prioritypoint friendly threat is '..friendlyThreat)
           --RNGLOG('prioritypoint enemy threat is '..enemyThreat)
           --RNGLOG('Priority Based on threat would be '..(healthdanger * (enemyThreat / friendlyThreat)))
           --RNGLOG('Instead is it '..healthdanger)
            local acuPriority = healthdanger * (enemyThreat / friendlyThreat)
            if aiBrain.CDRUnit.Caution then
                acuPriority = acuPriority + 100
            end
            unitAddedCount = unitAddedCount + 1
            aiBrain.prioritypoints['ACU']={type='raid',Position=aiBrain.CDRUnit.Position,priority=acuPriority,danger=RUtils.GrabPosDangerRNG(aiBrain,aiBrain.CDRUnit.Position,30, true, false, false).enemy,unit=nil}
        end
        for k, v in aiBrain.prioritypoints do
            if v.unit.Dead or (v.time and v.time + 60 < timeStamp) then
                aiBrain.prioritypoints[k] = nil
                needSort = true
            end
        end
        if needSort then
            aiBrain.prioritypoints = RebuildTable(aiBrain.prioritypoints)
            needSort = false
        end
        local highPriorityCount = 0
        for k, v in aiBrain.prioritypointshighvalue do
            if v.unit.Dead then
                aiBrain.prioritypointshighvalue[k] = nil
                needSort = true
            else
                highPriorityCount = highPriorityCount + 1
            end
        end
        if needSort then
            aiBrain.prioritypointshighvalue = RebuildTable(aiBrain.prioritypointshighvalue)
            needSort = false
        end
        if highPriorityCount > 0 then
            --RNGLOG('HighPriorityTarget is available')
            aiBrain.EnemyIntel.HighPriorityTargetAvailable = true
        else
            aiBrain.EnemyIntel.HighPriorityTargetAvailable = false
        end
        for k, v in aiBrain.EnemyIntel.Experimental do
            if v.object.Dead then
                aiBrain.EnemyIntel.Experimental[k] = nil
                needSort = true
            end
        end
        if needSort then
            aiBrain.EnemyIntel.Experimental = RebuildTable(aiBrain.EnemyIntel.Experimental)
            needSort = false
        end
        coroutine.yield(40)
    end
end



ShowPrirotyKnown = function(aiBrain)
    while not aiBrain.prioritypoints do
        coroutine.yield(2)
    end
    --LOG('Start last known')
    while aiBrain.result ~= "defeat" do
        local prioritypoints=table.copy(aiBrain.prioritypoints)
        for _,v in prioritypoints do
            if v.unit and not v.unit.Dead then
                DrawCircle(v.Position,3,'ff0000')
            end
        end
        coroutine.yield(2)
    end
end