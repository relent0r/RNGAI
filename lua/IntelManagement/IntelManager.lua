local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local NavUtils = import('/lua/sim/NavUtils.lua')
local MarkerUtils = import("/lua/sim/MarkerUtilities.lua")
local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
local GetMarkersRNG = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetThreatBetweenPositions = moho.aibrain_methods.GetThreatBetweenPositions
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetListOfUnits = moho.aibrain_methods.GetListOfUnits
local PlatoonExists = moho.aibrain_methods.PlatoonExists
local MapIntelGridSize = 32


-- pre-compute categories for performance
local CategoriesStructuresNotMex = categories.STRUCTURE - categories.WALL - categories.MASSEXTRACTION
local CategoriesEnergy = categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3 + categories.EXPERIMENTAL)
local CategoriesDefense = categories.DEFENSE * categories.STRUCTURE - categories.WALL - categories.SILO
local CategoriesStrategic = categories.STRATEGIC * (categories.TECH2 + categories.TECH3 + categories.EXPERIMENTAL)
local CategoriesIntelligence = categories.INTELLIGENCE * (categories.TECH2 + categories.TECH3 + categories.EXPERIMENTAL)
local CategoriesFactory = categories.FACTORY * categories.STRUCTURE - categories.SUPPORTFACTORY - categories.EXPERIMENTAL - categories.CRABEGG - categories.CARRIER
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
local WeakValueTable = { __mode = 'v' }
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

IntelManager = Class {
    Create = function(self, brain)
        self.Brain = brain
        self.Initialized = false
        self.Debug = false
        -- Used for scout assignments to zones
        self.ZoneExpansions = { 
            Pathable = {},
            NonPathable = {},
            ClosestToEnemy = {},
        }
        self.MapIntelGridXRes = 0
        self.MapIntelGridZRes = 0
        self.MapIntelGridSize = 0
        self.MapIntelGrid = false
        self.MapIntelStats = {
            ScoutLocationsBuilt = false,
            IntelCoverage = 0,
            MustScoutArea = false,
        }
        self.MapMaximumValues = {
            MaximumResourceValue = 0,
            MaxumumGraphValue = 0
        }
        self.StrategyFlags = {
            T3BomberRushActivated = false,
            EnemyAirSnipeThreat = false,
            EarlyT2AmphibBuilt = false,
            RangedAssaultPositions = {}
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
            ExperimentalLand = {
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
            Bomber = {
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
            RangedBot = {
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
            MissileShip = {
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
            NukeSub = {
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
        self:ForkThread(self.ZoneIntelAssignment)
        self:ForkThread(self.EnemyPositionAngleAssignment)
        self:ForkThread(self.ZoneDistanceValue)
        self:ForkThread(self.ZoneLabelAssignment)
        self:ForkThread(self.IntelGridThread, self.Brain)
        self:ForkThread(self.ZoneExpansionThreadRNG)
        self:ForkThread(self.TacticalIntelCheck)
        self.Brain:ForkThread(self.Brain.BuildScoutLocationsRNG)
        --self:ForkThread(self.DrawZoneArmyValue)
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
        local aiBrain = self.Brain
        while true do
            for _, z in aiBrain.Zones.Land.zones do
                DrawCircle(z.pos,3*z.weight,'b967ff')
                if z.enemylandthreat > 0 then
                    DrawCircle(z.pos,math.max(20,z.enemylandthreat),'d62d20')
                end
                if z.friendlyantisurfacethreat > 0 then
                    DrawCircle(z.pos,math.max(20,z.friendlyantisurfacethreat),'aa44ff44')
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

    WaitForNavmeshGeneration = function(self)
        while not NavUtils.IsGenerated() do
            RNGLOG('Waiting for NavMesh to Initialize '..self.Brain.Nickname)
            coroutine.yield(20)
        end
    end,

    WaitForMarkerInfection = function(self)
        --RNGLOG('Wait for marker infection at '..GetGameTimeSeconds())
        while not self.Brain.MarkersInfectedRNG do
            coroutine.yield(20)
        end
        --RNGLOG('Markers infection completed at '..GetGameTimeSeconds())
    end,

    ZoneExpansionThreadRNG = function(self)

        -- What does this shit do?
        -- Its going to look at the expansion table which holds information on expansion markers.
        -- Then its going to see what the mass value of the graph zone is so we can see if its even worth looking
        -- Then if its worth it we'll see if we have an expansion in this zone and if not then we should look to establish a presense
        -- But what if an enemy already has structure threat around the expansion marker?
        -- Then we are going to try and create a dynamic expansion in the zone somewhere so we can try and take it.
        -- By default if someone already has the expansion marker the AI will give up. But that doesn't stop humans and it shouldn't stop us.
        -- When debuging, dont repr the expansions as they might have a unit assigned to them.
        self:WaitForZoneInitialization()
        self:WaitForNavmeshGeneration()
        self:WaitForMarkerInfection()
        coroutine.yield(Random(250,350))
        local aiBrain = self.Brain
        local armyIndex = aiBrain:GetArmyIndex()
        local weightageValues = {
            teamValue = 0.4,
            massValue = 0.6,
            distanceValue = 0.5,
            graphValue = 0.2,
            enemyLand = 0.1,
            enemyAir = 0.1,
            bestArmy = 0.05,
            friendlyantisurfacethreat = 0.05,
            friendlylandantiairthreat = 0.05,
            enemyStartAngle = 0.3,
            enemyStartDistance = 0.2
        }
        local maxTeamValue = 2
        local maxResourceValue = self.MapMaximumValues.MaximumResourceValue
        local maxGraphValue = self.MapMaximumValues.MaximumGraphValue
        local maxEnemyLandThreat = 25
        local maxEnemyAirThreat = 25
        local maxFriendlyLandThreat = 25
        local maxFriendlyAirThreat = 25

        local mainBasePos = aiBrain.BrainIntel.StartPos
        local mainBaseLabelType
        if RUtils.PositionInWater(mainBasePos) then
            mainBaseLabelType = 'Water'
        else
            mainBaseLabelType = 'Land'
        end
        local mainBaseLabel = NavUtils.GetLabel(mainBaseLabelType, mainBasePos)
        local OwnIndex = aiBrain:GetArmyIndex()

        while true do
            --LOG('Running zone expansion check for '..tostring(aiBrain.Nickname))
            local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
            local maxDistance = math.max(playableArea[2],playableArea[4])
            maxDistance = maxDistance * maxDistance
            local zoneSet = aiBrain.Zones.Land.zones
            local zonePriorityList = {}
            local gameTime = GetGameTimeSeconds()
            local labelBaseValues = {}
            local labelResourceValue = {}
            local potentialAcuExpansionCount

            for k, v in zoneSet do
                if v.BuilderManager.BaseType and v.BuilderManager.BaseType == 'MAIN' and v.BuilderManager.FactoryManager.LocationActive then
                    continue
                end
                if v.label and v.pos[1] > playableArea[1] and v.pos[1] < playableArea[3] and v.pos[3] > playableArea[2] and v.pos[3] < playableArea[4] then
                    local graphLabel = aiBrain.GraphZones[v.label]
                    local markersInGraph = graphLabel.MassMarkersInGraph or 1
                    if markersInGraph > 2 then
                        labelResourceValue[v.label] = labelResourceValue[v.label] or {}
                        local bx = mainBasePos[1] - v.pos[1]
                        local bz = mainBasePos[3] - v.pos[3]
                        local mainBaseDistance = bx * bx + bz * bz
                        table.insert(labelResourceValue[v.label], {ZoneID = v.id, ResourceValue = v.resourcevalue, StartPositionClose = v.startpositionclose, DistanceToBase = mainBaseDistance})
                        if v.BuilderManager.FactoryManager.LocationActive then
                            if not labelBaseValues[v.BuilderManager.GraphArea] then
                                labelBaseValues[v.BuilderManager.GraphArea] = {}
                            end
                            if v.resourcevalue then
                                labelBaseValues[v.BuilderManager.GraphArea][v.id] = v.resourcevalue
                            end
                        end
                        local closeEnemyStart = false
                        local closeAllyStart = false
                        local edgeSkip = false
                        for _, e in  v.enemystartdata do
                            if e.startdistance < 10000 then
                                closeEnemyStart = true
                                break
                            end
                        end
                        for _, a in  v.allystartdata do
                            if a.startdistance < 10000 then
                                closeAllyStart = true
                                --LOG('Start Position too close for position '..tostring(v.pos[1])..':'..tostring(v.pos[3])..' distance is '..tostring(a.startdistance))
                                break
                            end
                        end
                        
                        if not closeEnemyStart and not closeAllyStart then
                            if mainBaseDistance > 10000 then
                                if not edgeSkip then
                                    if (not v.BuilderManager.FactoryManager.LocationActive or v.BuilderManagerDisabled) and (not v.engineerplatoonallocated or IsDestroyed(v.engineerplatoonallocated)) and (v.lastexpansionattempt == 0 or gameTime >= v.lastexpansionattempt + 30 ) then
                                        local normalizedDistanceValue = mainBaseDistance / maxDistance
                                        local normalizedTeamValue = v.teamvalue / maxTeamValue
                                        local normalizedResourceValue = v.resourcevalue / maxResourceValue
                                        local normalizedMarkersInGraphValue = markersInGraph  / maxGraphValue
                                        local normalizedEnemyLandThreatValue = v.enemylandthreat / maxEnemyLandThreat
                                        local normalizedEnemyAirThreatValue = v.enemyantiairthreat / maxEnemyAirThreat
                                        local normalizedFriendLandThreatValue = v.friendlyantisurfacethreat / maxFriendlyLandThreat
                                        local normalizedFriendAirThreatValue = v.friendlylandantiairthreat / maxFriendlyAirThreat
                                        local priorityScore = (
                                            normalizedTeamValue * weightageValues['teamValue'] +
                                            normalizedResourceValue * weightageValues['massValue'] -
                                            normalizedDistanceValue * weightageValues['distanceValue'] +
                                            normalizedMarkersInGraphValue * weightageValues['graphValue'] -
                                            normalizedEnemyLandThreatValue * weightageValues['enemyLand'] -
                                            normalizedEnemyAirThreatValue * weightageValues['enemyAir'] +
                                            normalizedFriendLandThreatValue * weightageValues['friendlyantisurfacethreat'] -
                                            normalizedFriendAirThreatValue * weightageValues['friendlylandantiairthreat']
                                        )
                                        table.insert(zonePriorityList, {ZoneID = v.id, Position = v.pos, Priority = priorityScore, Label = v.label, ResourceValue = v.resourcevalue, TeamValue = v.teamvalue, BestArmy = v.bestarmy, DistanceToBase = mainBaseDistance })
                                    end
                                end
                            end
                        end
                    end
                end
                coroutine.yield(1)
            end
            local filteredList = {}
            --LOG('Number of zoneprioritylist zones we can expand to '..table.getn(zonePriorityList))
            for _, zone in ipairs(zonePriorityList) do
                if aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE * (categories.FACTORY + categories.DIRECTFIRE), zone.Position, 30, 'Enemy') < 1 then
                    if zone.BestArmy and zone.BestArmy ~= armyIndex and ArmyBrains[zone.BestArmy].Status ~= 'Defeat' then
                        continue
                    end
                    if zone.ResourceValue < 3 then
                        --LOG('Zone worth less than 3')
                        --LOG('Team value was '..tostring(zone.TeamValue))
                        --LOG('Zone pos is '..tostring(zone.Position[1])..' : '..tostring(zone.Position[3]))
                        local higherValueExists = false
                        if zone.Label ~= mainBaseLabel then
                            for _, resValue in ipairs(labelResourceValue[zone.Label] or {}) do
                                if zoneSet[resValue.ZoneID].BuilderManager.FactoryManager.LocationActive and zoneSet[resValue.ZoneID].BuilderManager.BaseType ~= 'MAIN' then
                                    --LOG('Already have an active factory manager there on label '..tostring(zone.Label))
                                    --LOG('Location is '..tostring(zoneSet[resValue.ZoneID].pos[1])..' : '..tostring(zoneSet[resValue.ZoneID].pos[3]))
                                    higherValueExists = true
                                    break
                                end
                                if not resValue.StartPositionClose then
                                    if aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE * categories.FACTORY, zoneSet[resValue.ZoneID].pos, 30, 'Ally') < 1 
                                    and aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE * (categories.FACTORY + categories.DIRECTFIRE), zoneSet[resValue.ZoneID].pos, 30, 'Enemy') < 1 then
                                        if resValue.DistanceToBase < zone.DistanceToBase and resValue.ResourceValue >= zone.ResourceValue then
                                            --LOG('Low value, skip it pos '..tostring(zoneSet[resValue.ZoneID].pos[1]).. ':'..tostring(zoneSet[resValue.ZoneID].pos[3]))
                                            higherValueExists = true
                                            break
                                        end
                                    end
                                end
                            end
                        elseif zone.TeamValue < 0.8 or zone.TeamValue > 1.2 then
                            --LOG('Zone is less than 0.8 or more than 1.2')
                            for _, resValue in ipairs(labelResourceValue[zone.Label] or {}) do
                                if zoneSet[resValue.ZoneID].BuilderManager.FactoryManager.LocationActive then
                                    higherValueExists = true
                                    break
                                end
                                if not resValue.StartPositionClose then
                                    if aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE * categories.FACTORY, zoneSet[resValue.ZoneID].pos, 30, 'Ally') < 1 
                                    and aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE * (categories.FACTORY + categories.DIRECTFIRE), zoneSet[resValue.ZoneID].pos, 30, 'Enemy') < 1 then
                                        if resValue.DistanceToBase < zone.DistanceToBase and resValue.ResourceValue >= zone.ResourceValue then
                                            --LOG('Low value, skip it pos '..tostring(zoneSet[resValue.ZoneID].pos[1]).. ':'..tostring(zoneSet[resValue.ZoneID].pos[3]))
                                            higherValueExists = true
                                            break
                                        end
                                    end
                                end
                            end
                        else            
                            if aiBrain.BuilderManagers then
                                for _, base in aiBrain.BuilderManagers do
                                    local bx = zone.Position[1] - base.Position[1]
                                    local bz = zone.Position[3] - base.Position[3]
                                    local baseDistance = bx * bx + bz * bz
                                    if baseDistance <= 25600 then
                                        higherValueExists = true
                                        break
                                    end
                                end
                            end
                        end
                        if not higherValueExists then
                            table.insert(filteredList, zone)
                        end
                    else
                        if aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE * categories.FACTORY, zone.Position, 30, 'Ally') < 1 then
                            table.insert(filteredList, zone)
                        end
                    end
                end
            end
            --LOG('Number of filtered zones we can expand to '..table.getn(filteredList))
            if not table.empty(filteredList) then
                table.sort(filteredList, function(a, b) return a.Priority > b.Priority end)
                self.ZoneExpansions.Pathable = filteredList
                --aiBrain:ForkThread(self.DrawInfection, filteredList[1].Position)
            end
            coroutine.yield(50)
        end
    end,

    GetClosestZone = function(self, aiBrain, platoon, position, enemyPosition, controlRequired, minimumResourceValue)
            
        local zoneSet = false
        local movementLayer
        if not platoon then
            local inWater = RUtils.PositionInWater(position)
            if inWater then
                movementLayer = 'Water'
            else
                movementLayer = 'Land'
            end
        else
            movementLayer = platoon.MovementLayer
        end
        if aiBrain.ZonesInitialized then
            if platoon then
                if platoon.MovementLayer == 'Land' or platoon.MovementLayer == 'Amphibious' then
                    zoneSet = aiBrain.Zones.Land.zones
                elseif platoon.MovementLayer == 'Air' then
                    zoneSet = aiBrain.Zones.Air.zones
                elseif platoon.MovementLayer == 'Water' then
                    zoneSet = aiBrain.Zones.Naval.zones
                end
            else
                zoneSet = aiBrain.Zones.Land.zones
            end
            local originPosition
            if platoon then
                originPosition = platoon:GetPlatoonPosition()
            elseif position then
                originPosition = position
            end
            if not originPosition then
                return
            end
            local bestZoneDist
            local bestZone
            local control
            for k, v in zoneSet do
                if minimumResourceValue and v.resourcevalue < minimumResourceValue then
                    continue
                end
                if controlRequired then
                    control = aiBrain.GridPresence:GetInferredStatus(v.pos)
                end
                local dx = originPosition[1] - v.pos[1]
                local dz = originPosition[3] - v.pos[3]
                local zoneDist = dx * dx + dz * dz
                if (not bestZoneDist or zoneDist < bestZoneDist) and NavUtils.CanPathTo(movementLayer, originPosition, v.pos) then
                    if enemyPosition then 
                        local ex = enemyPosition[1] - v.pos[1]
                        local ez = enemyPosition[3] - v.pos[3]
                        local enemyDist = ex * ex + ez * ez
                        if enemyDist < zoneDist or RUtils.GetAngleRNG(originPosition[1], originPosition[3], v.pos[1], v.pos[3], enemyPosition[1], enemyPosition[3]) < 0.4 or (not controlRequired and enemyDist < 400) then
                            continue
                        end
                    end
                    if controlRequired then
                        if control == 'Allied' then
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
    end,

    CalculateZoneModifiers = function(self, zone)
        local GetControlValue = function(status)
            if status == 'Allied' then
                return 1
            elseif status == 'Hostile' then
                return 0
            elseif status == 'Contested' then
                return 0.5
            elseif status == 'Unoccupied' then
                return 0.25
            else
                return 0  -- Default in case of an unexpected value
            end
        end
        -- Transport Modifier
        local aiBrain = self.Brain
        local transportModifier = 1
    
        -- Distance Modifier
        local dx = zone.pos[1] - aiBrain.BrainIntel.StartPos[1]
        local dz = zone.pos[3] - aiBrain.BrainIntel.StartPos[3]
        local distanceModifier = math.sqrt(dx * dx + dz * dz)
    
        -- Threat Modifier
        local friendlyThreat = (zone.friendlyantisurfacethreat or 0) + 0.1 -- Only the zone's current friendly threat
        local threatRatio = zone.enemyantisurfacethreat / friendlyThreat
        local enemyModifier = 1 / (1 + threatRatio)
    
        -- Control Status Modifier
        local contestedWeight = 0.5 -- Adjust as needed
        local controlValue = GetControlValue(aiBrain.GridPresence:GetInferredStatus(zone.pos))
        local controlModifier = (1 - controlValue) + contestedWeight
    
        return transportModifier, distanceModifier, enemyModifier, controlModifier
    end,

    SelectZoneRNG = function(self, aiBrain, platoon, type, requireSameLabel)
        -- Tricky subject. Distance + threat + percentage of zones owned. If own a high value position do we pay more attention to the edges of that zone? 
        --A multiplier to adjacent edges if you would. We know how many and of what tier extractors we have in a zone. Actually getting an engineer to expand by zone would be interesting.
       --RNGLOG('RNGAI : Zone Selection Query Received for '..platoon.BuilderName)
        if PlatoonExists(aiBrain, platoon) then
            local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
            local zoneSet
            local zoneSelection
            local selection
            local platoonLabel = platoon.Label
            local currentPlatoonPos = platoon.Pos
            local enemyDanger = 1.0
            if requireSameLabel and platoon.MovementLayer == 'Amphibious' then
                local myLabel = NavUtils.GetLabel('Land', platoon.Pos)
                platoonLabel = myLabel
            end
            local enemyX, enemyZ
            if not platoon.Zone then
                WARN('RNGAI : Select Zone platoon has no zone attribute '..platoon.PlanName)
                coroutine.yield(20)
                return false
            end
           --RNGLOG('RNGAI : Zone Selection Query Checking if Zones initialized')
            if aiBrain.ZonesInitialized then
                if platoon.MovementLayer == 'Land' or platoon.MovementLayer == 'Amphibious' then
                    zoneSet = aiBrain.Zones.Land.zones
                elseif platoon.MovementLayer == 'Air' then
                    zoneSet = aiBrain.Zones.Air.zones
                elseif platoon.MovementLayer == 'Water' then
                    zoneSet = aiBrain.Zones.Naval.zones
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
                    for k, v in zoneSet do
                        if v.pos[1] > playableArea[1] and v.pos[1] < playableArea[3] and v.pos[3] > playableArea[2] and v.pos[3] < playableArea[4] then
                            if requireSameLabel and platoonLabel and v.label > 0 and platoonLabel ~= v.label then
                                continue
                            end
                            if currentPlatoonPos then
                                local rx = currentPlatoonPos[1] - v.pos[1]
                                local rz = currentPlatoonPos[3] - v.pos[3]
                                local zoneDist = rx * rx + rz * rz
                                if zoneDist < 625 then
                                    if platoon.CurrentPlatoonThreatAntiSurface > 0 then
                                        if v.enemylandthreat < 1 then
                                            platoon:LogDebug(string.format('We are too close to this zone and there is no enemy land threat'))
                                            continue
                                        end
                                    elseif v.BuilderManager.BaseType and platoon.CurrentPlatoonThreatAntiAir > 0 then
                                        local locationType = v.BuilderManager.BaseType
                                        if locationType then
                                            if aiBrain.BasePerimeterMonitor[locationType].AirUnits < 1 then
                                                platoon:LogDebug(string.format('We air threat only and are too close to this zone and there is no enemy air threat'))
                                                continue
                                            end
                                        end
                                    end
                                end
                            end
                            if not v.startpositionclose then
                                if platoonPosition then
                                    local compare
                                    local enemyDistanceModifier 
                                    if enemyX and enemyZ then
                                        enemyDistanceModifier = VDist2(v.pos[1],v.pos[3],enemyX, enemyZ)
                                    else
                                        enemyDistanceModifier = 1
                                    end
                                    local zoneDistanceModifier = VDist2(v.pos[1],v.pos[3],platoonPosition[1], platoonPosition[3])
                                    local enemyModifier = v.enemyantisurfacethreat
                                    local status = aiBrain.GridPresence:GetInferredStatus(v.pos)
                                    if enemyModifier > 0 then
                                        enemyModifier = enemyModifier * 5
                                    end
                                    for _, e in  v.enemystartdata do
                                        if e.startdistance < 10000 then
                                            enemyModifier = enemyModifier + 20
                                            break
                                        end
                                    end
                                    --RNGLOG('Start Distance Calculation '..( 20000 / enemyDistanceModifier )..' Zone Distance Calculation'..(20000 / zoneDistanceModifier)..' Resource Value '..v.resourcevalue..' Control Value '..status)
                                    --RNGLOG('Friendly threat at zone is '..v.friendlyantisurfacethreat)
                                    if status ~= 'Allied' and v.friendlyantisurfacethreat < 10 then
                                        compare = (20000 / zoneDistanceModifier) + ( 20000 / enemyDistanceModifier ) * v.resourcevalue - enemyModifier
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
                    end
                    if selection then
                        --LOG('Looking at non start position zones')
                        return zoneSelection
                    else
                        --LOG('Looking at start position zones')
                        for k, v in startPosZones do
                            if platoonPosition then
                                local compare
                                local enemyDistance
                                if enemyX and enemyZ then
                                    enemyDistance = math.ceil(VDist2(v.pos[1],v.pos[3],enemyX, enemyZ))
                                else
                                    enemyDistance = 512
                                end
                                local enemyDistanceModifier = enemyDistance > 0 and enemyDistance or 1
                                local zoneDistanceModifier = math.ceil(VDist2(v.pos[1],v.pos[3],platoonPosition[1], platoonPosition[3]))
                                local status = aiBrain.GridPresence:GetInferredStatus(v.pos)
                                --LOG('Start Distance modifier'..tostring(enemyDistanceModifier)..' Calculation '..( 20000 / enemyDistanceModifier )..' Zone Distance Modifier '..tostring(zoneDistanceModifier)..' Calculation'..(20000 / zoneDistanceModifier)..' Resource Value '..v.resourcevalue..' Control Value '..status)
                                if status == 'Allied' then
                                    compare = (20000 / zoneDistanceModifier) + ( 20000 / enemyDistanceModifier )
                                else
                                    compare = (20000 / zoneDistanceModifier) + ( 20000 / enemyDistanceModifier ) * v.resourcevalue
                                end
                                if compare then
                                    --RNGLOG('Compare variable '..compare)
                                end
                                if compare > 0 then
                                    if not selection or compare > selection then
                                        selection = compare
                                        zoneSelection = v.id
                                        --RNGLOG('Zone Query Select priority 2nd pass start locations'..selection)
                                        --RNGLOG('Zone target location is '..repr(v.pos))
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
                    for k, v in zoneSet do
                        if v.pos[1] > playableArea[1] and v.pos[1] < playableArea[3] and v.pos[3] > playableArea[2] and v.pos[3] < playableArea[4] then
                            if requireSameLabel and platoonLabel and v.label > 0 and platoonLabel ~= v.label then
                                continue
                            end
                            local distanceModifier = VDist3(v.pos,aiBrain.BrainIntel.StartPos)
                            local enemyModifier = 1
                            local startPos = 1
                            local status = aiBrain.GridPresence:GetInferredStatus(v.pos)
                            if v.enemyantisurfacethreat > 0 then
                                enemyModifier = enemyModifier + 2
                            end
                            if v.friendlyantisurfacethreat > 0 then
                                if v.enemyantisurfacethreat == 0 or v.enemyantisurfacethreat < v.friendlyantisurfacethreat then
                                    enemyModifier = enemyModifier - 1
                                else
                                    enemyModifier = enemyModifier + 1
                                end
                            end
                            if enemyModifier < 0 then
                                enemyModifier = 0.5
                            end
                            local controlValue = 1
                            if status =='Allied' then
                                controlValue = 0.25
                            end
                            local resourceValue = v.resourcevalue or 1
                            if v.startpositionclose then
                                startPos = 0.7
                            end
                            if v.enemyantisurfacethreat > v.friendlyantisurfacethreat then
                                if platoon.CurrentPlatoonThreatAntiSurface and platoon.CurrentPlatoonThreatAntiSurface < v.enemyantisurfacethreat then
                                    enemyDanger = 0.4
                                end
                            end
                        --[[ if aiBrain.RNGDEBUG then
                                if distanceModifier and resourceValue and controlValue and enemyModifier then
                                    RNGLOG('distanceModifier '..distanceModifier)
                                    RNGLOG('resourceValue '..resourceValue)
                                    RNGLOG('controlValue '..controlValue)
                                    RNGLOG('enemyModifier '..enemyModifier)
                                end
                            end]]
                            compare = ( 20000 / distanceModifier ) * resourceValue * controlValue * enemyModifier * startPos * enemyDanger * v.teamvalue
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
                    end
                    if not selection then
                        --LOG('No Selection was found')
                        for k, v in zoneSet do
                            if v.pos[1] > playableArea[1] and v.pos[1] < playableArea[3] and v.pos[3] > playableArea[2] and v.pos[3] < playableArea[4] then
                                if requireSameLabel and platoonLabel and v.label > 0 and platoonLabel ~= v.label then
                                    continue
                                end
                                if not v.startpositionclose then
                                    local distanceModifier = VDist2(v.pos[1],v.pos[3],enemyX, enemyZ)
                                    local enemyModifier = 1
                                    local status = aiBrain.GridPresence:GetInferredStatus(v.pos)
                                    if v.enemyantisurfacethreat > 0 then
                                        enemyModifier = enemyModifier + 2
                                    end
                                    if v.friendlyantisurfacethreat > 0 then
                                        if v.enemyantisurfacethreat < v.friendlyantisurfacethreat then
                                            enemyModifier = enemyModifier - 1
                                        else
                                            enemyModifier = enemyModifier + 1
                                        end
                                    end
                                    if enemyModifier < 0 then
                                        enemyModifier = 0
                                    end
                                    local controlValue = 1
                                    if status == 'Allied' then
                                        controlValue = 0.1
                                    end
                                    local resourceValue = v.resourcevalue or 1
                                --RNGLOG('Current platoon zone '..platoon.Zone..' Distance Calculation '..( 20000 / distanceModifier )..' Resource Value '..resourceValue..' Control Value '..controlValue..' position '..repr(v.pos)..' Enemy Modifier is '..enemyModifier)
                                    compare = ( 20000 / distanceModifier ) * resourceValue * controlValue * enemyModifier * v.teamvalue
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
                    end
                    if selection then
                        --LOG('Zone Selection was '..tostring(zoneSelection))
                        return zoneSelection
                    else
                       --RNGLOG('RNGAI : Zone Control Selection Query did not select zone')
                    end
                elseif type == 'aadefense' then
                    --local selfThreat = aiBrain.BrainIntel.SelfThreat
                    --local enemyThreat = aiBrain.EnemyIntel.EnemyThreatCurrent
                    --local zoneCount = aiBrain.BuilderManagers['MAIN'].PathableZones.PathableLandZoneCount
                    --local totalMobileAARequired = math.ceil(zoneCount * (enemyThreat.Air / selfThreat.AirNow)) or 1
                    --local threatRequired
                    local weightageValues = {
                        teamValue = 0.3,
                        massValue = 0.2,
                        enemyAntiSurface = 0.1,
                        enemyAir = 0.5,
                        friendlyantisurfacethreat = 0.05,
                        friendlylandantiairthreat = 0.05,
                        startPos = 0.3,
                        control = 0.3,
                    }
                    local originPos
                    local maxTeamValue = 2
                    local maxResourceValue = self.MapMaximumValues.MaximumResourceValue
                    if maxResourceValue == 0 then
                        maxResourceValue = 1
                    end
                    if platoon then
                        originPos = platoon.Pos
                    else
                        originPos = aiBrain.BrainIntel.StartPos
                    end
                    local maxEnemyAntiSurfaceThreat = 25
                    local maxEnemyAirThreat = 25
                    local maxFriendlyAntiSurfaceThreat = 25
                    local maxFriendlyAirThreat = 25
                    local zoneCount = aiBrain.BuilderManagers[platoon.LocationType].PathableZones.PathableLandZoneCount or 0
                    local enemyAirThreat = aiBrain.EnemyIntel.EnemyThreatCurrent.Air
                    local myAirThreat = aiBrain.BrainIntel.SelfThreat.AirNow
                    local enemyThreatRatio = 0
                    local ignoreHomeBase = platoon.Zone and aiBrain.BuilderManagers[platoon.LocationType].Zone and platoon.Zone == aiBrain.BuilderManagers[platoon.LocationType].Zone and 
                        aiBrain.BasePerimeterMonitor[platoon.LocationType].AirThreat and aiBrain.BasePerimeterMonitor[platoon.LocationType].AirThreat < 1
                    if zoneCount > 0 and enemyAirThreat > 0 and myAirThreat > 0 then
                        enemyThreatRatio = math.min((enemyAirThreat / myAirThreat * zoneCount), 25)
                    end

                    
                   --RNGLOG('RNGAI : Zone Control Selection Query Processing First Pass')
                    for k, v in zoneSet do
                        if v.pos[1] > playableArea[1] and v.pos[1] < playableArea[3] and v.pos[3] > playableArea[2] and v.pos[3] < playableArea[4] then
                            if requireSameLabel and platoonLabel and v.label > 0 and platoonLabel ~= v.label then
                                continue
                            end
                            if ignoreHomeBase then
                                continue
                            end
                            if v.friendlyantiairallocatedthreat > math.max(v.enemyairthreat, enemyThreatRatio) then
                                --LOG('Already enough aa threat allocated')
                                --LOG('Current antiair allocated '..tostring(v.friendlyantiairallocatedthreat))
                                --LOG('Maximum Allowed '..tostring(math.max(v.enemyairthreat * 2, enemyThreatRatio)))
                                continue
                            end
                            local startPos = 1
                            local status = aiBrain.GridPresence:GetInferredStatus(v.pos)
                            local controlValue = 1
                            if status == 'Hostile' and v.friendlyantisurfacethreat == 0 then continue end
                            if status == 'Contested' or status == 'Unoccupied' then
                                controlValue = 1.5
                            end
                            if v.startpositionclose then
                                startPos = 1.5
                            end
                            local normalizedTeamValue = v.teamvalue / maxTeamValue
                            local normalizedResourceValue = v.resourcevalue / maxResourceValue
                            local normalizedEnemyAntiSurfaceThreatValue = v.enemyantisurfacethreat / maxEnemyAntiSurfaceThreat
                            local normalizedEnemyAirThreatValue = v.enemyairthreat / maxEnemyAirThreat
                            local normalizedFriendAntiSurfaceThreatValue = v.friendlyantisurfacethreat / maxFriendlyAntiSurfaceThreat
                            local normalizedFriendAirThreatValue = v.friendlylandantiairthreat / maxFriendlyAirThreat
                            local normalizedStartPosValue = startPos
                            local normalizedControlValue = controlValue
                            local priorityScore = (
                                normalizedTeamValue * weightageValues['teamValue'] +
                                normalizedResourceValue * weightageValues['massValue'] -
                                normalizedEnemyAntiSurfaceThreatValue * weightageValues['enemyAntiSurface'] -
                                normalizedStartPosValue * weightageValues['startPos'] +
                                normalizedControlValue * weightageValues['control'] +
                                normalizedEnemyAirThreatValue * weightageValues['enemyAir'] +
                                normalizedFriendAntiSurfaceThreatValue * weightageValues['friendlyantisurfacethreat'] -
                                normalizedFriendAirThreatValue * weightageValues['friendlylandantiairthreat']
                            )
                            --LOG('Priority Score '..tostring(priorityScore))
                            --LOG('Current antiair allocated '..tostring(v.friendlyantiairallocatedthreat))
                            --LOG('Maximum Allowed '..tostring(math.max(v.enemyairthreat * 2, enemyThreatRatio)))
                            if not selection or priorityScore > selection then
                                selection = priorityScore
                                zoneSelection = v.id
                            end
                        end
                    end
                    if zoneSelection then
                        --LOG('AntiAir Defense zone was selected threat ratio was '..tostring(enemyThreatRatio)..' air threat at position was '..tostring(zoneSet[zoneSelection].enemyairthreat))
                        return zoneSelection
                    else
                        --LOG('AntiAir Defense zone was selected threat ratio was')
                        local randomZones = {}
                        local randomZoneCount = 0
                        for k, v in zoneSet do
                            if v.pos[1] > playableArea[1] and v.pos[1] < playableArea[3] and v.pos[3] > playableArea[2] and v.pos[3] < playableArea[4] then
                                if requireSameLabel and platoonLabel and v.label > 0 and platoonLabel ~= v.label then
                                    continue
                                end
                                if v.teamvalue > 0.8 then
                                    table.insert(randomZones, {zoneid = v.id})
                                    randomZoneCount = randomZoneCount + 1
                                end
                            end
                        end
                        if randomZoneCount > 0 then
                            zoneSelection = randomZones[Random(1,randomZoneCount)].zoneid
                        end
                    end
                    if zoneSelection then
                        --LOG('Returning random zone number '..tostring(zoneSelection))
                        --LOG('Details on zone ')
                        --LOG('Distance is '..tostring(VDist3(zoneSet[zoneSelection].pos, originPos)))
                        --LOG('friend aa threat '..tostring(zoneSet[zoneSelection].friendlylandantiairthreat))
                        return zoneSelection
                    else
                        --LOG('Still no zone selection, random zone count was '..tostring(randomZoneCount))
                    end
                elseif type == 'naval' then
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
        local aiBrain = self.Brain
        local selfIndex = aiBrain:GetArmyIndex()
        local ownedZones = 0
        local totalZones = 0
        while aiBrain.Status ~= "Defeat" do
            for k, v in Zones do
                for k1, v1 in aiBrain.Zones[v].zones do
                    local status = aiBrain.GridPresence:GetInferredStatus(v1.pos)
                    if v1.bestarmy == selfIndex then
                        totalZones = totalZones + 1
                        if status == 'Allied' then
                            ownedZones = ownedZones + 1
                        end
                    end
                    if not v1.startpositionclose and status == 'Allied' and v1.enemylandthreat > 0 then
                        --RNGLOG('Try create zone alert for threat')
                        aiBrain:BaseMonitorZoneThreatRNG(v1.id, v1.enemylandthreat)
                    end
                    coroutine.yield(5)
                end
                coroutine.yield(3)
            end
            if ownedZones > 0 then
                aiBrain.BrainIntel.PlayerZoneControl = ownedZones / totalZones
            else 
                aiBrain.BrainIntel.PlayerZoneControl = 0
            end
            coroutine.yield(40)
        end
    end,

    ZoneEnemyIntelMonitorRNG = function(self)
        local Zones = {
            'Land',
        }
        self:WaitForZoneInitialization()
        coroutine.yield(Random(5,20))
        local aiBrain = self.Brain
        while aiBrain.Status ~= "Defeat" do
            for k, v in Zones do
                for k1, v1 in aiBrain.Zones[v].zones do
                    v1.enemylandthreat = GetThreatAtPosition(aiBrain, v1.pos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'Land')
                    v1.enemyantisurfacethreat = GetThreatAtPosition(aiBrain, v1.pos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface')
                    v1.enemyantiairthreat = GetThreatAtPosition(aiBrain, v1.pos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
                    v1.enemyairthreat = GetThreatAtPosition(aiBrain, v1.pos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'Air')
                    v1.enemystructurethreat = GetThreatAtPosition(aiBrain, v1.pos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'StructuresNotMex')
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
        local aiBrain = self.Brain
        while aiBrain.Status ~= "Defeat" do
            local Zones = {
                'Land',
            }
            local AlliedPlatoons = aiBrain:GetPlatoonsList()
            for k, v in Zones do
                local friendlyThreatAntiSurface = {}
                local friendlyThreatDirecFireAntiSurface = {}
                local friendlyThreatIndirecFireAntiSurface = {}
                local friendlyThreatAntiAir = {}
                local friendlyThreatAntiAirAllocated = {}
                local labelThreat = {}
                for k1, v1 in AlliedPlatoons do
                    if not v1.MovementLayer then
                        AIAttackUtils.GetMostRestrictiveLayerRNG(v1)
                    end
                    if not v1.Dead then
                        if v1.Zone and v1.CurrentPlatoonThreatAntiSurface then
                            if not friendlyThreatAntiSurface[v1.Zone] then
                                friendlyThreatAntiSurface[v1.Zone] = 0
                            end
                            friendlyThreatAntiSurface[v1.Zone] = friendlyThreatAntiSurface[v1.Zone] + v1.CurrentPlatoonThreatAntiSurface
                        end
                        if v1.Zone and v1.CurrentPlatoonThreatDirectFireAntiSurface then
                            if not friendlyThreatDirecFireAntiSurface[v1.Zone] then
                                friendlyThreatDirecFireAntiSurface[v1.Zone] = 0
                            end
                            friendlyThreatDirecFireAntiSurface[v1.Zone] = friendlyThreatDirecFireAntiSurface[v1.Zone] + v1.CurrentPlatoonThreatDirectFireAntiSurface
                        end
                        if v1.Zone and v1.CurrentPlatoonThreatIndirectFireAntiSurface then
                            if not friendlyThreatIndirecFireAntiSurface[v1.Zone] then
                                friendlyThreatIndirecFireAntiSurface[v1.Zone] = 0
                            end
                            friendlyThreatIndirecFireAntiSurface[v1.Zone] = friendlyThreatIndirecFireAntiSurface[v1.Zone] + v1.CurrentPlatoonThreatIndirectFireAntiSurface
                        end
                        if v1.Zone and v1.CurrentPlatoonThreatAntiAir then
                            if not friendlyThreatAntiAir[v1.Zone] then
                                friendlyThreatAntiAir[v1.Zone] = 0
                            end
                            friendlyThreatAntiAir[v1.Zone] = friendlyThreatAntiAir[v1.Zone] + v1.CurrentPlatoonThreatAntiAir
                        end
                        if v1.ZoneAllocated and v1.CurrentPlatoonThreatAntiAir then
                            if not friendlyThreatAntiAirAllocated[v1.ZoneAllocated] then
                                friendlyThreatAntiAirAllocated[v1.ZoneAllocated] = 0
                            end
                            friendlyThreatAntiAirAllocated[v1.ZoneAllocated] = friendlyThreatAntiAirAllocated[v1.ZoneAllocated] + v1.CurrentPlatoonThreatAntiAir
                        end
                    end
                end
                for k2, v2 in aiBrain.Zones[v].zones do
                    for k3, v3 in friendlyThreatAntiSurface do
                        if k2 == k3 then
                            aiBrain.Zones[v].zones[k2].friendlyantisurfacethreat = v3
                        end
                    end
                    for k3, v3 in friendlyThreatAntiAirAllocated do
                        if k2 == k3 then
                            aiBrain.Zones[v].zones[k2].friendlyantiairallocatedthreat = v3
                        end
                    end
                    for k3, v3 in friendlyThreatDirecFireAntiSurface do
                        if k2 == k3 then
                            aiBrain.Zones[v].zones[k2].friendlydirectfireantisurfacethreat = v3
                            if v2.label > 0 and not labelThreat[v2.label] then
                                labelThreat[v2.label] = {
                                    friendlydirectfireantisurfacethreat = 0,
                                    friendlyindirectantisurfacethreat = 0,
                                    friendlyThreatAntiAir = 0
                                }
                            end
                            if v2.label > 0 then
                                labelThreat[v2.label].friendlydirectfireantisurfacethreat = labelThreat[v2.label].friendlydirectfireantisurfacethreat + v3
                            end
                        end
                    end
                    for k3, v3 in friendlyThreatIndirecFireAntiSurface do
                        if k2 == k3 then
                            aiBrain.Zones[v].zones[k2].friendlyindirectantisurfacethreat = v3
                            if v2.label > 0 and not labelThreat[v2.label] then
                                labelThreat[v2.label] = {
                                    friendlydirectfireantisurfacethreat = 0,
                                    friendlyindirectantisurfacethreat = 0,
                                    friendlyThreatAntiAir = 0
                                }
                            end
                            if v2.label > 0 then
                                labelThreat[v2.label].friendlyindirectantisurfacethreat = labelThreat[v2.label].friendlyindirectantisurfacethreat + v3
                            end
                        end
                    end
                    for k3, v3 in friendlyThreatAntiAir do
                        if k2 == k3 then
                            aiBrain.Zones[v].zones[k2].friendlyThreatAntiAir = v3
                            if v2.label > 0 and not labelThreat[v2.label] then
                                labelThreat[v2.label] = {
                                    friendlydirectfireantisurfacethreat = 0,
                                    friendlyindirectantisurfacethreat = 0,
                                    friendlyThreatAntiAir = 0
                                }
                            end
                            if v2.label > 0 then
                                labelThreat[v2.label].friendlyThreatAntiAir = labelThreat[v2.label].friendlyThreatAntiAir + v3
                            end
                        end
                    end
                end
                for k2, v2 in aiBrain.GraphZones do
                    for k3, v3 in labelThreat do
                        if k2 == k3 and v3.friendlydirectfireantisurfacethreat then
                            aiBrain.GraphZones[k2].FriendlySurfaceDirectFireThreat = v3.friendlydirectfireantisurfacethreat
                            --LOG('Assigned FriendlySurfaceDirectFireThreat to graphzone '..k2..' of '..aiBrain.GraphZones[k2].FriendlySurfaceDirectFireThreat)
                        end
                        if k2 == k3 and v3.friendlyindirectantisurfacethreat then
                            aiBrain.GraphZones[k2].FriendlySurfaceInDirectFireThreat = v3.friendlyindirectantisurfacethreat
                            --LOG('Assigned FriendlySurfaceInDirectFireThreat to graphzone '..k2..' of '..aiBrain.GraphZones[k2].FriendlySurfaceInDirectFireThreat)
                        end
                        if k2 == k3 and v3.friendlyThreatAntiAir then
                            aiBrain.GraphZones[k2].FriendlyLandAntiAirThreat = v3.friendlyThreatAntiAir
                            --LOG('Assigned FriendlyLandAntiAirThreat to graphzone '..k2..' of '..aiBrain.GraphZones[k2].FriendlyLandAntiAirThreat)
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
        local aiBrain = self.Brain
        local intelRadius = unit.Blueprint.Intel.RadarRadius * unit.Blueprint.Intel.RadarRadius
        local radarPosition = unit:GetPosition()
        if unit.Blueprint.CategoriesHash.RADAR then
            --RNGLOG('Zone set for radar that has been built '..unit.UnitId)
            unit.zoneid = MAP:GetZoneID(radarPosition,aiBrain.Zones.Land.index)
            if unit.zoneid then
                local zone = aiBrain.Zones.Land.zones[unit.zoneid]
                if VDist3Sq(radarPosition, zone.pos) < intelRadius then
                    if not zone.intelassignment.RadarUnits then
                        zone.intelassignment.RadarUnits = {}
                    end
                    RNGINSERT(zone.intelassignment.RadarUnits, unit)
                    zone.intelassignment.RadarCoverage = true
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
        local aiBrain = self.Brain
        local radarPosition = unit:GetPosition()
        if unit.Blueprint.CategoriesHash.RADAR then
            --RNGLOG('Unassigning Radar Unit')
            if unit.zoneid then
                local zone = aiBrain.Zones.Land.zones[unit.zoneid]
                if zone.intelassignment.RadarUnits then
                    for c, b in zone.intelassignment.RadarUnits do
                        if b == unit then
                            --RNGLOG('Found Radar that was covering zone '..k..' removing')
                            RNGREMOVE(zone.intelassignment.RadarUnits, c)
                        end
                    end
                    if zone.intelassignment.RadarCoverage and table.empty(zone.intelassignment.RadarUnits) then
                        --RNGLOG('No Radars in range for zone '..k..' setting radar coverage to false')
                        zone.intelassignment.RadarCoverage = false
                    end
                end
            end
            local gridSearch = math.floor(unit.Blueprint.Intel.RadarRadius / MapIntelGridSize)
            self:DisinfectGridPosition(radarPosition, gridSearch, 'Radar', 'IntelCoverage', false, unit)
        end
    end,

    TacticalIntelCheck = function(self)
        coroutine.yield(300)
        local aiBrain = self.Brain
        while aiBrain.Status ~= "Defeat" do
            coroutine.yield(45)
            self:ForkThread(self.AdaptiveProductionThread, 'AirAntiSurface',{ MaxThreat = 20})
            coroutine.yield(1)
            self:ForkThread(self.AdaptiveProductionThread, 'DefensiveAntiSurface')
            coroutine.yield(1)
            self:ForkThread(self.AdaptiveProductionThread, 'LandAntiSurface')
            coroutine.yield(1)
            self:ForkThread(self.AdaptiveProductionThread, 'AirAntiNaval',{ MaxThreat = 20})
            coroutine.yield(1)
            self:ForkThread(self.AdaptiveProductionThread, 'MobileAntiAir',{ MaxThreat = 20})
            coroutine.yield(1)
            self:ForkThread(self.AdaptiveProductionThread, 'ExperimentalArtillery',{ MaxThreat = 20})
            coroutine.yield(1)
            self:ForkThread(self.AdaptiveProductionThread, 'IntelStructure', { Tier = 'T3', Structure = 'optics'})
            coroutine.yield(1)
            self:ForkThread(self.AdaptiveProductionThread, 'LandIndirectFire')
            coroutine.yield(1)
            self:ForkThread(self.AdaptiveProductionThread, 'NavalAntiSurface')
            coroutine.yield(1)
            self:ForkThread(self.AdaptiveProductionThread, 'EngineerBuildPower')
        end
    end,

    DrawZoneRadius = function(self, position, colour, time)
        --RNGLOG('Draw Target Radius points')
        local counter = 0
        while counter < time do
            DrawCircle(position, 5, colour)
            counter = counter + 1
            coroutine.yield( 2 )
        end
    end,

    DrawZoneArmyValue = function(self)
        local colours = { 'aaff7f0e', 'aa2ca02c', 'aad62728', 'aa9467bd', 'aa8c564b', 'aae377c2', 'aa7f7f7f', 'aabcbd22', 'aa17becf' }
        self:WaitForZoneInitialization()
        self:WaitForNavmeshGeneration()
        while not self.MapIntelStats.ScoutLocationsBuilt do
            LOG('*AI:RNG NavalAttackCheck is waiting for ScoutLocations to be built')
            coroutine.yield(20)
        end
        coroutine.yield(50)
    
        local aiBrain = self.Brain
        local colourIndex = 1
        local colourAssignment = {}
        --LOG('starting zonedrawradius')
    
        for _, zone in aiBrain.Zones.Land.zones do
            -- Assign a color to the bestarmy if not already assigned
            --LOG('Zone is '..tostring(zone.id))
            if zone.bestarmy then
                --LOG('Zone has bestarmy '..tostring(zone.bestarmy))
                if not colourAssignment[zone.bestarmy] then
                    colourAssignment[zone.bestarmy] = colourIndex
                    colourIndex = colourIndex + 1
                end
        
                -- Get the correct color for this zone's bestarmy
                local assignedColor = colourAssignment[zone.bestarmy]
                self:ForkThread(self.DrawZoneRadius, zone.pos, colours[assignedColor], 600)
            end
        end
    end,

    ZoneIntelAssignment = function(self)
        -- Will setup table for scout assignment to zones
        -- I did this because I didn't want to assign units directly to the zones since it makes it hard to troubleshoot
        -- replaces the previous expansion scout assignment so that all mass points can be monitored
        -- Will also set data for intel based scout production.
        
        self:WaitForZoneInitialization()
        self:WaitForNavmeshGeneration()
        local aiBrain = self.Brain
        while not self.MapIntelStats.ScoutLocationsBuilt do
            LOG('*AI:RNG NavalAttackCheck is waiting for ScoutLocations to be built')
            coroutine.yield(20)
        end
        coroutine.yield(Random(5,20))
        local teamAveragePositions = self:GetTeamAveragePositions()
        self:CalculatePlayerSlot()
        local maximumResourceValue = 0
        local Zones = {
            'Land',
            'Naval'
        }
        local expansionSize = math.min((aiBrain.MapDimension / 2), 180)
        for _, v in Zones do
            for _, v1 in aiBrain.Zones[v].zones do
                v1.label = self:ZoneSetLabelAssignment(v, v1.pos)
                if v1.resourcevalue > maximumResourceValue then
                    maximumResourceValue = v1.resourcevalue
                end
                v1.teamvalue = self:GetTeamDistanceValue(v1.pos, teamAveragePositions)
                local enemyStartData, allyStartData = self:SetEnemyPositionAngleAssignment(v1)
                v1.enemystartdata = {}
                for k, v in enemyStartData do
                    v1.enemystartdata[k] = { startangle = v.startangle, startdistance = v.startdistance}
                end
                v1.allystartdata = {}
                for k, v in allyStartData do
                    v1.allystartdata[k] = { startangle = v.startangle, startdistance = v.startdistance}
                end
                v1.bestarmy = self:ZoneSetBestArmy(v1)
            end
        end
        --LOG('Best Armies are set')
        self.MapMaximumValues.MaximumResourceValue = maximumResourceValue
    end,

    ZoneSetBestArmy = function(self, zone)
        local aiBrain = self.Brain
        local closestArmy
        local closestDistance
        for k, v in aiBrain.BrainIntel.AllyStartLocations do
            local ax = v.Position[1] - zone.pos[1]
            local az = v.Position[3] - zone.pos[3]
            local armyDist = ax * ax + az * az
            if zone.teamvalue >= 1.0 and (not closestDistance or armyDist < closestDistance) then
                closestArmy = k
                closestDistance = armyDist
            end
        end
        if closestArmy then
            --LOG('Best army besting returned for zone is '..tostring(closestArmy))
            return closestArmy
        end
        --LOG('No closestArmy is being returned')
        return false
    end,

    ZoneSetIntelAssignment = function(self, key, zone)
        local IntelAssignment = { Zone = key, Position = zone.pos, RadarCoverage = false, RadarUnits = { }, ScoutUnit = false, StartPosition = zone.startpositionclose}
        return IntelAssignment
    end,

    ZoneSetLabelAssignment = function (self, movementLayer, zonePos)
        if movementLayer == 'Naval' then
            movementLayer = 'Water'
        end
        local label = NavUtils.GetLabel(movementLayer, zonePos) or 0
        return label
    end,

    SetEnemyPositionAngleAssignment = function(self, zone)

        local enemyStartData = { }
        local allyStartData = { }
        local aiBrain = self.Brain
        if not RNGTableEmpty(aiBrain.EnemyIntel.EnemyStartLocations) then
            for k, v in aiBrain.EnemyIntel.EnemyStartLocations do
                enemyStartData[k] = { }
                enemyStartData[k].startangle = RUtils.GetAngleToPosition(v.Position, zone.pos)
                enemyStartData[k].startdistance = VDist3Sq(v.Position, zone.pos)
            end
        else
            WARN('AI-RNG : No Enemy Start Locations are present')
        end
        if not RNGTableEmpty(aiBrain.BrainIntel.AllyStartLocations) then
            for k, v in aiBrain.BrainIntel.AllyStartLocations do
                allyStartData[k] = { }
                allyStartData[k].startangle = RUtils.GetAngleToPosition(v.Position, zone.pos)
                allyStartData[k].startdistance = VDist3Sq(v.Position, zone.pos)
            end
        else
            WARN('AI-RNG : No Ally Start Locations are present')
        end
        return enemyStartData, allyStartData

    end,

    GetTeamDistanceValue = function(self, pos, teamAveragePositions)
        -- This sets the team values for zones. Greater than 1 means that its closer to us than the enemy, less than 1 means its closer to the enemy than us.
        -- Positions are based on a team average. Could produce strange results if the team is spread in strange ways
        local teamValue
        if teamAveragePositions['Ally'] and teamAveragePositions['Enemy'] then
            local ax = teamAveragePositions['Ally'].x - pos[1]
            local az = teamAveragePositions['Ally'].z - pos[3]
            local allyPosDist = ax * ax + az * az
            local ex = teamAveragePositions['Enemy'].x - pos[1]
            local ez = teamAveragePositions['Enemy'].z - pos[3]
            local enemyPosDist = ex * ex + ez * ez
            teamValue = RUtils.CalculateRelativeDistanceValue(math.sqrt(enemyPosDist), math.sqrt(allyPosDist))
        else
            teamValue = 1
        end
        return teamValue
    end,

    CalculatePlayerSlot = function(self)
        local furthestPlayer = false
        local closestPlayer = false
        local aiBrain = self.Brain
        local selfIndex = aiBrain:GetArmyIndex()
        if aiBrain.BrainIntel.AllyCount > 2 and aiBrain.EnemyIntel.EnemyCount > 0 then
            local closestIndex
            local closestDistance
            local furthestPlayerDistance
            local closestPlayerDistance
            local selfDistanceToEnemy
            local selfDistanceToTeammates
            
            for _, b in aiBrain.EnemyIntel.EnemyStartLocations do
                if not closestIndex or b.Distance < closestDistance then
                    closestDistance = b.Distance
                    closestIndex = b.Index
                end
            end
            
            selfDistanceToEnemy = VDist3Sq(aiBrain.BrainIntel.StartPos, aiBrain.EnemyIntel.EnemyStartLocations[closestIndex].Position)
            
            for _, v in aiBrain.BrainIntel.AllyStartLocations do
                if v.Index ~= selfIndex then
                    local distanceToEnemy = VDist3Sq(v.Position, aiBrain.EnemyIntel.EnemyStartLocations[closestIndex].Position)
                    local distanceToTeammate = VDist3Sq(v.Position, aiBrain.BrainIntel.StartPos)
                    
                    if not furthestPlayerDistance or distanceToEnemy > furthestPlayerDistance then
                        furthestPlayerDistance = distanceToEnemy
                    end
                    if not closestPlayerDistance or distanceToEnemy < closestPlayerDistance then
                        closestPlayerDistance = distanceToEnemy
                    end
                    if not selfDistanceToTeammates or distanceToTeammate < selfDistanceToTeammates then
                        selfDistanceToTeammates = distanceToTeammate
                    end
                end
            end
            
            if closestDistance and furthestPlayerDistance and closestDistance > furthestPlayerDistance then
                if math.sqrt(closestDistance) - math.sqrt(furthestPlayerDistance) > 50 then
                    if not aiBrain.BrainIntel.PlayerRole.ExperimentalPlayer and not aiBrain.BrainIntel.PlayerRole.SpamPlayer then
                        furthestPlayer = true
                        aiBrain.BrainIntel.PlayerRole.AirPlayer = true
                        aiBrain:EvaluateDefaultProductionRatios()
                        return
                    end
                end
            end
            if not furthestPlayer then
                if closestDistance and selfDistanceToEnemy and selfDistanceToEnemy <= closestPlayerDistance then
                    if math.sqrt(selfDistanceToEnemy) - math.sqrt(selfDistanceToTeammates) > 50 then
                        if not aiBrain.BrainIntel.PlayerRole.ExperimentalPlayer and not aiBrain.BrainIntel.PlayerRole.AirPlayer then
                            aiBrain.BrainIntel.PlayerRole.SpamPlayer = true
                            self:ForkThread(self.SpamTriggerDurationThread)
                            return
                        end
                    end
                end
            end
            if not aiBrain.BrainIntel.PlayerRole.AirPlayer and not aiBrain.BrainIntel.PlayerRole.SpamPlayer then
                if aiBrain.BrainIntel.NavalBaseLabels and aiBrain.BrainIntel.NavalBaseLabelCount > 0 then
                    -- Check if any enemy start location has a matching water label
                    for _, b in aiBrain.EnemyIntel.EnemyStartLocations do
                        for label, state in aiBrain.BrainIntel.NavalBaseLabels do
                            if b.WaterLabels[label] and state == "Confirmed" then
                                navalPlayer = true
                                break
                            end
                        end
                        if navalPlayer then break end
                    end
    
                    if navalPlayer then
                        aiBrain.BrainIntel.PlayerRole.NavalPlayer = true
                        aiBrain:EvaluateDefaultProductionRatios()
                        return
                    end
                end
            end
        elseif aiBrain.BrainIntel.AllyCount == 1 and aiBrain.EnemyIntel.EnemyCount == 1 then
            local enemyX, enemyZ
            if aiBrain:GetCurrentEnemy() then
                enemyX, enemyZ = aiBrain:GetCurrentEnemy():GetArmyStartPos()
            end
        
            -- Get the armyindex from the enemy
            if enemyX then
                local EnemyIndex = aiBrain:GetCurrentEnemy():GetArmyIndex()
                local OwnIndex = aiBrain:GetArmyIndex()
                if aiBrain.CanPathToEnemyRNG[OwnIndex][EnemyIndex]['MAIN'] == 'LAND' and aiBrain.EnemyIntel.EnemyStartLocations[EnemyIndex].Distance < 348100 then
                    if not aiBrain.BrainIntel.PlayerRole.ExperimentalPlayer and not aiBrain.BrainIntel.PlayerRole.AirPlayer then
                        aiBrain.BrainIntel.PlayerRole.SpamPlayer = true
                        self:ForkThread(self.SpamTriggerDurationThread)
                    end
                end
            end
        end
    end,

    SpamTriggerDurationThread = function(self)
        -- This function just runs a timed thread for a more spammy approach with some bail outs along the way.
        local aiBrain = self.Brain
        local cancelSpam = false
        local startTime = GetGameTimeSeconds()
        while not cancelSpam do
            coroutine.yield(50)
            if GetGameTimeSeconds() - startTime > 360 then
                cancelSpam = true
            end
        end
        aiBrain.BrainIntel.PlayerRole.SpamPlayer = false
    end,

    GetTeamAveragePositions = function(self)
        local aiBrain = self.Brain
        local teamTable = {}
        if aiBrain.BrainIntel.AllyCount > 0 then
            teamTable['Ally'] = RUtils.CalculateAveragePosition(aiBrain.BrainIntel.AllyStartLocations, aiBrain.BrainIntel.AllyCount)
        end
        if aiBrain.EnemyIntel.EnemyCount > 0 then
            teamTable['Enemy'] = RUtils.CalculateAveragePosition(aiBrain.EnemyIntel.EnemyStartLocations, aiBrain.EnemyIntel.EnemyCount)
        end
        return teamTable
    end,

    IntelGridThread = function(self, aiBrain)
        while not self.MapIntelGrid do
            coroutine.yield(30)
        end
        local aiBrain = self.Brain
        while aiBrain.Status ~= "Defeat" do
            coroutine.yield(20)
            local intelCoverage = 0
            local mapOwnership = 0
            local mustScoutPresent = false
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
                    local unitsToRemove = {}
                    if not table.empty(self.MapIntelGrid[i][k].EnemyUnits) then
                        for c,b in self.MapIntelGrid[i][k].EnemyUnits do
                            if (b.object and b.object.Dead) then
                                table.insert(unitsToRemove, c)
                            elseif time-b.time>120 or (time-b.time>15 and GetNumUnitsAroundPoint(aiBrain,categories.MOBILE,b.Position,20,'Ally')>3) then
                                self.MapIntelGrid[i][k].EnemyUnits[c].recent=false
                                if time-b.time>300 then
                                    table.insert(unitsToRemove, c)
                                end
                            end
                        end
                    end
                    for _, c in unitsToRemove do
                        self.MapIntelGrid[i][k].EnemyUnits[c]=nil
                    end
                    local cellStatus = aiBrain.GridPresence:GetInferredStatus(self.MapIntelGrid[i][k].Position)
                    if cellStatus == 'Allied' then
                        mapOwnership = mapOwnership + 1
                    end
                end
                coroutine.yield(1)
            end
            self.MapIntelStats.IntelCoverage = intelCoverage / (self.MapIntelGridXRes * self.MapIntelGridZRes) * 100
            self.MapIntelStats.MustScoutArea = mustScoutPresent
            aiBrain.BrainIntel.MapOwnership = mapOwnership / aiBrain.IntelManager.CellCount * 100
            if aiBrain.RNGDEBUG then
                if mustScoutPresent then
                    RNGLOG('mustScoutPresent is true after loop')
                else
                    RNGLOG('mustScoutPresent is false after loop')
                end
            end
            --LOG('Current Map ownership '..aiBrain.BrainIntel.MapOwnership)
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
            --aiBrain:ForkThread(self.DrawInfection, self.MapIntelGrid[gridX][gridZ].Position)
            gridsSet = gridsSet + 1
        end
        for x = math.max(self.MapIntelGridXMin, gridX - gridSize), math.min(self.MapIntelGridXMax, gridX + gridSize), 1 do
            for z = math.max(self.MapIntelGridZMin, gridZ - gridSize), math.min(self.MapIntelGridZMax, gridZ + gridSize), 1 do
                self.MapIntelGrid[x][z][property] = value
                if type == 'Radar' then
                    self.MapIntelGrid[x][z].Radars[unit.EntityId] = {}
                    self.MapIntelGrid[x][z].Radars[unit.EntityId] = unit
                end
                --aiBrain:ForkThread(self.DrawInfection, self.MapIntelGrid[x][z].Position)
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
            --aiBrain:ForkThread(self.DrawInfection, self.MapIntelGrid[gridX][gridZ].Position)
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
                --aiBrain:ForkThread(self.DrawInfection, self.MapIntelGrid[x][z].Position)
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

    AdaptiveProductionThread = function(self, productiontype, data)
        local aiBrain = self.Brain
        local baseRestrictedArea = aiBrain.OperatingAreas['BaseRestrictedArea']
        local baseMilitaryArea = aiBrain.OperatingAreas['BaseMilitaryArea']
        local Zones = {
            'Land',
        }
        local factionIndex = aiBrain:GetFactionIndex()
        local gameTime = GetGameTimeSeconds()
        local threatType
        local minimumExtractorTier
        local desiredStrikeDamage = 0
        local potentialStrikes = {}
        local minThreatRisk = 0
        local abortZone = true
        local multiplier
        if aiBrain.CheatEnabled then
            multiplier = aiBrain.EcoManager.EcoMultiplier
        else
            multiplier = 1
        end
        if productiontype == 'AirAntiSurface' then
            threatType = 'AntiAir'
            minimumExtractorTier = 2
        end
        if productiontype == 'AirAntiNaval' then
            threatType = 'AntiAir'
            minimumExtractorTier = 2
        end
        -- note to self. When dividing using vdist3sq the division also needs to be squared. e.g instead of divide by 3, divide by 9.
        if productiontype == 'AirAntiSurface' then
            --RNGLOG('aiBrain.BrainIntel.SelfThreat.AirNow '..aiBrain.BrainIntel.SelfThreat.AirNow)
            --RNGLOG('aiBrain.EnemyIntel.EnemyThreatCurrent.Air '..aiBrain.EnemyIntel.EnemyThreatCurrent.Air)
            if aiBrain.BrainIntel.SelfThreat.AirNow > aiBrain.EnemyIntel.EnemyThreatCurrent.Air * 1.5 then
                minThreatRisk = 80
            elseif aiBrain.BrainIntel.SelfThreat.AirNow > aiBrain.EnemyIntel.EnemyThreatCurrent.Air then
                minThreatRisk = 50
            elseif aiBrain.BrainIntel.SelfThreat.AirNow * 1.5 > aiBrain.EnemyIntel.EnemyThreatCurrent.Air then
                minThreatRisk = 25
            end
            if minThreatRisk > 0 then
                for k, v in aiBrain.EnemyIntel.ACU do
                    if (not v.Unit.Dead) and (not v.Ally) and v.HP ~= 0 and v.Position[1] and v.LastSpotted + 120 > gameTime then
                        if v.HP < 12000 and minThreatRisk >= 50 and VDist3Sq(v.Position, aiBrain.BrainIntel.StartPos) < (aiBrain.EnemyIntel.ClosestEnemyBase / 4.84) then
                            if GetThreatBetweenPositions(aiBrain, aiBrain.BrainIntel.StartPos, v.Position, nil, threatType) < 5 then
                                --LOG('Enemy ACU is close to our base and I think we could snipe him')
                                --LOG('ACU ClosestEnemy base distance is '..(aiBrain.EnemyIntel.ClosestEnemyBase / 4.84))
                                --LOG('ACU Distance from start position '..VDist3Sq(v.Position, aiBrain.BrainIntel.StartPos))
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
                                --LOG('Adding ACU to potential strike target')
                                table.insert( potentialStrikes, { GridID = {GridX = gridX, GridZ = gridZ}, Position = self.MapIntelGrid[gridX][gridZ].Position, Type = 'ACU', Index = k} )
                            end
                        elseif v.HP < 7000 and aiBrain.BrainIntel.AirPhase == 3 then
                            --LOG('Enemy ACU is less than 7000 HP and we are air phase 3')
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
                            --LOG('Adding ACU to potential strike target')
                            table.insert( potentialStrikes, { GridID = {GridX = gridX, GridZ = gridZ}, Position = self.MapIntelGrid[gridX][gridZ].Position, Type = 'ACU', Index = k} )
                        end
                    end
                end
                local abortT2Bomber = false
                for k, v in aiBrain.BuilderManagers do
                    if v.Layer == 'Water' or k == 'MAIN' then
                        if aiBrain.BasePerimeterMonitor[k] and v.FactoryManager.LocationActive then
                            if aiBrain.BasePerimeterMonitor[k].NavalUnits > 0 then
                                abortT2Bomber = true
                            end
                        end
                    end
                end
                if not abortT2Bomber then
                    for k, v in Zones do
                        for k1, v1 in aiBrain.Zones[v].zones do
                            if minimumExtractorTier >= 2 then
                                if aiBrain.emanager.mex[v1.id].T2 > 0 or aiBrain.emanager.mex[v1.id].T3 > 0 then
                                    --RNGLOG('Enemy has T2+ mexes in zone')
                                    --RNGLOG('Enemystartdata '..repr(v1.enemystartdata))
                                    if productiontype == 'AirAntiSurface' then
                                        if minThreatRisk < 60 then
                                            for c, b in v1.enemystartdata do
                                                if b.startdistance > baseRestrictedArea * baseRestrictedArea then
                                                    abortZone = false
                                                end
                                            end
                                        end
                                        if not abortZone then
                                            if v1.enemyantiairthreat < data.MaxThreat then
                                                --RNGLOG('Zone air threat level below max')
                                                if GetThreatBetweenPositions(aiBrain, aiBrain.BrainIntel.StartPos, v1.pos, nil, threatType) < data.MaxThreat * 2 then
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
            end
        elseif productiontype == 'LandAntiSurface' then
            for k, v in aiBrain.EnemyIntel.ACU do
                --if v.Position[1] then
                --    RNGLOG('Current Distance '..VDist3Sq(v.Position, aiBrain.BrainIntel.StartPos))
                --end
                
                if (not v.Unit.Dead) and (not v.Ally) and v.Position[1] and v.HP ~= 0 and v.LastSpotted + 120 > gameTime then
                    if VDist3Sq(v.Position, aiBrain.BrainIntel.StartPos) < (aiBrain.EnemyIntel.ClosestEnemyBase / 9) then
                        local gridX, gridZ = self:GetIntelGrid(v.Position)
                        if v.HP < 4000 then
                            desiredStrikeDamage = desiredStrikeDamage + v.HP
                        else
                            desiredStrikeDamage = desiredStrikeDamage + 4000
                        end
                        desiredStrikeDamage = desiredStrikeDamage + 4000
                        if aiBrain.RNGDEBUG then
                            RNGLOG('Setting up antisurface acu snipe')
                            RNGLOG('Closest enemy base '..aiBrain.EnemyIntel.ClosestEnemyBase)
                            RNGLOG('Distance required is '..(aiBrain.EnemyIntel.ClosestEnemyBase / 9))
                            RNGLOG('Distance is '..VDist3Sq(v.Position, aiBrain.BrainIntel.StartPos))
                        end
                        table.insert( potentialStrikes, { GridID = {GridX = gridX, GridZ = gridZ}, Position = self.MapIntelGrid[gridX][gridZ].Position, Type = 'ACU', Index = k} )
                    end
                end
            end
        elseif productiontype == 'AirAntiNaval' then
            --RNGLOG(aiBrain.Nickname)
            --RNGLOG('aiBrain.BrainIntel.SelfThreat.AirNow '..aiBrain.BrainIntel.SelfThreat.AirNow)
            --RNGLOG('ally air threat is '..aiBrain.BrainIntel.SelfThreat.AllyAirThreat)
            --RNGLOG('aiBrain.EnemyIntel.EnemyThreatCurrent.Air '..aiBrain.EnemyIntel.EnemyThreatCurrent.Air)
            if aiBrain.BrainIntel.SelfThreat.AirNow + (aiBrain.BrainIntel.SelfThreat.AllyAirThreat / 2) > aiBrain.EnemyIntel.EnemyThreatCurrent.Air * 1.5 then
                minThreatRisk = 80
            elseif aiBrain.BrainIntel.SelfThreat.AirNow + (aiBrain.BrainIntel.SelfThreat.AllyAirThreat / 2) > aiBrain.EnemyIntel.EnemyThreatCurrent.Air then
                minThreatRisk = 50
            elseif aiBrain.BrainIntel.SelfThreat.AirNow + (aiBrain.BrainIntel.SelfThreat.AllyAirThreat / 2) * 1.5 > aiBrain.EnemyIntel.EnemyThreatCurrent.Air then
                minThreatRisk = 25
            else
                minThreatRisk = 5
            end
            
            if minThreatRisk > 0 and aiBrain.BrainIntel.SelfThreat.AirNow > 10 then
                --LOG('threat risk is '..tostring(minThreatRisk))
                --LOG('Current ally air threat is '..tostring(aiBrain.BrainIntel.SelfThreat.AirNow + (aiBrain.BrainIntel.SelfThreat.AllyAirThreat / 2)))
                --LOG('Current enemy air threat is '..tostring(aiBrain.EnemyIntel.EnemyThreatCurrent.Air))
                --LOG('Current T2 Torpedo count is '..tostring(aiBrain.amanager.Demand.Air.T2.torpedo))
                for k, v in aiBrain.EnemyIntel.ACU do
                    if (not v.Unit.Dead) and (not v.Ally) and v.HP ~= 0 and v.Position[1] then
                        if minThreatRisk >= 50 and VDist3Sq(v.Position, aiBrain.BrainIntel.StartPos) < (aiBrain.EnemyIntel.ClosestEnemyBase / 4) then
                            if RUtils.PositionInWater(v.Position) then
                                if GetThreatBetweenPositions(aiBrain, aiBrain.BrainIntel.StartPos, v.Position, nil, threatType) < data.MaxThreat * 2 then
                                    --RNGLOG('ACU ClosestEnemy base distance is '..(aiBrain.EnemyIntel.ClosestEnemyBase /2))
                                    --RNGLOG('ACU Distance from start position '..VDist3Sq(v.Position, aiBrain.BrainIntel.StartPos))
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
                                    --LOG('Adding ACU to antinaval potential strike target')
                                    table.insert( potentialStrikes, { GridID = {GridX = gridX, GridZ = gridZ}, Position = self.MapIntelGrid[gridX][gridZ].Position, Type = 'ACU', Index = k} )
                                end
                            end
                        end
                    end
                end
                for k, v in aiBrain.BasePerimeterMonitor do
                    local basePos = aiBrain.BuilderManagers[k].FactoryManager.Location
                    if v.NavalUnits > 0 then
                        local gridX, gridZ = self:GetIntelGrid(basePos)
                        desiredStrikeDamage = desiredStrikeDamage + (v.NavalThreat * 120)
                        --RNGLOG('Naval Threat detected at base, requesting torps for '..desiredStrikeDamage..' strike damage')
                        --RNGLOG('Naval threat at base is '..v.NavalThreat)
                        --RNGLOG('Adding AntiNavy potential strike target due to NavalUnits, threat is '..v.NavalThreat)
                        table.insert( potentialStrikes, { GridID = {GridX = gridX, GridZ = gridZ}, Position = self.MapIntelGrid[gridX][gridZ].Position, Type = 'AntiNavy'} )
                    end
                end
                if minThreatRisk > 25 and aiBrain.MapWaterRatio > 0.10 then
                    --LOG('minThreat risk is greater than 25 and mapwaterratio is greater than 10')
                    --LOG('Current MilitaryArea is '..tostring(baseMilitaryArea))
                    for _, x in aiBrain.EnemyIntel.EnemyThreatLocations do
                        for _, z in x do
                            local threatSet = false
                            if z['Naval'] and z['Naval'] > 0 and (gameTime - z.UpdateTime) < 45 then
                                local gridX, gridZ = self:GetIntelGrid(z.Position)
                                --RNGLOG('Enemy Threat Locations has a NavalThreat table')
                                -- position format as used by the engine
                                if aiBrain.BrainIntel.StartPos[1] then
                                    --LOG('Enemy Threat Locations distance to naval threat grid is '..self.MapIntelGrid[gridX][gridZ].DistanceToMain)
                                    if self.MapIntelGrid[gridX][gridZ].DistanceToMain < baseMilitaryArea then
                                        desiredStrikeDamage = desiredStrikeDamage + (z['Naval'] * 120)
                                        --RNGLOG('Strike Damage request is '..desiredStrikeDamage)
                                        --RNGLOG('Adding AntiNavy potential strike target due to Naval threat number is '..z['Naval'])
                                        table.insert( potentialStrikes, { GridID = {GridX = gridX, GridZ = gridZ}, Position = self.MapIntelGrid[gridX][gridZ].Position, Type = 'AntiNavy'} )
                                        --LOG('We found naval threat within the miligary area current strike damage is '..tostring(desiredStrikeDamage))
                                        threatSet = true
                                    end
                                end
                                if not threatSet and minThreatRisk > 50 then
                                    --LOG('minThreat risk is greater than 50 and threatSet has not triggered yet')
                                    local imapZone = MAP:GetZoneID(z.Position,aiBrain.Zones.Naval.index)
                                    for _, v in aiBrain.BuilderManagers do
                                        if v.Layer == 'Water' and v.Zone then
                                            local zoneID = v.Zone
                                            if zoneID == imapZone then
                                                --LOG('base is on the same zone as the threat')
                                                if aiBrain.Zones.Naval.zones[zoneID] then
                                                    desiredStrikeDamage = desiredStrikeDamage + (z['Naval'] * 120)
                                                    table.insert( potentialStrikes, { GridID = {GridX = gridX, GridZ = gridZ}, Position = self.MapIntelGrid[gridX][gridZ].Position, Type = 'AntiNavy'} )
                                                    --LOG('Found threat in adjacent zone, zone position is '..tostring(aiBrain.Zones.Naval.zones[c.zone].pos))
                                                    threatSet = true
                                                    break
                                                end
                                            end
                                            if not threatSet and aiBrain.Zones.Naval.zones[zoneID] then
                                                --LOG('Checking zone edges for base')
                                                for _, c in aiBrain.Zones.Naval.zones[zoneID].edges do
                                                    --LOG('Zone edge is '..tostring(c.zone.id))
                                                    --LOG('imapzone is '..tostring(imapZone))
                                                    if c.zone.id == imapZone then
                                                        --LOG('IMAP Threat is in same zone as edge')
                                                        desiredStrikeDamage = desiredStrikeDamage + (z['Naval'] * 120)
                                                        table.insert( potentialStrikes, { GridID = {GridX = gridX, GridZ = gridZ}, Position = self.MapIntelGrid[gridX][gridZ].Position, Type = 'AntiNavy'} )
                                                        --LOG('Found threat in adjacent zone, zone position is '..tostring(aiBrain.Zones.Naval.zones[c.zone.id].pos))
                                                        threatSet = true
                                                        break
                                                    end
                                                end
                                            end
                                        end
                                        if threatSet then
                                            break
                                        end
                                    end
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
        if productiontype == 'AirAntiSurface' then
            if not self.StrategyFlags.T3BomberRushActivated then
                if aiBrain.BrainIntel.AirPhase == 3 and aiBrain.EnemyIntel.AirPhase < 3 then
                    aiBrain.amanager.Demand.Air.T3.bomber = 1
                end
                if aiBrain.amanager.Current['Air']['T3']['bomber'] > 0 then
                    self.StrategyFlags.T3BomberRushActivated = true
                    aiBrain.amanager.Demand.Air.T3.bomber = 0
                end
            end
            local disableGunship = true
            local disableBomber = true
            if aiBrain.BrainIntel.AirPhase < 2 then
                if aiBrain.BrainIntel.SelfThreat.AntiAirNow > 5 then
                    local gunshipMassKilled = aiBrain.IntelManager.UnitStats['Gunship'].Kills.Mass
                    local gunshipMassBuilt = aiBrain.IntelManager.UnitStats['Gunship'].Built.Mass
                    if aiBrain.amanager.Current['Air']['T1']['gunship'] < 2 then
                        aiBrain.amanager.Demand.Air.T1.gunship = 2
                        disableGunship = false
                    end
                    if gunshipMassKilled > 0 and gunshipMassBuilt > 0 and math.min(gunshipMassKilled / gunshipMassBuilt, 2) > 1.2 then
                        aiBrain.amanager.Demand.Air.T1.gunship = aiBrain.amanager.Current['Air']['T1']['gunship'] + 1
                        disableGunship = false
                    end
                    local bomberMassKilled = aiBrain.IntelManager.UnitStats['Bomber'].Kills.Mass
                    local bomberMassBuilt = aiBrain.IntelManager.UnitStats['Bomber'].Built.Mass
                    local t1BombersBuilt = aiBrain:GetBlueprintStat("Units_History", categories.AIR * categories.BOMBER * categories.TECH1)
                    if t1BombersBuilt < 1 then
                        aiBrain.amanager.Demand.Air.T1.bomber = 1
                        disableBomber = false
                    end
                    if bomberMassKilled > 0 and bomberMassBuilt > 0 and math.min(bomberMassKilled / bomberMassBuilt, 2) > 1.2 then
                        aiBrain.amanager.Demand.Air.T1.bomber = aiBrain.amanager.Current['Air']['T1']['bomber'] + 1
                        disableBomber = false
                    end
                end
            elseif aiBrain.BrainIntel.AirPhase < 3 then
                if aiBrain.BrainIntel.SelfThreat.AntiAirNow > 20 then
                    local gunshipMassKilled = aiBrain.IntelManager.UnitStats['Gunship'].Kills.Mass
                    local gunshipMassBuilt = aiBrain.IntelManager.UnitStats['Gunship'].Built.Mass
                    if aiBrain.amanager.Current['Air']['T2']['gunship'] < 2 then
                        aiBrain.amanager.Demand.Air.T2.gunship = 2
                        disableGunship = false
                    end
                    if gunshipMassKilled > 0 and gunshipMassBuilt > 0 and math.min(gunshipMassKilled / gunshipMassBuilt, 2) > 1.2 then
                        aiBrain.amanager.Demand.Air.T2.gunship = aiBrain.amanager.Current['Air']['T2']['gunship'] + 1
                        disableGunship = false
                    end
                    local bomberMassKilled = aiBrain.IntelManager.UnitStats['Bomber'].Kills.Mass
                    local bomberMassBuilt = aiBrain.IntelManager.UnitStats['Bomber'].Built.Mass
                    local t2BombersBuilt = aiBrain:GetBlueprintStat("Units_History", categories.AIR * categories.BOMBER * categories.TECH2)
                    if t2BombersBuilt < 1 then
                        aiBrain.amanager.Demand.Air.T2.bomber = 1
                        disableBomber = false
                    end
                    if bomberMassKilled > 0 and bomberMassBuilt > 0 and math.min(bomberMassKilled / bomberMassBuilt, 2) > 1.2 then
                        aiBrain.amanager.Demand.Air.T2.bomber = aiBrain.amanager.Current['Air']['T2']['bomber'] + 1
                        disableBomber = false
                    end
                end
            elseif aiBrain.BrainIntel.AirPhase > 2 then
                if aiBrain.BrainIntel.SelfThreat.AntiAirNow > 60 then
                    local gunshipMassKilled = aiBrain.IntelManager.UnitStats['Gunship'].Kills.Mass
                    local gunshipMassBuilt = aiBrain.IntelManager.UnitStats['Gunship'].Built.Mass
                    if aiBrain.amanager.Current['Air']['T3']['gunship'] < 2 then
                        aiBrain.amanager.Demand.Air.T3.gunship = 2
                        disableGunship = false
                    end
                    if gunshipMassKilled > 0 and gunshipMassBuilt > 0 and math.min(gunshipMassKilled / gunshipMassBuilt, 2) > 1.1 then
                        aiBrain.amanager.Demand.Air.T3.gunship = aiBrain.amanager.Current['Air']['T3']['gunship'] + 1
                        disableGunship = false
                    end
                    local bomberMassKilled = aiBrain.IntelManager.UnitStats['Bomber'].Kills.Mass
                    local bomberMassBuilt = aiBrain.IntelManager.UnitStats['Bomber'].Built.Mass
                    local t3BombersBuilt = aiBrain:GetBlueprintStat("Units_History", categories.AIR * categories.BOMBER * categories.TECH3)
                    if t3BombersBuilt < 1 then
                        aiBrain.amanager.Demand.Air.T3.bomber = 1
                        disableBomber = false
                    end
                    if bomberMassKilled > 0 and bomberMassBuilt > 0 and math.min(bomberMassKilled / bomberMassBuilt, 2) > 1.2 then
                        local myAirThreat = aiBrain.BrainIntel.SelfThreat.AntiAirNow
                        local enemyAirThreat = aiBrain.EnemyIntel.EnemyThreatCurrent.AntiAir
                        local enemyCount = 1
                        if aiBrain.EnemyIntel.EnemyCount > 0 then
                            enemyCount = aiBrain.EnemyIntel.EnemyCount
                        end
                        if myAirThreat * 1.3 > (enemyAirThreat / enemyCount) then
                            aiBrain.amanager.Demand.Air.T3.bomber = aiBrain.amanager.Current['Air']['T3']['bomber'] + 1
                            disableBomber = false
                        end
                    end
                end
            end
            if disableGunship and aiBrain.amanager.Current['Air']['T1']['gunship'] > 1 then
                aiBrain.amanager.Demand.Air.T1.gunship = 0
            end
            if disableGunship and aiBrain.amanager.Current['Air']['T2']['gunship'] > 1 then
                aiBrain.amanager.Demand.Air.T2.gunship = 0
            end
            if disableGunship and aiBrain.amanager.Current['Air']['T3']['gunship'] > 2 then
                aiBrain.amanager.Demand.Air.T3.gunship = 0
            end
            if disableBomber and aiBrain.amanager.Current['Air']['T1']['bomber'] > 1 then
                aiBrain.amanager.Demand.Air.T1.bomber = 0
            end
            if disableBomber and aiBrain.amanager.Current['Air']['T2']['bomber'] > 1 then
                aiBrain.amanager.Demand.Air.T2.bomber = 0
            end
            if disableBomber and aiBrain.amanager.Current['Air']['T3']['bomber'] > 1 then
                aiBrain.amanager.Demand.Air.T3.bomber = 0
            end
            --LOG('Current T2 Gunship demand '..aiBrain.amanager.Demand.Air.T2.gunship)
            --LOG('Current T3 Gunship demand '..aiBrain.amanager.Demand.Air.T3.gunship)
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
                    aiBrain.TacticalMonitor.TacticalMissions.ACUSnipe[acuIndex]['AIR'] = { GameTime = gameTime, CountRequired = count, StrikeDamage = desiredStrikeDamage }
                    aiBrain.amanager.Demand.Air.T2.bomber = count
                    if aiBrain.BrainIntel.AirPhase == 3 then
                        aiBrain.amanager.Demand.Air.T3.bomber = count
                    end
                    --maybe one day they'll put the Mercy back to a sniping unit, until then the build logic is disabled
                    --aiBrain.amanager.Demand.Air.T2.mercy = count
                    aiBrain.EngineerAssistManagerFocusSnipe = true
                end
                if zoneAttack then
                    if aiBrain.BrainIntel.AirPhase < 3 then
                        aiBrain.amanager.Demand.Air.T2.bomber = count
                    end
                end
            else
                local disableBomb = true
                for k, v in aiBrain.TacticalMonitor.TacticalMissions.ACUSnipe do
                    if v.AIR then
                        if v.AIR.GameTime and v.AIR.GameTime + 300 < gameTime then
                            disableBomb = false
                        end
                    end
                end
                if disableBomb and aiBrain.amanager.Demand.Air.T2.mercy > 0 then
                    --RNGLOG('No mercy snipe missions, disable demand')
                    aiBrain.amanager.Demand.Air.T2.mercy = 0
                    aiBrain.EngineerAssistManagerFocusSnipe = false
                end
                if disableBomb and aiBrain.amanager.Demand.Air.T2.bomber > 0 then
                    --RNGLOG('No t2 bomber missions, disable demand')
                    aiBrain.amanager.Demand.Air.T2.bomber = 0
                    aiBrain.EngineerAssistManagerFocusSnipe = false
                end
            end
        elseif productiontype == 'LandAntiSurface' then
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
                    aiBrain.TacticalMonitor.TacticalMissions.ACUSnipe[acuIndex]['LAND'] = { GameTime = gameTime, CountRequired = count }
                    aiBrain.amanager.Demand.Land.T2.mobilebomb = count
                    aiBrain.EngineerAssistManagerFocusSnipe = true
                end
            else
                local disableBomb = true
                for k, v in aiBrain.TacticalMonitor.TacticalMissions.ACUSnipe do
                    if v.LAND then
                        if v.LAND.GameTime and v.LAND.GameTime + 300 < gameTime then
                            disableBomb = false
                        end
                    end
                end
                if disableBomb and aiBrain.amanager.Demand.Land.T2.mobilebomb > 0 then
                    --RNGLOG('No mobile bomb missions, disable demand')
                    aiBrain.amanager.Demand.Land.T2.mobilebomb = 0
                    aiBrain.EngineerAssistManagerFocusSnipe = false
                end
            end
            local disableRangedBot = true
            local disableExperimentalLand = true
            if aiBrain.BrainIntel.LandPhase < 2 then
                
            elseif aiBrain.BrainIntel.LandPhase < 3 then
                local rangedBotMassKilled = aiBrain.IntelManager.UnitStats['RangedBot'].Kills.Mass
                local rangedBotMassBuilt = aiBrain.IntelManager.UnitStats['RangedBot'].Built.Mass
                if rangedBotMassKilled > 0 and rangedBotMassBuilt > 0 and math.min(rangedBotMassKilled / rangedBotMassBuilt, 2) > 1.2 then
                    aiBrain.amanager.Demand.Land.T2.bot = aiBrain.amanager.Current['Land']['T2']['bot'] + 1
                    disableRangedBot = false
                end
                if not self.StrategyFlags.EarlyT2AmphibBuilt then
                    local t2AmphibBuilt = aiBrain:GetBlueprintStat("Units_History", categories.DIRECTFIRE * categories.LAND * categories.TECH2 * (categories.AMPHIBIOUS + categories.HOVER))
                    if t2AmphibBuilt < 5 then
                        aiBrain.amanager.Demand.Land.T2.amphib = 5
                    else
                        self.StrategyFlags.EarlyT2AmphibBuilt = true
                        aiBrain.amanager.Demand.Land.T2.amphib = 0
                    end
                end
            elseif aiBrain.BrainIntel.LandPhase > 2 then
                local rangedBotMassKilled = aiBrain.IntelManager.UnitStats['RangedBot'].Kills.Mass
                local rangedBotMassBuilt = aiBrain.IntelManager.UnitStats['RangedBot'].Built.Mass
                if rangedBotMassKilled > 0 and rangedBotMassBuilt > 0 and math.min(rangedBotMassKilled / rangedBotMassBuilt, 2) > 1.2 then
                    aiBrain.amanager.Demand.Land.T3.sniper = aiBrain.amanager.Current['Land']['T3']['sniper'] + 1
                    disableRangedBot = false
                end
                local experimentalLandMassKilled = aiBrain.IntelManager.UnitStats['ExperimentalLand'].Kills.Mass
                local experimentalLandMassBuilt = aiBrain.IntelManager.UnitStats['ExperimentalLand'].Built.Mass
                local experimentalLandBuilt = aiBrain:GetBlueprintStat("Units_History", categories.MOBILE * categories.LAND * categories.EXPERIMENTAL - categories.ARTILLERY)
                if experimentalLandBuilt < 2 or experimentalLandMassKilled > 0 and experimentalLandMassBuilt > 0 and math.min(experimentalLandMassKilled / experimentalLandMassBuilt, 2) > 0.7 then
                    aiBrain.amanager.Demand.Land.T4.experimentalland = aiBrain.amanager.Current['Land']['T4']['experimentalland'] + 1
                    disableExperimentalLand = false
                end
            end
            if disableRangedBot and aiBrain.amanager.Current['Land']['T2']['bot'] > 0 then
                aiBrain.amanager.Demand.Land.T2.bot = 0
            end
            if disableRangedBot and aiBrain.amanager.Current['Land']['T3']['sniper'] > 0 then
                aiBrain.amanager.Demand.Land.T3.sniper = 0
            end
            if disableExperimentalLand and aiBrain.amanager.Current['Land']['T4']['experimentalland'] > 0 then
                aiBrain.amanager.Demand.Land.T4.experimentalland = 0
            end
        elseif productiontype == 'AirAntiNaval' then
            if not table.empty(potentialStrikes) then
                --RNGLOG('potentialStrikes for navy '..repr(potentialStrikes))
                local count = math.ceil(desiredStrikeDamage / 1000)
                --RNGLOG('Adding AntiNavy potential strikes with a count of '..count)
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
                    aiBrain.TacticalMonitor.TacticalMissions.ACUSnipe[acuIndex]['AIRANTINAVY'] = { GameTime = gameTime, CountRequired = count }
                    aiBrain.amanager.Demand.Air.T2.torpedo = count
                    aiBrain.amanager.Demand.Air.T3.torpedo = math.ceil(count / 2)
                    aiBrain.EngineerAssistManagerFocusSnipe = true
                end
                if navalAttack then
                    --RNGLOG(aiBrain.Nickname)
                    --RNGLOG('numer of navalAttack torps required '..count)
                    aiBrain.amanager.Demand.Air.T2.torpedo = count
                    aiBrain.amanager.Demand.Air.T3.torpedo = math.ceil(count / 2)
                end
                --LOG('Current T2 torp demand is '..tostring(aiBrain.amanager.Demand.Air.T2.torpedo))
                --LOG('Current T3 torp demand is '..tostring(aiBrain.amanager.Demand.Air.T3.torpedo))
            else
                --RNGLOG('Disabling AntiNavy potential strikes ')
                local disableStrike = true
                for k, v in aiBrain.TacticalMonitor.TacticalMissions.ACUSnipe do
                    if v.AIRANTINAVY then
                        if v.AIRANTINAVY.GameTime and v.AIRANTINAVY.GameTime + 300 < gameTime then
                            disableStrike = false
                        end
                    end
                end
                if disableStrike and aiBrain.amanager.Demand.Air.T2.torpedo > 0 then
                    --RNGLOG('No mercy snipe missions, disable demand')
                    aiBrain.amanager.Demand.Air.T2.torpedo = 0
                    aiBrain.amanager.Demand.Air.T3.torpedo = 0
                    aiBrain.EngineerAssistManagerFocusSnipe = false
                end
            end
            --RNGLOG('Current T2 torpcount is '..aiBrain.amanager.Demand.Air.T2.torpedo)
        elseif productiontype == 'MobileAntiAir' then
            local selfThreat = aiBrain.BrainIntel.SelfThreat
            local enemyThreat = aiBrain.EnemyIntel.EnemyThreatCurrent
            --LOG('selfLandThreat '..tostring(selfThreat.LandNow))
            --LOG('selfLandThreatMultiplied '..tostring(selfThreat.LandNow * 1.4))
            --LOG('enemyLandThreat '..tostring(enemyThreat.Land))
            local safeAntiAir = selfThreat.AntiAirNow > 0 and selfThreat.AntiAirNow or 0.1
            if selfThreat.LandNow * 1.4 > enemyThreat.Land and safeAntiAir < enemyThreat.Air then
                local zoneCount = aiBrain.BuilderManagers['MAIN'].PathableZones.PathableLandZoneCount
                -- We are going to look at the threat in the pathable zones and see which ones are in our territory and make sure we have a theoretical number of air units there
                -- I want to do this on a per base method, but I realised I'm not keeping information.
                local totalMobileAARequired = 0 
                if selfThreat.AntiAirNow > 0 then
                    totalMobileAARequired = math.min(math.ceil((zoneCount * 0.65) * (enemyThreat.Air / safeAntiAir)), zoneCount * 1.5) or 0
                end
                --LOG('Pathable Zone Count '..tostring(zoneCount))
                --LOG('Enemy Air Threat '..tostring(enemyThreat.Air))
                --LOG('Self AntiAir '..tostring(safeAntiAir))
                --LOG('totalMobileAARequired '..tostring(totalMobileAARequired))
                --LOG('EnemyThreatRatio '..tostring((enemyThreat.Air / safeAntiAir)))
                if aiBrain.BrainIntel.LandPhase == 1 then
                    aiBrain.amanager.Demand.Bases['MAIN'].Land.T1.aa = totalMobileAARequired
                elseif aiBrain.BrainIntel.LandPhase == 2 then
                    aiBrain.amanager.Demand.Bases['MAIN'].Land.T2.aa = totalMobileAARequired
                elseif aiBrain.BrainIntel.LandPhase == 3 then
                    aiBrain.amanager.Demand.Bases['MAIN'].Land.T3.aa = totalMobileAARequired
                end

                --[[
                -- I thought I could set requirements per base but I don't have the structure yet.
                for k, v in aiBrain.BuilderManagers do
                    if v.PathableZones > 0 then
                        
                    end
                end
                ]]
                --for k, v in aiBrain.EnemyIntel.EnemyStartLocations
                --b.enemystartdata[v.Index].startangle
                --b.enemystartdata[v.Index].startdistance
            else
                aiBrain.amanager.Demand.Bases['MAIN'].Land.T1.aa = 0
                aiBrain.amanager.Demand.Bases['MAIN'].Land.T2.aa = 0
                aiBrain.amanager.Demand.Bases['MAIN'].Land.T3.aa = 0
            end
        elseif productiontype == 'ExperimentalArtillery' then
            local t3ArtilleryCount = 0
            local t3NukeCount = 0
            local experimentalNovaxCount = 0
            local experimentalArtilleryCount = 0
            local experimentalNukeCount = 0
            local lowValueNukes = 0
            for _, v in aiBrain.EnemyIntel.Artillery do
                if v.object and not v.object.Dead then
                    t3ArtilleryCount = t3ArtilleryCount + 1
                end
            end
            for _, v in aiBrain.EnemyIntel.SML do
                if v.object and not v.object.Dead then
                    t3NukeCount = t3NukeCount + 1
                end
            end
            for _, v in aiBrain.EnemyIntel.NavalSML do
                if v.object and not v.object.Dead then
                    local unitCats = v.Blueprint.CategoriesHash
                    if unitCats.BATTLESHIP then
                        lowValueNukes= lowValueNukes + 0.25
                    else
                        t3NukeCount = t3NukeCount + 1
                    end
                end
            end
            for _, v in aiBrain.EnemyIntel.Experimental do
                if v.object and not v.object.Dead then
                    if v.object.Blueprint.CategoriesHash.ORBITALSYSTEM then
                        experimentalNovaxCount = experimentalNovaxCount + 1
                    elseif v.object.Blueprint.CategoriesHash.ARTILLERY then
                        experimentalArtilleryCount = experimentalArtilleryCount + 1
                    elseif v.object.Blueprint.CategoriesHash.NUKE then
                        experimentalNukeCount = experimentalNukeCount + 1
                    end
                end
            end
            if lowValueNukes > 0 then
                lowValueNukes = math.ceil(lowValueNukes)
                t3NukeCount = t3NukeCount + lowValueNukes
            end
            aiBrain.emanager.Artillery.T3 = t3ArtilleryCount
            aiBrain.emanager.Artillery.T4 = experimentalArtilleryCount
            aiBrain.emanager.Satellite.T4 = experimentalNovaxCount
            aiBrain.emanager.Nuke.T3 = t3NukeCount
            aiBrain.emanager.Nuke.T4 = experimentalNukeCount
            --LOG('ExperimentalArtillery Count')
            --LOG('t3ArtilleryCount '..t3ArtilleryCount)
            --LOG('t3NukeCount '..t3NukeCount)
            --LOG('experimentalNovaxCount '..experimentalNovaxCount)
            --LOG('experimentalArtilleryCount '..experimentalArtilleryCount)
            --LOG('experimentalNukeCount '..experimentalNukeCount)
        elseif productiontype == 'IntelStructure' then
            if data.Tier == 'T3' and data.Structure == 'optics' then
                if aiBrain.smanager.Current.Structure['intel']['T3']['Optics'] < 1 and aiBrain.EconomyOverTimeCurrent.EnergyIncome > 1000 and aiBrain:GetEconomyIncome('ENERGY') > 1000 
                and aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime > 500 and aiBrain:GetEconomyTrend('ENERGY') > 500 then
                    aiBrain.smanager.Demand.Structure.intel.Optics = 1
                else
                    aiBrain.smanager.Demand.Structure.intel.Optics = 0
                end
            end
        elseif productiontype == 'LandIndirectFire' then
            local threatDillutionRatio = 17
            local enemyDefenseThreat = aiBrain.EnemyIntel.EnemyThreatCurrent.DefenseSurface or 0
            --if EnemyIndex and OwnIndex and aiBrain.CanPathToEnemyRNG[OwnIndex][EnemyIndex]['MAIN'] ~= 'LAND' then
                for k, v in aiBrain.BuilderManagers do
                    local totalEnemyStructureThreat = 0
                    local totalEnemyLandThreat = 0
                    local totalFriendlyDirectFireThreat = 0
                    local totalFriendlyIndirectFireThreat = 0
                    
                    if v.FactoryManager and v.FactoryManager.LocationActive then
                        local baseZone = aiBrain.Zones.Land.zones[v.Zone]
                        local closestDefenseClusterDistance
                        local closestDefenseClusterThreat = 0
                        local closestZoneLandDistance
                        local closestZoneLandThreat = 0
                        if v.PathableZones and v.PathableZones.PathableLandZoneCount > 0 and not table.empty(v.PathableZones.Zones) then
                            totalEnemyLandThreat = baseZone.enemylandthreat or 0
                            totalFriendlyDirectFireThreat = baseZone.friendlydirectfireantisurfacethreat or 0
                            totalFriendlyIndirectFireThreat = baseZone.friendlyindirectfireantisurfacethreat or 0

                            for _, cluster in aiBrain.EnemyIntel.DirectorData.DefenseCluster do
                                local dx = cluster.aggx - v.Position[1]
                                local dz = cluster.aggz - v.Position[3]
                                local clusterDist = dx * dx + dz * dz
                                --LOG('LocationType is  '..tostring(k))
                                --LOG('Location pos is '..tostring(v.Position[1])..':'..tostring(v.Position[3]))
                                --LOG('Defense cluster found with '..tostring(cluster.AntiSurfaceThreat)..' threat at '..tostring(clusterDist)..' distance')
                                if not closestDefenseClusterDistance or clusterDist < closestDefenseClusterDistance then
                                    closestDefenseClusterDistance = clusterDist
                                    closestDefenseClusterThreat = cluster.AntiSurfaceThreat
                                end
                            end

                            for _, z in v.PathableZones.Zones do
                                if z.PathType == 'Land' and z.ZoneID then
                                    local zone = aiBrain.Zones.Land.zones[z.ZoneID]
                                    if zone.enemystructurethreat > 0 then
                                        local dx = v.Position[1] - zone.pos[1]
                                        local dz = v.Position[3] - zone.pos[3]
                                        local posDist = dx * dx + dz * dz
                                        if posDist < 102400 then
                                            totalEnemyLandThreat = zone.enemylandthreat and totalEnemyLandThreat + zone.enemylandthreat
                                            if zone.enemyantisurfacethreat > 0 then
                                                totalEnemyStructureThreat = zone.enemystructurethreat and totalEnemyStructureThreat + zone.enemystructurethreat
                                            else
                                                totalEnemyStructureThreat = zone.enemystructurethreat and totalEnemyStructureThreat + (zone.enemystructurethreat * 0.7)
                                            end
                                            totalFriendlyDirectFireThreat = zone.friendlydirectfireantisurfacethreat and totalFriendlyDirectFireThreat + zone.friendlydirectfireantisurfacethreat
                                            totalFriendlyIndirectFireThreat = baseZone.friendlyindirectantisurfacethreat and totalFriendlyIndirectFireThreat + baseZone.friendlyindirectantisurfacethreat
                                            if not closestZoneLandDistance or posDist < closestZoneLandDistance then
                                                closestZoneLandThreat = zone.enemylandthreat
                                                closestZoneLandDistance = posDist
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        if aiBrain.BasePerimeterMonitor[k] then
                            if closestDefenseClusterDistance then
                                aiBrain.BasePerimeterMonitor[k].ClosestDefenseClusterDistance = closestDefenseClusterDistance
                                aiBrain.BasePerimeterMonitor[k].ClosestDefenseClusterThreat = closestDefenseClusterThreat
                            else
                                aiBrain.BasePerimeterMonitor[k].ClosestDefenseClusterDistance = nil
                                aiBrain.BasePerimeterMonitor[k].ClosestDefenseClusterThreat = 0
                            end
                            if closestZoneLandDistance then
                                aiBrain.BasePerimeterMonitor[k].ClosestZoneIntelLandThreatDistance = closestZoneLandDistance
                                aiBrain.BasePerimeterMonitor[k].ClosestZoneIntelLandThreat = closestZoneLandThreat
                            else
                                aiBrain.BasePerimeterMonitor[k].ClosestZoneIntelLandThreatDistance = nil
                                aiBrain.BasePerimeterMonitor[k].ClosestZoneIntelLandThreat = 0
                            end
                        end

                        local indirectFireCount = 0
                        local threatRatio = 1
                        if totalEnemyStructureThreat > 0 then
                            if totalEnemyLandThreat > 0 then
                                if totalFriendlyDirectFireThreat > 0 then
                                    threatRatio = totalFriendlyDirectFireThreat / totalEnemyLandThreat
                                end
                            end
                            if enemyDefenseThreat > 0 and totalEnemyStructureThreat > enemyDefenseThreat then
                                totalEnemyStructureThreat = enemyDefenseThreat
                            elseif enemyDefenseThreat == 0 and totalEnemyStructureThreat > 100 then
                                totalEnemyStructureThreat = 100
                            end
                            if threatRatio > 0.2 then
                                indirectFireCount = math.max(3, totalEnemyStructureThreat / threatDillutionRatio)
                            elseif closestDefenseClusterThreat > 0 then
                                --LOG('Cluster Threat is valid and greater than zero')
                                indirectFireCount = math.max(3, closestDefenseClusterThreat / threatDillutionRatio)
                            end
                            --LOG('Initial indirectFireCount '..tostring(indirectFireCount)..'enemy structure threat was '..tostring(totalEnemyStructureThreat)..' enemy defense threat was '..tostring(enemyDefenseThreat))
                            --LOG('Current threat ratio is '..tostring(threatRatio))
                            if indirectFireCount > 3 then
                                if totalEnemyLandThreat > 0 then
                                    if totalFriendlyDirectFireThreat > 0 then
                                        if threatRatio < 1 then
                                            indirectFireCount = math.max(3, math.ceil(indirectFireCount * threatRatio))
                                        end
                                    end
                                end
                            end
                            if indirectFireCount > 0 then
                                if v.FactoryManager:GetNumCategoryFactories(categories.FACTORY * categories.LAND * categories.TECH1) > 0 then
                                    --LOG('Intel Manage requesting '..tostring(indirectFireCount)..' T1 artillery for base '..tostring(k))
                                    aiBrain.amanager.Demand.Bases[k].Land.T1.arty= math.ceil(indirectFireCount * 1.5)
                                end
                                if v.FactoryManager:GetNumCategoryFactories(categories.FACTORY * categories.LAND * categories.TECH2) > 0 and self.StrategyFlags.EarlyT2AmphibBuilt then
                                    --LOG('Intel Manage requesting '..tostring(indirectFireCount)..' T2 mml for base '..tostring(k))
                                    aiBrain.amanager.Demand.Bases[k].Land.T2.mml = math.ceil(indirectFireCount * 1.3)
                                    --LOG('We want to build MML at builder manager '..tostring(k)..' at position '..tostring(v.Position[1])..':'..tostring(v.Position[3]))
                                    --LOG('Total Enemy land threat '..totalEnemyLandThreat)
                                    --LOG('Total Friendly Directfire threat '..totalFriendlyDirectFireThreat)
                                    --LOG('Threat ratio here is '..tostring(totalFriendlyDirectFireThreat / totalEnemyLandThreat))
                                    --LOG('The MML count is '..tostring(math.ceil(indirectFireCount * 1.3)))
                                end
                                if v.FactoryManager:GetNumCategoryFactories(categories.FACTORY * categories.LAND * categories.TECH3) > 0 then
                                    --LOG('Intel Manage requesting '..tostring(indirectFireCount)..' T3 artillery for base '..tostring(k))
                                    aiBrain.amanager.Demand.Bases[k].Land.T3.arty = indirectFireCount
                                    aiBrain.amanager.Demand.Bases[k].Land.T3.mml = math.ceil(indirectFireCount * 1.3)
                                end
                            end
                        end
                        if indirectFireCount < 1 and aiBrain.amanager.Demand.Bases[k] then
                            aiBrain.amanager.Demand.Bases[k].Land.T1.artillery = 0
                            aiBrain.amanager.Demand.Bases[k].Land.T2.mml = 0
                            aiBrain.amanager.Demand.Bases[k].Land.T3.artillery = 0
                            aiBrain.amanager.Demand.Bases[k].Land.T3.mml = 0
                        end
                    end
                end
            --end
        elseif productiontype == 'NavalAntiSurface' then
            if aiBrain.BrainIntel.SelfThreat.NavalNow + (aiBrain.BrainIntel.SelfThreat.AllyNavalThreat / 2) > aiBrain.EnemyIntel.EnemyThreatCurrent.Naval * 1.5 and aiBrain.EnemyIntel.MaxNavalStartRange <= 200 then
                minThreatRisk = 80
            end
            --LOG('Check NavalAntiSurface minThreatRisk '..tostring(minThreatRisk))
            --LOG('Self NavalNow '..tostring(aiBrain.BrainIntel.SelfThreat.NavalNow))
            --LOG('MapWaterRatio '..tostring(aiBrain.MapWaterRatio))
            local threatRequested = 0
            if minThreatRisk > 0 and aiBrain.BrainIntel.SelfThreat.NavalNow > 50 and aiBrain.MapWaterRatio > 0.20 then
                if aiBrain.EnemyIntel.DirectorData.Defense and not table.empty(aiBrain.EnemyIntel.DirectorData.Defense) then
                    for _, v in aiBrain.EnemyIntel.DirectorData.Defense do
                        threatRequested = v.Value and threatRequested + v.Value
                    end
                end
                if aiBrain.EnemyIntel.DirectorData.Energy and not table.empty(aiBrain.EnemyIntel.DirectorData.Energy) then
                    for _, v in aiBrain.EnemyIntel.DirectorData.Energy do
                        threatRequested = v.Value and threatRequested + v.Value
                    end
                end
                if aiBrain.EnemyIntel.DirectorData.Strategic and not table.empty(aiBrain.EnemyIntel.DirectorData.Strategic) then
                    for _, v in aiBrain.EnemyIntel.DirectorData.Strategic do
                        threatRequested = v.Value and threatRequested + v.Value
                    end
                end
            end
            --LOG('ThreatRequested is '..tostring(threatRequested))
            if threatRequested > 1 then
                local disableMissileShip = true
                local disableNukeSub = true
                local missileShipMassKilled = aiBrain.IntelManager.UnitStats['MissileShip'].Kills.Mass
                local missileShipBuilt = aiBrain.IntelManager.UnitStats['MissileShip'].Built.Mass
                local nukeSubMassKilled = aiBrain.IntelManager.UnitStats['NukeSub'].Kills.Mass
                local nukeSubBuilt = aiBrain.IntelManager.UnitStats['NukeSub'].Built.Mass
                for k, v in aiBrain.BuilderManagers do
                    if v.Layer == 'Water' then
                        if v.FactoryManager and v.FactoryManager.LocationActive then
                            if v.FactoryManager:GetNumCategoryFactories(categories.FACTORY * categories.NAVAL * categories.TECH2) > 0 then
                                --LOG('Intel Manage requesting '..tostring(indirectFireCount)..' T2 mml for base '..tostring(k))
                            end
                            if v.FactoryManager:GetNumCategoryFactories(categories.FACTORY * categories.NAVAL * categories.TECH3) > 0 then
                                local maxMissileShips = math.ceil(threatRequested / 1000)
                                if missileShipBuilt < 1 or (missileShipMassKilled > 0 and missileShipBuilt > 0 and math.min(missileShipMassKilled / missileShipBuilt, 2) > 1.2) then
                                    --LOG('Current MissileShips + Demand '..tostring(aiBrain.amanager.Current['Naval']['T3']['missileship'] + aiBrain.amanager.Demand.Bases[k].Naval.T3.missileship))
                                    if maxMissileShips > (aiBrain.amanager.Current['Naval']['T3']['missileship'] + aiBrain.amanager.Demand.Bases[k].Naval.T3.missileship) then
                                        --LOG('Base '..tostring(k)..' requesting '..tostring(maxMissileShips)..' maxMissileShips')
                                        aiBrain.amanager.Demand.Bases[k].Naval.T3.missileship = aiBrain.amanager.Current['Naval']['T3']['missileship'] + 1
                                        disableMissileShip = false
                                    end
                                end
                                local maxNukeSubs = math.ceil(threatRequested / 2000)
                                if nukeSubBuilt < 1 or (nukeSubMassKilled > 0 and nukeSubBuilt > 0 and math.min(nukeSubMassKilled / nukeSubBuilt, 2) > 1.2) then
                                    --LOG('Current NukeSub + Demand '..tostring(aiBrain.amanager.Current['Naval']['T3']['nukesub'] + aiBrain.amanager.Demand.Bases[k].Naval.T3.nukesub))
                                    if maxNukeSubs > (aiBrain.amanager.Current['Naval']['T3']['nukesub'] + aiBrain.amanager.Demand.Bases[k].Naval.T3.nukesub) then
                                        aiBrain.amanager.Demand.Bases[k].Naval.T3.nukesub = aiBrain.amanager.Current['Naval']['T3']['nukesub'] + 1
                                        --LOG('Base '..tostring(k)..' requesting '..tostring(maxNukeSubs)..' maxNukeSubs')
                                        disableNukeSub = false
                                    end
                                end
                            end
                            if disableMissileShip then
                                aiBrain.amanager.Demand.Bases[k].Naval.T3.missileship = 0
                            end
                            if disableNukeSub then
                                aiBrain.amanager.Demand.Bases[k].Naval.T3.nukesub = 0
                            end
                        end
                    end
                end
            else
                for k, v in aiBrain.BuilderManagers do
                    if v.Layer == 'Water' then
                        if v.FactoryManager and v.FactoryManager.LocationActive then
                            aiBrain.amanager.Demand.Bases[k].Naval.T3.missileship = 0
                            aiBrain.amanager.Demand.Bases[k].Naval.T3.nukesub = 0
                        end
                    end
                end
            end
        elseif productiontype == 'NavalAntiAir' then
            
        elseif productiontype == 'EngineerBuildPower' then
            local mainEngineers = aiBrain.BuilderManagers['MAIN'].EngineerManager.ConsumptionUnits.Engineers.UnitsList
            local mainBuildPower = 0
            if mainEngineers and not table.empty(mainEngineers) then
                for _, v in mainEngineers do
                    if v and not v.Dead then
                        local unitCats = v.Blueprint.CategoriesHash
                        if unitCats.TECH3 then
                            mainBuildPower = mainBuildPower + v.Blueprint.Economy.BuildRate
                        end
                    end
                    
                end
            end
            if aiBrain.cmanager.income.r.m > (450 * multiplier) and mainBuildPower < (2500 * multiplier) and aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime > 200 then
                local desiredSacuEng = math.ceil(math.max((aiBrain.cmanager.income.r.m * multiplier) - (450 * multiplier), (100 * multiplier)) / 100)
                if aiBrain.amanager.Demand.Bases['MAIN'].Engineer.T3.sacueng and aiBrain.amanager.Current.Engineer.T3.sacueng and aiBrain.amanager.Current.Engineer.T3.sacueng < desiredSacuEng then
                    aiBrain.amanager.Demand.Bases['MAIN'].Engineer.T3.sacueng = desiredSacuEng
                elseif aiBrain.amanager.Demand.Bases['MAIN'].Engineer.T3.sacueng > 0 then
                    aiBrain.amanager.Demand.Bases['MAIN'].Engineer.T3.sacueng = 0
                end
            else
                if aiBrain.amanager.Demand.Bases['MAIN'].Engineer.T3.sacueng then
                    aiBrain.amanager.Demand.Bases['MAIN'].Engineer.T3.sacueng = 0
                end
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
                if sourceCat.MOBILE and sourceCat.LAND and sourceCat.EXPERIMENTAL and not sourceCat.ARTILLERY then
                    data.sourcecat = 'ExperimentalLand'
                    if targetUnit.Blueprint.Economy.BuildCostMass then
                        valueGained = targetUnit.Blueprint.Economy.BuildCostMass or 0
                    end
                end
            elseif sourceCat.AIR then
                if sourceCat.GROUNDATTACK then
                    data.sourcecat = 'Gunship'
                    if targetUnit.Blueprint.Economy.BuildCostMass then
                        valueGained = targetUnit.Blueprint.Economy.BuildCostMass or 0
                    end
                elseif sourceCat.BOMBER then
                    data.sourcecat = 'Bomber'
                    if targetUnit.Blueprint.Economy.BuildCostMass then
                        valueGained = targetUnit.Blueprint.Economy.BuildCostMass or 0
                    end
                    if sourceUnit.PlatoonHandle.UnitTarget == 'ENGINEER' then

                    end
                else
                    data.sourcecat = 'Air'
                end
            elseif sourceCat.LAND then
                if ( sourceCat.UEF or sourceCat.CYBRAN ) and sourceCat.BOT and sourceCat.TECH2 and sourceCat.DIRECTFIRE or sourceCat.SNIPER and sourceCat.TECH3 then
                    data.sourcecat = 'RangedBot'
                    if targetUnit.Blueprint.Economy.BuildCostMass then
                        valueGained = targetUnit.Blueprint.Economy.BuildCostMass or 0
                    end
                end
            elseif sourceCat.STRUCTURE then
                data.sourcecat = 'Structure'
            elseif sourceCat.NAVAL then
                if sourceCat.MISSILESHIP then
                    data.sourcecat = 'MissileShip'
                    if targetUnit.Blueprint.Economy.BuildCostMass then
                        valueGained = targetUnit.Blueprint.Economy.BuildCostMass or 0
                    end
                elseif sourceCat.NUKESUB then
                    data.sourcecat = 'NukeSub'
                    if targetUnit.Blueprint.Economy.BuildCostMass then
                        valueGained = targetUnit.Blueprint.Economy.BuildCostMass or 0
                    end
                end
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
end

function ProcessSourceOnDeath(targetBrain, targetUnit, sourceUnit, damageType)
    local data = {
        targetcat = false,
        sourcecat = false
    }

    if targetBrain.RNG then
        local valueLost
        local targetCat = targetUnit.Blueprint.CategoriesHash
        local sourceCat = sourceUnit.Blueprint.CategoriesHash
        if targetCat.EXPERIMENTAL then
            if sourceCat.MOBILE and sourceCat.LAND and sourceCat.EXPERIMENTAL and not sourceCat.ARTILLERY then
                data.targetcat = 'ExperimentalLand'
                if targetUnit.Blueprint.Economy.BuildCostMass then
                    valueLost = targetUnit.Blueprint.Economy.BuildCostMass
                end
            end
        elseif targetCat.AIR then
            if targetCat.SCOUT then
                RecordUnitDeath(targetUnit, 'SCOUT')
            elseif targetCat.GROUNDATTACK then
                data.targetcat = 'Gunship'
                if targetUnit.Blueprint.Economy.BuildCostMass then
                    valueLost = targetUnit.Blueprint.Economy.BuildCostMass
                end
            elseif targetCat.BOMBER then
                data.targetcat = 'Bomber'
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
            if targetCat.DEFENSE and not targetCat.WALL then
                local locationType = targetUnit.BuilderManagerData.LocationType
                if locationType then
                    RUtils.RemoveDefenseUnit(targetBrain, locationType, targetUnit)
                else
                    WARN('AI RNG : No location type in defensive unit on death, may have been gifted. Unit is '..targetUnit.UnitId)
                end
            end
            if sourceCat.TACTICALMISSILEPLATFORM then
                local tmlPos = sourceUnit:GetPosition()
                if targetBrain.EnemyIntel.TML and not targetBrain.EnemyIntel.TML[sourceUnit.EntityId] then
                    targetBrain.EnemyIntel.TML[sourceUnit.EntityId] = {object = sourceUnit, position=tmlPos, validated=false, range=sourceUnit.Blueprint.Weapon[1].MaxRadius }
                    local sm = import('/mods/RNGAI/lua/StructureManagement/StructureManager.lua').GetStructureManager(targetBrain)
                    ForkThread(sm.ValidateTML, sm, targetBrain, targetBrain.EnemyIntel.TML[sourceUnit.EntityId])
                end
            end
        elseif targetCat.NAVAL then
            if targetCat.MISSILESHIP then
                data.targetcat = 'MissileShip'
                if targetUnit.Blueprint.Economy.BuildCostMass then
                    valueLost = targetUnit.Blueprint.Economy.BuildCostMass or 0
                end
            elseif targetCat.NUKESUB then
                data.targetcat = 'NukeSub'
                if targetUnit.Blueprint.Economy.BuildCostMass then
                    valueLost = targetUnit.Blueprint.Economy.BuildCostMass or 0
                end
            end
        end
        if valueLost then
            local unitStats = targetBrain.IntelManager.UnitStats
            unitStats[data.targetcat].Deaths.Mass = unitStats[data.targetcat].Deaths.Mass + valueLost
            if valueLost then
                --LOG('Unit type '..data.targetcat..' died')
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
                --LOG('Current Unit Efficiency '..(math.min(gained / lost, 2)))
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
        if im.MapIntelGrid[gridXID][gridZID].RecentScoutDeaths then
            im.MapIntelGrid[gridXID][gridZID].RecentScoutDeaths = im.MapIntelGrid[gridXID][gridZID].RecentScoutDeaths + 1
        else
            WARN('AI RNG : Unable to record scout death. Grid IDs '..repr(gridXID)..' '..repr(gridZID))
            if not im.MapIntelGrid[gridXID][gridZID] then
                WARN('AI RNG : Intel Grid entry does not exist.')
            end
        end
    end

end

DrawTargetRadius = function(self, position, colour)
    --RNGLOG('Draw Target Radius points')
    local counter = 0
    while counter < 120 do
        DrawCircle(position, 3, colour)
        counter = counter + 1
        coroutine.yield( 2 )
    end
end

function InitialNavalAttackCheck(aiBrain)
    -- This function will check if there are mass markers that can be hit by frigates. This can trigger faster naval factory builds initially.
    -- points = number of points around the extractor, doesn't need to have too many.
    -- radius = the radius that the points will be, be set this a little lower than a frigates max weapon range
    -- center = the x,y values for the position of the mass extractor. e.g {x = 0, y = 0} 
    
    aiBrain.IntelManager:WaitForMarkerInfection()
    while not aiBrain.IntelManager.MapIntelStats.ScoutLocationsBuilt do
        LOG('*AI:RNG NavalAttackCheck is waiting for ScoutLocations to be built')
        coroutine.yield(20)
    end
    if aiBrain.MapWaterRatio > 0.10 then
        local factionIndex = aiBrain:GetFactionIndex()
        local navalMarkers = {}
        local frigateMarkers = {}
        local markers = GetMarkersRNG()
        local maxRadius = 30
        local maxValue = 0
        local maxNavalStartRange
        local confirmedAttackLabel
        local unitTable = {
            Frigate = { Template = 'T1SeaFrigate', UnitID = 'ues0103',Range = 0 },
            Destroyer = { Template = 'T2SeaDestroyer', UnitID = 'ues0201',Range = 0 },
            Cruiser = { Template = 'T2SeaCruiser', UnitID = 'ues0202',Range = 0 },
            BattleShip = { Template = 'T3SeaBattleship', UnitID = 'ues0302',Range = 0 },
            MissileShip = { Template = 'T3MissileBoat', UnitID = 'xas0306',Range = 0 }
        }
        
        for k, v in unitTable do
            if factionIndex ~= 2 and k == 'MissileShip' then continue end
            if (factionIndex == 2 or factionIndex == 3) and k == 'Cruiser' then continue end
            v.Range = ALLBPS[v.UnitID].Weapon[1].MaxRadius
            if not maxRadius or v.Range > maxRadius then
                maxRadius = v.Range
            end
            maxValue = maxValue + v.Range
        end

        if not table.empty(aiBrain.EnemyIntel.EnemyStartLocations) then
            local validNavalLabels = {}
            local selfNavalPositions = NavUtils.GetPositionsInRadius('Water', aiBrain.BrainIntel.StartPos, 256, 10)
            if selfNavalPositions then
                for _, v in selfNavalPositions do
                    local label = NavUtils.GetLabel('Water', {v[1], v[2], v[3]})
                    if label and not validNavalLabels[label] then
                        validNavalLabels[label] = 'Unconfirmed'
                    end
                end
                for _, b in aiBrain.EnemyIntel.EnemyStartLocations do
                    local enemyNavalPositions = NavUtils.GetPositionsInRadius('Water', b.Position, 256, 10)
                    if enemyNavalPositions then
                        for _, v in enemyNavalPositions do
                            local label = NavUtils.GetLabel('Water', {v[1], v[2], v[3]})
                            if label and validNavalLabels[label] then
                                validNavalLabels[label] = 'Confirmed'
                                if not b.WaterLabels[label] then
                                    b.WaterLabels[label] = true
                                end
                                local dx = b.Position[1] - v[1]
                                local dz = b.Position[3] - v[3]
                                local posDist = dx * dx + dz * dz
                                if not maxNavalStartRange or posDist < maxNavalStartRange then
                                    maxNavalStartRange = posDist
                                end

                            end
                        end
                    end
                end
            end
            if not table.empty(validNavalLabels) then
                aiBrain.BrainIntel.NavalBaseLabels = validNavalLabels
                local labelCount = 0
                for _, v in validNavalLabels do
                    labelCount = labelCount + 1
                end
                aiBrain.BrainIntel.NavalBaseLabelCount = labelCount
                --LOG('Label Table '..repr(validNavalLabels))
            end
        end
        if markers then
            local markerCount = 0
            local markerCountNotBlocked = 0
            local frigateRaidMarkers = 0
            local markerCountBlocked = 0
            local totalMarkerValue = 0
            local frigateRange = unitTable.Frigate.Range
            for _, v in markers do 
                if not v.Water then
                    markerCount = markerCount + 1
                    local markerValue = 0
                    local frigateValidated = false
                    --local checkPoints = RUtils.DrawCirclePoints(8, frigateRange, v.position)
                    local frigateCheckPoints = NavUtils.GetDetailedPositionsInRadius('Water', v.position, frigateRange, 6)
                    local navalCheckPoints = NavUtils.GetPositionsInRadius('Water', v.position, maxRadius)
                    --LOG('CheckPoints for '..repr(v))
                    --LOG(repr(checkPoints))
                    if frigateCheckPoints then
                        local valueValidated = false
                        for _, m in frigateCheckPoints do
                            local dx = v.position[1] - m[1]
                            local dz = v.position[3] - m[3]
                            local posDist = dx * dx + dz * dz
                            --aiBrain:ForkThread(DrawTargetRadius, m, 'cc0000')
                            if not valueValidated then
                                if posDist <= frigateRange * frigateRange then
                                    valueValidated = true
                                end
                            end
                            if valueValidated then
                                local markerValue = 1000 / 28
                                if not aiBrain:CheckBlockingTerrain({m[1], GetSurfaceHeight(m[1], m[3]), m[3]}, v.position, 'low') then
                                    markerCountNotBlocked = markerCountNotBlocked + 1
                                    if frigateValidated then
                                        frigateRaidMarkers = frigateRaidMarkers + 1
                                        table.insert( frigateMarkers, { Position=v.position, Name=v.name, RaidPosition={m[1], m[2], m[3]}, Distance = posDist, MarkerValue = markerValue } )
                                    end
                                    totalMarkerValue = totalMarkerValue + markerValue
                                else
                                    markerCountBlocked = markerCountBlocked + 1
                                end
                                if valueValidated then
                                    break
                                end
                            end
                        end
                    end
                    if navalCheckPoints then
                        local valueValidated = false
                        for _, m in navalCheckPoints do
                            local dx = v.position[1] - m[1]
                            local dz = v.position[3] - m[3]
                            local posDist = dx * dx + dz * dz
                            --aiBrain:ForkThread(DrawTargetRadius, m, 'FFFF00')
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
                                if valueValidated then
                                    break
                                end
                            end
                        end
                    end
                else
                    if not aiBrain.MassMarkersInWater then
                        aiBrain.MassMarkersInWater = true
                    end
                end
            end
            --LOG('There are potentially '..markerCount..' markers that are in range for frigates')
            --LOG('There are '..markerCountNotBlocked..' markers NOT blocked by terrain')
            --LOG('There are '..markerCountBlocked..' markers that ARE blocked')
            --LOG('Total Map marker value is '..(totalMarkerValue/markerCount))
            --LOG('Marker count that frigates can try and raid '..frigateRaidMarkers)
            --LOG('Marker count that can be hit by navy '..table.getn(navalMarkers))
            --LOG('Naval Value = '..totalMarkerValue)
            --LOG('Max total marker value '..tostring(maxValue * markerCount))
            --LOG('Potential priority '..totalMarkerValue/markerCount*1000)
            if frigateRaidMarkers > 6 then
                aiBrain.EnemyIntel.FrigateRaid = true
                aiBrain.EnemyIntel.FrigateRaidMarkers = frigateRaidMarkers
            end
            if maxNavalStartRange then
                aiBrain.EnemyIntel.MaxNavalStartRange = math.sqrt(maxNavalStartRange)
            else
                aiBrain.EnemyIntel.MaxNavalStartRange = 65536
            end
            if totalMarkerValue and totalMarkerValue > 0 then
                aiBrain.EnemyIntel.NavalValue = totalMarkerValue
            end
            --LOG('Lowest Enemy Start Position Range is '..tostring(aiBrain.EnemyIntel.MaxNavalStartRange))
        end
    end
end

function QueryExpansionTable(aiBrain, location, radius, movementLayer, threat, type)
    -- Should be a multipurpose Expansion query that can provide units, acus a place to go

    local MainPos = aiBrain.BuilderManagers.MAIN.Position
    local label, reason = NavUtils.GetLabel('Land', location)
    if not label then
        WARN('No water label returned reason '..reason)
        WARN('Water label failure position was '..repr(location))
    end
    local centerPoint = aiBrain.MapCenterPoint
    local im = GetIntelManager(aiBrain)
    local mainBaseToCenter = VDist2Sq(MainPos[1], MainPos[3], centerPoint[1], centerPoint[3])
    local bestExpansions = {}
    local options = {}
    -- Note, the expansions zones are land only. Need to fix this to include amphib zone.
    if label then
        if not table.empty(im.ZoneExpansions.Pathable) then
            for _, expansion in im.ZoneExpansions.Pathable do
                local expLabel, reason = NavUtils.GetLabel('Land', expansion.Position)
                --LOG('Pre Distance check expansion has '..tostring(aiBrain.Zones.Land.zones[expansion.ZoneID].resourcevalue)..' mass points')
                if expLabel == label then
                    local expansionDistance = VDist2Sq(location[1], location[3], expansion.Position[1], expansion.Position[3])
                    --LOG('Expansion distance is '..tostring(expansionDistance)..' max allowed distance is '..tostring(radius * radius))
                    if expansionDistance < radius * radius then
                        --LOG('Expansion Zone is within radius '..tostring(expansion.ZoneID))
                        if type == 'acu' or VDist2Sq(MainPos[1], MainPos[3], expansion.Position[1], expansion.Position[3]) < (VDist2Sq(MainPos[1], MainPos[3], centerPoint[1], centerPoint[3]) + 900) then
                            local zone = aiBrain.Zones.Land.zones[expansion.ZoneID]
                            --LOG('Expansion has '..zone.resourcevalue..' mass points')
                            --LOG('Expansion is '..expansion.ZoneID..' at '..tostring(repr(expansion.Position)))
                            local extractorCount = zone.resourcevalue
                            local teamValue = zone.teamvalue
                            if extractorCount > 1 and teamValue > 0.8 then
                                -- Lets ponder this a bit more, the acu is strong, but I don't want him to waste half his hp on civilian PD's
                                if type == 'acu' and GetThreatAtPosition( aiBrain, expansion.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface') > 5 then
                                    --LOG('Threat at location too high for easy building')
                                    continue
                                end
                                if type == 'acu' and GetNumUnitsAroundPoint(aiBrain, categories.MASSEXTRACTION, expansion.Position, 30, 'Ally') >= (extractorCount / 2) then
                                    --LOG('ACU Location has enough masspoints to indicate its already taken')
                                    continue
                                end
                                RNGINSERT(options, {Expansion = expansion, Value = extractorCount * extractorCount, Key = zone.id, Distance = expansionDistance})
                            end
                        else
                            --LOG('Expansion is beyond the center point')
                            --LOG('Distance from main base to expansion '..VDist2Sq(MainPos[1], MainPos[3], expansion.Position[1], expansion.Position[3]))
                            --LOG('Should be less than ')
                            --LOG('Distance from main base to center point '..VDist2Sq(MainPos[1], MainPos[3], centerPoint[1], centerPoint[3]))
                        end
                    end
                end
            end
        end
        local optionCount = 0
        
        for k, withinRadius in options do
            if mainBaseToCenter > VDist2Sq(withinRadius.Expansion.Position[1], withinRadius.Expansion.Position[3], centerPoint[1], centerPoint[3]) then
                --LOG('Expansion has high mass value at location '..tostring(withinRadius.Expansion.Key)..' at position '..tostring(repr(withinRadius.Expansion.Position)))
                RNGINSERT(bestExpansions, withinRadius)
            end
        end
    else
        WARN('No GraphArea in path node, either its not created yet or the marker analysis hasnt happened')
    end
    --LOG('We have '..RNGGETN(bestExpansions)..' expansions to pick from')
    if not table.empty(bestExpansions) then
        if type == 'acu' then
            local bestOption = false
            local secondBestOption = false
            local bestValue = 9999999999
            for _, v in options do
                if VDist2Sq(MainPos[1], MainPos[3], v.Expansion.Position[1], v.Expansion.Position[3]) > 10000 then
                    local alreadySecure = false
                    for k, b in aiBrain.BuilderManagers do
                        if b.Zone == v.Key and not table.empty(aiBrain.BuilderManagers[k].FactoryManager.FactoryList) then
                           --LOG('Already a builder manager with factory present, set')
                            alreadySecure = true
                            break
                        end
                    end
                    if alreadySecure then
                       --LOG('Position already secured, ignore and move to next expansion')
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
                --LOG('ACU is having a random expansion returned')
                return acuOptions[Random(1,2)]
            end
            --LOG('ACU is having the best expansion returned')
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
            intelGrid[x][z].Radars = setmetatable({}, WeakValueTable)
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
            intelGrid[x][z].EnemyUnits = setmetatable({}, WeakValueTable)
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
        local eThreatLocations = aiBrain.EnemyIntel.EnemyThreatLocations
        for _, x in eThreatLocations do
            for _, z in x do
                if z['StructuresNotMex'] and (gameTime - z.UpdateTime) < 35 then
                    --RNGLOG('Enemy Threat Locations has a StructuresNotMex table')
                    -- position format as used by the engine
                    v = z.Position
                    z.LandDefStructureCount = 0
                    z.LandDefStructureThreat = 0
                    z.LandDefStructureMaxRange = 0
                    z.AirDefStructureCount = 0
                    z.AirDefStructureThreat = 0
                    z.AirDefStructureMaxRange = 0
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
                               -- RNGLOG('Position '..repr(unit:GetPosition()))
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
            if eThreatLocations[unit.IMAP[1]][unit.IMAP[3]]['StructuresNotMex'] then
                    if unit.Object.Blueprint.Defense.SurfaceThreatLevel > 0 then
                        eThreatLocations[unit.IMAP[1]][unit.IMAP[3]].LandDefStructureCount = eThreatLocations[unit.IMAP[1]][unit.IMAP[3]].LandDefStructureCount + 1
                        eThreatLocations[unit.IMAP[1]][unit.IMAP[3]].LandDefStructureThreat = eThreatLocations[unit.IMAP[1]][unit.IMAP[3]].LandDefStructureThreat + unit.Object.Blueprint.Defense.SurfaceThreatLevel
                        if unit.Object.Blueprint.Weapon[1].MaxRadius and unit.Object.Blueprint.Weapon[1].MaxRadius > eThreatLocations[unit.IMAP[1]][unit.IMAP[3]].LandDefStructureMaxRange then
                            eThreatLocations[unit.IMAP[1]][unit.IMAP[3]].LandDefStructureMaxRange = unit.Object.Blueprint.Weapon[1].MaxRadius
                        end
                    elseif unit.Object.Blueprint.Defense.AirThreatLevel > 0 then
                        eThreatLocations[unit.IMAP[1]][unit.IMAP[3]].AirDefStructureCount = eThreatLocations[unit.IMAP[1]][unit.IMAP[3]].AirDefStructureCount + 1
                        eThreatLocations[unit.IMAP[1]][unit.IMAP[3]].AirDefStructureThreat = eThreatLocations[unit.IMAP[1]][unit.IMAP[3]].AirDefStructureThreat + unit.Object.Blueprint.Defense.AirThreatLevel
                    end
                    if eThreatLocations[unit.IMAP[1]][unit.IMAP[3]].LandDefStructureCount + eThreatLocations[unit.IMAP[1]][unit.IMAP[3]].AirDefStructureCount > 5 then
                        aiBrain.EnemyIntel.EnemyFireBaseDetected = true
                    end
                end
            end
        end

        local firebaseTable = {}
        for _, x in eThreatLocations do
            for _, z in x do
                if z.LandDefStructureCount > 0 or z.AirDefStructureCount > 0 then
                    local tableEntry = { Position = z.Position, Land = { Count = 0, Threat = 0 }, Air = { Count = 0, Threat = 0 }, aggX = 0, aggZ = 0, weight = 0, maxRangeLand = 0, validated = false}
                    if z.LandDefStructureCount > 0 then
                        --LOG('Enemy Threat Location with ID '..q..' has '..threat.LandDefStructureCount..' at imap position '..repr(threat.Position))
                        tableEntry.maxRangeLand = z.LandDefStructureMaxRange
                        --LOG('Firebase max range set to '..tableEntry.maxRangeLand)
                        tableEntry.Land = { Count = z.LandDefStructureCount, Threat = z.LandDefStructureThreat }
                    end
                    if z.AirDefStructureCount > 0 then
                        --LOG('Enemy Threat Location with ID '..q..' has '..threat.AirDefStructureCount..' at imap position '..repr(threat.Position))
                        tableEntry.Air = { Count = z.AirDefStructureCount, Threat = z.AirDefStructureThreat }
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
            local defenseGroup = {Land = best.Land.Count, Air = best.Air.Count, MaxLandRange = best.maxRangeLand or 0, LandThreat = best.Land.Threat, AirThreat = best.Air.Threat}
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
            RNGINSERT(firebaseaggregationTable, {aggx = x, aggz = z, DefensiveCount = defenseGroup.Land + defenseGroup.Air, MaxLandRange = defenseGroup.MaxLandRange, AntiSurfaceThreat = defenseGroup.LandThreat, AntiAirThreat = defenseGroup.AirThreat})
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
                        if VDist3Sq(b:GetPosition(), v.position) < (v.range * v.range) + 100 then
                            --LOG('EnemyIntelTML there is an extractor that is in range')
                            if not b.TMLInRange then
                                b.TMLInRange = setmetatable({}, WeakValueTable)
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
            local isUpgradng = unit.Object:IsUnitState('Upgrading')
            if aiBrain.EnemyIntel.AirPhase < 2 and unit.Object.Blueprint.CategoriesHash.AIR and 
            (unit.Object.Blueprint.CategoriesHash.TECH2 or unit.Object.Blueprint.CategoriesHash.TECH1 and isUpgradng) then
                aiBrain.EnemyIntel.AirPhase = 2
            elseif aiBrain.EnemyIntel.AirPhase < 3 and unit.Object.Blueprint.CategoriesHash.AIR and 
            (unit.Object.Blueprint.CategoriesHash.TECH3 or unit.Object.Blueprint.CategoriesHash.TECH2 and isUpgradng) then
                aiBrain.EnemyIntel.AirPhase = 3
            end
            if aiBrain.EnemyIntel.LandPhase < 2 and unit.Object.Blueprint.CategoriesHash.LAND and 
            (unit.Object.Blueprint.CategoriesHash.TECH2 or unit.Object.Blueprint.CategoriesHash.TECH1 and isUpgradng) then
                aiBrain.EnemyIntel.LandPhase = 2
            elseif aiBrain.EnemyIntel.LandPhase < 3 and unit.Object.Blueprint.CategoriesHash.LAND and 
            (unit.Object.Blueprint.CategoriesHash.TECH3 or unit.Object.Blueprint.CategoriesHash.TECH2 and isUpgradng) then
                aiBrain.EnemyIntel.LandPhase = 3
            end
            if aiBrain.EnemyIntel.NavalPhase < 2 and unit.Object.Blueprint.CategoriesHash.NAVAL and 
            (unit.Object.Blueprint.CategoriesHash.TECH2 or unit.Object.Blueprint.CategoriesHash.TECH1 and isUpgradng) then
                aiBrain.EnemyIntel.NavalPhase = 2
            elseif aiBrain.EnemyIntel.NavalPhase < 3 and unit.Object.Blueprint.CategoriesHash.NAVAL and 
            (unit.Object.Blueprint.CategoriesHash.TECH3 or unit.Object.Blueprint.CategoriesHash.TECH2 and isUpgradng) then
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
    while aiBrain.Status ~= "Defeat" do
        local time=GetGameTimeSeconds()
        for _=0,10 do
            local enemyMexes = {}
            local mexcount = 0
            local eunits=aiBrain:GetUnitsAroundPoint((categories.NAVAL + categories.AIR + categories.LAND + categories.STRUCTURE) - categories.INSIGNIFICANTUNIT, {0,0,0}, math.max(ScenarioInfo.size[1],ScenarioInfo.size[2])*1.5, 'Enemy')
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
                        im.MapIntelGrid[gridXID][gridZID].EnemyUnits = setmetatable({}, WeakValueTable)
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
                                            im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].type='exp'
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
                                    elseif unitCat.NAVAL then
                                        if unitCat.NUKE then
                                            if not aiBrain.EnemyIntel.NavalSML[id] then
                                                aiBrain.EnemyIntel.NavalSML[id] = {object = v, Position=unitPosition, Detected=time }
                                            end
                                        end
                                        if unitCat.SILO and unitCat.INDIRECTFIRE then
                                            im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].type='silo'
                                        end
                                    end
                                elseif unitCat.STRUCTURE then
                                    if unitCat.EXPERIMENTAL and not unitCat.UNTARGETABLE then
                                        if not aiBrain.EnemyIntel.Experimental[id] then
                                            aiBrain.EnemyIntel.Experimental[id] = {object = v, position=unitPosition }
                                        end
                                    elseif unitCat.TECH3 and unitCat.ARTILLERY then
                                        if not aiBrain.EnemyIntel.Artillery[id] then
                                            aiBrain.EnemyIntel.Artillery[id] = {object = v, position=unitPosition }
                                        end
                                    elseif unitCat.RADAR then
                                        im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].type='radar'
                                    elseif unitCat.DEFENSE and unitCat.DIRECTFIRE then
                                        im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].type='pointdefense'
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
                                            aiBrain.EnemyIntel.SMD[id] = {object = v, Position=unitPosition, Detected=time }
                                        end
                                    elseif unitCat.TECH3 and unitCat.NUKE and unitCat.SILO then
                                        im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].type='sml'
                                        if not aiBrain.EnemyIntel.SML[id] then
                                            aiBrain.EnemyIntel.SML[id] = {object = v, Position=unitPosition, Detected=time }
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
                            if unitCat.TECH3 and unitCat.ANTIMISSILE and unitCat.SILO then
                                if aiBrain.EnemyIntel.SMD[id] and not aiBrain.EnemyIntel.SMD[id].object.Dead and not aiBrain.EnemyIntel.SMD[id].Completed then
                                    --LOG('Fraction Complete on SMD '..repr(aiBrain.EnemyIntel.SMD[id].object:GetFractionComplete()))
                                    if aiBrain.EnemyIntel.SMD[id].object:GetFractionComplete() >= 1.0 then
                                        aiBrain.EnemyIntel.SMD[id].Completed = time
                                    end
                                end
                            end
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
                    local distanceFactor = (1 - normalizedDistance) * 250
                    --LOG('basePriority * '..(1 + distanceFactor * distanceExponent / maxPriority))
                    scaledPriority = basePriority * (1 + distanceFactor * distanceExponent / maxPriority)
                    local statusModifier = 1
                    --RNGLOG('angle of enemy units '..angleOfEnemyUnits)
                    --RNGLOG('distance to main '..im.MapIntelGrid[i][k].DistanceToMain)
                    im.MapIntelGrid[i][k].EnemyUnitDanger = RUtils.GrabPosDangerRNG(aiBrain,position,30,30, true, false, false).enemyTotal
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
                                    priority=anglePriority + 60
                                elseif b.type=='arty' then
                                    priority=anglePriority + 30
                                elseif b.type=='tank' then
                                    priority=anglePriority + 30
                                elseif b.type=='exp' then
                                    priority=anglePriority + 150
                                else
                                    priority=anglePriority + 20
                                end
                            end
                            priority = priority * statusModifier
                            unitAddedCount = unitAddedCount + 1
                            aiBrain.prioritypoints[c..i..k]={type='raid',Position=b.Position,priority=priority,danger=im.MapIntelGrid[i][k].EnemyUnitDanger,unit=b.object,time=b.time}
                            if im.MapIntelGrid[i][k].DistanceToMain < baseRestrictedArea or priority > 250 then
                                if b.type == 'arty' or b.type == 'exp' or b.type == 'pointdefense' then
                                    priority = priority + 100
                                end
                                aiBrain.prioritypointshighvalue[c..i..k]={type='raid',Position=b.Position,priority=math.max(priority,250),danger=im.MapIntelGrid[i][k].EnemyUnitDanger,unit=b.object,time=b.time}
                            end
                        end
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
           --RNGLOG('prioritypoint friendly threat is '.antisurface)
           --RNGLOG('prioritypoint enemy threat is '..enemyThreat)
           --RNGLOG('Priority Based on threat would be '..(healthdanger * (enemyThreat / friendlyThreat)))
           --RNGLOG('Instead is it '..healthdanger)
            local acuPriority = healthdanger * (enemyThreat / friendlyThreat)
            if aiBrain.CDRUnit.Caution then
                acuPriority = acuPriority + 100
            end
            unitAddedCount = unitAddedCount + 1
            aiBrain.prioritypoints['ACU']={type='raid',Position=aiBrain.CDRUnit.Position,priority=acuPriority,danger=RUtils.GrabPosDangerRNG(aiBrain,aiBrain.CDRUnit.Position,30,30, true, false, false).enemyTotal,unit=nil}
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