local RNGAIGLOBALS = import("/mods/RNGAI/lua/AI/RNGAIGlobals.lua")
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
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
local GetProductionPerSecondMass = moho.unit_methods.GetProductionPerSecondMass

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
            Naval = {},
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
        self.ZoneIMAPThreat = {}
        self.LabelIMAPThreat = {
            Land = {},
            Air = {},
            Naval = {}
        }
        self.ZoneToGridMap = {}
        self.ZoneWeightTable = {
            control = {
                zonePressureWeight = 2.0,
                zoneDistanceWeight = 1.8,
                threatOpportunityWeight = 2.0
            },
            raid = {
                zonePressureWeight = 0.8,
                zoneDistanceWeight = 0.5,
                threatOpportunityWeight = 0.4
            },
            aadefense = {
                zonePressureWeight = 3.0,
                zoneDistanceWeight = 1.4,
                threatOpportunityWeight = 2.0
            },
            airsurface = {
                zonePressureWeight = 3.0,
                zoneDistanceWeight = 1.0,
                threatOpportunityWeight = 2.0,
                minThreshold = 11.0,
            }
        }
        self.SafeAirThreatRadius = 0
        self.FactoryInvasionThreatThreshold = 10.0      -- [ThreatToFactoryMassRatio] 100 Threat = 10 Mass Drain req.
        self.FactoryEconInvestmentThreshold = 1.5       -- [IncomeToFactoryMassRatio] 10 Income = 15 Mass Drain req.
        self.FactoryReclaimThresholdBuffer = 25.0       -- Buffer to prevent "fluttering" (building/reclaiming repeatedly)
        self.ScoutingCurveZones = {}
        self.CurrentFrontLineZones = {}
        self.UnpathableExpansionZoneCount = 0
        self.InitialTransportRequested = false
        self.NavalFocusSafe = false
        self.StructureRequests = {
            RADAR = {},
            TMD = {},
            TECH1POINTDEFENSE = {},
            SMD = {},
            SONAR = {},
        }
        self.MapMaximumValues = {
            MaximumResourceValue = 0,
            MaxumumGraphValue = 0
        }
        self.StrategyFlags = {
            T3BomberRushActivated = false,
            EnemyAirSnipeThreat = false,
            EarlyT2AmphibBuilt = false,
            EarlyT3Built = false,
            RangedAssaultPositions = {},
            T2RadarAllowed = false,
            T3RadarAllowed = false,
            T2SonarAllowed = false,
            T3SonarAllowed = false,
            T3ShieldsAllowed = false,
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
            Cruiser = {
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
            Carrier = {
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
        self.EnemyPerformance = {
            --=== AIR DOMAIN ===--
            Air = {
                TotalMassKilled = 0,
                TotalMassLost = 0,
                KillsAgainst = {
                    Air = 0,
                    Land = 0,
                    Naval = 0,
                    Experimental = 0,
                    Structure = 0,
                },
                LossesAgainst = {
                    Air = 0,
                    Land = 0,
                    Naval = 0,
                    Experimental = 0,
                    Structure = 0,
                },
                Subtypes = {
                    Bomber = { TotalMassKilled = 0, KillsAgainst = {}, TotalMassLost = 0, LossesAgainst = {} },
                    Gunship = { TotalMassKilled = 0, KillsAgainst = {}, TotalMassLost = 0, LossesAgainst = {} },
                    TorpedoBomber = { TotalMassKilled = 0, KillsAgainst = {}, TotalMassLost = 0, LossesAgainst = {} },
                    Interceptor = { TotalMassKilled = 0, KillsAgainst = {}, TotalMassLost = 0, LossesAgainst = {} },
                    Scout = { TotalMassKilled = 0, KillsAgainst = {}, TotalMassLost = 0, LossesAgainst = {} },
                }
            },
        
            --=== LAND DOMAIN ===--
            Land = {
                TotalMassKilled = 0,
                TotalMassLost = 0,
                KillsAgainst = {
                    Air = 0,
                    Land = 0,
                    Naval = 0,
                    Experimental = 0,
                    Structure = 0,
                },
                LossesAgainst = {
                    Air = 0,
                    Land = 0,
                    Naval = 0,
                    Experimental = 0,
                    Structure = 0,
                },
                Subtypes = {
                    Tank = { TotalMassKilled = 0, KillsAgainst = {}, TotalMassLost = 0, LossesAgainst = {} },
                    Bot = { TotalMassKilled = 0, KillsAgainst = {}, TotalMassLost = 0, LossesAgainst = {} },
                    Artillery = { TotalMassKilled = 0, KillsAgainst = {}, TotalMassLost = 0, LossesAgainst = {} },
                    MobileAA = { TotalMassKilled = 0, KillsAgainst = {}, TotalMassLost = 0, LossesAgainst = {} },
                }
            },
        
            --=== NAVAL DOMAIN ===--
            Naval = {
                TotalMassKilled = 0,
                TotalMassLost = 0,
                KillsAgainst = {
                    Air = 0,
                    Land = 0,
                    Naval = 0,
                    Experimental = 0,
                    Structure = 0,
                },
                LossesAgainst = {
                    Air = 0,
                    Land = 0,
                    Naval = 0,
                    Experimental = 0,
                    Structure = 0,
                },
                Subtypes = {
                    Frigate = { TotalMassKilled = 0, KillsAgainst = {}, TotalMassLost = 0, LossesAgainst = {} },
                    Destroyer = { TotalMassKilled = 0, KillsAgainst = {}, TotalMassLost = 0, LossesAgainst = {} },
                    Cruiser = { TotalMassKilled = 0, KillsAgainst = {}, TotalMassLost = 0, LossesAgainst = {} },
                    Battleship = { TotalMassKilled = 0, KillsAgainst = {}, TotalMassLost = 0, LossesAgainst = {} },
                    Submarine = { TotalMassKilled = 0, KillsAgainst = {}, TotalMassLost = 0, LossesAgainst = {} },
                }
            },
        
            --=== EXPERIMENTALS ===--
            Experimental = {
                TotalMassKilled = 0,
                TotalMassLost = 0,
                KillsAgainst = {
                    Air = 0,
                    Land = 0,
                    Naval = 0,
                    Experimental = 0,
                    Structure = 0,
                },
                LossesAgainst = {
                    Air = 0,
                    Land = 0,
                    Naval = 0,
                    Experimental = 0,
                    Structure = 0,
                },
                Subtypes = {
                    ExperimentalLand = { TotalMassKilled = 0, KillsAgainst = {}, TotalMassLost = 0, LossesAgainst = {} },
                    ExperimentalAir = { TotalMassKilled = 0, KillsAgainst = {}, TotalMassLost = 0, LossesAgainst = {} },
                    ExperimentalNaval = { TotalMassKilled = 0, KillsAgainst = {}, TotalMassLost = 0, LossesAgainst = {} },
                }
            },
        
            --=== STRUCTURES (STATIC DEFENSES, ECONOMY, ETC.) ===--
            Structure = {
                TotalMassKilled = 0,
                TotalMassLost = 0,
                KillsAgainst = {
                    Air = 0,
                    Land = 0,
                    Naval = 0,
                    Experimental = 0,
                    Structure = 0,
                },
                LossesAgainst = {
                    Air = 0,
                    Land = 0,
                    Naval = 0,
                    Experimental = 0,
                    Structure = 0,
                },
                Subtypes = {
                    PD = { TotalMassKilled = 0, KillsAgainst = {}, TotalMassLost = 0, LossesAgainst = {} },
                    AA = { TotalMassKilled = 0, KillsAgainst = {}, TotalMassLost = 0, LossesAgainst = {} },
                    TML = { TotalMassKilled = 0, KillsAgainst = {}, TotalMassLost = 0, LossesAgainst = {} },
                    SAM = { TotalMassKilled = 0, KillsAgainst = {}, TotalMassLost = 0, LossesAgainst = {} },
                    Shield = { TotalMassKilled = 0, KillsAgainst = {}, TotalMassLost = 0, LossesAgainst = {} },
                }
            },
        }
        self.ProductionZones = {}
    end,

    Run = function(self)
        --LOG('RNGAI : IntelManager Starting')
        self:ForkThread(self.ZoneAlertThreadRNG)
        self:ForkThread(self.ZoneFriendlyIntelMonitorRNG)
        self:ForkThread(self.ConfigureResourcePointZoneID)
        self:ForkThread(self.ZoneIntelAssignment)
        self:ForkThread(self.MonitorEnemyThreatOnBaseLabels)
        self:ForkThread(self.EnemyPositionAngleAssignment)
        self:ForkThread(self.ZoneDistanceValue)
        self:ForkThread(self.ZoneLabelAssignment)
        self:ForkThread(self.IntelGridThread, self.Brain)
        self:ForkThread(self.ZoneExpansionThreadRNG)
        self:ForkThread(self.TacticalIntelCheck)
        self:ForkThread(self.ZoneTransportRequirementCheck)
        self:ForkThread(self.GenerateZonePathDistanceCache)
        self:ForkThread(self.MaintainScoutingCurve)
        self:ForkThread(self.StructureRequestThread)
        self:ForkThread(self.IntelGridThreatThread, self.Brain)
        self:ForkThread(self.ZoneMetricUpdateThread)
        self:ForkThread(self.ZoneRenderDebugThread)
        self.Brain:ForkThread(self.Brain.BuildScoutLocationsRNG)
        --self:ForkThread(self.DrawZoneArmyValue)
        if self.Debug then
            self:ForkThread(self.IntelDebugThread)
        end

        --LOG('RNGAI : IntelManager Started')
        self.Initialized = true
    end,

    MaintainScoutingCurve = function(self)
        -- Currently this only really works on land maps. To be improved.

        coroutine.yield(50)
        local mainZoneID = self.Brain.BuilderManagers['MAIN'].ZoneID
        --LOG('Main base ID for player '..tostring(self.Brain.Nickname)..' is '..tostring(mainZoneID))
        local zones = self.Brain.Zones.Land.zones

        while self.Brain.Status ~= 'Defeat' do
            coroutine.yield(50)
            local scoutPosTable = self:GetDefensiveCurveZones(zones, mainZoneID, nil)
            self.ScoutingCurveZones = scoutPosTable
            --[[
            local counter = 0
            while counter < 150 do
                coroutine.yield(2)
                for k, v in scoutPosTable do
                    DrawCircle(zones[v].pos,3*zones[v].weight,'b967ff')
                end
                counter = counter + 1
            end
            ]]
            
        end
    end,

    GetScoutCurveZone = function(self, scoutPos)
        local aiBrain = self.Brain
        if not aiBrain.ZonesInitialized then
            return false
        end
        if not scoutPos[1] then
            return false
        end
        local curveZones = self.ScoutingCurveZones
        local zones = self.Brain.Zones.Land.zones
        local zoneId
        local zoneIdTable = {}
        if curveZones then
            for _, v in curveZones do
                local zone = zones[v]
                if zone and (not zone.intelassignment.ScoutUnit or zone.intelassignment.ScoutUnit.Dead) then
                    zoneId = v
                    table.insert(zoneIdTable, { ZoneID = zones[v].id, ZoneType = 'Land', ZonePosition = zones[v].pos })
                end
            end
        end
        if table.getn(zoneIdTable) > 0 then
            table.sort(zoneIdTable,function(k1,k2) return VDist2Sq(k1.ZonePosition[1],k1.ZonePosition[3],scoutPos[1],scoutPos[3])<VDist2Sq(k2.ZonePosition[1],k2.ZonePosition[3],scoutPos[1],scoutPos[3]) end)
            return zoneIdTable[1]
        end
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
        local mainBaseAmphibLabel = NavUtils.GetLabel('Amphibious', mainBasePos)
        local OwnIndex = aiBrain:GetArmyIndex()

        while true do
            --LOG('Running zone expansion check for '..tostring(aiBrain.Nickname))
            local maxDistance
            local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
            if not playableArea then
                maxDistance = math.max(ScenarioInfo.size[1],ScenarioInfo.size[2])
            end
            maxDistance = math.max(playableArea[3],playableArea[4])
            maxDistance = maxDistance * maxDistance
            local skipDistance = 8100
            local zoneSet = aiBrain.Zones.Land.zones
            local zonePriorityList = {}
            local gameTime = GetGameTimeSeconds()
            local labelBaseValues = {}
            local labelResourceValue = {}
            local zoneTypes = {
                'Land',
                'Naval',
            }
            for _, zoneType in zoneTypes do
                for k, v in aiBrain.Zones[zoneType].zones do
                    if v.BuilderManager.BaseType and v.BuilderManager.BaseType == 'MAIN' and v.BuilderManager.FactoryManager.LocationActive then
                        continue
                    end
                    if v.label and v.pos[1] > playableArea[1] and v.pos[1] < playableArea[3] and v.pos[3] > playableArea[2] and v.pos[3] < playableArea[4] then
                        local graphLabel = aiBrain.GraphZones[v.label]
                        local markersInGraph = graphLabel.MassMarkersInGraph or 1
                        if markersInGraph > 2 or zoneType == 'Naval' then
                            if zoneType == 'Naval' then
                                skipDistance = 4225
                            end
                            local bx = mainBasePos[1] - v.pos[1]
                            local bz = mainBasePos[3] - v.pos[3]
                            local mainBaseDistance = bx * bx + bz * bz
                            if v.BuilderManager.FactoryManager.LocationActive then
                                if not labelBaseValues[v.BuilderManager.Label] then
                                    labelBaseValues[v.BuilderManager.Label] = {}
                                end
                                if v.resourcevalue then
                                    labelBaseValues[v.BuilderManager.Label][v.id] = v.resourcevalue
                                end
                            end
                            local closeEnemyStart = false
                            local closeAllyStart = false
                            local edgeSkip = false
                            for _, e in  v.enemystartdata do
                                if e.startdistance < skipDistance then
                                    closeEnemyStart = true
                                    break
                                end
                            end
                            for index, a in  v.allystartdata do
                                if index ~= OwnIndex and a.startdistance < skipDistance then
                                    closeAllyStart = true
                                    break
                                end
                            end
                            if not closeEnemyStart and not closeAllyStart then
                                if mainBaseDistance > skipDistance then
                                    labelResourceValue[v.label] = labelResourceValue[v.label] or {}
                                    table.insert(labelResourceValue[v.label], {ZoneID = v.id, ResourceValue = v.resourcevalue, StartPositionClose = v.startpositionclose, DistanceToBase = mainBaseDistance, ZoneType = zoneType})
                                    if not edgeSkip then
                                        if (not v.BuilderManager.FactoryManager.LocationActive or v.BuilderManagerDisabled) and (not v.engineerplatoonallocated or IsDestroyed(v.engineerplatoonallocated)) and (v.lastexpansionattempt == 0 or gameTime >= v.lastexpansionattempt + 30 ) then
                                            local normalizedDistanceValue = mainBaseDistance / maxDistance
                                            local normalizedTeamValue = v.teamvalue / maxTeamValue
                                            local normalizedResourceValue = v.resourcevalue / maxResourceValue
                                            local normalizedMarkersInGraphValue = markersInGraph / maxGraphValue
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
                                            if zoneType == 'Naval' then
                                                local navalMultiplier = 1.0

                                                if v.label then
                                                    local labelData = aiBrain.BrainIntel.NavalBaseLabels[v.label]
                                                    local labelMeta = NavUtils.GetLabelMetadata(v.label)

                                                    -- Label State Check
                                                    if labelData then
                                                        if labelData.State == 'Confirmed' then
                                                            -- This label is within 256 units of a start position
                                                            navalMultiplier = navalMultiplier * 1.2 
                                                        elseif labelData.State == 'Unconfirmed' then
                                                            -- Known but no connectivity yet
                                                            navalMultiplier = navalMultiplier * 0.5
                                                        end
                                                    else
                                                        -- State is 'Unconfirmed'
                                                        navalMultiplier = navalMultiplier * 0.1
                                                    end

                                                    -- Area Size Scaling
                                                    if labelMeta and labelMeta.Area and labelMeta.Area < 10 then
                                                        navalMultiplier = navalMultiplier * (labelMeta.Area / 10)
                                                    end
                                                else
                                                    -- Label is nil - I should double check why
                                                    navalMultiplier = 0.05
                                                end

                                                priorityScore = priorityScore * navalMultiplier
                                            end
                                            table.insert(zonePriorityList, {ZoneID = v.id, Position = v.pos, Priority = priorityScore, Label = v.label, ResourceValue = v.resourcevalue, TeamValue = v.teamvalue, BestArmy = v.bestarmy, DistanceToBase = mainBaseDistance, ZoneType = zoneType, AmphibLabel = v.amphiblabel })
                                        end
                                    end
                                end
                            end
                        end
                    end
                    coroutine.yield(1)
                end
            end
            local filteredLandPathableList = {}
            local filteredLandUnPathableList = {}
            local filteredNavalList = {}
            --LOG('Number of zoneprioritylist zones we can expand to '..table.getn(zonePriorityList))
            --LOG('ZonePriorityList '..tostring(repr(zonePriorityList)))
            for _, zone in ipairs(zonePriorityList) do
                if aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE * (categories.FACTORY + categories.DIRECTFIRE), zone.Position, 30, 'Enemy') < 1 then
                    if zone.BestArmy and zone.BestArmy ~= armyIndex and ArmyBrains[zone.BestArmy].Status ~= 'Defeat' then
                        continue
                    end
                    local graphLabel = aiBrain.GraphZones[zone.Label]
                    local markersInGraph = graphLabel.MassMarkersInGraph or 1
                    local normalizedMarkersInGraphValue = markersInGraph  / maxGraphValue
                    --LOG('normalizedMarkersInGraphValue '..tostring(normalizedMarkersInGraphValue))
                    local isPrimaryLabel = (normalizedMarkersInGraphValue > 0.7)
                    if zone.ResourceValue < 3 and zone.ZoneType ~= 'Naval' then
                        --LOG('Zone worth less than 3')
                        --LOG('Team value was '..tostring(zone.TeamValue))
                        --LOG('Zone pos is '..tostring(zone.Position[1])..' : '..tostring(zone.Position[3]))
                        local higherValueExists = false
                        if zone.Label ~= mainBaseLabel then
                            for _, resValue in ipairs(labelResourceValue[zone.Label] or {}) do
                                if resValue.DistanceToBase < zone.DistanceToBase and resValue.ResourceValue >= zone.ResourceValue then
                                    -- If we are on the primary label, unbuildable ghosts don't shadow us.
                                    if isPrimaryLabel then
                                        -- We ignore this resValue and continue the loop
                                        local friendlyBaseFound = false
                                        for name, manager in aiBrain.BuilderManagers do
                                            if manager and manager.FactoryManager and manager.FactoryManager.LocationActive then
                                                local mPos = manager.Position

                                                local dist = VDist2Sq(zone.Position[1], zone.Position[3], mPos[1], mPos[3])
                                                if dist < 8100 then -- Log anything within a reasonable range
                                                    friendlyBaseFound = true
                                                    break
                                                end
                                            end
                                        end
                                        if friendlyBaseFound then
                                            higherValueExists = true
                                            break
                                        end
                                    else
                                        -- Check for active bases or start positions
                                        if (zoneSet[resValue.ZoneID].BuilderManager.FactoryManager.LocationActive and zoneSet[resValue.ZoneID].BuilderManager.BaseType ~= 'MAIN') then
                                            --LOG('HigherValueExists set to true due to StartPositionClose or an active factory manager for zone '..tostring(zone.ZoneID))
                                            higherValueExists = true
                                            break
                                        end

                                        -- Check for unit threats
                                        if aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE * categories.FACTORY, zoneSet[resValue.ZoneID].pos, 30, 'Ally') < 1 
                                        and aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE * (categories.FACTORY + categories.DIRECTFIRE), zoneSet[resValue.ZoneID].pos, 30, 'Enemy') < 1 then
                                            
                                            --LOG('HigherValueExists set to true due to factories being present for zone '..tostring(zone.ZoneID))
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
                            if zone.AmphibLabel ~= mainBaseAmphibLabel and zone.ZoneType == 'Land' then
                                table.insert(filteredLandUnPathableList, zone)
                            elseif zone.ZoneType == 'Land' then
                                table.insert(filteredLandPathableList, zone)
                            elseif zone.ZoneType == 'Naval' then
                                table.insert(filteredNavalList, zone)
                            end
                        end
                    else
                        --LOG('Zone checked '..tostring(zone.ZoneID))
                        --LOG('Amphib Label '..tostring(zone.AmphibLabel)..' mainbaseAmphibLabel '..tostring(mainBaseAmphibLabel)..' zone type '..tostring(zone.ZoneType))
                        --LOG('Ally factory count '..tostring(aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE * categories.FACTORY, zone.Position, 30, 'Ally')))
                        if aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE * categories.FACTORY, zone.Position, 30, 'Ally') < 1 then
                            if zone.AmphibLabel ~= mainBaseAmphibLabel and zone.ZoneType == 'Land' then
                                table.insert(filteredLandUnPathableList, zone)
                            elseif zone.ZoneType == 'Land' then
                                table.insert(filteredLandPathableList, zone)
                            elseif zone.ZoneType == 'Naval' then
                                table.insert(filteredNavalList, zone)
                            end
                        end
                    end
                end
            end
            --LOG('Number of filtered zones we can expand to '..table.getn(filteredLandUnPathableList))
            if not table.empty(filteredLandPathableList) then
                table.sort(filteredLandPathableList, function(a, b) return a.Priority > b.Priority end)
                self.ZoneExpansions.Pathable = filteredLandPathableList
                --aiBrain:ForkThread(self.DrawInfection, filteredLandPathableList[1].Position)
            end
            if not table.empty(filteredLandUnPathableList) then
                table.sort(filteredLandUnPathableList, function(a, b) return a.Priority > b.Priority end)
                self.ZoneExpansions.NonPathable = filteredLandUnPathableList
                --aiBrain:ForkThread(self.DrawInfection, filteredLandPathableList[1].Position)
            end
            if not table.empty(filteredNavalList) then
                table.sort(filteredNavalList, function(a, b) return a.Priority > b.Priority end)
                self.ZoneExpansions.Naval = filteredNavalList
                --LOG('ZoneExpansionsNaval '..tostring(aiBrain.Nicknacm)..' is '..tostring(repr(filteredNavalList)))
                --aiBrain:ForkThread(self.DrawInfection, filteredNavalList[1].Position)
            end
            coroutine.yield(50)
        end
    end,

    GetClosestZone = function(self, aiBrain, platoon, position, enemyPosition, controlRequired, minimumResourceValue)
            
        local zoneSet = false
        local cdr = platoon.PlatoonName == 'ACUBehavior' and platoon.cdr
        local isRetreating = cdr and (platoon.StateName == 'Retreating')
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
                    if cdr and isRetreating then
                        local baseLabel = aiBrain.BuilderManagers['MAIN'].Label
                        local zoneLabel = v.label
                        if zoneLabel ~= baseLabel then
                            local zoneDefense = v.friendlyantisurfacethreat or 0
                            local dx = position[1] - zonePos[1]
                            local dz = position[3] - zonePos[3]
                            if (dx*dx + dz*dz) > 14400 and zoneDefense < 20 then
                                continue
                            end
                        end
                    end
                    if enemyPosition then 
                        local ex = enemyPosition[1] - v.pos[1]
                        local ez = enemyPosition[3] - v.pos[3]
                        local enemyDist = ex * ex + ez * ez
                        if enemyDist < (zoneDist + 25) or RUtils.GetAngleRNG(originPosition[1], originPosition[3], v.pos[1], v.pos[3], enemyPosition[1], enemyPosition[3]) < 0.65 or (not controlRequired and enemyDist < 625) then
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

    GetZoneLabelControlRatio = function(self, zoneSet, label)
        local totalZones = 0
        local alliedZones = 0
    
        for _, zone in zoneSet do
            if zone.label == label then
                totalZones = totalZones + 1
                if zone.status == 'Allied' then
                    alliedZones = alliedZones + 1
                end
            end
        end
    
        if totalZones == 0 then return 0 end
        return alliedZones / totalZones
    end,

    GetClosestRetreatZone = function(self, aiBrain, platoon, position, enemyPosition, enemyRange, defensiveRetreat, minimumResourceValue, movementLayer)
        --LOG('Get closest retreat zone '..tostring(defensiveRetreat)..' platoon buildername is '..tostring(platoon.BuilderName))

        local teamPositions = aiBrain.IntelManager:GetTeamAveragePositions()
        local myBasePos = { teamPositions['Ally'].x, 0, teamPositions['Ally'].z }
        local enemyBasePos = { teamPositions['Enemy'].x, 0 ,teamPositions['Enemy'].z }
        if not myBasePos or not enemyBasePos then
            return nil
        end
        local originPosition = platoon and platoon.Pos or position
        if not originPosition then 
            return nil 
        end
    
        if not movementLayer then
            movementLayer = RUtils.PositionInWater(originPosition) and 'Naval' or 'Land'
        end
    
        local zoneSet = aiBrain.Zones[movementLayer].zones
        if not zoneSet then
            WARN('GetClosestZone: No zones for movement layer')
            return nil
        end   
        local originZoneID = platoon.ZoneID or MAP:GetZoneID(originPosition,aiBrain.Zones[movementLayer].index)
        local originZone = aiBrain.Zones[movementLayer].zones[originZoneID]
        --LOG('Origin Zone ID is '..tostring(originZone.id))
    
        if not originZone or not originZone.edges then
            WARN('GetClosestZone: Origin zone or edges missing')
            return nil
        end
    
        -- Vector to enemy base for directional scoring
        local vecToEnemy = {
            x = enemyBasePos[1] - myBasePos[1],
            z = enemyBasePos[3] - myBasePos[3]
        }
    
        -- Visited table to avoid revisits in multi-hop
        local visited = {}
        local candidates = {}
    
        local avoidRadiusSq = 625
        if platoon.BuilderData.Position[1] then
            --LOG('Check angle to existing zone for enemy base'..tostring(RUtils.GetAngleRNG(originPosition[1], originPosition[3], platoon.BuilderData.Position[1], platoon.BuilderData.Position[3], enemyBasePos[1], enemyBasePos[3])))
            if enemyPosition then
                --LOG('Check angle to existing zone for enemy unit'..tostring(RUtils.GetAngleRNG(originPosition[1], originPosition[3], platoon.BuilderData.Position[1], platoon.BuilderData.Position[3], enemyPosition[1], enemyPosition[3])))
            end
        end
    
        -- Score one zone
        local function ConsiderZone(originZoneId, zone)
            if not zone or visited[zone.id] then 
                return 
            end
            visited[zone.id] = true
    
            if minimumResourceValue and zone.resourcevalue < minimumResourceValue then 
                return 
            end
            if not NavUtils.CanPathTo(platoon.MovementLayer, originPosition, zone.pos) then 
                return 
            end
    
            -- Check enemy unit proximity
            local distToEnemyUnitSq
            if enemyPosition then
                local ex = enemyPosition[1] - zone.pos[1]
                local ez = enemyPosition[3] - zone.pos[3]
                distToEnemyUnitSq = ex * ex + ez * ez
                if distToEnemyUnitSq < avoidRadiusSq then return end
            end
    
            -- Angle scoring
            local angleToEnemyBase = RUtils.GetAngleRNG(originPosition[1], originPosition[3], zone.pos[1], zone.pos[3], enemyBasePos[1], enemyBasePos[3])

            local angleToUnit
            if enemyPosition then
                angleToUnit = RUtils.GetAngleRNG(originPosition[1], originPosition[3], zone.pos[1], zone.pos[3], enemyPosition[1], enemyPosition[3])
            end
            local dx = originPosition[1] - zone.pos[1]
            local dz = originPosition[3] - zone.pos[3]
            local distSq = dx * dx + dz * dz
    
            local score = 0
    
            if defensiveRetreat then
                --LOG(string.format('RNGAI Defensive Retreat Analysis | Platoon: %s | Origin Zone: %s', platoon.BuilderName or 'Unknown', tostring(originZoneId)))
                -- RETREAT MODE: Avoid enemy, move away
                if angleToEnemyBase and angleToEnemyBase < 0.4 then return end
                if angleToUnit and angleToUnit < 0.35 then return end
                if zone.status == 'Hostile' then return end
                local aggroBonus = 18
                local baseWeight = 0
                local consolidationWeight = 0.5
                local factoryManager = zone.BuilderManager.FactoryManager
                if factoryManager and factoryManager.LocationActive then
                    baseWeight = 10
                    aggroBonus = 20
                end
            
                local _, baseDist = StateUtils.GetClosestBaseManager(aiBrain, zone.pos)

                score = -(math.min(90000, distSq) * 0.0001)
                score = score - (baseDist * 0.00005)
                score = score + baseWeight
                --LOG('Score after distances applied '..tostring(score))
            
                if zone.teamvalue and zone.teamvalue >= 1.0 then
                    score = score + 3
                elseif zone.teamvalue then
                    score = score - 2
                end
                local maxAggressiveDistanceSq = 10000
                if distToEnemyUnitSq and distToEnemyUnitSq > 0 and enemyRange and enemyRange > 0 then
                    
                    local enemyRangeSq = enemyRange * enemyRange
                    local rangeDiffSq = distToEnemyUnitSq - enemyRangeSq + 1
                    --LOG('We are taking into account an enemy position, enemy range dif '..tostring(rangeDiffSq)..' current score '..tostring(score))
                    if distToEnemyUnitSq < enemyRangeSq then
                        return
                    end
                    if rangeDiffSq < maxAggressiveDistanceSq then 
                        -- Nudge: Use the dynamic aggroBonus
                        score = score + aggroBonus 
                        local nudge = math.min(10, 100 / math.max(1, rangeDiffSq))
                        score = score + nudge 
                    else
                        score = score - (rangeDiffSq * 0.001)
                    end
                    --LOG('Score after range diff penality '..tostring(score))
                end
            
                if zone.zoneincome.selfincome and zone.zoneincome.selfincome > 0 then
                    score = score + math.min(3, zone.zoneincome.selfincome * 0.5)
                    --LOG('Income Bonus '..tostring(math.min(3, zone.zoneincome.selfincome * 0.5)))
                end
                if zone.friendlydirectfireantisurfacethreat and zone.friendlydirectfireantisurfacethreat > 0 then
                    -- A small nudge (e.g., 10 threat = +5 score) to favor regrouping
                    local mobileBonus = zone.friendlydirectfireantisurfacethreat * 0.2
                    --LOG('Mobile Bonus '..tostring(math.min(6, mobileBonus)))
                    score = score + math.min(6, mobileBonus)
                end
                if zone.friendlydefenseantisurfacethreat and zone.friendlydefenseantisurfacethreat > 0 then
                    local defenseBonus = zone.friendlydefenseantisurfacethreat * 0.4
                    --LOG('Defense Bonus '..tostring(defenseBonus))
                    score = score + math.min(10, defenseBonus)
                end
            
                if zone.gridenemylandthreat and zone.friendlydirectfireantisurfacethreat then
                    local threatRatio = zone.gridenemylandthreat / math.max(1, zone.friendlydirectfireantisurfacethreat)
                    if threatRatio > 1.0 then
                        score = score - math.min(4, (threatRatio - 1.0) * 2)
                        --LOG('threat ratio is being take away from score, ratio is '..tostring(math.min(4, (threatRatio - 1.0) * 2)))
                    end
                end
                if RUtils.IsEnemyStartClose(zone) then
                    score = score - 2
                end
            
                if zone.enemyantisurfacethreat and zone.enemyantisurfacethreat > 0 then
                    local enemyBonus = zone.enemyantisurfacethreat * 0.25
                    score = score - math.min(6, enemyBonus)
                    --LOG('enemyantisurfacethreat Bonus being removed'..tostring(math.min(6, enemyBonus)))
                end
                --LOG(string.format(' Zone: %s | Score: %0.2f', zone.id, score))
            else
                if angleToEnemyBase and angleToEnemyBase > 0.70 then return end
                if angleToUnit and angleToUnit < 0.25 then return end

                local toEnemyBaseSq = VDist2Sq(zone.pos[1], zone.pos[3], enemyBasePos[1], enemyBasePos[3])
                score = score + math.max(0, 10000 - toEnemyBaseSq) * 0.002

                if zone.teamvalue and zone.teamvalue < 1.0 then
                    score = score + 2
                end
            
                if zone.zoneincome.selfincome and zone.zoneincome.selfincome > 0 then
                    score = score - math.min(2, zone.zoneincome.selfincome * 0.3)
                end

                if zone.id == originZone.id and not defensiveRetreat then
                    -- Avoid "stalling" in same zone during offensive logic
                    score = score - 4
                end
            
                if RUtils.IsEnemyStartClose(zone) then
                    score = score - 2
                    score = score + zone.resourcevalue * 1
                else
                    score = score +  zone.resourcevalue * 4
                end

                if zone.gridenemylandthreat and platoon.CurrentPlatoonThreatDirectFireAntiSurface then
                    local threatRatio = zone.gridenemylandthreat / math.max(1, platoon.CurrentPlatoonThreatDirectFireAntiSurface)
                    if threatRatio > 1.3 then
                        score = score - math.min(4, (threatRatio - 1.0) * 3)
                    end
                end
            
                if zone.enemyantisurfacethreat then
                    score = score - math.min(2, zone.enemyantisurfacethreat * 0.2)
                end
            
                if zone.status ~= 'Allied' then
                    score = score + 1
                end

                local defenseClusterDanger = StateUtils.CheckDefenseClusters(aiBrain, zone.pos, platoon['rngdata'].MaxPlatoonWeaponRange or 0, platoon.MovementLayer, platoon.CurrentPlatoonThreatAntiSurface or 0)
                if defenseClusterDanger then
                    score = score - 5
                end

                
                --LOG('Score ' .. tostring(score))
            end
    
            table.insert(candidates, { zone = zone, score = score })
        end
        --LOG('Origin Zone is '..tostring(originZone))
        -- Expand out from origin zone to 2 hops
        for _, edge in originZone.edges or {} do
            ConsiderZone(originZone, edge.zone)
            if edge.zone and edge.zone.edges then
                for _, subEdge in edge.zone.edges do
                    ConsiderZone(originZone, subEdge.zone)
                end
            end
        end
    
        table.sort(candidates, function(a, b) return a.score > b.score end)
        --LOG('Returning position '..tostring(repr(candidates[1].zone.pos)))
        return candidates[1].zone
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
        local controlValue = GetControlValue(zone.status)
        local controlModifier = (1 - controlValue) + contestedWeight
    
        return transportModifier, distanceModifier, enemyModifier, controlModifier
    end,

    ZoneMetricUpdateThread = function(self)
        local aiBrain = self.Brain
        -- Using CamelCase for constants (per instructions)
        local MaxBfsDepth = 25 
        local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
        local mapDiagonalSq = VDist2Sq(playableArea[1], playableArea[2], playableArea[3], playableArea[4])
        local statusValueTable = {
            Allied = 0.75,        -- Lower urgency unless threatened
            Hostile = 1.0,        -- High urgency
            Contested = 2.0,      -- Medium-high urgency
            Unoccupied = 1.5      -- Moderate interest for expansion
           }
        local weightTable = {
            control = {
                zoneDistanceWeight = 1.0,
                enemyDistanceWeight = 1.0,
                homeDistanceWeight = 1.8, -- Increases gravity toward base/supply lines
                incomeValueWeight = 0.5,
                threatOpportunityWeight = 2.0,
                zoneStatusWeight = 1.2,
                zonePressureWeight = 3.0,
                teamValueWeight = 0.8,
                contiguityWeight = 3.0, -- Strengthens the value of territory connected to allies
                adjacencyThreatWeight = 0.9,
                encirclementWeight = 2.0,
                zoneHomeWeight = 1.0,
                zoneFlankRiskWeight = 1.3,
                frontlineWeight = 2.5,    -- High gravity for main combat groups
                stagingPressureWeight = 3.5,
            },
            raid = {
                zoneDistanceWeight = 0.5,
                enemyDistanceWeight = 0.4,
                homeDistanceWeight = 0.3,
                incomeValueWeight = 1.2,
                threatOpportunityWeight = 0.4,
                zoneStatusWeight = 0.1,
                teamValueWeight = 0.7,
                contiguityWeight = 0.8,
                adjacencyThreatWeight = 0.8,
                zonePressureWeight = 1.2,
                zoneFlankWeight = 2.5,
                frontlineBypassWeight = -1.5, -- Discourages raw raiding straight into a locked front wall
            },
            aadefense = {
                teamValue = 0.3,
                massValue = 0.2,
                enemyAntiSurface = 0.1,
                enemyAir = 0.5,
                friendlyantisurfacethreat = 0.05,
                friendlylandantiairthreat = 0.05,
                startPos = 0.3,
                control = 0.3,
                alliedAntiAirDeficit = 0.3,
                contiguityWeight = 0.5,
                frontlineWeight = 1.5,
                adjacenyWeight = 1.0,
            },
            airsurface = {
                incomeValueWeight = 0.7,
                utilityWeight = 2.0,
                viabilityWeight = 2.5,        -- Multiplier for the RUtils.GetZoneAirSurfaceViability result
                utilityWeight = 1.2,          -- Multiplier for the Island/Angle utility
                enemyAirFrictionWeight = 0.5, -- Extra penalty if global enemy air is strong
                exposurePenaltyWeight = 5.0,
            }
        }
        self:WaitForZoneInitialization()
        local mainBaseZoneID
        while not mainBaseZoneID do
            mainBaseZoneID = aiBrain.BuilderManagers['MAIN'].ZoneID
            coroutine.yield(20)
        end
        local debugFocusZoneID = false
        --LOG(string.format("RNGAI VALIDATION: Main Base Zone ID is %s", tostring(mainBaseZoneID)))
    
        while aiBrain.Result ~= "defeat" do
            local currentEnemy = aiBrain:GetCurrentEnemy()
            local enemyArmyIndex = currentEnemy and currentEnemy:GetArmyIndex()
            local myIndex = aiBrain:GetArmyIndex()
            local myStart = aiBrain.BuilderManagers['MAIN'].Position
            local enemyStart

            if enemyArmyIndex then
                enemyStart = aiBrain.EnemyIntel.EnemyStartLocations[enemyArmyIndex].Position
            else
                enemyStart = aiBrain.MapCenterPoint
            end
            local zones = aiBrain.Zones.Land.zones
            local intel = self.EnemyIntel.EnemyThreatCurrent
            local currentFrontlines = self.CurrentFrontLineZones or {}
            local totalHighValueRaidTargets = 0
            local totalFrontlinePressure = 0
            local totalContestedIncomeZones = 0
    
            -- 1. BFS PHASE: Path-Distance Mapping
            -- This determines homeDistanceValue and reachability via edges
            local homeDepths = {}
            if mainBaseZoneID then
                local queue = { { id = mainBaseZoneID, depth = 0 } }
                homeDepths[mainBaseZoneID] = 0
                local head = 1
                while head <= table.getn(queue) do
                    local current = queue[head]
                    head = head + 1
                    local z = zones[current.id]
                    for _, edge in ipairs(z.edges or {}) do
                        if not homeDepths[edge.zone.id] and current.depth < MaxBfsDepth then
                            homeDepths[edge.zone.id] = current.depth + 1
                            table.insert(queue, { id = edge.zone.id, depth = current.depth + 1 })
                        end
                    end
                end
            end
       
            -- 3. THE MAIN SCORING PASS (One loop for performance)
            for id, v in zones do
                -- A. Core Variable Setup (From your snippet)
                local enemyStartClose = RUtils.IsEnemyStartClose(v)
                local allyStartClose = RUtils.IsAllyStartClose(v)
                local aggressionScale = self.Aggression or 1.0
                
                -- B. BFS-Based Distance Metrics
                -- distanceValue (platoon) is REDUNDANT here.
                -- homeDistanceValue is replaced by BFS path depth.
                local homePathDist = (homeDepths[id] or MaxBfsDepth) / MaxBfsDepth
                local enemyDistValue = (v.enemystartdata and v.enemystartdata[enemyArmyIndex]) and (v.enemystartdata[enemyArmyIndex].startdistance / mapDiagonalSq) or 1.0

                local isFrontlineNode = currentFrontlines[id] and 1.0 or 0.0
                local maxMapIncome = self.MapMaximumValues.MaximumResourceValue
                if not maxMapIncome or maxMapIncome <= 0 then
                    maxMapIncome = 1.0
                end
    
                -- C. RUtils Calculations (Leveraging your snippet)
                local controlValue = RUtils.GetAdaptiveStatusValue(v, self) * aggressionScale
                local resourceValueControl = RUtils.GetZoneIncomeValue(v, 'control', enemyStartClose, allyStartClose) / maxMapIncome
                local resourceValueRaid = RUtils.GetZoneIncomeValue(v, 'raid', enemyStartClose, allyStartClose) / maxMapIncome
                local zoneHomeValue = RUtils.GetZoneHomeBiasValue(allyStartClose, enemyStartClose, v)
                local encirclementValue = RUtils.GetZoneEncirclementValue(v) * aggressionScale
                local adjacencyValue = RUtils.GetAdjacencyThreatBonus(self, v, statusValueTable, 'Surface') * aggressionScale
                local contiguityValue = RUtils.GetZoneContiguityValue(self, v)
                local zoneFlankRisk = RUtils.GetZoneFlankRiskValue(v)
                local zoneFlankRaidBonus = RUtils.GetRaidFlankBonusValue(v, aiBrain, enemyArmyIndex, mapDiagonalSq) 
                local aaEscortValue = RUtils.GetZoneAAEscortValue(v, statusValueTable)
                local teamValueBonus = (v.teamvalue > 1) and (3 - v.teamvalue) or v.teamvalue
                local airUtilityValue = RUtils.GetZoneAirSurfaceUtility(v, teamValueBonus)
                local airSurfaceViabilityValue = RUtils.GetZoneAirSurfaceViability(self.MapMaximumValues.MaximumResourceValue, v)
                local airExposureValue = RUtils.GetZoneExposureValue(myStart, enemyStart, v.pos, mapDiagonalSq)
                local stagingPressureValue = RUtils.GetZoneStagingPressureValue(self, v)

                local enemyIncome = (v.zoneincome and v.zoneincome.enemyincome) or 0
                if v.staticraidscore > 0.8 and enemyIncome > 0 then
                    totalHighValueRaidTargets = totalHighValueRaidTargets + 1
                end

                -- Track active macro tactical pressure (Staging or contested stress)
                if stagingPressureValue > 2.0 or (currentFrontlines[id] and adjacencyValue > 1.5) then
                    totalFrontlinePressure = totalFrontlinePressure + 1
                end

                -- Track income nodes currently floating in the open or actively contested
                if (v.status == 'Contested' or v.status == 'Unoccupied') and (v.resourcevalue or 0) > 0 then
                    totalContestedIncomeZones = totalContestedIncomeZones + 1
                end

                -- D. CALCULATE STATIC SCORES
                -- Note: We omit distanceValue, threatValue, and zonePressureValue (calculated by platoon)
                v.staticcontrolscore = (
                    ((1.0 - enemyDistValue) * weightTable.control.enemyDistanceWeight) +
                    ((1.0 - homePathDist) * weightTable.control.homeDistanceWeight) +
                    resourceValueControl * weightTable.control.incomeValueWeight + 
                    controlValue * weightTable.control.zoneStatusWeight +
                    contiguityValue * weightTable.control.contiguityWeight +
                    zoneHomeValue * weightTable.control.zoneHomeWeight - 
                    teamValueBonus * weightTable.control.teamValueWeight + 
                    adjacencyValue * weightTable.control.adjacencyThreatWeight + 
                    encirclementValue * weightTable.control.encirclementWeight -
                    zoneFlankRisk * weightTable.control.zoneFlankRiskWeight +
                    isFrontlineNode * weightTable.control.frontlineWeight +
                    stagingPressureValue * weightTable.control.stagingPressureWeight
                )
    
                -- D2. STATIC RAID SCORE
                v.staticraidscore = (
                    ((1.0 - enemyDistValue) * weightTable.raid.enemyDistanceWeight) +
                    homePathDist * weightTable.raid.homeDistanceWeight +
                    resourceValueRaid * weightTable.raid.incomeValueWeight + 
                    controlValue * weightTable.raid.zoneStatusWeight +
                    contiguityValue * weightTable.raid.contiguityWeight - 
                    teamValueBonus * weightTable.raid.teamValueWeight +
                    zoneFlankRaidBonus * weightTable.raid.zoneFlankWeight +
                    isFrontlineNode * weightTable.raid.frontlineBypassWeight
                )
    
                -- D3. STATIC AA DEFENSE SCORE
                -- Note: Uses specific keys from your aadefense weightTable
                local eAir = v.enemyairthreat or 0
                local eAntiAir = v.enemyantiairthreat or 0

                -- Apply the "Fighter/Scout Filter" logic to the static score
                local aaUrgency = eAir
                if eAir < 1 and eAntiAir > 0 then
                    aaUrgency = 0 -- Don't value this zone for AA if it's just land-based AA
                end
                v.staticaascore = (
                    (v.teamvalue or 0) * weightTable.aadefense.teamValue +
                    (v.resourcevalue or 0) * weightTable.aadefense.massValue +
                    (aaUrgency / 20 * weightTable.aadefense.enemyAir) +
                    (aaEscortValue * weightTable.aadefense.frontlineWeight) +
                    contiguityValue * weightTable.aadefense.contiguityWeight +
                    adjacencyValue * weightTable.aadefense.adjacenyWeight
                )
                local globalAirScale = (aiBrain.BrainIntel.SelfThreat.AirNow > aiBrain.EnemyIntel.EnemyThreatCurrent.Air* 1.5) and 1.3 or 1.0

                -- D4. STATIC AIR SURFACE SCORE (Tunable)
                v.staticsurfaceairscore = (
                    (resourceValueControl * weightTable.airsurface.incomeValueWeight) +
                    (airSurfaceViabilityValue * weightTable.airsurface.viabilityWeight) +
                    (airUtilityValue * weightTable.airsurface.utilityWeight) -
                    (airExposureValue * weightTable.airsurface.exposurePenaltyWeight)
                ) * globalAirScale

                self.HighValueRaidTargets = totalHighValueRaidTargets
                self.FrontlinePressureCount = totalFrontlinePressure
                self.ContestedIncomeCount = totalContestedIncomeZones

               if debugFocusZoneID then
                    WARN(string.format("RNGLOG AUDIT: --- TUNING DATA FOR ZONE %s ---", tostring(id)))
                    WARN(string.format("  [CONTROL SCORE: %.3f]", v.staticcontrolscore))
                    LOG(string.format("    > EnemyDist:    (1.0 - %.2f) * %.1f = %.2f", enemyDistValue, weightTable.control.enemyDistanceWeight, (1.0 - enemyDistValue) * weightTable.control.enemyDistanceWeight))
                    LOG(string.format("    > HomeBfsDist:  (1.0 - %.2f) * %.1f = %.2f", homePathDist, weightTable.control.homeDistanceWeight, (1.0 - homePathDist) * weightTable.control.homeDistanceWeight))
                    LOG(string.format("    > ZoneIncome:   %.2f * %.1f = %.2f", resourceValueControl, weightTable.control.incomeValueWeight, resourceValueControl * weightTable.control.incomeValueWeight))
                    LOG(string.format("    > AdaptiveStat: %.2f * %.1f = %.2f", controlValue, weightTable.control.zoneStatusWeight, controlValue * weightTable.control.zoneStatusWeight))
                    LOG(string.format("    > Contiguity:   %.2f * %.1f = %.2f", contiguityValue, weightTable.control.contiguityWeight, contiguityValue * weightTable.control.contiguityWeight))
                    LOG(string.format("    > HomeBias:     %.2f * %.1f = %.2f", zoneHomeValue, weightTable.control.zoneHomeWeight, zoneHomeValue * weightTable.control.zoneHomeWeight))
                    LOG(string.format("    > TeamBonus:    -%.2f * %.1f = -%.2f", teamValueBonus, weightTable.control.teamValueWeight, teamValueBonus * weightTable.control.teamValueWeight))
                    LOG(string.format("    > AdjThreat:    %.2f * %.1f = %.2f", adjacencyValue, weightTable.control.adjacencyThreatWeight, adjacencyValue * weightTable.control.adjacencyThreatWeight))
                    LOG(string.format("    > Encircle:     %.2f * %.1f = %.2f", encirclementValue, weightTable.control.encirclementWeight, encirclementValue * weightTable.control.encirclementWeight))
                    LOG(string.format("    > FlankRisk:    -%.2f * %.1f = -%.2f", zoneFlankRisk, weightTable.control.zoneFlankRiskWeight, zoneFlankRisk * weightTable.control.zoneFlankRiskWeight))
                    
                    WARN(string.format("  [RAID SCORE: %.3f]", v.staticraidscore))
                    LOG(string.format("    > EnemyDist:    (1.0 - %.2f) * %.1f = %.2f", enemyDistValue, weightTable.raid.enemyDistanceWeight, (1.0 - enemyDistValue) * weightTable.raid.enemyDistanceWeight))
                    LOG(string.format("    > HomeBfsDist:  %.2f * %.1f = %.2f", homePathDist, weightTable.raid.homeDistanceWeight, homePathDist * weightTable.raid.homeDistanceWeight))
                    LOG(string.format("    > ZoneIncome:   %.2f * %.1f = %.2f", resourceValueRaid, weightTable.raid.incomeValueWeight, resourceValueRaid * weightTable.raid.incomeValueWeight))
                    LOG(string.format("    > AdaptiveStat: %.2f * %.1f = %.2f", controlValue, weightTable.raid.zoneStatusWeight, controlValue * weightTable.raid.zoneStatusWeight))
                    LOG(string.format("    > Contiguity:   %.2f * %.1f = %.2f", contiguityValue, weightTable.raid.contiguityWeight, contiguityValue * weightTable.raid.contiguityWeight))
                    LOG(string.format("    > TeamBonus:    -%.2f * %.1f = -%.2f", teamValueBonus, weightTable.raid.teamValueWeight, teamValueBonus * weightTable.raid.teamValueWeight))
                    LOG(string.format("    > ZoneFlankBonus:    %.2f * %.1f = %.2f", zoneFlankRaidBonus, weightTable.raid.zoneFlankWeight, zoneFlankRaidBonus * weightTable.raid.zoneFlankWeight))

                end
                    -- =====================================
                    -- LIVE VISUAL DEBUG ENGINE INJECTION
                    -- =====================================
                    self.VisualDebugData = self.VisualDebugData or {}
                    if v.pos then
                        self.VisualDebugData[id] = {
                            pos = v.pos,
                            controlRadius = math.max(1, v.staticcontrolscore * 4),
                            raidRadius = math.max(1, v.staticraidscore * 4),
                            parentPos = nil
                        }
                        
                        -- Trace structural paths for BFS without drawing yet
                        if homeDepths[id] and homeDepths[id] > 0 then
                            for _, edge in ipairs(v.edges or {}) do
                                if homeDepths[edge.zone.id] and homeDepths[edge.zone.id] < homeDepths[id] then
                                    self.VisualDebugData[id].parentPos = edge.zone.pos
                                    break
                                end
                            end
                        end
                    end
            end
            coroutine.yield(20) 
        end
    end,

    ZoneRenderDebugThread = function(self)
        -- Wait until data starts populating
        while not self.VisualDebugData do
            coroutine.yield(10)
        end

        local aiBrain = self.Brain
        local currentTime = GetGameTimeSeconds()
        while aiBrain.Result ~= "defeat" do
            -- Render every single tick for solid, non-flickering visuals
            for id, data in self.VisualDebugData do
                if data.pos then
                    -- Solid Blue for Control Score Intensity
                    DrawCircle(data.pos, data.controlRadius, '0000FF')
                    
                    -- Solid Red for Raid Score Intensity
                    DrawCircle(data.pos, data.raidRadius, 'ffFF0000')
                    
                    -- Solid Yellow lines for BFS paths back to base
                    if data.parentPos then
                        DrawLinePop(data.pos, data.parentPos, 'ffFFFF00')
                    end
                    -- Render Active Return Choices (Decays after 5 seconds)
                    if data.selectionExpiry and data.selectionExpiry > currentTime then
                        if data.lastSelectionType == 'raid' then
                            -- Vivid Orange/Red for active Raid Target
                            DrawCircle(data.pos, 6, 'ffFF4500') 
                            DrawCircle(data.pos, 8, 'ffFF4500')
                        elseif data.lastSelectionType == 'control' then
                            -- Deep Cyan for active Control Target
                            DrawCircle(data.pos, 6, 'ff00FFFF')
                            DrawCircle(data.pos, 8, 'ff00FFFF')
                        else
                            -- Magenta for any other types (aadefense, airsurface)
                            DrawCircle(data.pos, 6, 'ffFF00FF')
                            DrawCircle(data.pos, 8, 'ffFF00FF')
                        end
                    end
                end
            end
            for id, data in self.CurrentFrontLineZones do
                if aiBrain.Zones.Land.zones[id] then
                    local renderPos = aiBrain.Zones.Land.zones[id].pos
                    DrawCircle(renderPos, 10, 'FFFFFF')
                end
            end
            coroutine.yield(2)
        end
    end,

    GetBestZoneForPlatoon = function(self, platoon, zonetype, origZoneID)
        local aiBrain = self.Brain
        local zones = aiBrain.Zones.Land.zones
        local platPos = platoon:GetPlatoonPosition()
        local weights = self.ZoneWeightTable[string.lower(zonetype or 'control')]
        local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
        local mapDiagonalSq = VDist2Sq(playableArea[1], playableArea[2], playableArea[3], playableArea[4])
        local stabilityWeight = 6.0 -- Increased to compensate for potentially higher strategic scores
        
        local bestZone = nil
        local bestScore
        local bestPos = nil
        local noTransportsAvailable = not aiBrain.TransportPool or aiBrain.TransportPool and aiBrain.TransportPressure and aiBrain.TransportPressure.PressureLevel > 2
        local minThreshold = 0
        if weights.minThreshold then
            local platoonThreat = platoon.CurrentPlatoonThreatAntiSurface or 0
            local reduction = weights.threatScale and (platoonThreat / weights.threatScale) or 0
            minThreshold = math.max(weights.minFloor or 0, weights.minThreshold - reduction)
        end
    
        for id, v in zones do
            local canPathTo = false
            if platoon.MovementLayer == 'Air' then
                canPathTo = true
            elseif v.label and platoon.Label and v.label == platoon.Label then
                canPathTo = true
            elseif platoon.MovementLayer == 'Amphibious' and platoon.Label == v.amphiblabel then
                canPathTo = true
            elseif not noTransportsAvailable then
                canPathTo = true
            end
            if not canPathTo then
                continue 
            end
            -- 1. Base Strategic Score
            local baseScore = (zonetype == 'raid') and v.staticraidscore or 
                             (zonetype == 'aadefense') and v.staticaascore or 
                             (zonetype == 'airsurface') and v.staticsurfaceairscore or 
                             v.staticcontrolscore

            local currentStab = 0
            if id == origZoneID then
                currentStab = stabilityWeight
                baseScore = baseScore + currentStab
            end

            -- 3. Dynamic Distance
            local distSq = VDist2Sq(platPos[1], platPos[3], v.pos[1], v.pos[3])
            local distanceValue = distSq / mapDiagonalSq
            
            -- 4. Using RUtils with cached platoon values
            -- Note: RUtils should likely use platoon.CurrentPlatoonThreatAntiSurface etc inside
            local threatValue = RUtils.GetThreatOportunityValue(v, zonetype, platoon)
            local zonePressureValue = RUtils.GetZonePressureValue(RUtils.IsEnemyStartClose(v), v, platoon, zonetype)


            local zoneOwner = v.control or 'None'
            --LOG(string.format("RNGLOG | Zone: %s | Owner: %s | DistWeight: %.2f | DistVal: %.4f", v.id, tostring(zoneOwner), weights.zoneDistanceWeight or 0, distanceValue))
            -- 5. Final Calculation
            local finalScore = baseScore + 
                (threatValue * weights.threatOpportunityWeight) -
                (distanceValue * weights.zoneDistanceWeight) -
                (zonePressureValue * weights.zonePressureWeight)

            if not bestScore or finalScore > (bestScore - 0.5) then
                --LOG(string.format("RNG_ZONE_DECISION: Plat=%s | Zone=%s | Final=%.2f | Base=%.2f | Opp=%.2f | DistP=%.4f | PressP=%.4f | Stab=%.1f | Status=%s", 
                    --platoon.BuilderName or "Unk", v.id, finalScore, baseScore, (threatValue * weights.threatOpportunityWeight), (distanceValue * weights.zoneDistanceWeight), (zonePressureValue * weights.zonePressureWeight), currentStab, v.status or "None"))
            end

            if zonetype == 'aadefense' then
                local saturationPenalty = RUtils.GetAASaturationPenalty(v)
                finalScore = finalScore - saturationPenalty
            end

            ------------
            local RallyPointBonus = 2.5 -- Use a constant for easy tuning
            
            -- Check neighbors to see if we are a 'Staging Area'
            if v.edges then
                for _, edge in v.edges do
                    local neighbor = edge.zone
                    if neighbor and neighbor.BuilderManager and neighbor.BuilderManager.FactoryManager.LocationActive then
                        -- Is the neighbor (the base) under attack?
                        if (neighbor.enemyantisurfacethreat or 0) > 0 then -- Consider adding a threshold here, e.g., > 5
                            finalScore = finalScore + RallyPointBonus
                            break 
                        end
                    end
                end
            end

            ---------------------------------------------------------
            -- CONTEXT-RICH LOGGING BLOCK
            ---------------------------------------------------------
            -- We log if this zone is the one the NEW logic currently likes, 
            -- OR if it's the one the OLD logic chose.
            
            --[[
            local debugType = 'control' -- e.g., 'aadefense' or 'raid'
            
            if debugType == 'all' or zonetype == debugType then
                if not bestScore or finalScore > bestScore then
                    local eAir = v.enemyairthreat or 0
                    local fAir = v.friendlylandantiairthreat or 0
                    local eSurf = v.enemyantisurfacethreat or 0
                    local fSurf = v.friendlyantisurfacethreat or 0
                    
                    LOG(string.format("RNGAI Selection | Type: %-9s | Zone: %s | Platoon: %s", zonetype, v.id, platoon.PlatoonName or 'N/A'))
                    
                    -- Math Breakdown: Shows exactly how the weights affected the final choice
                    LOG(string.format("  > Score: %.2f (Base: %.2f | Opp: +%.2f | Dist: -%.2f | Press: -%.2f)", finalScore, baseScore, (threatValue * weights.threatOpportunityWeight), (distanceValue * weights.zoneDistanceWeight), (zonePressureValue * weights.zonePressureWeight)))
                    
                    -- Specific Context for the Type
                    if zonetype == 'aadefense' then
                        local satPenalty = RUtils.GetAASaturationPenalty(v)
                        LOG(string.format("  > AA Context: EnemyAir: %.1f | SaturationPenalty: -%.2f", eAir, satPenalty))
                    elseif zonetype == 'raid' then
                        LOG(string.format("  > Raid Context: Income: %.1f | EnemySurf: %.1f", (v.resourcevalue or 0), eSurf))
                    end

                    -- Platoon vs Zone Threat Balance
                    LOG(string.format("  > Threat Balance: Zone[E:%.1f/F:%.1f] Platoon[Surf:%.1f/AA:%.1f]", eSurf, fSurf, (platoon.CurrentPlatoonThreatAntiSurface or 0), (platoon.CurrentPlatoonThreatAntiAir or 0)))
                end
            end
            ]]
            
    
            if not bestScore or finalScore > bestScore then
                bestScore = finalScore
                bestZone = v
                bestPos = v.pos

                -- 6. Edge Awareness: If defending a frontline zone, find the specific border to guard
                if (zonetype == 'control' or zonetype == 'aadefense') and self.CurrentFrontLineZones[id] then
                    local myBasePos = aiBrain.BrainIntel.StartPos
                    local worstEdge = nil
                    local maxIncomingThreat = -1
                    
                    for _, edge in v.edges or {} do
                        local neighbor = edge.zone
                        -- Check if the neighbor is the source of threat
                        if neighbor.status == 'Hostile' or neighbor.status == 'Contested' then
                            -- Check if midpoint is not significantly closer to base than zone center
                            local distCenterSq = VDist2Sq(v.pos[1], v.pos[3], myBasePos[1], myBasePos[3])
                            local distEdgeSq = VDist2Sq(edge.midpoint[1], edge.midpoint[3], myBasePos[1], myBasePos[3])
                            
                            -- Requirement: promote moving forward or staying steady, not retreating.
                            -- We allow a 10% tolerance (0.9) for irregular zone shapes.
                            if distEdgeSq >= (distCenterSq * 0.9) then
                                local neighborThreat = (zonetype == 'aadefense') and neighbor.enemyairthreat or neighbor.enemyantisurfacethreat
                                if neighborThreat > maxIncomingThreat then
                                    maxIncomingThreat = neighborThreat
                                    worstEdge = edge
                                end
                            end
                        end
                    end
                    
                    if worstEdge then
                        bestPos = worstEdge.midpoint
                    end
                end
            end
        end
        if not bestZone or (bestZone and bestScore < minThreshold) then
            return nil, nil
        end
        if bestZone then
            self.VisualDebugData[bestZone.id] = self.VisualDebugData[bestZone.id] or {}
            self.VisualDebugData[bestZone.id].pos = bestPos
            self.VisualDebugData[bestZone.id].lastSelectionType = zonetype
            self.VisualDebugData[bestZone.id].selectionExpiry = GetGameTimeSeconds() + 10.0
        end
        return bestZone.id, bestPos
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
        local homeLabel = aiBrain.BuilderManagers['MAIN'].Label or 0
        if homeLabel == 0 then
            WARN('WARNING RNGAI home label is zero indicating the label is not set yet or there is an error')
        end


        while aiBrain.Status ~= "Defeat" do
            
            local globalFairTotal, globalInferredAllied, globalFactualIncome = 0, 0, 0
            local labelFairTotal, labelInferredAllied, labelFactualIncome = 0, 0, 0
            local ownedZones = 0
            local incomeZones = 0
            local totalZones = 0
            for k, v in Zones do
                for k1, v1 in aiBrain.Zones[v].zones do
                    local status = aiBrain.GridPresence:GetInferredStatus(v1.pos)
                    local hasIncome = (v1.zoneincome.selfincome or 0) > 0
                    local isFairShare = (v1.bestarmy == selfIndex)
                    local isHomeLabel = (homeLabel and v1.label == homeLabel)
                    -- Global Metrics (Your fair share across the whole map)
                    if isFairShare then
                        globalFairTotal = globalFairTotal + 1
                        if status == 'Allied' then globalInferredAllied = globalInferredAllied + 1 end
                        if hasIncome then globalFactualIncome = globalFactualIncome + 1 end
                    end

                    -- Label Metrics (The island/continent you actually live on)
                    if isHomeLabel and isFairShare then
                        labelFairTotal = labelFairTotal + 1
                        if status == 'Allied' then labelInferredAllied = labelInferredAllied + 1 end
                        if hasIncome then labelFactualIncome = labelFactualIncome + 1 end
                    end
                    if not v1.startpositionclose and status == 'Allied' and v1.enemylandthreat > 0 then
                        --RNGLOG('Try create zone alert for threat')
                        aiBrain:BaseMonitorZoneThreatRNG(v1.id, v1.enemylandthreat)
                    end
                    coroutine.yield(2)
                end
                coroutine.yield(3)
            end
            if globalFairTotal > 0 then
                -- Use INFERRED for "Am I safe?" checks
                aiBrain.BrainIntel.PlayerZoneControl = globalInferredAllied / globalFairTotal
                --LOG('Player Zone Control is '..tostring(aiBrain.BrainIntel.PlayerZoneControl)..' game time is '..tostring(GetGameTimeSeconds()))
                -- Use INCOME for "Do I need more factories?" checks
                aiBrain.BrainIntel.PlayerZoneOwnership = globalFactualIncome / globalFairTotal
                --LOG('Player Zone Ownership is '..tostring(aiBrain.BrainIntel.PlayerZoneOwnership))
            end

            if labelFairTotal > 0 then
                -- Island-specific drive
                aiBrain.BrainIntel.LabelZoneOwnership = labelFactualIncome / labelFairTotal
                --LOG('Player Label Zone Ownership is '..tostring(aiBrain.BrainIntel.LabelZoneOwnership))
            end
            coroutine.yield(30)
        end
    end,

    UpdateThreatMemoryScan = function(self, timeNow, threatType)
        local gridSize = self.IMAPConfig.IMAPSize
        local scanData = self.Brain:GetThreatsAroundPosition(
            {ScenarioInfo.size[1]/2, 0, ScenarioInfo.size[2]/2},
            16, true, threatType
        )
    
        for _, data in scanData do
            local gx, gz = self:GetIntelGrid({data[1], 0, data[2]})
            local threatVal = data[3]
    
            local cell = self.MapIntelGrid[gx] and self.MapIntelGrid[gx][gz]
            if cell then
                cell.IMAPCurrentThreat[threatType] = threatVal
                -- Keep the max between new threat and decayed memory
                if threatVal > 0 then
                    -- Active threat sighted: lock in the highest peak seen
                    cell.IMAPHistoricalThreat[threatType] = math.max(cell.IMAPHistoricalThreat[threatType] or 0, threatVal)
                else
                    -- Threat is 0 at this position
                    if cell.IntelCoverage then
                        -- If we have active radar/vision and it's empty, wipe it instantly
                        cell.IMAPHistoricalThreat[threatType] = 0
                    else
                        -- It's in the fog of war. Decay the memory based on elapsed time!
                        local lastUpdate = cell.LastThreatUpdate or timeNow
                        local timeDelta = timeNow - lastUpdate
                        local currentHist = cell.IMAPHistoricalThreat[threatType] or 0
                        
                        if currentHist > 0 and timeDelta > 0 then
                            -- Decay Rate: Loses 0.5 threat points per second in the dark
                            -- (Adjust 0.5 to change how "forgetful" or "paranoid" the AI is)
                            cell.IMAPHistoricalThreat[threatType] = math.max(0, currentHist - (timeDelta * 0.5))
                        end
                    end
                end
                cell.LastThreatUpdate = timeNow
            end
        end
    end,

    IntelGridThreatThread = function(self, aiBrain)
        while not self.MapIntelGrid do
            coroutine.yield(30)
        end
        local threatTypes = {
            'Naval',
            'AntiAir',
            'Air',
            'Land',
            'AntiSurface',
            'StructuresNotMex',
            'Land',
            'Naval'
        }
        while aiBrain.Status ~= "Defeat" do
            local gameTime = GetGameTimeSeconds()
            for _, ttype in threatTypes do
                self:UpdateThreatMemoryScan(gameTime, ttype)
                coroutine.yield(2)
            end
            self:AssignIMAPThreat(aiBrain, 'Land', gameTime)
            self:AssignIMAPThreat(aiBrain, 'Naval', gameTime)
            self:AssignIMAPThreat(aiBrain, 'Air', gameTime)
            self.ProductionZones = {}
            self:AssignThreatToFactories(aiBrain.Zones['Land'].zones, 'Land')
            self:AssignThreatToFactories(aiBrain.Zones['Naval'].zones, 'Naval')
            for _, zone in aiBrain.Zones['Land'].zones do
                zone.status = aiBrain.GridPresence:GetInferredStatus(zone.pos)
            end
            for _, zone in aiBrain.Zones['Naval'].zones do
                zone.status = aiBrain.GridPresence:GetInferredStatus(zone.pos)
            end
            coroutine.yield(20)
        end
    end,

    AssignIMAPThreat = function(self, aiBrain, zoneType, imapTime)
        local zoneTable = aiBrain.Zones[zoneType].zones
        local labelTable = {}
        local zoneToGridMap = self.ZoneToGridMap[zoneType]
        local currentTime = GetGameTimeSeconds()
        local STALE_TIME = 5
    
        for _, zone in zoneTable do
            local cells = zoneToGridMap[zone.id]
            if not cells or table.getn(cells) == 0 then continue end
    
            local total = {
                Land = 0, Air = 0, AntiAir = 0, Naval = 0, 
                AntiSurface = 0, StructuresNotMex = 0, count = 0
            }
            
            -- Initialize peaks for every category we care about
            local historicalPeak = {
                Land = 0, Air = 0, AntiAir = 0, Naval = 0, 
                AntiSurface = 0, StructuresNotMex = 0
            }
    
            for _, cell in cells do
                if not cell.Enabled then continue end
                if (cell.LastUpdate_Land or 0) < imapTime then cell.IMAPCurrentThreat.Land = 0 end
                if (cell.LastUpdate_Air or 0) < imapTime then cell.IMAPCurrentThreat.Air = 0 end
                if (cell.LastUpdate_AntiAir or 0) < imapTime then cell.IMAPCurrentThreat.AntiAir = 0 end
                if (cell.LastUpdate_Naval or 0) < imapTime then cell.IMAPCurrentThreat.Naval = 0 end
                if (cell.LastUpdate_AntiSurface or 0) < imapTime then cell.IMAPCurrentThreat.AntiSurface = 0 end
                if (cell.LastUpdate_StructuresNotMex or 0) < imapTime then cell.IMAPCurrentThreat.StructuresNotMex = 0 end
                
                local current = cell.IMAPCurrentThreat
                local hist = cell.IMAPHistoricalThreat
                
                -- SUM Current: Accurate count of units presently in the zone
                total.Land = total.Land + (current.Land or 0)
                total.Air = total.Air + (current.Air or 0)
                total.AntiAir = total.AntiAir + (current.AntiAir or 0)
                total.Naval = total.Naval + (current.Naval or 0)
                total.AntiSurface = total.AntiSurface + (current.AntiSurface or 0)
                total.StructuresNotMex = total.StructuresNotMex + (current.StructuresNotMex or 0)
    
                -- MAX Historical: Tracks the largest army seen in this zone, 
                -- without multiplying it by the number of cells they walked through.
                historicalPeak.Land = math.max(historicalPeak.Land, hist.Land or 0)
                historicalPeak.Air = math.max(historicalPeak.Air, hist.Air or 0)
                historicalPeak.AntiAir = math.max(historicalPeak.AntiAir, hist.AntiAir or 0)
                historicalPeak.Naval = math.max(historicalPeak.Naval, hist.Naval or 0)
                historicalPeak.AntiSurface = math.max(historicalPeak.AntiSurface, hist.AntiSurface or 0)
                historicalPeak.StructuresNotMex = math.max(historicalPeak.StructuresNotMex, hist.StructuresNotMex or 0)
    
                total.count = total.count + 1
            end
    
            if total.count > 0 then
                -- Apply Noise Floor to prevent floating point remnants (the "0.1" ghosts)
                -- from blocking the historical decay branch.
                local landThreat = (total.Land > 0.5) and total.Land or 0
                local airThreat = (total.Air > 0.5) and total.Air or 0
                local antiAirThreat = (total.AntiAir > 0.5) and total.AntiAir or 0
                local navalThreat = (total.Naval > 0.5) and total.Naval or 0
                local antiSurfaceThreat = (total.AntiSurface > 0.5) and total.AntiSurface or 0
                local structThreat = (total.StructuresNotMex > 0.5) and total.StructuresNotMex or 0

                -- For each type: If filtered current is 0, use a decayed version of the PEAK.
                zone.enemylandthreat = (landThreat > 0) and landThreat or (historicalPeak.Land * 0.5)
                zone.enemyairthreat  = (airThreat > 0) and airThreat or (historicalPeak.Air * 0.5)
                zone.enemyantiairthreat = (antiAirThreat > 0) and antiAirThreat or (historicalPeak.AntiAir * 0.5)
                zone.enemynavalthreat = (navalThreat > 0) and navalThreat or (historicalPeak.Naval * 0.5)
                zone.enemyantisurfacethreat = (antiSurfaceThreat > 0) and antiSurfaceThreat or (historicalPeak.AntiSurface * 0.5)
                zone.enemystructurethreat = (structThreat > 0) and structThreat or (historicalPeak.StructuresNotMex * 0.5)
                
                -- Zero out the value entirely if it falls below the absolute minimum visibility threshold
                if zone.enemylandthreat < 0.1 then zone.enemylandthreat = 0 end
                if zone.enemyairthreat < 0.1 then zone.enemyairthreat = 0 end
                if zone.enemyantiairthreat < 0.1 then zone.enemyantiairthreat = 0 end
                if zone.enemynavalthreat < 0.1 then zone.enemynavalthreat = 0 end
                if zone.enemyantisurfacethreat < 0.1 then zone.enemyantisurfacethreat = 0 end
                if zone.enemystructurethreat < 0.1 then zone.enemystructurethreat = 0 end
                if zone.label then
                    if not labelTable[zone.label] then
                        labelTable[zone.label] = {
                            enemylandthreat = 0,
                            enemyairthreat = 0,
                            enemyantiairthreat = 0,
                            enemynavalthreat = 0,
                            enemyantisurfacethreat = 0,
                            enemystructurethreat = 0
                        }
                    end
                    labelTable[zone.label].enemylandthreat = labelTable[zone.label].enemylandthreat + zone.enemylandthreat
                    labelTable[zone.label].enemyairthreat = labelTable[zone.label].enemyairthreat + zone.enemyairthreat
                    labelTable[zone.label].enemyantiairthreat = labelTable[zone.label].enemyantiairthreat + zone.enemyantiairthreat
                    labelTable[zone.label].enemynavalthreat = labelTable[zone.label].enemynavalthreat + zone.enemynavalthreat
                    labelTable[zone.label].enemyantisurfacethreat = labelTable[zone.label].enemyantisurfacethreat + zone.enemyantisurfacethreat
                    labelTable[zone.label].enemystructurethreat = labelTable[zone.label].enemystructurethreat + zone.enemystructurethreat
                end
            end
        end
        self.LabelIMAPThreat[zoneType] = labelTable
    end,

    ZoneFriendlyIntelMonitorRNG = function(self)
        local function ClearTable(t)
            for k in t do t[k] = nil end
        end
        local Zones = {
            'Land',
            'Naval'
        }

        local labelThreat = {}
        local threatLayers = { 
            Naval = {
                friendlyThreatAntiSurface = {},
                friendlyThreatDirecFireAntiSurface = {},
                friendlyThreatIndirecFireAntiSurface = {},
                friendlyThreatAntiAir = {},
                friendlyThreatAntiAirAllocated = {},
                friendlyThreatAntiNavy = {},
                friendlyThreatDirecFireAntiSurfaceAllocated = {}
            }, 
            Land = {
                friendlyThreatAntiSurface = {},
                friendlyThreatDirecFireAntiSurface = {},
                friendlyThreatIndirecFireAntiSurface = {},
                friendlyThreatAntiAir = {},
                friendlyThreatAntiAirAllocated = {},
                friendlyThreatAntiNavy = {},
                friendlyThreatDirecFireAntiSurfaceAllocated = {}
            }
        }
        self:WaitForZoneInitialization()
        coroutine.yield(Random(5,20))
        local aiBrain = self.Brain
        while aiBrain.Status ~= "Defeat" do
            --local startTime = GetSystemTimeSecondsOnlyForProfileUse()
            --local zoneCount = 0
            for layerName, drawer in threatLayers do
                for threatName, threatTable in drawer do
                    ClearTable(threatTable)
                end
            end
            local AlliedPlatoons = aiBrain:GetPlatoonsList()
            for k1, v1 in AlliedPlatoons do
                if not IsDestroyed(v1) then
                    if not v1.MovementLayer then
                        AIAttackUtils.GetMostRestrictiveLayerRNG(v1)
                    end
                    local layer = v1.MovementLayer == 'Water' and 'Naval' or 'Land'
                    local bucket = threatLayers[layer]
                    if v1.ZoneID and v1.CurrentPlatoonThreatAntiSurface then
                        bucket.friendlyThreatAntiSurface[v1.ZoneID] = (bucket.friendlyThreatAntiSurface[v1.ZoneID] or 0) + v1.CurrentPlatoonThreatAntiSurface
                    end
                    if v1.ZoneID and v1.CurrentPlatoonThreatDirectFireAntiSurface then
                        bucket.friendlyThreatDirecFireAntiSurface[v1.ZoneID] = (bucket.friendlyThreatDirecFireAntiSurface[v1.ZoneID] or 0) + v1.CurrentPlatoonThreatDirectFireAntiSurface
                    end
                    if v1.ZoneID and v1.CurrentPlatoonThreatIndirectFireAntiSurface then
                        bucket.friendlyThreatIndirecFireAntiSurface[v1.ZoneID] = (bucket.friendlyThreatIndirecFireAntiSurface[v1.ZoneID] or 0) + v1.CurrentPlatoonThreatIndirectFireAntiSurface
                    end
                    if v1.ZoneID and v1.CurrentPlatoonThreatAntiAir then
                        bucket.friendlyThreatAntiAir[v1.ZoneID] = (bucket.friendlyThreatAntiAir[v1.ZoneID] or 0) + v1.CurrentPlatoonThreatAntiAir
                    end
                    if v1.ZoneID and v1.CurrentPlatoonThreatAntiNavy then
                        bucket.friendlyThreatAntiNavy[v1.ZoneID] = (bucket.friendlyThreatAntiNavy[v1.ZoneID] or 0) + v1.CurrentPlatoonThreatAntiNavy
                    end
                    if v1.ZoneAllocated and v1.CurrentPlatoonThreatAntiAir then
                        bucket.friendlyThreatAntiAirAllocated[v1.ZoneAllocated] = (bucket.friendlyThreatAntiAirAllocated[v1.ZoneAllocated] or 0) + v1.CurrentPlatoonThreatAntiAir
                    end
                    if v1.ZoneAllocated and v1.CurrentPlatoonThreatDirectFireAntiSurface then
                        bucket.friendlyThreatDirecFireAntiSurfaceAllocated[v1.ZoneAllocated] = (bucket.friendlyThreatDirecFireAntiSurfaceAllocated[v1.ZoneAllocated] or 0) + v1.CurrentPlatoonThreatDirectFireAntiSurface
                    end
                end
            end
            for k, v in Zones do
                for zId, zData in aiBrain.Zones[v].zones do
                    zData.friendlylandantiairthreat = 0
                    zData.friendlydefenseantiairthreat = 0
                    zData.friendlyantisurfacethreat = 0
                    zData.friendlyantinavythreat = 0
                    zData.friendlydefenseantisurfacethreat = 0
                    zData.friendlyindirectfireantisurfacethreat = 0
                    zData.friendlydirectfireantisurfacethreat = 0
                    zData.platoonallocations.friendlyantiairallocatedthreat = 0
                    zData.platoonallocations.friendlydirectfireallocatedthreat = 0
                    --zoneCount = zoneCount + 1
                    local friendlydefenseantisurfacethreat = 0
                    local friendlydefenseantiairthreat = 0
                    if zData.defensespokes then
                        for _, ring in zData.defensespokes do
                            for _, spoke in ring do
                                if spoke.Enabled then
                                    friendlydefenseantisurfacethreat = friendlydefenseantisurfacethreat + (spoke.AntiSurfaceThreat or 0)
                                    friendlydefenseantiairthreat = friendlydefenseantiairthreat + (spoke.AntiAirThreat or 0)
                                end
                            end
                        end
                        zData.friendlydefenseantisurfacethreat=friendlydefenseantisurfacethreat
                        zData.friendlydefenseantiairthreat=friendlydefenseantiairthreat
                    end
                end
                for zoneId, threatValue in threatLayers[v].friendlyThreatAntiSurface do
                    local zone = aiBrain.Zones[v].zones[zoneId]
                    if zone then
                        zone.friendlyantisurfacethreat = threatValue
                    end
                end
                for zoneId, threatValue in threatLayers[v].friendlyThreatAntiNavy do
                    local zone = aiBrain.Zones[v].zones[zoneId]
                    if zone then
                        zone.friendlyantinavythreat = threatValue
                    end
                end
                for zoneId, threatValue in threatLayers[v].friendlyThreatAntiAirAllocated do
                    local zone = aiBrain.Zones[v].zones[zoneId]
                    if zone then
                        zone.platoonallocations.friendlyantiairallocatedthreat = threatValue
                    end
                end
                for zoneId, threatValue in threatLayers[v].friendlyThreatDirecFireAntiSurfaceAllocated do
                    local zone = aiBrain.Zones[v].zones[zoneId]
                    if zone then
                        zone.platoonallocations.friendlydirectfireallocatedthreat = threatValue
                    end
                end
                for zoneId, threatValue in threatLayers[v].friendlyThreatDirecFireAntiSurface do
                    local zone = aiBrain.Zones[v].zones[zoneId]
                    if zone then
                        zone.friendlydirectfireantisurfacethreat = threatValue
                        if zone.label > 0 and not labelThreat[zone.label] then
                            labelThreat[zone.label] = {
                                friendlydirectfireantisurfacethreat = 0,
                                friendlyindirectfireantisurfacethreat = 0,
                                friendlyThreatAntiAir = 0
                            }
                        end
                        if zone.label > 0 then
                            labelThreat[zone.label].friendlydirectfireantisurfacethreat = labelThreat[zone.label].friendlydirectfireantisurfacethreat + threatValue
                        end
                    end
                end
                for zoneId, threatValue in threatLayers[v].friendlyThreatIndirecFireAntiSurface do
                    local zone = aiBrain.Zones[v].zones[zoneId]
                    if zone then
                        zone.friendlyindirectfireantisurfacethreat = threatValue
                        if zone.label > 0 and not labelThreat[zone.label] then
                            labelThreat[zone.label] = {
                                friendlydirectfireantisurfacethreat = 0,
                                friendlyindirectfireantisurfacethreat = 0,
                                friendlyThreatAntiAir = 0
                            }
                        end
                        if zone.label > 0 then
                            labelThreat[zone.label].friendlyindirectfireantisurfacethreat = labelThreat[zone.label].friendlyindirectfireantisurfacethreat + threatValue
                        end
                    end
                end
                for zoneId, threatValue in threatLayers[v].friendlyThreatAntiAir do
                    local zone = aiBrain.Zones[v].zones[zoneId]
                    if zone then
                        zone.friendlylandantiairthreat = threatValue
                        if zone.label > 0 and not labelThreat[zone.label] then
                            labelThreat[zone.label] = {
                                friendlydirectfireantisurfacethreat = 0,
                                friendlyindirectfireantisurfacethreat = 0,
                                friendlyThreatAntiAir = 0
                            }
                        end
                        if zone.label > 0 then
                            labelThreat[zone.label].friendlyThreatAntiAir = labelThreat[zone.label].friendlyThreatAntiAir + threatValue
                        end
                    end
                end
                --[[
                -- test our data sets
                for zId, zData in aiBrain.Zones[v].zones do
                    local logEntry = string.format(
                        'INTEL_FINAL_AUDIT | Zone: %s | Label: %d | ' ..
                        'Air(Mob/Stat): %0.1f/%0.1f | ' ..
                        'Surf(Mob/Stat): %0.1f/%0.1f | ' ..
                        'Indir: %0.1f | Dir: %0.1f',
                        tostring(zId),
                        zData.label or 0,
                        zData.friendlylandantiairthreat or 0,
                        zData.friendlydefenseantiairthreat or 0,
                        zData.friendlyantisurfacethreat or 0,
                        zData.friendlydefenseantisurfacethreat or 0,
                        zData.friendlyindirectfireantisurfacethreat or 0,
                        zData.friendlydirectfireantisurfacethreat or 0
                    )
                    LOG(logEntry)
                end
                ]]
            end


            -- Note right now this is only for land labels, we'll figure out the naval stuff later.
            for labelId, threatData in labelThreat do
                local gZone = aiBrain.GraphZones[labelId]
                if gZone then
                    gZone.FriendlySurfaceDirectFireThreat = threatData.friendlydirectfireantisurfacethreat
                    --LOG('Assigned FriendlySurfaceDirectFireThreat to graphzone '..k2..' of '..aiBrain.GraphZones[k2].FriendlySurfaceDirectFireThreat)
                    gZone.FriendlySurfaceInDirectFireThreat = threatData.friendlyindirectfireantisurfacethreat
                    --LOG('Assigned FriendlySurfaceInDirectFireThreat to graphzone '..k2..' of '..aiBrain.GraphZones[k2].FriendlySurfaceInDirectFireThreat)
                    gZone.FriendlyLandAntiAirThreat = threatData.friendlyThreatAntiAir
                    --LOG('Assigned FriendlyLandAntiAirThreat to graphzone '..k2..' of '..aiBrain.GraphZones[k2].FriendlyLandAntiAirThreat)
                end
            end
            --local duration = (GetSystemTimeSecondsOnlyForProfileUse() - startTime)
            --LOG(string.format('INTEL_MONITOR_PERF: Zones: %d | Platoons: %d | Cycle: %0.4fms', zoneCount, table.getn(AlliedPlatoons), duration))
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
                    v.zoneid = MAP:GetZoneID(v.position,self.Zones.Naval.index)
                else
                    v.zoneid = MAP:GetZoneID(v.position,self.Zones.Land.index)
                end
            end
        end
    end,

    AssignIntelUnit = function(self, unit)
        local aiBrain = self.Brain
        
        local intelPosition = unit:GetPosition()
        if unit.Blueprint.CategoriesHash.RADAR then
            
            local intelRadius = unit.Blueprint.Intel.RadarRadius
            --LOG('Zone set for radar that has been built '..unit.UnitId)
            unit.zoneid = MAP:GetZoneID(intelPosition,aiBrain.Zones.Land.index)
            if unit.zoneid then
                local zone = aiBrain.Zones.Land.zones[unit.zoneid]
                if VDist3Sq(intelPosition, zone.pos) < intelRadius * intelRadius then
                    if not zone.intelassignment.RadarUnits then
                        zone.intelassignment.RadarUnits = {}
                    end
                    RNGINSERT(zone.intelassignment.RadarUnits, unit)
                    zone.intelassignment.RadarCoverage = true
                end
            else
                WARN('No ZoneID for Radar, unable to set coverage area')
            end
            local gridSearch = math.floor(unit.Blueprint.Intel.RadarRadius / self.MapIntelGridSize)
            --RNGLOG('GridSearch for IntelCoverage is '..gridSearch)
            self:InfectGridPosition(intelPosition, gridSearch, 'Radar', 'IntelCoverage', true, unit)
            self:FlushExistingStructureRequest(intelPosition, math.ceil(intelRadius * 0.7), 'RADAR')
        elseif unit.Blueprint.CategoriesHash.SONAR then
            local intelRadius = unit.Blueprint.Intel.SonarRadius
            --LOG('Zone set for radar that has been built '..unit.UnitId)
            unit.zoneid = MAP:GetZoneID(intelPosition,aiBrain.Zones.Naval.index)
            if unit.zoneid then
                local zone = aiBrain.Zones.Naval.zones[unit.zoneid]
                if VDist3Sq(intelPosition, zone.pos) < intelRadius * intelRadius then
                    if not zone.intelassignment.SonarUnits then
                        zone.intelassignment.SonarUnits = {}
                    end
                    RNGINSERT(zone.intelassignment.SonarUnits, unit)
                    zone.intelassignment.SonarCoverage = true
                end
            else
                WARN('No ZoneID for Sonar, unable to set coverage area')
            end
            local gridSearch = math.floor(unit.Blueprint.Intel.SonarRadius / self.MapIntelGridSize)
            --RNGLOG('GridSearch for IntelCoverage is '..gridSearch)
            self:InfectGridPosition(intelPosition, gridSearch, 'Sonar', 'IntelCoverage', true, unit)
            self:FlushExistingStructureRequest(intelPosition, math.ceil(intelRadius * 0.7), 'SONAR')
        end
    end,

    UnassignIntelUnit = function(self, unit)
        local aiBrain = self.Brain
        local intelPosition = unit:GetPosition()
        if unit.Blueprint.CategoriesHash.RADAR then
            --LOG('Unassigning Radar Unit '..tostring(unit.UnitId))
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
            local gridSearch = math.floor(unit.Blueprint.Intel.RadarRadius / self.MapIntelGridSize)
            self:DisinfectGridPosition(intelPosition, gridSearch, 'Radar', 'IntelCoverage', false, unit)
        elseif unit.Blueprint.CategoriesHash.SONAR then
            --LOG('Unassigning Sonar Unit '..tostring(unit.UnitId))
            if unit.zoneid then
                local zone = aiBrain.Zones.Land.zones[unit.zoneid]
                if zone.intelassignment.SonarUnits then
                    for c, b in zone.intelassignment.SonarUnits do
                        if b == unit then
                            --RNGLOG('Found Sonar that was covering zone '..k..' removing')
                            RNGREMOVE(zone.intelassignment.SonarUnits, c)
                        end
                    end
                    if zone.intelassignment.SonarCoverage and table.empty(zone.intelassignment.SonarUnits) then
                        --RNGLOG('No Sonars in range for zone '..k..' setting radar coverage to false')
                        zone.intelassignment.SonarCoverage = false
                    end
                end
            end
            local gridSearch = math.floor(unit.Blueprint.Intel.SonarRadius / self.MapIntelGridSize)
            self:DisinfectGridPosition(intelPosition, gridSearch, 'Sonar', 'IntelCoverage', false, unit)
        end
    end,

    ZoneIsIntelStale = function(self, zone, time, layer)
        local cells = self.ZoneToGridMap[layer][zone.id]
        if not cells then
            return false
        end
        local staleCount = 0
        local total = 0
    
        for _, cell in cells do
            total = total + 1
    
            local stale = false
    
            if not cell.IntelCoverage or cell.IntelCoverage == false then
                stale = true
            end
    
            if not cell.LastScouted or (time - cell.LastScouted > 90) then
                stale = true
            end
    
            if stale then
                staleCount = staleCount + 1
            end
        end
    
        -- If more than 50% of the zone is stale, mark the whole zone as stale
        return staleCount / total > 0.5
    end,

    IsZoneSafeToScout = function(self, currentTime, zone, layer)
        if zone.status == 'Allied' or zone.status == 'Unoccupied' or (zone.status == 'Contested' and zone.enemyantisurfacethreat == 0) then
            if zone.enemystartdata then
                for _, v in zone.enemystartdata do
                    if v.startdistance < 100 then
                        if GetThreatAtPosition(self.Brain, zone.pos, 0, true, 'StructuresNotMex') > 0 then
                            return false
                        end
                    end
                end
            end
            --[[
            -- Not implementing this yet as it needs more refinement
            if zone.status ~= 'Allied' and self:ZoneIsIntelStale(zone, currentTime, layer) then
                return false
            end
            ]]
            return true
        end
        return false
    end,

    GetDefensiveCurveZones = function(self, zonesTable, baseZoneID, safeZones)

        local aiBrain = self.Brain
        local currentTime = GetGameTimeSeconds()
        -- Step 1: Find all safe zones reachable from baseZoneID if safeZones not provided
        if not safeZones then
            safeZones = {}
            local queue = { baseZoneID }
            safeZones[baseZoneID] = true
    
            while table.getn(queue) > 0 do
                local current = table.remove(queue, 1)
                local zoneData = zonesTable[current]
                if zoneData then
                    for _, neighborID in ipairs(zoneData.edges) do
                        if not safeZones[neighborID.zone.id] and self:IsZoneSafeToScout(currentTime, neighborID.zone, 'Land') then
                            safeZones[neighborID.zone.id] = true
                            table.insert(queue, neighborID.zone.id)
                        end
                    end
                end
            end
        end
        --LOG('Safe zones now has '..tostring(table.getn(safeZones))..' zones')
    
        -- Step 2: Find all zones adjacent to safeZones that are NOT safe
        local defensiveCurveZones = {}
    
        for safeZoneID, _ in pairs(safeZones) do
            local zoneData = zonesTable[safeZoneID]
            if zoneData then
                for _, neighborID in ipairs(zoneData.edges) do
                    if not self:IsZoneSafeToScout(currentTime, neighborID.zone, 'Land') then
                        defensiveCurveZones[safeZoneID] = true
                        break  -- we only need one unsafe neighbor to qualify this zone
                    end
                end
            end
        end
    
        -- Convert defensiveCurveZones from keys to list
        local defensiveCurveList = {}
        for zoneID,_ in pairs(defensiveCurveZones) do
            table.insert(defensiveCurveList, zoneID)
        end
    
        return defensiveCurveList
    end,

    TacticalIntelCheck = function(self)
        coroutine.yield(300)
        local aiBrain = self.Brain
        while aiBrain.Status ~= "Defeat" do
            --LOG('Units Stats')
            --LOG(tostring(repr(self.UnitStats)))
            --LOG(tostring(repr(self.EnemyPerformance)))
            coroutine.yield(35)
            self:ForkThread(self.AdaptiveProductionThread, 'AirTransport')
            coroutine.yield(1)
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
            coroutine.yield(1)
            self:ForkThread(self.AdaptiveProductionThread, 'TacticalMissileDefense')
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

    ZoneTransportRequirementCheck = function(self)
        -- Sets a flag to determine is a transport should be required as early as possible

        self:WaitForZoneInitialization()
        self:WaitForNavmeshGeneration()
        local aiBrain = self.Brain
        while not self.MapIntelStats.ScoutLocationsBuilt do
            LOG('*AI:RNG NavalAttackCheck is waiting for ScoutLocations to be built')
            coroutine.yield(20)
        end
        coroutine.yield(Random(5,20))
        local Zones = {
            'Land'
        }
        local scenarioMapSizeX, scenarioMapSizeZ = GetMapSize()
        local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
        local mapSizeX, mapSizeZ

        if not playableArea then
            mapSizeX = scenarioMapSizeX
            mapSizeZ = scenarioMapSizeZ
        else
            mapSizeX = playableArea[3]
            mapSizeZ = playableArea[4]
        end
        local startPos = aiBrain.BrainIntel.StartPos
        local unpathableZones = 0
        local mapDimension = math.max(mapSizeX, mapSizeZ)
        local expansionSize = math.min((mapDimension * 0.7), 384)
        --LOG('Expansion size '..tostring(expansionSize))
        for _, v in Zones do
            for _, v1 in aiBrain.Zones[v].zones do
                if not NavUtils.CanPathTo('Amphibious', startPos, v1.pos) then
                    local rx = startPos[1] - v1.pos[1]
                    local rz = startPos[3] - v1.pos[3]
                    local zoneDist = rx * rx + rz * rz
                    if zoneDist < (expansionSize * expansionSize) then
                        unpathableZones = unpathableZones + 1
                    end
                end
            end
        end
        --LOG('Best Armies are set')
        --LOG('Unpathable Expansion Zone Count = '..tostring(unpathableZones))
        self.UnpathableExpansionZoneCount = unpathableZones
        if unpathableZones > 0 then
            self.InitialTransportRequested = true
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
        self:ForkThread(self.CalculatePlayerSlot)
        local maximumResourceValue = 0
        local Zones = {
            'Land',
            'Naval',
            'Air'
        }
        local myIndex = aiBrain:GetArmyIndex()
        local myResourceCount = 0
        local expansionSize = math.min((aiBrain.MapDimension / 2), 180)
        for _, v in Zones do
            for _, v1 in aiBrain.Zones[v].zones do
                v1.label = self:ZoneSetLabelAssignment(v, v1.pos)
                v1.amphiblabel = self:ZoneSetLabelAssignment('Amphibious', v1.pos)
                if v1.resourcevalue > maximumResourceValue then
                    maximumResourceValue = v1.resourcevalue
                end
                v1.teamvalue = self:GetTeamDistanceValue(v1.pos, teamAveragePositions)
                local enemyStartData, allyStartData = self:SetEnemyPositionAngleAssignment(v1)
                v1.enemystartdata = {}
                for startIndex, startValue in enemyStartData do
                    v1.enemystartdata[startIndex] = { startangle = startValue.startangle, startdistance = startValue.startdistance}
                end
                v1.allystartdata = {}
                for startIndex, startValue in allyStartData do
                    v1.allystartdata[startIndex] = { startangle = startValue.startangle, startdistance = startValue.startdistance}
                end
                v1.bestarmy = self:ZoneSetBestArmy(v1)
                if v == 'Land' and v1.bestarmy == myIndex and v1.teamvalue >= 1.0 then
                    myResourceCount = myResourceCount + v1.resourcevalue
                end
            end
        end
        --LOG('Best Armies are set')
        local absoluteFloorMass = 5
        local optimalCeilingMass = 14
        local clampedMass = math.max(absoluteFloorMass, math.min(myResourceCount, optimalCeilingMass))
        
        -- Calculate base linear starvation factor (0.0 = Rich, 1.0 = Starved)
        local starvationFactor = (optimalCeilingMass - clampedMass) / (optimalCeilingMass - absoluteFloorMass)
        
        -- 3. Calculate game format brakes to prolong map contest in 1v1 and 2v2
        local numAllies = 0
        local numOpponents = 0
        
        for _, brain in ArmyBrains do
            local armyIndex = brain:GetArmyIndex()
            if IsEnemy(myIndex, armyIndex) then
                numOpponents = numOpponents + 1
            elseif IsAlly(myIndex, armyIndex) and armyIndex ~= myIndex then
                numAllies = numAllies + 1
            end
        end
        
        local formatBrake = 1.0
        
        -- A 1v1 game has exactly 0 allies and 1 opponent
        if numAllies == 0 and numOpponents == 1 then
            formatBrake = 0.70 -- True 1v1 match: Dampen upgrade spend to enforce early map control pressure
        -- A 2v2 game has exactly 1 ally and 2 opponents
        elseif numAllies == 1 and numOpponents == 2 then
            formatBrake = 0.85 -- True 2v2 match: Maintain higher unit output for early expansion protection
        end
        
        -- 4. Apply final calibrated spend scaling
        local maxAdditionalSpend = 0.35
        local dynamicSpendBonus = starvationFactor * maxAdditionalSpend * formatBrake

        --LOG('aiBrain.EconomyUpgradeSpendDefault at start of game is '..tostring(aiBrain.EconomyUpgradeSpendDefault)..' for player '..tostring(aiBrain.Nickname))
        aiBrain.EconomyUpgradeSpendDefault = aiBrain.EconomyUpgradeSpendDefault + dynamicSpendBonus
        --LOG('RNG AI: EconomyUpgradeSpendDefault adjusted to ' .. tostring(aiBrain.EconomyUpgradeSpendDefault) .. ' (StarvationFactor: ' .. tostring(starvationFactor) .. ', FormatBrake: ' .. tostring(formatBrake) .. ', DynamicSpendBonus: ' .. tostring(dynamicSpendBonus) .. ' for player '..tostring(aiBrain.Nickname)..')')
        
        -- Retain legacy flag support for external modules if necessary
        if starvationFactor >= 0.65 then
            aiBrain.LowResourceMapProfile = true
        end
    end,

    MonitorEnemyThreatOnBaseLabels = function(self)
        self:WaitForZoneInitialization()
        self:WaitForNavmeshGeneration()
        local aiBrain = self.Brain
        while not self.MapIntelStats.ScoutLocationsBuilt do
            LOG('*AI:RNG NavalAttackCheck is waiting for ScoutLocations to be built')
            coroutine.yield(20)
        end
        coroutine.yield(Random(5,20))
        local sm = import('/mods/RNGAI/lua/StructureManagement/StructureManager.lua').GetStructureManager(aiBrain)
        while aiBrain.Status ~= "Defeat" do
            coroutine.yield(35)
            local labelsTable = {}
            local smFactories = sm.Factories
            local hasNavalProduction = smFactories.NAVAL[1].Total > 0 or smFactories.NAVAL[2].Total > 0 or smFactories.NAVAL[3].Total > 0
            if hasNavalProduction then
                for k, v in aiBrain.BuilderManagers do
                    if v.FactoryManager and v.FactoryManager.LocationActive then
                        if v.Layer ~= 'Water' and not labelsTable[v.Label] then
                            labelsTable[v.Label] = {}
                            for i=self.MapIntelGridXMin, self.MapIntelGridXMax do
                                for j=self.MapIntelGridZMin, self.MapIntelGridZMax do
                                    if self.MapIntelGrid[i][j] then
                                        local gridCell = self.MapIntelGrid[i][j]
                                        if gridCell.LandLabel == v.Label then
                                            if not labelsTable[v.Label].LandThreat then
                                                labelsTable[v.Label].LandThreat = 0
                                            end
                                            if gridCell.IMAPHistoricalThreat['Land'] then
                                                labelsTable[v.Label].LandThreat = labelsTable[v.Label].LandThreat + gridCell.IMAPHistoricalThreat['Land']
                                            end
                                        end

                                    end
                                end
                            end
                        end
                    end
                end
                --LOG('This is the base label threat')
                local enemyThreatPresent = false
                for k, v in labelsTable do
                    if v.LandThreat then
                        local selfFriendlySurfaceThreat = aiBrain.GraphZones[k].FriendlySurfaceDirectFireThreat
                        if v.LandThreat and v.LandThreat > 0 and selfFriendlySurfaceThreat and v.LandThreat * 1.5 > selfFriendlySurfaceThreat then
                            enemyThreatPresent = true
                        end
                    end
                    --LOG('Label is '..tostring(k))
                    --LOG('Land threat is '..tostring(v.LandThreat))
                end
                if enemyThreatPresent then
                    self.NavalFocusSafe = false
                else
                    self.NavalFocusSafe = true
                end
                --LOG('Is enemy threat present '..tostring(enemyThreatPresent))
            end
        end
    end,

    GenerateZonePathDistanceCache = function(self)
        self:WaitForZoneInitialization()
        self:WaitForNavmeshGeneration()
        coroutine.yield(Random(5, 20))
    
        -- Check if already generated
        if RNGAIGLOBALS.ZoneDistanceCacheGenerated then
            return
        end
        RNGAIGLOBALS.ZoneDistanceCacheGenerated = true
    
        RNGAIGLOBALS.ZoneDistanceCache = RNGAIGLOBALS.ZoneDistanceCache or {}
        local aiBrain = self.Brain
        local Zones = { 'Land', 'Naval' }
    
        for _, layer in Zones do
            local zoneSet = aiBrain.Zones[layer].zones
            RNGAIGLOBALS.ZoneDistanceCache[layer] = {}
            local navLayer = (layer == 'Naval') and 'Water' or layer
    
            for _, fromZone in zoneSet do
                local fromID = fromZone.id
                RNGAIGLOBALS.ZoneDistanceCache[layer][fromID] = {}
    
                for _, toZone in zoneSet do
                    local toID = toZone.id
                    if fromID ~= toID then
                        if NavUtils.CanPathTo(navLayer, fromZone.pos, toZone.pos) then
                            local _, _, distance = NavUtils.PathTo(navLayer, fromZone.pos, toZone.pos)
                            RNGAIGLOBALS.ZoneDistanceCache[layer][fromID][toID] = distance or false
                        end
                    end
                end
            end
        end
        --LOG('ZoneDistanceCache is generated land entries are '..tostring(repr(RNGAIGLOBALS.ZoneDistanceCache.Land)))
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
        local function ProjectOntoVector(point, origin, direction)
            local vec = {point[1] - origin[1], point[2] - origin[2], point[3] - origin[3]}
            -- Dot product of vec and normalized direction vector
            local dot = vec[1]*direction[1] + vec[2]*direction[2] + vec[3]*direction[3]
            return dot
        end
        local furthestPlayer = false
        local closestPlayer = false
        local aiBrain = self.Brain
        local selfIndex = aiBrain:GetArmyIndex()
        local teamReference = aiBrain.TeamReference
        coroutine.yield(selfIndex)
        if not RNGAIGLOBALS.PlayerRoles[teamReference] then
            RNGAIGLOBALS.PlayerRoles[teamReference] = {}
        end
        if aiBrain.BrainIntel.AllyCount > 2 and aiBrain.EnemyIntel.EnemyCount > 0 then
            local closestDistance
            local selfDistanceToTeammates
            
            local teamAveragePositions = self:GetTeamAveragePositions()
            local teamEnemyAveragePosition
            local teamAllyAveragePosition
            if teamAveragePositions['Enemy'].x and teamAveragePositions['Enemy'].z then
                teamEnemyAveragePosition = {teamAveragePositions['Enemy'].x,GetSurfaceHeight(teamAveragePositions['Enemy'].x, teamAveragePositions['Enemy'].z), teamAveragePositions['Enemy'].z}
            end
            if teamAveragePositions['Ally'].x and teamAveragePositions['Ally'].z then
                teamAllyAveragePosition = {teamAveragePositions['Ally'].x,GetSurfaceHeight(teamAveragePositions['Ally'].x, teamAveragePositions['Ally'].z), teamAveragePositions['Ally'].z}
            end
            local selfStartPos = aiBrain.BrainIntel.StartPos
            local direction = RUtils.NormalizeVector({teamEnemyAveragePosition[1] - teamAllyAveragePosition[1], 0, teamEnemyAveragePosition[3] - teamAllyAveragePosition[3]})
            local projections = {}
            local minProjection
            local maxProjection
            local relativeThreshold = 0.2  -- 20%
            
            for _, v in aiBrain.BrainIntel.AllyStartLocations do
                local proj = ProjectOntoVector(v.Position, teamEnemyAveragePosition, direction)
                --LOG('Projection for player index '..tostring(v.Index)..' is '..tostring(proj))
                if not minProjection or proj < minProjection then
                    minProjection = proj
                end
                if not maxProjection or proj > maxProjection then
                    maxProjection = proj
                end
                table.insert(projections, {player=v.Index, proj=proj})
            end
            --LOG('Player Name '..tostring(aiBrain.Nickname))
            table.sort(projections, function(a,b) return a.proj < b.proj end)
            local backPlayer = projections[1].player
            local frontPlayer = projections[table.getn(projections)].player
            --LOG('Checking back player '..tostring(backPlayer)..' vs selfIndex '..tostring(selfIndex))
            --LOG('Checking front player '..tostring(frontPlayer)..' vs selfIndex '..tostring(selfIndex))
            local spread = maxProjection - minProjection
            if spread > 0 then
                local backGap = projections[2].proj - projections[1].proj
                local tableLength = table.getn(projections)
                local frontGap = projections[tableLength].proj - projections[tableLength-1].proj
                --LOG('backGap '..tostring(backGap)..' spread * relativeThreshold '..tostring(spread * relativeThreshold))
                --LOG('frontGap '..tostring(frontGap)..' spread * relativeThreshold '..tostring(spread * relativeThreshold))
                if backGap > spread * relativeThreshold then
                    if backPlayer == selfIndex then
                        --LOG(projections[1].player .. " is significantly behind the rest!")
                        local airRestricted = false
                        if not table.empty(ScenarioInfo.Options.RestrictedCategories) then
                            for _, v in ScenarioInfo.Options.RestrictedCategories do
                                if v == "AIR" or string.find(v, "T3_AIR") then
                                    airRestricted = true
                                    break
                                end
                            end
                        end
                        if not airRestricted then
                            if not aiBrain.BrainIntel.PlayerRole.ExperimentalPlayer then
                                local alreadySelected = false
                                for _, v in RNGAIGLOBALS.PlayerRoles[teamReference] do
                                    if v == 'AirPlayer' then
                                        alreadySelected = true
                                        break
                                    end
                                end
                                if not alreadySelected then
                                    furthestPlayer = true
                                    aiBrain.BrainIntel.PlayerRole.AirPlayer = true
                                    aiBrain.BrainIntel.PlayerStrategy.T3AirRush = true
                                    RNGAIGLOBALS.PlayerRoles[teamReference][selfIndex] = 'AirPlayer'
                                    aiBrain:EvaluateDefaultProductionRatios()
                                    return
                                end
                            end
                        end
                    end

                end
                if frontGap > spread * relativeThreshold then
                    if frontPlayer == selfIndex then
                        -- assign SpamPlayer role
                        if not aiBrain.BrainIntel.PlayerRole.ExperimentalPlayer then
                            local alreadySelected = false
                            for _, v in RNGAIGLOBALS.PlayerRoles[teamReference] do
                                if v == 'SpamPlayer' then
                                    alreadySelected = true
                                    break
                                end
                            end
                            if not alreadySelected then
                                aiBrain.BrainIntel.PlayerRole.SpamPlayer = true
                                RNGAIGLOBALS.PlayerRoles[teamReference][selfIndex] = 'SpamPlayer'
                                self:ForkThread(self.SpamTriggerDurationThread, 420)
                                return
                            end
                        end
                    end
                end
            else
                --LOG("Team is tightly packed; no real spread.")
            end
            if not aiBrain.BrainIntel.PlayerRole.AirPlayer and not aiBrain.BrainIntel.PlayerRole.SpamPlayer and (aiBrain.MapSize > 10 and aiBrain.MapWaterRatio > 0.35 or aiBrain.MapSize <= 10 and aiBrain.MapWaterRatio > 0.60) then
                local navalRestricted = false
                if not table.empty(ScenarioInfo.Options.RestrictedCategories) then
                    for _, v in ScenarioInfo.Options.RestrictedCategories do
                        if v == "NAVAL" then
                            navalRestricted = true
                            break
                        end
                    end
                end
                if not navalRestricted then
                    local navalPlayer
                    local alreadySelected = false
                    for _, v in RNGAIGLOBALS.PlayerRoles[teamReference] do
                        if v == 'NavalPlayer' then
                            --LOG('Naval Player already exist in team '..tostring(repr(RNGAIGLOBALS.PlayerRoles[teamReference])))
                            alreadySelected = true
                            break
                        end
                    end
                    if not alreadySelected then
                        if aiBrain.BrainIntel.NavalBaseLabels and aiBrain.BrainIntel.NavalBaseLabelCount > 0 then
                            -- Check if any enemy start location has a matching water label
                            for _, b in aiBrain.EnemyIntel.EnemyStartLocations do
                                for label, data in aiBrain.BrainIntel.NavalBaseLabels do
                                    if b.WaterLabels[label] and data.State == "Confirmed" then
                                        navalPlayer = true
                                        break
                                    end
                                end
                                if navalPlayer then break end
                            end
            
                            if navalPlayer then
                                aiBrain.BrainIntel.PlayerRole.NavalPlayer = true
                                RNGAIGLOBALS.PlayerRoles[teamReference][selfIndex] = 'NavalPlayer'
                                aiBrain:EvaluateDefaultProductionRatios()
                                return
                            end
                        end
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
                        RNGAIGLOBALS.PlayerRoles[teamReference][selfIndex] = 'SpamPlayer'
                        self:ForkThread(self.SpamTriggerDurationThread, 360)
                    end
                end
            end
        end
    end,

    SpamTriggerDurationThread = function(self, timer)
        -- This function just runs a timed thread for a more spammy approach with some bail outs along the way.
        local aiBrain = self.Brain
        local cancelSpam = false
        local startTime = GetGameTimeSeconds()
        while not cancelSpam do
            coroutine.yield(50)
            if GetGameTimeSeconds() - startTime > timer then
                cancelSpam = true
            end
        end
        aiBrain.BrainIntel.PlayerRole.SpamPlayer = false
        aiBrain:EvaluateDefaultProductionRatios()
    end,

    GetTeamAveragePositions = function(self)
        local aiBrain = self.Brain
        local teamTable = {}
        if aiBrain.BrainIntel.AllyCount > 0 then
            teamTable['Ally'] = RUtils.CalculateAveragePosition(aiBrain.BrainIntel.AllyStartLocations)
        end
        if aiBrain.EnemyIntel.EnemyCount > 0 then
            teamTable['Enemy'] = RUtils.CalculateAveragePosition(aiBrain.EnemyIntel.EnemyStartLocations)
        end
        return teamTable
    end,


    GetHistoricalThreatInRings = function(self, gridX, gridZ, threatType, ringCount)
        local intelGrid = self.MapIntelGrid
        local totalThreat = 0
        for x = math.max(self.MapIntelGridXMin, gridX - ringCount), math.min(self.MapIntelGridXMax, gridX + ringCount) do
            for z = math.max(self.MapIntelGridZMin, gridZ - ringCount), math.min(self.MapIntelGridZMax, gridZ + ringCount) do
                totalThreat = totalThreat + self.MapIntelGrid[x][z].IMAPHistoricalThreat[threatType]
            end
        end
        return totalThreat
    end,

    IntelGridThread = function(self, aiBrain)
        while not self.MapIntelGrid do
            coroutine.yield(30)
        end
        local aiBrain = self.Brain
        local threatDecayRate = 10
        while aiBrain.Status ~= "Defeat" do
            coroutine.yield(20)
            local intelCoverage = 0
            local mapOwnership = 0
            local mustScoutPresent = false
            local coveredByRadarCount = 0
            local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()        
            local realMapSizeX = playableArea[3] - playableArea[1]
            local realMapSizeZ = playableArea[4] - playableArea[2]
            local recommendedAirScouts = math.floor((realMapSizeX + realMapSizeZ) / 250)
            self.ZoneIMAPThreat = {}
            local threatSamples = {}
            local totalAAThreat = 0
            local totalCells = 0
            for i=self.MapIntelGridXMin, self.MapIntelGridXMax do
                local time = GetGameTimeSeconds()
                for k=self.MapIntelGridZMin, self.MapIntelGridZMax do
                    local cell = self.MapIntelGrid[i][k]
                    if cell.Enabled then
                        if cell.MustScout and (not cell.ScoutAssigned or cell.ScoutAssigned.Dead) then
                            --RNGLOG('mustScoutPresent in '..i..k)
                            --RNGLOG(repr(cell))
                            mustScoutPresent = true
                        end
                        if cell.RecentScoutDeaths > 0 and cell.RecentScoutDeathTime then
                            if time - cell.RecentScoutDeathTime > 240 then
                                --LOG('Reset scout death time, number of scout deaths was '..tostring(cell.RecentScoutDeaths))
                                cell.RecentScoutDeaths = 0
                                cell.RecentScoutDeathTime = 0
                            end
                        end
                        if cell.Enabled and not cell.Water then
                            cell.TimeScouted = time - cell.LastScouted
                            if cell.IntelCoverage or (cell.ScoutPriority > 0 and cell.TimeScouted ~= 0 and cell.TimeScouted < 120) then
                                intelCoverage = intelCoverage + 1
                            end
                        end
                        local unitsToRemove = {}
                        if not table.empty(cell.EnemyUnits) then
                            for c,b in cell.EnemyUnits do
                                if (b.object and b.object.Dead) then
                                    table.insert(unitsToRemove, c)
                                elseif time-b.time>120 or (time-b.time>15 and GetNumUnitsAroundPoint(aiBrain,categories.MOBILE,b.Position,20,'Ally')>3) then
                                    cell.EnemyUnits[c].recent=false
                                    if time-b.time>300 then
                                        table.insert(unitsToRemove, c)
                                    end
                                end
                            end
                        end
                        for _, c in unitsToRemove do
                            cell.EnemyUnits[c]=nil
                        end
                        local secondsSinceThreatUpdate = time - cell.LastThreatUpdate
                        local threatDecayAmount = threatDecayRate * secondsSinceThreatUpdate
                        cell.IMAPHistoricalThreat.AntiAir = math.max(0, cell.IMAPHistoricalThreat.AntiAir - threatDecayAmount)
                        cell.IMAPHistoricalThreat.Naval = math.max(0, cell.IMAPHistoricalThreat.Naval - threatDecayAmount)
                        cell.IMAPHistoricalThreat.Air = math.max(0, cell.IMAPHistoricalThreat.Air - threatDecayAmount)
                        cell.IMAPHistoricalThreat.Land = math.max(0, cell.IMAPHistoricalThreat.Land - threatDecayAmount)
                        if cell.LandZoneID then
                            if time - 30 > cell.LastThreatUpdate then
                                if not self.ZoneIMAPThreat[cell.LandZoneID] then
                                    self.ZoneIMAPThreat[cell.LandZoneID] = {}
                                end
                                if not self.ZoneIMAPThreat[cell.LandZoneID].Air then
                                    self.ZoneIMAPThreat[cell.LandZoneID].Air = 0
                                end
                                self.ZoneIMAPThreat[cell.LandZoneID].Air = self.ZoneIMAPThreat[cell.LandZoneID].Air + (cell.IMAPCurrentThreat['Air'] or 0)
                            end
                        end
                        if cell.IMAPHistoricalThreat.AntiAir > 0 then
                            local dist = cell.DistanceToMain
                            local aaThreat = cell.IMAPHistoricalThreat.AntiAir
                            table.insert(threatSamples, {dist = dist, threat = aaThreat})
                            totalAAThreat = totalAAThreat + aaThreat
                        end
                        local cellStatus = aiBrain.GridPresence:GetInferredStatus(cell.Position)
                        if cellStatus == 'Allied' then
                            mapOwnership = mapOwnership + 1
                        end
                        totalCells = totalCells + 1
                    end
                end
                coroutine.yield(1)
            end
            local radarCoverageRatio = 0.0
            if totalCells > 0 then
                radarCoverageRatio = intelCoverage / totalCells
            end
            -- AA Safe Radius Calculation
            table.sort(threatSamples, function(a, b) return a.dist < b.dist end)
            local cumulativeThreat = 0
            local safeRadius = 0
            local centroid, teamSpreadDist, isCohesive = RUtils.CalculateTeamCentroidAndSpread(aiBrain, aiBrain.BrainIntel.AllyStartLocations)
            local searchOrigin
            local minimumSafeRadius = 0
            local minSafeDistance = aiBrain.OperatingAreas['BaseRestrictedArea'] * 1.5

            if isCohesive and centroid then
                -- CASE A: Team is Clustered
                -- Center logic on the group. Enforce coverage of all bases.
                searchOrigin = {centroid.x, 0, centroid.z}
                minimumSafeRadius = math.max(minSafeDistance, teamSpreadDist + 150)
                
                self.TeamCenterPosition = centroid
            else
                -- CASE B: Team is Split (Line/Corners)
                -- Center logic on Self to avoid overextending into the gap.
                searchOrigin = aiBrain.BrainIntel.StartPos
                minimumSafeRadius = minSafeDistance
                
                self.TeamCenterPosition = nil -- Flags fighters to use Local Radius logic
            end
            local ownAA = aiBrain.BrainIntel.SelfThreat.AntiAirNow + aiBrain.BrainIntel.SelfThreat.AllyAntiAirThreat
            local enemyAA = aiBrain.EnemyIntel.EnemyThreatCurrent.AntiAir
            local safetyFactor = math.max(1, enemyAA / math.max(ownAA, 1))  -- >1 if enemy stronger
            

            for _, sample in threatSamples do
                cumulativeThreat = cumulativeThreat + sample.threat
                local threatPerKm = cumulativeThreat / sample.dist

                -- Tunable: how much AA threat is acceptable per distance band
                if threatPerKm * safetyFactor < 0.4 then
                    safeRadius = sample.dist
                else
                    break
                end
            end
            safeRadius = math.max(minimumSafeRadius, math.min(safeRadius, aiBrain.OperatingAreas['BaseEnemyArea']))
            self.SafeAirThreatRadius = safeRadius
            --LOG('Safe Radius on calculation is '..tostring(safeRadius))

            -- End AA Safe Radius Calcuation
            local radarCoverageDeficiency = 1.0 - radarCoverageRatio
            local stealthDetected = (self.EnemyIntel and self.EnemyIntel.StealthUnitsDetected) or false
            local stealthMultiplier = stealthDetected and 1.5 or 1.0
            local airScoutDemand
            if mustScoutPresent then
                airScoutDemand = recommendedAirScouts
            else
                airScoutDemand = math.ceil(recommendedAirScouts * radarCoverageDeficiency * stealthMultiplier)
            end
            airScoutDemand = math.max(1, airScoutDemand)
            if self.amanager.Demand.Air.T1.scout then
                self.amanager.Demand.Air.T1.scout = airScoutDemand
            end
            if self.amanager.Demand.Air.T3.scout then
                self.amanager.Demand.Air.T3.scout = airScoutDemand
            end
            self:ProcessFrontlineRadarRequests(aiBrain)
            self.MapIntelStats.IntelCoverage = intelCoverage / (self.MapIntelGridXRes * self.MapIntelGridZRes) * 100
            self.MapIntelStats.MustScoutArea = mustScoutPresent
            aiBrain.BrainIntel.MapOwnership = mapOwnership / aiBrain.IntelManager.CellCount * 100
            --LOG('Current Map ownership '..aiBrain.BrainIntel.MapOwnership)
        end
    end,

    IntelGridSetGraph = function(self, locationType, x, z, startPos, endPos)
        if (not startPos) or (not endPos) then
            WARN('IntelGridSetGraph start or end position was nil')
            --LOG('startPos '..tostring(repr(startPos))..' end Pos '..tostring(repr(endPos)))
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
        elseif type == 'Sonar' then
            self.MapIntelGrid[gridX][gridZ].Sonars[unit.EntityId] = {}
            self.MapIntelGrid[gridX][gridZ].Sonars[unit.EntityId] = unit
            self.MapIntelGrid[gridX][gridZ].SonarCoverage = true
            --aiBrain:ForkThread(self.DrawInfection, self.MapIntelGrid[gridX][gridZ].Position)
            gridsSet = gridsSet + 1
        end
        for x = math.max(self.MapIntelGridXMin, gridX - gridSize), math.min(self.MapIntelGridXMax, gridX + gridSize), 1 do
            for z = math.max(self.MapIntelGridZMin, gridZ - gridSize), math.min(self.MapIntelGridZMax, gridZ + gridSize), 1 do
                self.MapIntelGrid[x][z][property] = value
                if type == 'Radar' then
                    self.MapIntelGrid[x][z].Radars[unit.EntityId] = {}
                    self.MapIntelGrid[x][z].Radars[unit.EntityId] = unit
                elseif type == 'Sonar' then
                    self.MapIntelGrid[x][z].Sonars[unit.EntityId] = {}
                    self.MapIntelGrid[x][z].Sonars[unit.EntityId] = unit
                end
                --aiBrain:ForkThread(self.DrawInfection, self.MapIntelGrid[x][z].Position)
                gridsSet = gridsSet + 1
            end
        end
        --RNGLOG('Number of grids set '..gridsSet..'with property '..property..' with the value '..repr(value))
    end,

    DisinfectGridPosition = function (self, position, gridSize, intelType, property, value, unit)
        local gridX, gridZ = self:GetIntelGrid(position)
        local gridsSet = 0
        local intelRadius
        local needSort = false
        --RNGLOG('Disinfecting Grid Positions, grid size is '..gridSize)
        if intelType == 'Radar' then
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
        elseif intelType == 'Sonar' then
            self.MapIntelGrid[gridX][gridZ].Radars[unit.EntityId] = nil
            needSort = true
            local sonarCoverage = false
            for k, v in self.MapIntelGrid[gridX][gridZ].Sonars do
                if v and not v.Dead then
                    sonarCoverage = true
                    break
                end
            end
            if needSort then
                self.MapIntelGrid[gridX][gridZ].Sonars = self:RebuildTable(self.MapIntelGrid[gridX][gridZ].Sonars)
            end
            if not sonarCoverage then
                self.MapIntelGrid[gridX][gridZ][property] = value
            end
            --aiBrain:ForkThread(self.DrawInfection, self.MapIntelGrid[gridX][gridZ].Position)
            gridsSet = gridsSet + 1
        end
        for x = math.max(1, gridX - gridSize), math.min(self.MapIntelGridXRes, gridX + gridSize) do
            for z = math.max(1, gridZ - gridSize), math.min(self.MapIntelGridZRes, gridZ + gridSize) do
                if intelType == 'Radar' then
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
                elseif intelType == 'Sonar' then
                    --RNGLOG('Check for another sonar and then confirm radius is same or greater?')
                    local sonarCoverage = false
                    for k, v in self.MapIntelGrid[x][z].Sonars do
                        if v and not v.Dead then
                            --RNGLOG('Found another sonar, dont set this grid to false')
                            sonarCoverage = true
                            break
                        end
                    end
                    if not sonarCoverage then
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
            local gridx = math.floor((Position[1] - playableArea[1]) / self.MapIntelGridSize) + 1
            local gridy = math.floor((Position[3] - playableArea[2]) / self.MapIntelGridSize) + 1
            --RNGLOG('Grid return X '..gridx..' Y '..gridy)
            --RNGLOG('Unit Position '..repr(Position))
            --RNGLOG('Attempt to return grid location '..repr(self.MapIntelGrid[gridx][gridy]))
    
            return math.floor( (Position[1] - playableArea[1]) / self.MapIntelGridSize) + self.MapIntelGridXMin, math.floor((Position[3] - playableArea[2]) / self.MapIntelGridSize) + self.MapIntelGridZMin
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
            local friendlyAir = aiBrain.BrainIntel.SelfThreat.AirNow + (aiBrain.BrainIntel.SelfThreat.AllyAirThreat / 2)
            local enemyAir = aiBrain.EnemyIntel.EnemyThreatCurrent.Air
            local enemyNaval = aiBrain.EnemyIntel.EnemyThreatCurrent.Naval
        
            -- Base air-vs-air risk logic
            if friendlyAir > enemyAir * 1.5 then
                minThreatRisk = 80
            elseif friendlyAir > enemyAir then
                minThreatRisk = 50
            elseif friendlyAir * 1.5 > enemyAir then
                minThreatRisk = 25
            else
                minThreatRisk = 5
            end
            --LOG('friendlyAir for '..tostring(aiBrain.Nickname)..' : '..tostring(friendlyAir))
            --LOG('enemyAir for '..tostring(aiBrain.Nickname)..' : '..tostring(enemyAir))
            --LOG('enemyNaval for '..tostring(aiBrain.Nickname)..' : '..tostring(enemyNaval))
        
            -- === Performance Adjustment ===
            local airVsNavalEff = self.EnemyPerformance.Air.KillsAgainst.Naval / math.max(self.EnemyPerformance.Air.TotalMassKilled, 1)
            local navalVsNavalEff = self.EnemyPerformance.Air.KillsAgainst.Naval / math.max(self.EnemyPerformance.Naval.TotalMassKilled, 1)
            local navalVsAirEff = self.EnemyPerformance.Naval.KillsAgainst.Air / math.max(self.EnemyPerformance.Naval.TotalMassKilled, 1)
            --LOG('Enemy Air Kills against Stats '..tostring(repr(self.EnemyPerformance.Air.KillsAgainst)))
            --LOG('Air.KillsAgainst.Naval '..tostring(aiBrain.Nickname)..' : '..tostring(self.EnemyPerformance.Air.KillsAgainst.Naval))
            --LOG('Air.KillsAgainst.Naval '..tostring(aiBrain.Nickname)..' : '..tostring(self.EnemyPerformance.Air.KillsAgainst.Naval))
            --LOG('Naval.KillsAgainst.Air '..tostring(aiBrain.Nickname)..' : '..tostring(self.EnemyPerformance.Naval.KillsAgainst.Air))

            --LOG('airVsNavalEff for '..tostring(aiBrain.Nickname)..' : '..tostring(airVsNavalEff))
            --LOG('navalVsNavalEff '..tostring(aiBrain.Nickname)..' : '..tostring(navalVsNavalEff))
            --LOG('navalVsAirEff '..tostring(aiBrain.Nickname)..' : '..tostring(navalVsAirEff))
        
            -- Amplify perceived risk if air dominance is lethal to navy
            if airVsNavalEff > 0.25 then  -- e.g. 25%+ of air’s damage is against navy
                minThreatRisk = minThreatRisk * (1 + airVsNavalEff)
            end
        
            -- If enemy navy is performing well, boost anti-naval urgency
            if navalVsNavalEff > 0.2 then
                minThreatRisk = minThreatRisk + 10
            end
        
            -- If enemy navy is good at killing air units (AA heavy), reduce willingness to use torp bombers
            if navalVsAirEff > 0.15 then
                minThreatRisk = minThreatRisk * 0.6
            end
        
            minThreatRisk = math.min(100, math.max(5, minThreatRisk))
            --LOG('AI : '..tostring(aiBrain.Nickname))
            local gridSize = self.MapIntelGridSize
            local desiredRadius = 180
            local rings = math.ceil(desiredRadius / gridSize)
            local baseX, baseZ = self:GetIntelGrid(aiBrain.BrainIntel.StartPos)

            local localAirThreat = self:GetHistoricalThreatInRings(baseX, baseZ, 'Air', rings)
            --LOG('localAirThreat '..tostring(aiBrain.Nickname)..' : '..tostring(localAirThreat))

            local localFactor = 1.0

            if enemyAir > 0 then
                localFactor = math.min(2.0, localAirThreat / enemyAir)
            end

            -- You can even scale minThreatRisk slightly:
            minThreatRisk = minThreatRisk * math.min(1.5, 0.5 + localFactor)
            --LOG('minThreatRisk for '..tostring(aiBrain.Nickname)..' is '..tostring(minThreatRisk))
            
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
                if aiBrain.EnemyIntel.Experimental then
                    for _, v in aiBrain.EnemyIntel.Experimental do
                        if v.object and not v.object.Dead then
                            local unitCats = v.object.Blueprint.CategoriesHash
                            if unitCats.NAVAL then
                                local targetPos = v.object:GetPosition()
                                local gridX, gridZ = self:GetIntelGrid(targetPos)
                                desiredStrikeDamage = desiredStrikeDamage + (150 * 120)
                                table.insert( potentialStrikes, { GridID = {GridX = gridX, GridZ = gridZ}, Position = targetPos, Type = 'AntiNavy'} )
                            elseif unitCats.AMPHIBIOUS then
                                local targetPos = v.object:GetPosition()
                                if RUtils.PositionInWater(targetPos) then
                                    local gridX, gridZ = self:GetIntelGrid(targetPos)
                                    desiredStrikeDamage = desiredStrikeDamage + (150 * 120)
                                    table.insert( potentialStrikes, { GridID = {GridX = gridX, GridZ = gridZ}, Position = targetPos, Type = 'AntiNavy'} )
                                end
                            end
                        end
                    end
                end
                if aiBrain.CDRUnit and not aiBrain.CDRUnit.Dead and aiBrain.CDRUnit['rngdata'].EnemyNavalPresent then
                    local acuPos = aiBrain.CDRUnit.Position
                    local gridX, gridZ = self:GetIntelGrid(acuPos)
                    table.insert( potentialStrikes, { GridID = {GridX = gridX, GridZ = gridZ}, Position = acuPos, Type = 'AntiNavy'} )
                    desiredStrikeDamage = desiredStrikeDamage + 4000

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
                                        if v.Layer == 'Water' and v.ZoneID then
                                            local zoneID = v.ZoneID
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
        if productiontype == 'AirTransport' then
            if self.UnpathableExpansionZoneCount > 0 and self.InitialTransportRequested then
                local t1TransportsBuilt = aiBrain:GetBlueprintStat("Units_History", categories.AIR * categories.TRANSPORTFOCUS * categories.TECH1)
                if t1TransportsBuilt < 1 then
                    --LOG('Transport Required has been set to 1')
                    aiBrain.amanager.Demand.Air.T1.transport = 1
                end
            end
        elseif productiontype == 'AirAntiSurface' then
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
            local acuSnipe = false
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
                    if aiBrain.amanager.Current['Air']['T2']['gunship'] < 3 then
                        aiBrain.amanager.Demand.Air.T2.gunship = 3
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
                    if aiBrain.amanager.Current['Air']['T3']['gunship'] < 4 then
                        aiBrain.amanager.Demand.Air.T3.gunship = 4
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
                    aiBrain:RequestEngineerAssistFocus('IntelManager', 'SnipeACU', 150, 60, true)
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
                end
                if disableBomb and aiBrain.amanager.Demand.Air.T2.bomber > 0 then
                    --RNGLOG('No t2 bomber missions, disable demand')
                    aiBrain.amanager.Demand.Air.T2.bomber = 0
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
                    aiBrain:RequestEngineerAssistFocus('IntelManager', 'SnipeACU', 150, 60, true)
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
                if not self.StrategyFlags.EarlyT3Built then
                    local t3DirectBuilt = aiBrain:GetBlueprintStat("Units_History", categories.DIRECTFIRE * categories.LAND * categories.TECH3)
                    --LOG('Early t3 strategy flag is live, build some t3 bots, current built is '..tostring(t3DirectBuilt))
                    if t3DirectBuilt < 3 then
                        aiBrain.amanager.Demand.Land.T3.tank = 3
                    else
                        --LOG('T3 production is met, disable build')
                        self.StrategyFlags.EarlyT3Built = true
                        aiBrain.amanager.Demand.Land.T3.tank = 0
                    end
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
                --LOG('Number of T2 torpedo bombers wanted '..count)
                if acuSnipe then
                    --RNGLOG('Setting acuSnipe mission for air torpedo units')
                    --RNGLOG('Set game time '..gameTime)
                    aiBrain.TacticalMonitor.TacticalMissions.ACUSnipe[acuIndex]['AIRANTINAVY'] = { GameTime = gameTime, CountRequired = count }
                    aiBrain.amanager.Demand.Air.T2.torpedo = count
                    aiBrain.amanager.Demand.Air.T3.torpedo = math.ceil(count / 2)
                    aiBrain:RequestEngineerAssistFocus('IntelManager', 'SnipeACU', 150, 60, true)
                end
                if navalAttack then
                    --LOG(aiBrain.Nickname)
                    --LOG('numer of navalAttack torps required '..count)
                    aiBrain.amanager.Demand.Air.T2.torpedo = count
                    aiBrain.amanager.Demand.Air.T3.torpedo = math.ceil(count / 2)
                end
                --LOG('Current T2 torp demand for '..tostring(aiBrain.Nickname)..' is '..tostring(aiBrain.amanager.Demand.Air.T2.torpedo))
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
                end
            end
            --RNGLOG('Current T2 torpcount is '..aiBrain.amanager.Demand.Air.T2.torpedo)
        elseif productiontype == 'MobileAntiAir' then
            -- Tunables
            local airThreatToUnitRatio = 9       
            local threatToUnitConversion = 5     
            local airThreatMultiplier 
            local cellSize = aiBrain.BrainIntel.IMAPConfig.IMAPSize
            local maxDistanceSq = 250 * 250      
            local globalEnemyAirSurface = aiBrain.EnemyIntel.EnemyThreatCurrent.AirSurface or 0

            local armyEscortRatio = 0

            if globalEnemyAirSurface > 25 then
                armyEscortRatio = 0.08
                if globalEnemyAirSurface > 150 then
                    armyEscortRatio = 0.15
                end
            end

            -- Tables
            local baseCandidates = {}
            local zoneRequirements = {}

            -- NEW: A ledger to prevent double-counting shared neighbors
            local enemyThreatClaims = {} 

            -- 1. RESET DEMAND
            for baseName, baseData in aiBrain.BuilderManagers do
                if aiBrain.amanager.Demand.Bases[baseName] then
                    local demand = aiBrain.amanager.Demand.Bases[baseName].Land
                    demand.T1.aa = 0; demand.T2.aa = 0; demand.T3.aa = 0
                end
            end

            -- 2. IDENTIFY CANDIDATES
            for baseName, baseData in aiBrain.BuilderManagers do
                if baseData.FactoryManager and baseData.FactoryManager.LocationActive and baseData.Layer ~= 'Water' then
                    
                    local baseZone = aiBrain.Zones.Land.zones[baseData.ZoneID]
                    
                    local highestTier = 0
                    if baseData.FactoryManager:GetNumCategoryFactories(categories.FACTORY * categories.LAND * categories.TECH3) > 0 then
                        highestTier = 3
                    elseif baseData.FactoryManager:GetNumCategoryFactories(categories.FACTORY * categories.LAND * categories.TECH2) > 0 then
                        highestTier = 2
                    elseif baseData.FactoryManager:GetNumCategoryFactories(categories.FACTORY * categories.LAND * categories.TECH1) > 0 then
                        highestTier = 1
                    end

                    local localAAThreat = baseZone.friendlylandantiairthreat or 0
                    
                    if highestTier > 0 then
                        table.insert(baseCandidates, {
                            ID = baseName,
                            Base = baseData,
                            Tier = highestTier,
                            NumFactories = baseData.FactoryManager:GetNumCategoryFactories(categories.FACTORY * categories.LAND),
                            Position = baseData.Position,
                            LocalAABuffer = localAAThreat
                        })
                    end
                end
            end

            -- 3. IDENTIFY DEMAND
            -- To make the claiming fair, we ideally want to process High Value zones first.
            -- However, for performance, a standard loop with the claim system is usually sufficient.
            local minThreatThreshold = 2.5
            for zoneID, zoneData in aiBrain.Zones.Land.zones do

                
                local isDefensiveZone = (zoneData.teamvalue and zoneData.teamvalue > 0)
                local myLandThreat = zoneData.friendlylandthreat or 0
                local isActiveFront = (myLandThreat > 30) 
                
                if isDefensiveZone or isActiveFront then
                    
                    -- A. DIRECT THREAT (Always unique to this zone, no claiming needed)
                    local directAirThreat = zoneData.enemyairthreat or 0
                    
                    -- B. PROXIMITY THREAT (Shared Neighbors)
                    local adjacentAirThreat = 0
                    if zoneData.edges then
                        for _, edge in ipairs(zoneData.edges) do
                            local adjZone = edge.zone
                            
                            -- Only check if there is actual threat
                            if adjZone and adjZone.enemyairthreat and adjZone.enemyairthreat > 0 then
                                
                                local totalThreatInNeighbor = adjZone.enemyairthreat
                                local alreadyClaimed = enemyThreatClaims[adjZone.id] or 0
                                
                                -- Determine how much of this threat is "fresh" and unaccounted for
                                local claimableThreat = math.max(0, totalThreatInNeighbor - alreadyClaimed)
                                
                                if claimableThreat > 0 then
                                    adjacentAirThreat = adjacentAirThreat + claimableThreat
                                    
                                    -- Mark this threat as claimed so the next zone doesn't count it
                                    enemyThreatClaims[adjZone.id] = alreadyClaimed + claimableThreat
                                end
                            end
                        end
                    end
                    
                    local totalReactiveThreat = directAirThreat + adjacentAirThreat
                    --LOG('ZoneID '..tostring(zoneID)..' directAirThreat is '..tostring(directAirThreat)..' adjacentAirThreat is '..tostring(adjacentAirThreat))

                    -- C. PROACTIVE THREAT
                    local umbrellaThreatNeed = 0
                    if isActiveFront then
                        umbrellaThreatNeed = myLandThreat * armyEscortRatio
                    end

                    -- D. DETERMINE FINAL REQUIREMENT
                    local finalThreatNeed = math.max(totalReactiveThreat, umbrellaThreatNeed)
                    
                    if finalThreatNeed > minThreatThreshold then 
                        local rawUnitsNeeded = math.ceil(finalThreatNeed / airThreatToUnitRatio)
                        
                        local cap = 60 
                        if isDefensiveZone and not isActiveFront then
                            cap = math.max(10, (zoneData.teamvalue or 1) * 8)
                        end
                        rawUnitsNeeded = math.min(rawUnitsNeeded, cap)

                        -- E. GAP ANALYSIS
                        local currentFriendlyAA = zoneData.friendlylandantiairthreat or 0
                        local unitsAlreadyThere = math.ceil(currentFriendlyAA / threatToUnitConversion)
                        
                        local netNeeded = math.max(0, rawUnitsNeeded - unitsAlreadyThere)
                        --LOG('netNeeded is '..tostring(netNeeded))

                        if netNeeded > 0 then
                            table.insert(zoneRequirements, {
                                ZoneID = zoneID,
                                Needed = netNeeded,
                                Position = zoneData.pos,
                                Threat = totalReactiveThreat + (umbrellaThreatNeed * 0.5) 
                            })
                        end
                    end
                end
            end

            -- Sort Zones by Threat
            table.sort(zoneRequirements, function(a,b) return a.Threat > b.Threat end)

            -- 4. ALLOCATION (Match Candidates to Zones)
            for _, req in ipairs(zoneRequirements) do
                
                local potentialBases = {}

                for _, cand in ipairs(baseCandidates) do
                    if cand.Base.PathableZones.Zones[req.ZoneID] then
                        local dx = cand.Position[1] - req.Position[1]
                        local dz = cand.Position[3] - req.Position[3]
                        local distSq = dx*dx + dz*dz
                        
                        if distSq < maxDistanceSq then
                            cand.DistSq = distSq
                            table.insert(potentialBases, cand)
                        end
                    end
                end

                for _, cand in ipairs(potentialBases) do
                    local bucket = math.floor(math.sqrt(cand.DistSq) / cellSize)
                    local distPenalty = bucket * 25 
                    local tierScore = cand.Tier * 50
                    cand.Score = tierScore - distPenalty
                end

                table.sort(potentialBases, function(a,b) return a.Score > b.Score end)

                local remainingNeed = req.Needed

                for _, bestBase in ipairs(potentialBases) do
                    if remainingNeed <= 0 then break end

                    local techEfficiency = 1
                    if bestBase.Tier == 3 then techEfficiency = 4
                    elseif bestBase.Tier == 2 then techEfficiency = 2 end

                    local baseCapacity = bestBase.NumFactories * 4 
                    local allocation = math.min(remainingNeed, baseCapacity)
                    
                    -- Buffer Logic
                    local bufferValue = math.ceil(bestBase.LocalAABuffer / threatToUnitConversion)
                    local filledByBuffer = math.min(allocation, bufferValue)
                    
                    if filledByBuffer > 0 then
                        bestBase.LocalAABuffer = math.max(0, bestBase.LocalAABuffer - (filledByBuffer * threatToUnitConversion))
                        allocation = allocation - filledByBuffer
                        remainingNeed = remainingNeed - filledByBuffer
                    end

                    if allocation > 0 then
                        local actualBuildCount = math.ceil(allocation / techEfficiency)
                        local demandTable = aiBrain.amanager.Demand.Bases[bestBase.ID].Land
                        
                        if bestBase.Tier == 3 then
                            demandTable.T3.aa = (demandTable.T3.aa or 0) + actualBuildCount
                            --LOG('demandTable.T3.aa is '..tostring(demandTable.T3.aa)..' for base '..tostring(bestBase.ID))
                        elseif bestBase.Tier == 2 then
                            demandTable.T2.aa = (demandTable.T2.aa or 0) + actualBuildCount
                            --LOG('demandTable.T2.aa is '..tostring(demandTable.T2.aa)..' for base '..tostring(bestBase.ID))
                        else
                            demandTable.T1.aa = (demandTable.T1.aa or 0) + actualBuildCount
                            --LOG('demandTable.T1.aa is '..tostring(demandTable.T1.aa)..' for base '..tostring(bestBase.ID))
                        end
                        
                        remainingNeed = remainingNeed - (actualBuildCount * techEfficiency)
                    end
                end
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
                    local unitCats = v.object.Blueprint.CategoriesHash
                    if unitCats.ORBITALSYSTEM then
                        experimentalNovaxCount = experimentalNovaxCount + 1
                    elseif unitCats.ARTILLERY and unitCats.STRUCTURE or unitCats.url0401 then
                        experimentalArtilleryCount = experimentalArtilleryCount + 1
                    elseif unitCats.NUKE then
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
            if not aiBrain.CDRUnit['rngdata']['RadarCoverage'] then
                local cdrPos = aiBrain.CDRUnit.Position
                if cdrPos then
                    local gridX, gridZ = self:GetIntelGrid(aiBrain.CDRUnit.Position)
                end
            end
            if aiBrain.smanager.Current.Structure['intel']['T3']['Optics'] < 1 and aiBrain.EconomyOverTimeCurrent.EnergyIncome > 1000 and aiBrain:GetEconomyIncome('ENERGY') > 1000 
            and aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime > 500 and aiBrain:GetEconomyTrend('ENERGY') > 500 then
                aiBrain.smanager.Demand.Structure.intel.Optics = 1
            else
                aiBrain.smanager.Demand.Structure.intel.Optics = 0
            end
            --LOG('Check intelstructure game time is '..tostring(gameTime)..' and T2RadarAllowed is '..tostring(self.StrategyFlags.T2RadarAllowed))
            if self.StrategyFlags.T2RadarAllowed == false and gameTime > 360 then
                self.StrategyFlags.T2RadarAllowed = true
            end
            if self.StrategyFlags.T3RadarAllowed == false and gameTime > 720 then
                self.StrategyFlags.T3RadarAllowed = true
            end
            if self.StrategyFlags.T2SonarAllowed == false and gameTime > 360 then
                self.StrategyFlags.T2SonarAllowed = true
            end
            if self.StrategyFlags.T3SonarAllowed == false and gameTime > 720 then
                self.StrategyFlags.T3SonarAllowed = true
            end

        elseif productiontype == 'LandIndirectFire' then
            local threatDillutionRatio = 15
            local threatDefenseDillutionRatio = 8
            local threatToUnitConversion = 5
            local enemyDefenseThreat = aiBrain.EnemyIntel.EnemyThreatCurrent.DefenseSurface or 0
            local cellSize = aiBrain.BrainIntel.IMAPConfig.IMAPSize
        
            local baseCandidates = {}
            local zoneAllocations = {}
            -- Quick reset demand 
            for k, v in aiBrain.BuilderManagers do
                if aiBrain.amanager.Demand.Bases[k] then
                    local b = aiBrain.amanager.Demand.Bases[k].Land
                    b.T1.arty = 0
                    b.T2.mml = 0
                    b.T3.arty = 0
                    b.T3.mml = 0
                end
            end
        
            for k, v in aiBrain.BuilderManagers do
                local totalEnemyStructureThreat = 0
                local allocationRequired = false
        
                if v.FactoryManager and v.FactoryManager.LocationActive then
                    local baseZone = aiBrain.Zones.Land.zones[v.ZoneID]
                    local closestDefenseClusterDistance
                    local closestDefenseClusterThreat = 0
                    local closestDefenseClusterZone
                    local closestDefenseClusterLayer
                    local closestZoneLandDistance
                    local closestZoneLandThreat = 0
                    local localEnemyLandThreat = baseZone.enemylandthreat or 0
                    local localFriendlyDirectFireThreat = baseZone.friendlydirectfireantisurfacethreat or 0
                    local localFriendlyIndirectFireThreat = baseZone.friendlyindirectfireantisurfacethreat or 0
        
                    if v.PathableZones and v.PathableZones.PathableLandZoneCount > 0 and not table.empty(v.PathableZones.Zones) then

                        for _, cluster in aiBrain.EnemyIntel.DirectorData.DefenseCluster do
                            local dx = cluster.aggx - v.Position[1]
                            local dz = cluster.aggz - v.Position[3]
                            local clusterDist = dx * dx + dz * dz
                            if not closestDefenseClusterDistance or clusterDist < closestDefenseClusterDistance then
                                allocationRequired = true
                                closestDefenseClusterDistance = clusterDist
                                closestDefenseClusterThreat = cluster.AntiSurfaceThreat
                                if cluster.ZoneID and cluster.FireBaseLayer then
                                    closestDefenseClusterZone = cluster.ZoneID
                                    closestDefenseClusterLayer = cluster.FireBaseLayer
                                else
                                    closestDefenseClusterZone = self:GetClosestZone(aiBrain, nil, {cluster.aggx,0,cluster.aggz}, nil, nil, nil)
                                    if RUtils.PositionInWater({cluster.aggx,0,cluster.aggz}) then
                                        closestDefenseClusterLayer = 'Naval'
                                    else
                                        closestDefenseClusterLayer = 'Land'
                                    end
                                end
                            end
                        end
        
                        for _, z in v.PathableZones.Zones do
                            if z.PathType == 'Land' and z.ZoneID then
                                local zone = aiBrain.Zones.Land.zones[z.ZoneID]
                                if zone.enemystructurethreat > 0 then
                                    local dx = v.Position[1] - zone.pos[1]
                                    local dz = v.Position[3] - zone.pos[3]
                                    local posDist = dx * dx + dz * dz
                                    if posDist < 262144 then
                                        allocationRequired = true
                                        local structureThreat = zone.enemystructurethreat or 0
                                        local structureDefenseThreat = zone.enemydefensestructurethreat or 0

                                        if structureDefenseThreat <= 0 then
                                            structureThreat = math.min(structureThreat * 0.1, 30)
                                        else
                                            structureThreat = structureDefenseThreat + (structureThreat * 0.05)
                                        end
                                        if not closestZoneLandDistance or posDist < closestZoneLandDistance then
                                            closestZoneLandThreat = zone.enemylandthreat
                                            closestZoneLandDistance = posDist
                                        end
        
                                        -- Group by zoneID for later allocation
                                        local clusterDefenseThreat = 0

                                        if closestDefenseClusterZone == z.ZoneID and closestDefenseClusterLayer == 'Land' then
                                            clusterDefenseThreat = closestDefenseClusterThreat
                                        end


                                        if not zoneAllocations[z.ZoneID] then
                                            --LOG('Modified structure threat for zone '..tostring(z.ZoneID)..' is '..tostring(structureThreat))
                                            zoneAllocations[z.ZoneID] = {
                                                TotalStructureThreat = structureThreat,
                                                DefenseClusterThreat = clusterDefenseThreat,
                                                DefenseStructureThreat = structureDefenseThreat,
                                                Bases = {}
                                            }
                                        end
                                    end
                                end
                            end
                        end
                    end
        
                    -- Build candidate data for this base
                    if allocationRequired then
                        local highestTier = 0
                        if v.FactoryManager:GetNumCategoryFactories(categories.FACTORY * categories.LAND * categories.TECH3) > 0 then
                            highestTier = 3
                        elseif v.FactoryManager:GetNumCategoryFactories(categories.FACTORY * categories.LAND * categories.TECH2) > 0 then
                            highestTier = 2
                        elseif v.FactoryManager:GetNumCategoryFactories(categories.FACTORY * categories.LAND * categories.TECH1) > 0 then
                            highestTier = 1
                        end
                        local localDefensePenalty = 0
                        local safetyThreshold = localFriendlyDirectFireThreat * 0.8
                        
                
                        if localEnemyLandThreat > safetyThreshold then
                            local threatOverage = localEnemyLandThreat - safetyThreshold
                            if localEnemyLandThreat > localFriendlyDirectFireThreat then
                                localDefensePenalty = threatOverage * 4.0
                            else
                                localDefensePenalty = threatOverage * 1.5
                            end
                            --LOG('Base '..tostring(k)..' unstable. Enemy: '..localEnemyLandThreat..' FriendlyDF: '..localFriendlyDirectFireThreat..' Penalty: '..localDefensePenalty)
                        end
        
                        table.insert(baseCandidates, {
                            ID = k,
                            Base = v,
                            Tier = highestTier,
                            NumFactories = v.FactoryManager:GetNumCategoryFactories(categories.FACTORY * categories.LAND),
                            ClosestZoneDistance = closestZoneLandDistance or 99999999,
                            ClosestClusterDistance = closestDefenseClusterDistance or 99999999,
                            LocalDefensePenalty = localDefensePenalty,
                            LocalIndirectThreatBuffer = localFriendlyIndirectFireThreat
                        })
                    end
                end
            end
        
            -- Stage 2: Allocate per zone based on reachability
            local globalEnemyLand = aiBrain.EnemyIntel.EnemyThreatCurrent.Land or 0
            local globalSelfLand = aiBrain.BrainIntel.SelfThreat.LandNow or 0
            local landPowerRatio = 1.0
            if globalEnemyLand > 0 then
                landPowerRatio = math.min(globalSelfLand / globalEnemyLand, 1.2)
            else
                landPowerRatio = (globalSelfLand > 0) and 1.2 or 0.5
            end
            
            -- Stage 2: Allocate per zone
            for zoneID, zoneData in zoneAllocations do
                local originalTotalNeeded = math.min(math.max(1, zoneData.TotalStructureThreat / threatDillutionRatio), 25)
                if zoneData.DefenseClusterThreat > 0 then
                    originalTotalNeeded = originalTotalNeeded + math.max(2, zoneData.DefenseClusterThreat / threatDefenseDillutionRatio)
                end
                
                local totalNeeded = originalTotalNeeded
                local targetZone = aiBrain.Zones.Land.zones[zoneID]
                
                -- Coverage Check
                local localCoverageThreat = targetZone.friendlyindirectfireantisurfacethreat or 0
                if targetZone.edges then
                    for _, adjEdge in ipairs(targetZone.edges) do
                        localCoverageThreat = localCoverageThreat + (adjEdge.zone.friendlyindirectfireantisurfacethreat or 0)
                    end
                end
                
                if localCoverageThreat > 0 then
                    local unitsAlreadyFulfilling = math.ceil(localCoverageThreat / threatToUnitConversion) 
                    totalNeeded = math.max(0, totalNeeded - unitsAlreadyFulfilling)
                end
                
                -- Land Power Dampener
                totalNeeded = totalNeeded * landPowerRatio
                
                -- No-Defense Ceiling
                local zoneDefenseThreat = targetZone.enemydefensestructurethreat or 0
                if zoneDefenseThreat <= 0 then
                    local MaxHarassmentUnits = 2
                    if landPowerRatio < 0.8 then MaxHarassmentUnits = 1 end
                    totalNeeded = math.min(totalNeeded, MaxHarassmentUnits)
                end
            
                local remaining = math.ceil(totalNeeded)
                local candidates = {}
            
                -- Filter and Score
                for _, c in baseCandidates do
                    if c.Base.PathableZones.Zones[zoneID] then
                        -- Fix: Use linear distance for linear cell size buckets
                        local distance = math.sqrt(math.min(c.ClosestZoneDistance, c.ClosestClusterDistance))
                        local tierScore = (c.Tier * c.Tier) * 100
                        local capacityScore = math.sqrt(c.NumFactories) * 20
                        local bucket = math.floor(distance / cellSize) -- Fixed math here
                        local distancePenalty = bucket * 10
                        
                        c.Score = tierScore + capacityScore - distancePenalty - c.LocalDefensePenalty
                        table.insert(candidates, c)
                    end
                end
            
                table.sort(candidates, function(a,b) return a.Score > b.Score end)
            
                -- Stage 3: Distribution
                for _, c in candidates do
                    if remaining <= 0 then break end
            
                    local capacity = c.NumFactories * 3 
                    local localAllocation = math.min(capacity, remaining)
                    local unitsToBeMetByBase = math.ceil(localAllocation)
                    local finalAllocation = localAllocation
                    
                    -- Buffer Logic
                    if c.LocalIndirectThreatBuffer > 0 then
                        local unitsFromBuffer = math.ceil(c.LocalIndirectThreatBuffer / threatToUnitConversion) 
                        local bufferCovers = math.min(localAllocation, unitsFromBuffer)
                        finalAllocation = localAllocation - bufferCovers
                        c.LocalIndirectThreatBuffer = math.max(0, c.LocalIndirectThreatBuffer - (bufferCovers * threatToUnitConversion))
                    end
            
                    finalAllocation = math.ceil(finalAllocation)
                    remaining = remaining - unitsToBeMetByBase
                    --LOG('indirectFire finalAllocation is '..tostring(finalAllocation)..' for base is '..tostring(c.ID))
                    
                    if finalAllocation > 0 then
                        local baseDemand = aiBrain.amanager.Demand.Bases[c.ID].Land
                        if c.Tier == 3 then
                            baseDemand.T3.arty = baseDemand.T3.arty + finalAllocation
                            baseDemand.T3.mml = baseDemand.T3.mml + finalAllocation -- Removed 1.3x multiplier
                        elseif c.Tier == 2 then
                            baseDemand.T2.mml = baseDemand.T2.mml + finalAllocation -- Removed 1.3x multiplier
                        elseif c.Tier == 1 then
                            baseDemand.T1.arty = baseDemand.T1.arty + finalAllocation -- Removed 1.5x multiplier
                        end
                    end
                end
            end
        elseif productiontype == 'NavalAntiSurface' then
            if aiBrain.EnemyIntel.EnemyThreatCurrent.Air > 10 and (aiBrain.BrainIntel.SelfThreat.NavalNow + (aiBrain.BrainIntel.SelfThreat.AllyNavalThreat / 2)) > aiBrain.EnemyIntel.EnemyThreatCurrent.Naval * 0.7 
                and aiBrain.BrainIntel.SelfThreat.AirNow + (aiBrain.BrainIntel.SelfThreat.AllyAirThreat / 2) < aiBrain.EnemyIntel.EnemyThreatCurrent.Air then
                minThreatRisk = 60
            end
            if aiBrain.BrainIntel.SelfThreat.NavalNow + (aiBrain.BrainIntel.SelfThreat.AllyNavalThreat / 2) > aiBrain.EnemyIntel.EnemyThreatCurrent.Naval * 1.5 and aiBrain.EnemyIntel.MaxNavalStartRange <= 200 then
                minThreatRisk = 80
            end
            --LOG('Check NavalAntiSurface minThreatRisk '..tostring(minThreatRisk))
            --LOG('Self NavalNow '..tostring(aiBrain.BrainIntel.SelfThreat.NavalNow))
            --LOG('MapWaterRatio '..tostring(aiBrain.MapWaterRatio))
            local rangedThreatRequested = 0
            local antiairThreatRequested = 0
            local airAntiNavalThreatRatio = 0
            local navalAirDeathRatio = 0
            if minThreatRisk > 60 and aiBrain.BrainIntel.SelfThreat.NavalNow > 10 and aiBrain.MapWaterRatio > 0.20 then
                if aiBrain.EnemyIntel.DirectorData.Defense and not table.empty(aiBrain.EnemyIntel.DirectorData.Defense) then
                    for _, v in aiBrain.EnemyIntel.DirectorData.Defense do
                        rangedThreatRequested = v.Value and rangedThreatRequested + v.Value
                    end
                end
                if aiBrain.EnemyIntel.DirectorData.Energy and not table.empty(aiBrain.EnemyIntel.DirectorData.Energy) then
                    for _, v in aiBrain.EnemyIntel.DirectorData.Energy do
                        rangedThreatRequested = v.Value and rangedThreatRequested + v.Value
                    end
                end
                if aiBrain.EnemyIntel.DirectorData.Strategic and not table.empty(aiBrain.EnemyIntel.DirectorData.Strategic) then
                    for _, v in aiBrain.EnemyIntel.DirectorData.Strategic do
                        rangedThreatRequested = v.Value and rangedThreatRequested + v.Value
                    end
                end
                local cruiserRangeCount = 0
                --LOG('Naval markers '..tostring(table.getn(aiBrain.EnemyIntel.NavalMarkers)))
                if aiBrain.EnemyIntel.NavalMarkers and table.getn(aiBrain.EnemyIntel.NavalMarkers) > 0 then
                    for _, m in aiBrain.EnemyIntel.NavalMarkers do
                        if m.Distance and m.Distance <= 22500 then
                            cruiserRangeCount = cruiserRangeCount + 1
                        end
                    end
                    rangedThreatRequested = rangedThreatRequested + (math.floor(cruiserRangeCount / 3))
                    --LOG('Cruiser type threat requested '..tostring(threatRequested))
                end
            end
            if minThreatRisk > 0 and aiBrain.BrainIntel.SelfThreat.NavalNow > 10 and aiBrain.MapWaterRatio > 0.20 then
                local navalAAUrgency = aiBrain.EnemyIntel.EnemyThreatCurrent.AirAntiNavy or 0
                local teamAirThreat = aiBrain.BrainIntel.SelfThreat.AirNow + (aiBrain.BrainIntel.SelfThreat.AllyAirThreat / 2)
                navalAAUrgency = navalAAUrgency * math.min(1.5, teamAirThreat)
                local currentCruisers = self.Naval.T2.cruiser
                local currentCarriers = self.Naval.T3.carrier
                local currentAAValue = ((aiBrain.amanager.Current['Naval']['T2']['cruiser'] or 0) * 75) + ((aiBrain.amanager.Current['Naval']['T3']['carrier'] or 0) * 100)
                local enemyAirKillsMass = self.EnemyPerformance.Air.KillsAgainst.Naval
                local totalNavalKillsMass = self.EnemyPerformance.Naval.KillsAgainst.Naval
                navalAirDeathRatio = totalNavalKillsMass > 0 and (enemyAirKillsMass / totalNavalKillsMass) or 0
                airAntiNavalThreatRatio = navalAAUrgency / math.max(currentAAValue, 1)
                antiairThreatRequested = antiairThreatRequested + aiBrain.EnemyIntel.EnemyThreatCurrent.Air
                --LOG('airAntiNavalThreatRatio '..tostring(airAntiNavalThreatRatio))
                --LOG('navalAirDeathRatio '..tostring(navalAirDeathRatio))
            end
            --LOG('Naval antiair threat requested '..tostring(antiairThreatRequested))
            --LOG('ThreatRequested is '..tostring(threatRequested))
            if rangedThreatRequested > 1 or antiairThreatRequested > 0 then
                local disableMissileShip = true
                local disableNukeSub = true
                local disableCruiserShip = true
                local disableCarrier = true
                local missileShipMassKilled = aiBrain.IntelManager.UnitStats['MissileShip'].Kills.Mass
                local missileShipBuilt = aiBrain.IntelManager.UnitStats['MissileShip'].Built.Mass
                local nukeSubMassKilled = aiBrain.IntelManager.UnitStats['NukeSub'].Kills.Mass
                local nukeSubBuilt = aiBrain.IntelManager.UnitStats['NukeSub'].Built.Mass
                local cruiserMassKilled = aiBrain.IntelManager.UnitStats['Cruiser'].Kills.Mass
                local cruiserBuilt = aiBrain.IntelManager.UnitStats['Cruiser'].Built.Mass
                local carrierMassKilled = aiBrain.IntelManager.UnitStats['Carrier'].Kills.Mass
                local carrierBuilt = aiBrain.IntelManager.UnitStats['Carrier'].Built.Mass
                --LOG('Cruisers build mass '..tostring(cruiserBuilt))
                --LOG('Cruisers killed mass '..tostring(cruiserMassKilled))
                --LOG('Carriers build mass '..tostring(carrierBuilt))
                --LOG('Carriers killed mass '..tostring(carrierMassKilled))
                for k, v in aiBrain.BuilderManagers do
                    if v.Layer == 'Water' then
                        if v.FactoryManager and v.FactoryManager.LocationActive then
                            if rangedThreatRequested > 0 and v.FactoryManager:GetNumCategoryFactories(categories.FACTORY * categories.NAVAL * categories.TECH2 * (categories.UEF + categories.SERAPHIM)) > 0 then
                                --LOG('We have a T2 naval factory')
                                local maxCruisers = math.ceil(rangedThreatRequested / 1000)
                                --LOG('Max Cruisers being requested '..tostring(maxCruisers))
                                if cruiserBuilt < 1 or (cruiserMassKilled > 0 and cruiserBuilt > 0 and math.min(cruiserMassKilled / cruiserBuilt, 2) > 1.2) then
                                    --LOG('Current MissileShips + Demand '..tostring(aiBrain.amanager.Current['Naval']['T3']['missileship'] + aiBrain.amanager.Demand.Bases[k].Naval.T3.missileship))
                                    if maxCruisers > (aiBrain.amanager.Current['Naval']['T2']['cruiser'] + aiBrain.amanager.Demand.Bases[k].Naval.T3.missileship) then
                                        --LOG('Base '..tostring(k)..' requesting '..tostring(maxMissileShips)..' maxMissileShips')
                                        aiBrain.amanager.Demand.Bases[k].Naval.T2.cruiser = aiBrain.amanager.Current['Naval']['T2']['cruiser'] + 1
                                        disableCruiserShip = false
                                    end
                                end
                                --LOG('Intel Manage requesting '..tostring(indirectFireCount)..' T2 mml for base '..tostring(k))
                            end
                            if antiairThreatRequested > 0 and v.FactoryManager:GetNumCategoryFactories(categories.FACTORY * categories.NAVAL * categories.TECH2) > 0 then
                                local maxCruisers = math.max(1, antiairThreatRequested / 75)
                                --LOG('antiairThreatRequested is greater than zero, cruisers built '..tostring(cruiserBuilt)..' cruisers mass killed '..tostring(cruiserMassKilled)..' max cruisers '..tostring(maxCruisers))
                                if cruiserBuilt < 1 or (cruiserMassKilled > 0 and cruiserBuilt > 0 and math.min(cruiserMassKilled / cruiserBuilt, 2) > 1.2) or (airAntiNavalThreatRatio > 1.2  and navalAirDeathRatio > 0.5) then
                                    --LOG('Current Cruiser + Carrier Demand '..tostring(aiBrain.amanager.Current['Naval']['T2']['cruiser'] + aiBrain.amanager.Demand.Bases[k].Naval.T3.carrier))
                                    if maxCruisers > aiBrain.amanager.Demand.Bases[k].Naval.T2.cruiser and maxCruisers > (aiBrain.amanager.Current['Naval']['T2']['cruiser'] + aiBrain.amanager.Demand.Bases[k].Naval.T3.carrier) then
                                        --LOG('Base '..tostring(k)..' requesting '..tostring(maxCruisers)..' maxCruisers')
                                        aiBrain.amanager.Demand.Bases[k].Naval.T2.cruiser = aiBrain.amanager.Current['Naval']['T2']['cruiser'] + 1
                                        disableCruiserShip = false
                                    end
                                end
                            end
                            if rangedThreatRequested  > 30 and v.FactoryManager:GetNumCategoryFactories(categories.FACTORY * categories.NAVAL * categories.TECH3) > 0 then
                                local maxMissileShips = math.ceil(rangedThreatRequested  / 1000)
                                if missileShipBuilt < 1 or (missileShipMassKilled > 0 and missileShipBuilt > 0 and math.min(missileShipMassKilled / missileShipBuilt, 2) > 1.2) then
                                    --LOG('Current MissileShips + Demand '..tostring(aiBrain.amanager.Current['Naval']['T3']['missileship'] + aiBrain.amanager.Demand.Bases[k].Naval.T3.missileship))
                                    if maxMissileShips > (aiBrain.amanager.Current['Naval']['T3']['missileship'] + aiBrain.amanager.Demand.Bases[k].Naval.T3.missileship) then
                                        --LOG('Base '..tostring(k)..' requesting '..tostring(maxMissileShips)..' maxMissileShips')
                                        aiBrain.amanager.Demand.Bases[k].Naval.T3.missileship = aiBrain.amanager.Current['Naval']['T3']['missileship'] + 1
                                        disableMissileShip = false
                                    end
                                end
                                local maxNukeSubs = math.ceil(rangedThreatRequested  / 2000)
                                if nukeSubBuilt < 1 or (nukeSubMassKilled > 0 and nukeSubBuilt > 0 and math.min(nukeSubMassKilled / nukeSubBuilt, 2) > 1.2) then
                                    --LOG('Current NukeSub + Demand '..tostring(aiBrain.amanager.Current['Naval']['T3']['nukesub'] + aiBrain.amanager.Demand.Bases[k].Naval.T3.nukesub))
                                    if maxNukeSubs > (aiBrain.amanager.Current['Naval']['T3']['nukesub'] + aiBrain.amanager.Demand.Bases[k].Naval.T3.nukesub) then
                                        aiBrain.amanager.Demand.Bases[k].Naval.T3.nukesub = aiBrain.amanager.Current['Naval']['T3']['nukesub'] + 1
                                        --LOG('Base '..tostring(k)..' requesting '..tostring(maxNukeSubs)..' maxNukeSubs')
                                        disableNukeSub = false
                                    end
                                end
                            end
                            if antiairThreatRequested > 0 and v.FactoryManager:GetNumCategoryFactories(categories.FACTORY * categories.NAVAL * categories.TECH3 - categories.UEF) > 0 then
                                local maxCarriers = math.max(1, antiairThreatRequested / 100)
                                if carrierBuilt < 1 or (carrierMassKilled > 0 and carrierBuilt > 0 and math.min(carrierMassKilled / carrierBuilt, 2) > 1.2) or (airAntiNavalThreatRatio > 1.2  and navalAirDeathRatio > 0.5) then
                                    --LOG('Current carriers '..tostring(aiBrain.amanager.Current['Naval']['T3']['carrier']))
                                    if maxCarriers > aiBrain.amanager.Demand.Bases[k].Naval.T3.carrier and maxCarriers > (aiBrain.amanager.Current['Naval']['T3']['carrier']) then
                                        --LOG('Base '..tostring(k)..' requesting '..tostring(maxCarriers)..' maxCarriers')
                                        aiBrain.amanager.Demand.Bases[k].Naval.T3.carrier = aiBrain.amanager.Current['Naval']['T3']['carrier'] + 1
                                        disableCarrier = false
                                    end
                                end
                            end
                            if disableMissileShip then
                                aiBrain.amanager.Demand.Bases[k].Naval.T3.missileship = 0
                            end
                            if disableNukeSub then
                                aiBrain.amanager.Demand.Bases[k].Naval.T3.nukesub = 0
                            end
                            if disableCarrier then
                                aiBrain.amanager.Demand.Bases[k].Naval.T3.carrier = 0
                            end
                            if disableCruiserShip then
                                aiBrain.amanager.Demand.Bases[k].Naval.T2.cruiser = 0
                            end
                        end
                        --LOG('Current t2 cruiser demand for location is '..tostring(aiBrain.amanager.Demand.Bases[k].Naval.T2.cruiser))
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
        elseif productiontype == 'TacticalMissileDefense' then
            local silos = {}
            for i=self.MapIntelGridXMin, self.MapIntelGridXMax do
                for k=self.MapIntelGridZMin, self.MapIntelGridZMax do
                    if not RNGTableEmpty(self.MapIntelGrid[i][k].EnemyUnits) then
                        for k, v in self.MapIntelGrid[i][k].EnemyUnits do
                            if v.type == 'silo' and v.object and not v.object.Dead then
                                local unitMissileRange = StateUtils.GetUnitMaxWeaponRange(v.object)
                                local rangeTrigger = math.max(120, unitMissileRange)
                                table.insert(silos, {unitPos = v.object:GetPosition(), range = rangeTrigger})
                            end
                        end
                    end
                end
            end
            local landZones = aiBrain.Zones.Land.zones
            for _, zone in landZones do
                local enemySilos = 0
                local enemySiloAngle
                for _, s in silos do
                    local unitRange = (s.range * s.range) + 900
                    local sx = s.unitPos[1] - zone.pos[1]
                    local sz = s.unitPos[3] - zone.pos[3]
                    local posDist = sx * sx + sz * sz
                    if posDist < unitRange then
                        enemySilos = enemySilos + 1
                        if not enemySiloAngle then
                            enemySiloAngle = RUtils.GetAngleToPosition(zone.pos, s.unitPos)
                        end
                    end
                end
                zone.enemySilos = enemySilos
                if enemySiloAngle then
                    zone.enemySiloAngle = enemySiloAngle
                end
            end
        end
    end,

    FindIntelInRings = function(self, position, radarRange)
        local gridX, gridZ = self:GetIntelGrid(position)
        local cells = self.MapIntelGrid
    
        local cell = cells[gridX] and cells[gridX][gridZ]
        if not cell or not cell.Size then
            return "error"
        end
    
        local cellSizeX = cell.Size.sx
        local cellSizeZ = cell.Size.sz
        if not cellSizeX or not cellSizeZ then
            return "error"
        end
    
        -- Determine how many cells the radar range spans, round up to fully cover the area
        local rangeInCellsX = math.ceil(radarRange / cellSizeX)
        local rangeInCellsZ = math.ceil(radarRange / cellSizeZ)
    
        -- Search surrounding cells for any radar coverage
        for dx = -rangeInCellsX, rangeInCellsX do
            local column = cells[gridX + dx]
            if column then
                for dz = -rangeInCellsZ, rangeInCellsZ do
                    local neighborCell = column[gridZ + dz]
                    if neighborCell and neighborCell.IntelCoverage then
                        return neighborCell
                    end
                end
            end
        end
    
        -- No coverage found, can return nil or fallback cell
        return nil
    end,

    AssignEngineerToStructureRequestNearPosition = function(self, eng, position, radius, structureType)
        local radiusSq = radius * radius
        --LOG('Checking for an existing requests, current request count '..tostring(table.getn(self.StructureRequests)))
        if self.StructureRequests[structureType] then
            for _, v in self.StructureRequests[structureType] do
                if not v.Assigned then
                    local dx = position[1] - v.Position[1]
                    local dz = position[3] - v.Position[3]
                    local distSq = dx*dx + dz*dz
                    if distSq < radiusSq then
                        if not self:IsAssignedStructureRequestPresent(v.Position, radius, structureType) then
                            v.Assigned = true
                            v.AssignedTime = GetGameTimeSeconds()
                            v.AssignedEngineer = eng  -- or unit ID
                            return v.Position
                        end
                    end
                end
            end
        else
            WARN('AI-RNG: Invalid structure type passed to AssignEngineerToStructureRequestNearPosition, passed value was '..tostring(structureType))
        end
    end,

    IsExistingStructureRequestPresent = function(self, pos, radius, structureType)
        local rSq = radius * radius
        --LOG('IsExistingStructureRequestPresent, source position is '..tostring(repr(pos)))
        local currentGameTime = GetGameTimeSeconds()
        local requestTable = self.StructureRequests[structureType]
        if not requestTable then
            WARN('AI-RNG: Invalid structure type passed to IsExistingStructureRequestPresent, passed value was '..tostring(structureType))
            return false
        end
        local buildKeyMap = {
            RADAR = 'RadarBuild',
            TMD = 'TMDBuild',
            SMD = 'SMDBuild',
            TECH1POINTDEFENSE = 'T1PDBuild',
        }
        local key = buildKeyMap[structureType]
        if not key then
            WARN('AI-RNG: buildKeyMap missing entry for structure type '..tostring(structureType))
            return false
        end
        
        for i = table.getn(requestTable), 1, -1 do
            local data = requestTable[i]
            local ap = data.Position
            local dx = pos[1] - ap[1]
            local dz = pos[3] - ap[3]
            local distSq = dx * dx + dz * dz
            if distSq < rSq then
                invalidAssignment = false
                if data.Assigned then
                    local key = buildKeyMap[structureType]
                    local buildData = data.AssignedEngineer.PlatoonHandle.BuilderData
                    if not (buildData and buildData.Construction and buildData.Construction[key]) then
                        invalidAssignment = true
                    end
                    if not data.AssignedTime or data.AssignedTime + 120 < currentGameTime then
                        --LOG('Request was stale, time was '..tostring(data.AssignedTime)..' current time is '..tostring(currentGameTime))
                        invalidAssignment = true
                    end
                end
                if invalidAssignment then
                    --LOG('Removing invalid assignment')
                    table.remove(requestTable, i)
                else
                    return true
                end
            end
        end
        return false
    end,

    IsAssignedStructureRequestPresent = function(self, pos, radius, structureType)
        local rSq = radius * radius
        --LOG('IsExistingStructureRequestPresent, source position is '..tostring(repr(pos)))
        if self.StructureRequests[structureType] then
            for _, data in self.StructureRequests[structureType] do
                if data.Assigned then
                    local ap = data.Position
                    local dx = pos[1] - ap[1]
                    local dz = pos[3] - ap[3]
                    if dx*dx + dz*dz < rSq then
                        return true
                    end
                end
            end
        else
            WARN('AI-RNG: Invalid structure type passed to IsAssignedStructureRequestPresent, passed value was '..tostring(structureType))
        end
        return false
    end,

    RemoveFailedStructureRequest = function(self, unit, structureType)
        local keysToRemove = {}
        if self.StructureRequests[structureType] then
            for k, data in self.StructureRequests[structureType] do
                if data.Assigned and data.AssignedEngineer.EntityId == unit.EntityId then
                    table.insert(keysToRemove, k)
                end
            end
        else
            WARN('AI-RNG: Invalid structure type passed to IsAssignedStructureRequestPresent, passed value was '..tostring(structureType))
        end
        if not table.empty(keysToRemove) then
            for _, v in keysToRemove do
                --LOG('Removing request key on failed build '..tostring(v))
                self.StructureRequests[structureType][v] = nil
            end
            self.StructureRequests[structureType] = self:RebuildTable(self.StructureRequests[structureType])
            return true
        end
        return false
    end,

    FlushExistingStructureRequest = function(self, pos, radius, structureType)
        local rSq = radius * radius
        local keysToRemove = {}
        if self.StructureRequests[structureType] then
            for k, data in self.StructureRequests[structureType] do
                local ap = data.Position
                local dx = pos[1] - ap[1]
                local dz = pos[3] - ap[3]
                local distance = dx*dx + dz*dz
                if distance < rSq then
                    table.insert(keysToRemove, k)
                end
                if data.Assigned and data.AssignedEngineer and not data.AssignedEngineer.Dead then
                    if data.AssignedEngineer.AIPlatoonReference.ExitStateMachine then
                        --LOG('Aborting existing engineer')
                        data.AssignedEngineer.AIPlatoonReference:ExitStateMachine()
                    end
                end
            end
        else
            WARN('AI-RNG: Invalid structure type passed to FlushExistingStructureRequest, passed value was '..tostring(structureType))
        end
        if not table.empty(keysToRemove) then
            for _, v in keysToRemove do
                self.StructureRequests[structureType][v] = nil
            end
            self.StructureRequests[structureType] = self:RebuildTable(self.StructureRequests[structureType])
            return true
        end
        return false
    end,

    RequestStructureNearPosition = function(self, position, radius, structureType)
        local gridX, gridZ = self:GetIntelGrid(position)
        local zoneId
        if RUtils.PositionInWater(position) then
            zoneId = MAP:GetZoneID(position,self.Brain.Zones.Naval.index)
        else
            zoneId = MAP:GetZoneID(position,self.Brain.Zones.Land.index)
        end
        if gridZ and gridZ then
            if self.StructureRequests[structureType] then
                table.insert(self.StructureRequests[structureType], {
                    Position = position,
                    GridX = gridX,
                    GridZ = gridZ,
                    Assigned = false,
                    AssignedTime = nil,
                    AssignedEngineer = nil,
                    RequestedTime = GetGameTimeSeconds(),
                    ZoneID = zoneId,
                })
            else
                WARN('AI-RNG: Invalid structure type passed to RequestStructureNearPosition, passed value was '..tostring(structureType))
            end
        end
    end,

    StructureRequestThread = function(self)
        coroutine.yield(50)
        local aiBrain = self.Brain
        while aiBrain.Status ~= 'Defeat' do
            coroutine.yield(30)
            local numEnemyUnits = aiBrain.emanager.Nuke.T3
            if numEnemyUnits and numEnemyUnits > 0 then
                for _, builderManager in aiBrain.BuilderManagers do
                    local structureManager = aiBrain.StructureManager
                    if builderManager.ZoneID then
                        local structureTable = structureManager.ZoneStructures[builderManager.ZoneID]['EXTRACTOR']
                        local extractorIncome = 0
                        local numberOfExtractors = 0
                        if structureTable then
                            for _, v in structureTable do
                                if v and not v.Dead and v.GetProductionPerSecondMass then
                                    numberOfExtractors = numberOfExtractors + 1
                                    extractorIncome = extractorIncome + v:GetProductionPerSecondMass()
                                end
                            end
                        end
                        if extractorIncome > 24 * aiBrain.EcoManager.EcoMultiplier then
                            local engineerManager = builderManager.EngineerManager
                            local currentSMD = engineerManager:GetNumUnits('AntiNuke')
                            if currentSMD == 0 then
                                if not aiBrain.IntelManager:IsExistingStructureRequestPresent(engineerManager.Location, 45, 'SMD') then
                                    local queuedSmdCount = engineerManager:NumStructuresQueued('TECH3', { 'STRUCTURE', 'ANTIMISSILE', 'DEFENSE' })
                                    if queuedSmdCount == 0 then
                                        local beingBuiltSmd = engineerManager:NumStructuresBeingBuiltTechCategory('TECH3', { 'STRUCTURE', 'ANTIMISSILE', 'DEFENSE' })
                                        if beingBuiltSmd == 0 then
                                            aiBrain.IntelManager:RequestStructureNearPosition(engineerManager.Location, 45, 'SMD')
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end,

    AssignThreatToFactories = function(self, zoneLayerSet, layer)
        local distanceCache = RNGAIGLOBALS.ZoneDistanceCache[layer]
        if not distanceCache then
            WARN('ZoneDistanceCache missing for layer: ' .. (layer or 'nil'))
            return
        end
        local aiBrain = self.Brain
        --LOG('AssignThreatToFactories loop')
        -- First, collect all production zones
        local localIslandEnemyThreat = {}
        local productionZones = {}
        local totalBuildRate = 0
        local minHighValueThreat = 15
        local minLowValueThreat = 8
        local buildRateKey = (layer == 'Naval') and 'NavalBuildRate' or (layer == 'Air') and 'AirBuildRate' or 'LandBuildRate'
        local productionZoneCount = 0
        for zID, zData in pairs(zoneLayerSet) do
            if zData.label then
                localIslandEnemyThreat[zData.label] = (localIslandEnemyThreat[zData.label] or 0) + (zData.gridenemylandthreat or 0)
            end
            if zData.BuilderManager and zData.BuilderManager.FactoryManager and zData.BuilderManager.FactoryManager.LocationActive then
                totalBuildRate = totalBuildRate + (zData.BuilderManager.FactoryManager[buildRateKey] or 0)
                zData.BuilderManager.FactoryManager.ZoneThreatAssignment = 0
                zData.BuilderManager.FactoryManager.EconomicGravity = 0
                table.insert(productionZones, zData)
                productionZoneCount = productionZoneCount + 1
            end
        end
        local controlledZones, frontlineZones, zoneSecurityDepth, zonePathSecurity = self:ComputeContainmentState(productionZones, zoneLayerSet, layer)
        local aiStartPos = aiBrain.BrainIntel.StartPos
        local distancePropagationCap = 1500
        local enemyStartPos
        local labelStats = {}
        if aiBrain:GetCurrentEnemy() then
            local enemyX, enemyZ = aiBrain:GetCurrentEnemy():GetArmyStartPos()
            -- if we don't have an enemy position then we can't search for a path. Return until we have an enemy position
            enemyStartPos = Vector(enemyX, GetSurfaceHeight(enemyX, enemyZ), enemyZ)
        end
        local avgFactoryBuildRate = 1
        if productionZoneCount > 0 then
            avgFactoryBuildRate = math.max(totalBuildRate / math.max(productionZoneCount, 1), 1)
        end
        --LOG('----Start Assign Threat To Factories Cycle----')
        -- Iterate over all zones with enemy threat
        for tID, tData in pairs(zoneLayerSet) do
            --LOG('Zone cycle for zone id'..tostring(tID))
            --LOG('Zone Position '..tostring(repr(tData.pos)))
            local enemyThreatLevel = 0
            local friendlyThreatLevel
            local status = tData.status
            local teamValue = tData.teamvalue or 1
            local label = tData.label
            if label then
                labelStats[label] = labelStats[label] or { totalValue = 0, selfCapturedValue = 0, teamCapturedValue = 0, gravity = 0 }
                local rzValue = tData.resourcevalue or 0
                labelStats[label].totalValue = labelStats[label].totalValue + rzValue

                -- FACTUAL DATA: Use income instead of inferred status
                local selfIncome = tData.zoneincome.selfincome or 0
                local allyIncome = tData.zoneincome.allyincome or 0
                local enemyIncome = tData.zoneincome.enemyincome or 0

                if selfIncome > 0 then
                    -- Factual Saturation: We own and are extracting from this zone
                    labelStats[label].selfCapturedValue = labelStats[label].selfCapturedValue + rzValue
                    labelStats[label].teamCapturedValue = labelStats[label].teamCapturedValue + rzValue
                elseif allyIncome > 0 then
                    labelStats[label].teamCapturedValue = labelStats[label].teamCapturedValue + rzValue
                else
                    -- Factual Opportunity: This zone is not paying US. Calculate the "Pull"
                    local riskWeight = 1.0 + (zonePathSecurity[tID] or 0)
                    
                    -- Multipliers to prevent inefficient diversion:
                    -- 1. Ally Presence: If an ally has it, significantly lower the pull (don't steal)
                    local allyDampener = (allyIncome > 0) and 0.2 or 1.0
                    
                    -- 2. Enemy Presence: If an enemy has a mex, increase gravity (denial target)
                    local enemyIncentive = (enemyIncome > 0) and 1.5 or 1.0

                    -- 3. Security Depth (derived from target zone relative to frontline)
                    local targetDepth = zoneSecurityDepth[tID] or 0
                    local depthMult = (targetDepth == 0) and 2.0 or (1.0 / math.max(targetDepth, 1))

                    local adjustedGravity = rzValue * riskWeight * allyDampener * enemyIncentive * depthMult
                    labelStats[label].gravity = labelStats[label].gravity + adjustedGravity
                    if adjustedGravity > 0 then
                        for _, pZone in ipairs(productionZones) do
                            local pID = pZone.id
                            local dist = (pID == tID) and 0 or (distanceCache[pID] and distanceCache[pID][tID])

                            if dist and dist < distancePropagationCap then
                                -- Project distance decayed gravity to this specific base manager
                                local distanceDecay = math.exp(-dist * 0.004)
                                local fmgr = pZone.BuilderManager.FactoryManager
                                fmgr.EconomicGravity = (fmgr.EconomicGravity or 0) + (adjustedGravity * distanceDecay)
                            end
                        end
                    end
                end
            end

            --LOG('Zone Distance to AI start position '..VDist3(aiStartPos,tData.pos))
            --LOG('Current status of zone '..tostring(status))
            --LOG('Zone Distance to enemy start position '..VDist3(enemyStartPos,tData.pos))
            --LOG('GridEnemyLandThreat for zone '..tostring(tData.gridenemylandthreat))
            --LOG('ZoneIncome for zone '..tostring(tData.zoneincome.selfincome))
            
            if layer == 'Land' then
                enemyThreatLevel = math.ceil(tData.gridenemylandthreat)
                if frontlineZones[tID] then
                    enemyThreatLevel = math.max(enemyThreatLevel, 35)
                elseif status == 'Unoccupied' or status == 'Contested' then
                    -- Use some uncertainty estimate
                    if teamValue > 0.6 then
                        enemyThreatLevel = math.max(enemyThreatLevel, minHighValueThreat)
                    else
                        enemyThreatLevel = math.max(enemyThreatLevel, minLowValueThreat)
                    end
                elseif tData.zoneincome.selfincome == 0 then
                    if teamValue > 0.6 then
                        enemyThreatLevel = math.max(enemyThreatLevel, minHighValueThreat)
                    else
                        enemyThreatLevel = math.max(enemyThreatLevel, minLowValueThreat)
                    end
                end
                friendlyThreatLevel = tData.friendlydirectfireantisurfacethreat
            elseif layer == 'Naval' then
                -- This isn't implemented yet, should be using naval threat which is not currently recorded
                enemyThreatLevel = math.ceil(tData.enemynavalthreat)
                if status == 'Unoccupied' or status == 'Contested' then
                    -- Use some uncertainty estimate
                    if teamValue > 0.6 then
                        enemyThreatLevel = math.max(enemyThreatLevel, minHighValueThreat)
                    else
                        enemyThreatLevel = math.max(enemyThreatLevel, minLowValueThreat)
                    end
                elseif tData.zoneincome.selfincome == 0 then
                    if teamValue > 0.6 then
                        enemyThreatLevel = math.max(enemyThreatLevel, minHighValueThreat)
                    else
                        enemyThreatLevel = math.max(enemyThreatLevel, minLowValueThreat)
                    end
                end
                friendlyThreatLevel = tData.friendlydirectfireantisurfacethreat
            end

            local effectiveThreat = math.max(enemyThreatLevel - friendlyThreatLevel, 0)
            --LOG('Effective Threat was '..tostring(effectiveThreat)..' enemy threat was '..tostring(enemyThreatLevel)..' friendly threat was '..tostring(friendlyThreatLevel))
            if effectiveThreat and effectiveThreat > 0 then
                local distMap = {}
                local totalWeight = 0
                -- Measure distances from each production zone
                for _, pID in ipairs(productionZones) do
                    local dist
                    if pID.id == tID then
                        dist = 0 
                    else
                        dist = distanceCache[pID.id] and distanceCache[pID.id][tID]
                    end
                    
                    if dist and dist > 0 then
                        if dist > distancePropagationCap then
                            continue
                        end
                        local decayRate = (layer == 'Naval') and 0.002 or 0.005 -- Lower decay for naval
                        if controlledZones[pID.id] and not frontlineZones[pID.id] then
                            decayRate = (layer == 'Naval') and 0.008 or 0.015
                        end
                        local weight = math.exp(-dist * decayRate)
                        distMap[pID.id] = weight
                        totalWeight = totalWeight + weight
                    end
                end
                -- Distribute threat proportionally
                for pID, weight in pairs(distMap) do
                    local pZone = zoneLayerSet[pID]
                    local fmgr = pZone.BuilderManager.FactoryManager
                    if fmgr and fmgr.LocationActive then
                        local myBuildRate = fmgr[buildRateKey] or 1
                        local share = (weight / totalWeight) * effectiveThreat
                        local weightedShare = share * (myBuildRate / math.max(avgFactoryBuildRate, 0.1))-- normalize relative to all bases
                        fmgr.ZoneThreatAssignment = (fmgr.ZoneThreatAssignment or 0) + weightedShare
                    end
                end
            end
            --LOG('End Cycle for zone '..tostring(tID))
        end
        for _, pZone in ipairs(productionZones) do
            local fmgr = pZone.BuilderManager.FactoryManager
            local pID = pZone.id
            local label = pZone.label
            local stats = labelStats[label]

            -- 1. These are defined first
            fmgr.SecurityDepth = zoneSecurityDepth[pID] or 0
            fmgr.PathSecurity = zonePathSecurity[pID] or 1.0

            if stats and stats.totalValue > 0 then
                fmgr.SaturationRatio = stats.selfCapturedValue / stats.totalValue
                fmgr.TeamSaturationRatio = stats.teamCapturedValue / stats.totalValue
            else
                fmgr.SaturationRatio = 1
                fmgr.TeamSaturationRatio = 1
            end

            -- 2. POLICY CALCULATION (Injected here so variables exist)
            local modifier = 1.0
            -- Using your verified BrainIntel values
            local techLevel = aiBrain.BrainIntel.LandPhase or 1
            local techBoost = 1.0 + (techLevel * 0.2)
            
            if fmgr.SaturationRatio < 0.85 then
                -- Identify "Desperate Expansion" state
                local isExpanding = (fmgr.SaturationRatio < 0.4 and fmgr.EconomicGravity > 50)
                local boostBase = isExpanding and 1.8 or 1.4
                
                local massIncome = aiBrain.cmanager.income.r.m
                local incomeMult = math.min(massIncome / 20, 1.0)
                if isExpanding then incomeMult = 1.0 end
                
                -- modifier = (Base * Tech) + SaturationNeed + PathRisk
                modifier = (boostBase * techBoost) + ((1.0 - fmgr.SaturationRatio) * incomeMult) + (math.min(fmgr.PathSecurity, 2.0) * 0.2)
                fmgr.NoStoragePriority = (fmgr.EconomicGravity > 10 and fmgr.SecurityDepth < 3) or isExpanding
            
            elseif fmgr.SaturationRatio >= 0.85 and fmgr.SecurityDepth >= 2 and fmgr.PathSecurity < 1.5 then
                modifier = 0.5
                fmgr.NoStoragePriority = false
            end
            local tacticalFactor = 1.0
            local isSpamPlayer = aiBrain.BrainIntel.PlayerRole.SpamPlayer
            if (fmgr.ZoneThreatAssignment or 0) > 0 then
                local minFactor = isSpamPlayer and 0.5 or 0.1
                tacticalFactor = math.max(minFactor, math.min(fmgr.ZoneThreatAssignment / 10.0, 1.0))
            elseif not isSpamPlayer and fmgr.SecurityDepth >= 2 and fmgr.PathSecurity > 2.0 then
                tacticalFactor = 0.4
            end
            fmgr.ProductionModifier = modifier * tacticalFactor
        end
        local globalOpportunity = 0
        for lID, lData in labelStats do
            globalOpportunity = globalOpportunity + lData.gravity
        end
        --LOG(string.format("RNGLOG_GRAVITY_AUDIT | FactoryLabelGravity: %.2f | TrueMapGravity: %.2f", aiBrain.BrainIntel.GlobalEconomicGravity or 0, globalOpportunity))
        self.ProductionZones[layer] = productionZones
        --LOG('---- End AssignThreatToFactories Loop ----')
    end,

    ComputeContainmentState = function(self, productionZones, zoneLayerSet, layer)
        --[[
        This function evaluates the map zones the AI controls *via threat*,
        starting from zones with production and expanding outward into adjacent zones 
        only if friendly threat exceeds enemy threat by a set ratio.
    
        It returns:
          controlledZones: [zoneId] = true if dominated by AI threat and pathable from base
          frontlineZones: [zoneId] = true if zone borders an enemy-dominated or contested zone
        ]]
    
        local controlledZones = {}
        local visited = {}
        local frontier = {}
        local frontlineZones = {}
        local zoneSecurityDepth = {}
        local zonePathSecurity = {}
        
        -- Parameters
        local THREAT_DOMINANCE_RATIO = 1.25  -- AI must have this much more threat than enemy to spread
        local MAX_ISLAND_DANGER_RATIO = 2.0 -- If enemy has 2x island threat, ignore safety

        local enemyThreatKey = (layer == 'Naval') and 'enemynavalthreat' or 'gridenemylandthreat'
        local friendlyThreatKey = (layer == 'Naval') and 'friendlyantisurfacethreat' or 'friendlydirectfireantisurfacethreat'
    
        -- Start from all production zones (not just main base)
        local labelSeeds = {}
        
        -- First, prioritize our absolute primary main base if it exists
        local aiBrain = self.Brain
        local mainBaseManager = aiBrain.BuilderManagers.MAIN
        local mainBaseZoneId = mainBaseManager and mainBaseManager.ZoneID
        if mainBaseZoneId and zoneLayerSet[mainBaseZoneId] then
            local mainZone = zoneLayerSet[mainBaseZoneId]
            if mainZone.label then
                labelSeeds[mainZone.label] = mainZone.id
            end
        end

        -- Next, find the primary seed for any other disconnected landmasses/labels
        for _, zone in ipairs(productionZones) do
            if zone and zone.id and zone.label then
                -- Only seed this base if we haven't already picked a root for this island label
                if not labelSeeds[zone.label] then
                    labelSeeds[zone.label] = zone.id
                end
            end
        end

        -- Initialize the frontier using our unique island roots
        for label, zoneId in pairs(labelSeeds) do
            frontier[zoneId] = true
            visited[zoneId] = true
            controlledZones[zoneId] = true
            zoneSecurityDepth[zoneId] = 0
            zonePathSecurity[zoneId] = 10.0
        end
    
        while next(frontier) do
            local nextFrontier = {}
    
            for zoneId, _ in pairs(frontier) do
                --local currentHopCount = zoneSecurityDepth[zoneId] or 0
                local zone = zoneLayerSet[zoneId]
                local currentHops = zoneSecurityDepth[zoneId]
                for _, neighbor in ipairs(zone.edges or {}) do
                    local edgeId = neighbor.zone.id
                    if not visited[edgeId] then
                        local neighborZone = neighbor.zone
                        --LOG(string.format("RNGAI_DEBUG: BFS Hop %d | Zone %s -> Neighbor %s | Status: %s", currentHopCount, tostring(zoneId), tostring(edgeId), tostring(neighborZone.status)))
                        if zone.label == neighborZone.label then
                            visited[edgeId] = true

                            -- Comprehensive Enemy Threat Calculation
                            local eThreatGrid = neighborZone[enemyThreatKey] or 0
                            local eThreatRaw = (layer == 'Land') and (neighborZone.enemylandthreat or 0) or 0
                            local eThreatStruct = (layer == 'Land') and ((neighborZone.enemystructurethreat or 0) + (neighborZone.enemydefensestructurethreat or 0)) or 0
                            local totalEnemyThreat = math.max(eThreatGrid, eThreatRaw, eThreatStruct)

                            -- NEW: Comprehensive Friendly Threat Aggregation
                            local fDirect = neighborZone[friendlyThreatKey] or 0
                            local fDef = (layer == 'Land') and (neighborZone.friendlydefenseantisurfacethreat or 0) or 0
                            local fInd = (layer == 'Land') and (neighborZone.friendlyindirectfireantisurfacethreat or 0) or 0
                            local totalFriendlyThreat = fDirect + fDef + fInd

                            local status = neighborZone.status

                            -- --- REVISED PASSABILITY CALCULUS ---
                            -- 1. Allied territory: Passable if clear, OR if our combined presence protects it from being overwhelmed
                            local isPassableAllied = (status == 'Allied') and 
                                                        ((totalEnemyThreat == 0) or ((totalFriendlyThreat * THREAT_DOMINANCE_RATIO) >= totalEnemyThreat))
                            
                            -- 2. Contested/Unoccupied territory: Push forward unless a significant enemy presence blocks us
                            local isCurrentZoneAllied = (zone.status == 'Allied')
                            local hasPresenceOrProximity = isCurrentZoneAllied or (((zone[friendlyThreatKey] or 0) + (zone.friendlydefenseantisurfacethreat or 0)) > 0)
                            
                            local isPassableContested = (status == 'Unoccupied' or status == 'Contested') and 
                                                        hasPresenceOrProximity and 
                                                        ((totalEnemyThreat <= 1.0) or (totalFriendlyThreat >= totalEnemyThreat))

                            if isPassableAllied or isPassableContested then
                                controlledZones[edgeId] = true
                                nextFrontier[edgeId] = true
                                
                                local localRatio = totalFriendlyThreat / math.max(totalEnemyThreat, 1.0)
                                zonePathSecurity[edgeId] = math.min(zonePathSecurity[zoneId], localRatio)
                                zoneSecurityDepth[edgeId] = currentHops + 1
                            else
                                -- Hard boundary hit: This is where our combat front locks down
                                frontlineZones[edgeId] = true
                            end
                        end
                    end
                end
            end
    
            frontier = nextFrontier
        end
        if layer == 'Land' then
            self.CurrentFrontLineZones = frontlineZones
            self.CurrentControlledZones = controlledZones
            self.ZoneSecurityDepth = zoneSecurityDepth
            self.ZonePathSecurity = zonePathSecurity
        end
        return controlledZones, frontlineZones, zoneSecurityDepth, zonePathSecurity
    end,

    ProcessFrontlineRadarRequests = function(self, aiBrain)

        if aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime > 14 then
            -- Configurations
            local RadarRange = 200 -- T1 Radar Range
            local MaxRadarThreatForConstruction = 10 
            local RequestProximityDistance = 100 
            --LOG("DEBUG_RADAR: Proximity Distance Parameter is:", RequestProximityDistance)
            
            local PlacementRequestRadius = math.ceil(RadarRange * 0.075)

            -- 1. Acquire Data
            local controlledZones = self.CurrentControlledZones
            local frontlineZones = self.CurrentFrontLineZones
            local zoneMap = aiBrain.Zones.Land.zones

            if not frontlineZones then return end

            for zoneId, _ in pairs(frontlineZones) do
                local targetZone = zoneMap[zoneId]
                if not targetZone then continue end

                local isZoneCoveredBroadly = self:FindIntelInRings(targetZone.pos, 45) 
                if isZoneCoveredBroadly then
                    continue 
                end
                
                -- Filter 1: If factory is active, skip radar requests to prioritize combat build.
                if targetZone.BuilderManager and targetZone.BuilderManager.FactoryManager and targetZone.BuilderManager.FactoryManager.LocationActive then
                    continue 
                end
                
                -- Filter 2: Dedicated Radar Check (Fast Fail)
                if targetZone.intelassignment and targetZone.intelassignment.RadarCoverage then
                    continue 
                end
                
                -- === NEW FILTER 3: FORWARD VISIBILITY CHECK ===
                -- Check if the area of interest (the enemy-facing border) is already covered.
                local needsForwardRadar = true
                
                if targetZone.edges then
                    for _, edge in ipairs(targetZone.edges) do
                        local neighborZone = edge.zone
                        
                        -- Find edges that border an UNCONTROLLED zone (which we assume is the enemy direction)
                        if not controlledZones[neighborZone.id] and neighborZone.status ~= 'Allied' then
                            
                            -- Use the EDGE MIDPOINT as the point of interest (POI)
                            -- We check the POI itself and a spot just inside the TARGET ZONE (0.9 * distance)
                            local checkPoint = edge.midpoint
                            
                            -- We can check if the POI is visible. If ANY border is visible, we might not need a new radar.
                            local isEdgeVisible = self:FindIntelInRings(checkPoint, 20)
                            
                            if isEdgeVisible then
                                -- If any critical border is visible, we assume current coverage is sufficient
                                -- and break the outer loop.
                                needsForwardRadar = false
                                break
                            end
                        end
                    end
                end
                local CDRUnit = aiBrain.CDRUnit
                if CDRUnit and not CDRUnit.Dead and CDRUnit.rngdata and not CDRUnit.rngdata.RadarCoverage then
                    if CDRUnit.Position and VDist3Sq(CDRUnit.Position, targetZone.pos) < 6400 then
                        needsForwardRadar = true
                    end
                end

                if not needsForwardRadar then
                    continue
                end
                
                -- If we reach here, the Frontline Zone is dark or its enemy-facing borders are dark.
                
                -- === STEP 2: FIND A SAFE BUILD POSITION ===
                local bestBuildPosition = nil
                local bestSupportMetric = -1

                if targetZone.edges then
                    for _, edge in ipairs(targetZone.edges) do
                        local neighborZone = edge.zone
                        
                        -- We build in CONTROLLED (Allied) zones looking INTO Frontline zones.
                        if controlledZones[neighborZone.id] and neighborZone.status == 'Allied' then
                            
                            local startPos = neighborZone.pos
                            local endPos = targetZone.pos
                            
                            local distance = VDist3(startPos, endPos) 
                            
                            local stepSize = 10
                            local steps = math.floor(distance / stepSize)
                            
                            for i = 1, steps do
                                local lerpFactor = i / steps
                                
                                -- Stay strictly on the friendly side of the border (90%).
                                if lerpFactor > 0.9 then break end

                                local checkPos = {
                                    startPos[1] + (endPos[1] - startPos[1]) * lerpFactor,
                                    GetSurfaceHeight(startPos[1], startPos[3]), 
                                    startPos[3] + (endPos[3] - startPos[3]) * lerpFactor
                                }
                                
                                local gridX, gridZ = self:GetIntelGrid(checkPos)
                                if gridX and self.MapIntelGrid[gridX] and self.MapIntelGrid[gridX][gridZ] then
                                    local cell = self.MapIntelGrid[gridX][gridZ]
                                    
                                    -- 1. Must be in the Friendly Zone.
                                    local inFriendlyZone = (cell.LandZoneID == neighborZone.id)
                                    
                                    -- 2. Must be safe from Historical Threat.
                                    local isSafe = (cell.IMAPHistoricalThreat.Land or 0) < MaxRadarThreatForConstruction
                                    
                                    -- 3. Must not have a request pending nearby.
                                    local isUnique = not self:IsExistingStructureRequestPresent(checkPos, RequestProximityDistance, 'RADAR')
                                    --LOG("DEBUG_RADAR: isUnique at pos [%.1f, %.1f]: %s", checkPos[1], checkPos[3], tostring(isUnique))

                                    if inFriendlyZone and isSafe and isUnique then
                                        
                                        -- SCORING:
                                        local metric = lerpFactor * 10 
                                        
                                        -- Bonus for extending the network into a dark cell.
                                        if not cell.IntelCoverage then
                                            metric = metric + 5
                                        end

                                        if metric > bestSupportMetric then
                                            bestSupportMetric = metric
                                            bestBuildPosition = checkPos
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                --local finalIsCovered = self:FindIntelInRings(targetZone.pos, 45) 
                --LOG("DEBUG_RADAR: Zone %d final state isCovered: %s", targetZone.id, tostring(finalIsCovered ~= nil))
                
                -- === STEP 3: EXECUTE ===
                if bestBuildPosition and bestSupportMetric > 0 then
                    --LOG('Requesting radar to be built at '..tostring(repr(bestBuildPosition)))
                    self:RequestStructureNearPosition(bestBuildPosition, PlacementRequestRadius, 'RADAR')
                    break 
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

function ClassifyUnit(unit)
    if not unit or not unit.Blueprint or not unit.Blueprint.CategoriesHash then
        return nil
    end

    local cat = unit.Blueprint.CategoriesHash
    local unitClassification
    local unitType

    if cat.EXPERIMENTAL then
        unitClassification = 'Experimental'
        if cat.MOBILE and cat.LAND and not cat.ARTILLERY then
            unitType = 'ExperimentalLand'
        else
            unitType = 'Experimental'
        end
    elseif cat.AIR then
        unitClassification = 'Air'
        if cat.BOMBER then
            unitType = 'Bomber'
        elseif cat.GROUNDATTACK then
            unitType = 'Gunship'
        elseif cat.SCOUT then
            unitType = 'Scout'
        else
            unitType = 'Air'
        end
    elseif cat.LAND then
        unitClassification = 'Land'
        if (cat.UEF or cat.CYBRAN) and cat.BOT and cat.TECH2 and cat.DIRECTFIRE or cat.SNIPER and cat.TECH3 then
            unitType = 'RangedBot'
        else
            unitType = 'Land'
        end
    elseif cat.STRUCTURE then
        unitClassification = 'Structure'
        unitType = 'Structure'
    elseif cat.NAVAL then
        unitClassification = 'Naval'
        if cat.MISSILESHIP then
            unitType = 'MissileShip'
        elseif cat.NUKESUB then
            unitType = 'NukeSub'
        elseif cat.CRUISER then
            unitType = 'Cruiser'
        elseif cat.CARRIER then
            unitType = 'Carrier'
        else
            unitType = 'Naval'
        end
    end

    return unitClassification, unitType
end

function ProcessSourceOnKilled(targetUnit, sourceUnit)
    if not (sourceUnit and sourceUnit.GetAIBrain) then return end
    local sourceBrain = sourceUnit:GetAIBrain()
    if not sourceBrain.RNG then return end
    if not targetUnit['RNGKilledCallbackRun'] then
        targetUnit['RNGKilledCallbackRun'] = true

        local targetBP = targetUnit.Blueprint
        local valueGained = targetBP and targetBP.Economy.BuildCostMass or 0
        if valueGained <= 0 then return end

        local sourceClassification, sourceType = ClassifyUnit(sourceUnit)
        --LOG('ProcessSourceOnKilled triggered for source unit '..tostring(sourceUnit.UnitId)..' and target unit '..tostring(targetUnit.UnitId)..' sourceType was set as '..tostring(sourceType))
        if not sourceType then return end

        local unitStats = sourceBrain.IntelManager.UnitStats
        if not unitStats[sourceType] then return end

        unitStats[sourceType].Kills.Mass = (unitStats[sourceType].Kills.Mass or 0) + valueGained

        -- Optional efficiency calculation (unchanged)
        local gained = math.max(unitStats[sourceType].Kills.Mass, 0.1)
        local built  = math.max(unitStats[sourceType].Built.Mass or 0, 0.1)
        --LOG('Efficiency '..(math.min(gained / built, 2)))
    end
end

function ProcessSourceOnDeath(targetBrain, targetUnit, sourceUnit, damageType)
    if not targetBrain.RNG then
        return
    end

    local valueLost = targetUnit.Blueprint.Economy.BuildCostMass or 0
    if valueLost <= 0 then
        return
    end

    local targetCat = targetUnit.Blueprint.CategoriesHash
    local sourceCat = (sourceUnit and sourceUnit.Blueprint and sourceUnit.Blueprint.CategoriesHash) or {}

    local sourceClassification, sourceType = ClassifyUnit(sourceUnit)
    local targetClassification, targetType = ClassifyUnit(targetUnit)
    if not targetType or not sourceType then
        return
    end

    -- Handle special target cases
    if targetType == 'Scout' then
        RecordUnitDeath(targetUnit, 'SCOUT')
    end

    -- Structure-specific cleanup
    if targetType == 'Structure' then
        if targetCat.DEFENSE and not targetCat.WALL then
            local locationType = targetUnit.BuilderManagerData.LocationType
            if locationType then
                RUtils.RemoveDefenseUnitFromSpoke(targetBrain, locationType, targetUnit)
            else
                WARN('AI RNG: Missing locationType on defensive structure death for unit ' .. targetUnit.UnitId)
            end
        end

        -- Track tactical missile launchers
        if sourceCat.TACTICALMISSILEPLATFORM and sourceUnit then
            local tmlPos = sourceUnit:GetPosition()
            if targetBrain.EnemyIntel.TML and not targetBrain.EnemyIntel.TML[sourceUnit.EntityId] then
                targetBrain.EnemyIntel.TML[sourceUnit.EntityId] = {
                    object = sourceUnit,
                    position = tmlPos,
                    validated = false,
                    range = sourceUnit.Blueprint.Weapon[1].MaxRadius
                }
                local sm = import('/mods/RNGAI/lua/StructureManagement/StructureManager.lua').GetStructureManager(targetBrain)
                ForkThread(sm.ValidateTML, sm, targetBrain, targetBrain.EnemyIntel.TML[sourceUnit.EntityId])
            end
        end

        -- Radar / Omni / Sonar cleanup
        if (targetCat.RADAR or targetCat.OMNI or targetCat.SONAR) and targetBrain.IntelManager then
            ForkThread(targetBrain.IntelManager.UnassignIntelUnit, targetBrain.IntelManager, targetUnit)
        end
    end

    -- Record enemy performance
    if sourceType and targetType then
        local enemyPerf = targetBrain.IntelManager.EnemyPerformance  -- or targetBrain.IntelManager.EnemyPerformance
        if enemyPerf and enemyPerf[sourceClassification] then
            enemyPerf[sourceClassification].KillsAgainst[targetType] = (enemyPerf[sourceClassification].KillsAgainst[targetType] or 0) + valueLost
            enemyPerf[sourceClassification].KillsAgainst.Total = (enemyPerf[sourceClassification].KillsAgainst.Total or 0) + valueLost
            enemyPerf[sourceClassification].TotalMassKilled = (enemyPerf[sourceClassification].TotalMassKilled or 0) + valueLost
        end
    end

    -- Record own unit loss
    local unitStats = targetBrain.IntelManager.UnitStats
    if unitStats[targetType] and unitStats[targetType].Deaths then
        unitStats[targetType].Deaths.Mass = (unitStats[targetType].Deaths.Mass or 0) + valueLost
    end

    -- Update efficiency ratio
    if unitStats[targetType] then
        local killsMass = (unitStats[targetType].Kills.Mass or 0) + 0.1
        local deathsMass = (unitStats[targetType].Deaths.Mass or 0) + 0.1
        unitStats[targetType].Efficiency = math.min(killsMass / deathsMass, 2)
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
        local gameTime = GetGameTimeSeconds()
        local gridXID, gridZID = im:GetIntelGrid(targetUnit:GetPosition())
        if im.MapIntelGrid[gridXID][gridZID].RecentScoutDeaths then
            im.MapIntelGrid[gridXID][gridZID].RecentScoutDeaths = im.MapIntelGrid[gridXID][gridZID].RecentScoutDeaths + 1
            im.MapIntelGrid[gridXID][gridZID].RecentScoutDeathTime = gameTime
        else
            WARN('AI RNG : Unable to record scout death. Grid IDs '..repr(gridXID)..' '..repr(gridZID))
            if not im.MapIntelGrid[gridXID][gridZID] then
                WARN('AI RNG : Intel Grid entry does not exist.')
            end
        end
        if targetUnit.AIPlatoonReference then
            local platoon = targetUnit.AIPlatoonReference
            if platoon and platoon.BuilderData and platoon.BuilderData.TargetData then
                local targetData = platoon.BuilderData.TargetData
                if targetData.RecentScoutDeaths then
                    targetData.RecentScoutDeaths = targetData.RecentScoutDeaths + 1
                    targetData.RecentScoutDeathTime = gameTime
                end
            end
        end
    end
end

DrawTargetRadius = function(self, position, colour, radius)
    --RNGLOG('Draw Target Radius points')
    local counter = 0
    while counter < 75 do
        DrawCircle(position, radius, colour)
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
                        validNavalLabels[label] = {
                            State = 'Unconfirmed',
                            AllyPlayerCount = 1,
                            EnemyPlayerCount = 0
                        }
                    end
                end
                for _, b in aiBrain.EnemyIntel.EnemyStartLocations do
                    local enemyStartAdded = {}
                    local enemyNavalPositions = NavUtils.GetPositionsInRadius('Water', b.Position, 256, 10)
                    if enemyNavalPositions then
                        for _, v in enemyNavalPositions do
                            local label = NavUtils.GetLabel('Water', {v[1], v[2], v[3]})
                            local labelMeta = NavUtils.GetLabelMetadata(label)
                            if labelMeta.Area and labelMeta.Area > 5 then
                                if label and validNavalLabels[label] then
                                    validNavalLabels[label].State = 'Confirmed'
                                    if not enemyStartAdded[label] then
                                        validNavalLabels[label].EnemyPlayerCount = validNavalLabels[label].EnemyPlayerCount + 1
                                        enemyStartAdded[label] = true
                                    end
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
                for _, b in aiBrain.BrainIntel.AllyStartLocations do
                    local allyStartAdded = {}
                    local allyNavalPositions = NavUtils.GetPositionsInRadius('Water', b.Position, 256, 10)
                    if allyNavalPositions then
                        for _, v in allyNavalPositions do
                            local label = NavUtils.GetLabel('Water', {v[1], v[2], v[3]})
                            local labelMeta = NavUtils.GetLabelMetadata(label)
                            if labelMeta.Area and labelMeta.Area > 5 then
                                if label and validNavalLabels[label] then
                                    validNavalLabels[label].State = 'Confirmed'
                                    if not allyStartAdded[label] then
                                        validNavalLabels[label].AllyPlayerCount = validNavalLabels[label].AllyPlayerCount + 1
                                        allyStartAdded[label] = true
                                    end
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
            end
            if not table.empty(validNavalLabels) then
                local labelCount = 0
                for labelID, label in validNavalLabels do
                    local labelMeta = NavUtils.GetLabelMetadata(labelID)
                   if labelMeta.Area and labelMeta.Area < 10 then
                        if label.AllyPlayerCount == 0 or label.EnemyPlayerCount == 0 then
                            label.State = 'Unconfirmed'
                        end
                    end
                    --LOG('Label State '..tostring(v.State))
                    if label.State == 'Confirmed' then
                        labelCount = labelCount + 1
                    end
                end
                aiBrain.BrainIntel.NavalBaseLabels = validNavalLabels
                aiBrain.BrainIntel.NavalBaseLabelCount = labelCount
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
                    --local checkPoints = RUtils.DrawCirclePoints(8, frigateRange, v.position)
                    local frigateCheckPoints = NavUtils.GetDetailedPositionsInRadius('Water', v.position, frigateRange, 0)
                    local navalCheckPoints = NavUtils.GetPositionsInRadius('Water', v.position, maxRadius)
                    --LOG('CheckPoint for '..tostring(repr(v)))
                    --LOG(repr(checkPoints))
                    if frigateCheckPoints then
                        local valueInrange = false
                        local valueValidated = false
                        for _, m in frigateCheckPoints do
                            local label = NavUtils.GetLabel('Water', {m[1], m[2], m[3]})
                            local labelMeta = NavUtils.GetLabelMetadata(label)
                            if labelMeta.Area and labelMeta.Area > 5 then
                                local dx = v.position[1] - m[1]
                                local dz = v.position[3] - m[3]
                                local posDist = dx * dx + dz * dz
                                --aiBrain:ForkThread(DrawTargetRadius, m, 'cc0000', 1)
                                if not valueValidated then
                                    if posDist <= frigateRange * frigateRange then
                                        valueInrange = true
                                    end
                                end
                                if valueInrange then
                                    local markerValue = 1000 / 28
                                    if not aiBrain:CheckBlockingTerrain({m[1], (GetSurfaceHeight(m[1], m[3]) + 1.1), m[3]}, v.position, 'low') then
                                        markerCountNotBlocked = markerCountNotBlocked + 1
                                        frigateRaidMarkers = frigateRaidMarkers + 1
                                        table.insert( frigateMarkers, { Position=v.position, Name=v.name, RaidPosition={m[1], m[2], m[3]}, Distance = posDist, MarkerValue = markerValue, LastRaidTime = 0 } )
                                        valueValidated = true
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
                    end
                    if navalCheckPoints then
                        local valueValidated = false
                        for _, m in navalCheckPoints do
                            local label = NavUtils.GetLabel('Water', {m[1], m[2], m[3]})
                            local labelMeta = NavUtils.GetLabelMetadata(label)
                            if labelMeta.Area and labelMeta.Area > 5 then
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
                                    if not aiBrain:CheckBlockingTerrain({m[1], (GetSurfaceHeight(m[1], m[3]) + 2.0), m[3]}, v.position, 'low') then
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
            --LOG('Naval base label count '..tostring(aiBrain.BrainIntel.NavalBaseLabelCount))
            if frigateRaidMarkers > 0 then
                aiBrain.EnemyIntel.FrigateRaidMarkers = frigateMarkers
            end
            if frigateRaidMarkers > 6 then
                aiBrain.EnemyIntel.FrigateRaid = true
            end
            if markerCountNotBlocked > 0 then
                aiBrain.EnemyIntel.NavalMarkers = navalMarkers
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
        WARN('No Label in path node, either its not created yet or the marker analysis hasnt happened')
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
                        if b.ZoneID == v.Key and not table.empty(aiBrain.BuilderManagers[k].FactoryManager.FactoryList) then
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
    local zoneToGridMap = aiBrain.IntelManager.ZoneToGridMap
    local layers = {
        Land = aiBrain.Zones.Land.index,
        Naval = aiBrain.Zones.Naval.index,
        Air = aiBrain.Zones.Air.index
    }

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
            intelGrid[x][z].Sonars = setmetatable({}, WeakValueTable)
            intelGrid[x][z].Size = { }
            intelGrid[x][z].DistanceToMain = 0
            intelGrid[x][z].AssignedScout = false
            intelGrid[x][z].LastScouted = 0
            intelGrid[x][z].RecentScoutDeaths = 0
            intelGrid[x][z].RecentScoutDeathTime = 0
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
            intelGrid[x][z].LastThreatUpdate = 0
            intelGrid[x][z].IMAPCurrentThreat = {
                AntiAir = 0,
                Naval = 0,
                Air = 0,
                Land = 0,
                AntiSurface = 0,
                StructuresNotMex = 0
            }
            intelGrid[x][z].IMAPHistoricalThreat = {
                AntiAir = 0,
                Naval = 0,
                Air = 0,
                Land = 0,
                AntiSurface = 0,
                StructuresNotMex = 0
            }
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
            local gridPos = {cx, GetTerrainHeight(cx, cz), cz}
            cellCount = cellCount + 1
            startingGridx = math.min(x, startingGridx)
            startingGridz = math.min(z, startingGridz)
            endingGridx = math.max(x, endingGridx)
            endingGridz = math.max(z, endingGridz)
            intelGrid[x][z].Position = gridPos
            intelGrid[x][z].DistanceToMain = VDist3(intelGrid[x][z].Position, aiBrain.BrainIntel.StartPos) 
            intelGrid[x][z].Water = GetTerrainHeight(cx, cz) < GetSurfaceHeight(cx, cz)
            intelGrid[x][z].Size = { sx = fx, sz = fz}
            for layerName, layerIdx in layers do
                local zId = MAP:GetZoneID(gridPos, layerIdx) or 0
                if zId > 0 then
                    -- We need separate mapping tables to avoid ID collisions between layers
                    if not zoneToGridMap[layerName] then
                        zoneToGridMap[layerName] = {}
                    end
                    if not zoneToGridMap[layerName][zId] then
                        zoneToGridMap[layerName][zId] = {}
                    end
                    table.insert(zoneToGridMap[layerName][zId], intelGrid[x][z])
                    
                    -- Store the ID on the cell for debugging
                    intelGrid[x][z][layerName .. 'ZoneID'] = zId
                end
            end
            --intelGrid[x][z].LandZoneID = zoneId
            intelGrid[x][z].LandLabel = NavUtils.GetLabel('Land', gridPos)
            intelGrid[x][z].Enabled = true
        end
    end
    aiBrain.IntelManager.MapIntelGrid = intelGrid
    aiBrain.IntelManager.ZoneToGridMap = zoneToGridMap
    aiBrain.IntelManager.MapIntelGridSize = fx
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

GetFactoryPhase = function(unitCats, unitObject)
    if unitCats.TECH3 then 
        return 3 
    end
    local isUpgrading = unitObject:IsUnitState('Upgrading')

    if unitCats.TECH2 then 
        if isUpgrading then
            return 2.5
        else
            return 2 
        end
    end
    if unitCats.TECH1 then
        if isUpgrading then 
            return 1.5
        else
            return 1
        end
    end
    return 1
end


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
                    z.ShieldCount = 0
                    z.ShieldEconomyThreat = 0
                    z.AntiMissileCount = 0
                    z.AntiMissileThreat = 0
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
                    elseif unit.Object.Blueprint.Defense.ArmorType == "TMD" then
                        eThreatLocations[unit.IMAP[1]][unit.IMAP[3]].AntiMissileCount = eThreatLocations[unit.IMAP[1]][unit.IMAP[3]].AntiMissileCount + 1
                        eThreatLocations[unit.IMAP[1]][unit.IMAP[3]].AntiMissileThreat = eThreatLocations[unit.IMAP[1]][unit.IMAP[3]].AntiMissileThreat + 15
                    elseif unit.Object.Blueprint.Defense.Shield then
                        eThreatLocations[unit.IMAP[1]][unit.IMAP[3]].ShieldCount = eThreatLocations[unit.IMAP[1]][unit.IMAP[3]].ShieldCount + 1
                        eThreatLocations[unit.IMAP[1]][unit.IMAP[3]].ShieldEconomyThreat = eThreatLocations[unit.IMAP[1]][unit.IMAP[3]].ShieldEconomyThreat + unit.Object.Blueprint.Defense.EconomyThreatLevel
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
                    local tableEntry = { Position = z.Position, Land = { Count = 0, Threat = 0 }, Air = { Count = 0, Threat = 0 }, Shield = { Count = 0, Threat = 0 }, AntiMissile = { Count = 0, Threat = 0 }, aggX = 0, aggZ = 0, weight = 0, maxRangeLand = 0, validated = false}
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
                    if z.AntiMissileCount > 0 then
                        --LOG('Enemy Threat Location with ID '..q..' has '..threat.AntiMissileCount..' at imap position '..repr(threat.Position))
                        tableEntry.AntiMissile = { Count = z.AntiMissileCount, Threat = z.AntiMissileThreat }
                    end
                    if z.ShieldCount > 0 then
                        --LOG('Enemy Threat Location with ID '..q..' has '..threat.ShieldCount..' at imap position '..repr(threat.Position))
                        tableEntry.Shield = { Count = z.ShieldCount, Threat = z.ShieldEconomyThreat }
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
            local defenseGroup = {Land = best.Land.Count, Air = best.Air.Count, MaxLandRange = best.maxRangeLand or 0, LandThreat = best.Land.Threat, AirThreat = best.Air.Threat, ShieldCount = best.Shield.Count, ShieldThreat = best.Shield.Threat, AntiMissileCount = best.AntiMissile.Count, AntiMissileThreat = best.AntiMissile.Threat}
            best.validated = true
            local x = best.aggX/best.weight
            local z = best.aggZ/best.weight
            for _, v in firebaseTable do
                if (not v.validated) and VDist3Sq(v.Position, best.Position) < 3600 then
                    defenseGroup.Land = defenseGroup.Land + v.Land.Count
                    defenseGroup.LandThreat = defenseGroup.LandThreat + v.Land.Threat
                    defenseGroup.Air = defenseGroup.Air + v.Air.Count
                    defenseGroup.AirThreat = defenseGroup.AirThreat + v.Air.Threat 
                    defenseGroup.ShieldCount = defenseGroup.ShieldCount + v.Shield.Count
                    defenseGroup.ShieldThreat = defenseGroup.ShieldThreat + v.Shield.Threat
                    defenseGroup.AntiMissileCount = defenseGroup.AntiMissileCount + v.AntiMissile.Count
                    defenseGroup.AntiMissileThreat = defenseGroup.AntiMissileThreat + v.AntiMissile.Threat
                    v.validated = true
                elseif not v.validated then
                    complete = false
                end
            end
            firebaseaggregation = firebaseaggregation + 1
            if RUtils.PositionInWater({x,0,z}) then
                baseLabelType = 'Naval'
            else
                baseLabelType = 'Land'
            end
            local firebaseZone = MAP:GetZoneID({x,0,z}, aiBrain.Zones[baseLabelType].index)
            RNGINSERT(firebaseaggregationTable, {aggx = x, aggz = z, DefensiveCount = defenseGroup.Land + defenseGroup.Air, MaxLandRange = defenseGroup.MaxLandRange, AntiSurfaceThreat = defenseGroup.LandThreat, AntiAirThreat = defenseGroup.AirThreat, ShieldCount = defenseGroup.ShieldCount, ShieldThreat = defenseGroup.ShieldThreat, AntiMissileCount = defenseGroup.AntiMissileCount, AntiMissileThreat = defenseGroup.AntiMissileThreat, ZoneID = firebaseZone, FireBaseLayer = baseLabelType})
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
                    local extractors = GetListOfUnits(aiBrain, (categories.STRUCTURE * categories.FACTORY) + (categories.STRUCTURE * categories.MASSEXTRACTION - categories.TECH1) - categories.EXPERIMENTAL , false, false)
                    for c, b in extractors do
                        if VDist3Sq(b:GetPosition(), v.position) < (v.range * v.range) + 100 then
                            --LOG('EnemyIntelTML there is an extractor that is in range')
                            if not b['rngdata'].TMLInRange then
                                b['rngdata'].TMLInRange = setmetatable({}, WeakValueTable)
                            end
                            b['rngdata'].TMLInRange[v.object.EntityId] = v.object
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
        local landPhase = 1
        local airPhase = 1
        local navalPhase = 1
        for k, unit in factoryUnits do
            local unitCats = unit.Object.Blueprint.CategoriesHash
            if unitCats.AIR then
                airPhase = math.max(airPhase, GetFactoryPhase(unitCats, unit.Object))
            end
            if unitCats.LAND then
                landPhase = math.max(landPhase, GetFactoryPhase(unitCats, unit.Object))
            end
            if unitCats.NAVAL then
                navalPhase = math.max(navalPhase, GetFactoryPhase(unitCats, unit.Object))
            end
        end
        aiBrain.EnemyIntel.AirPhase = math.max(aiBrain.EnemyIntel.AirPhase, airPhase)
        aiBrain.EnemyIntel.LandPhase = math.max(aiBrain.EnemyIntel.LandPhase, landPhase)
        aiBrain.EnemyIntel.NavalPhase = math.max(aiBrain.EnemyIntel.NavalPhase, navalPhase)
        aiBrain.EnemyIntel.HighestPhase = math.max(aiBrain.EnemyIntel.AirPhase, aiBrain.EnemyIntel.LandPhase, aiBrain.EnemyIntel.NavalPhase)
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
            local enemyZoneThreats = {}
            local mexcount = 0
            local eunits=aiBrain:GetUnitsAroundPoint((categories.NAVAL + categories.AIR + categories.LAND + categories.STRUCTURE) - categories.INSIGNIFICANTUNIT, {0,0,0}, math.max(ScenarioInfo.size[1],ScenarioInfo.size[2])*1.5, 'Enemy')
            for _,v in eunits do
                if not v or v.Dead then continue end
                if ArmyIsCivilian(v:GetArmy()) then continue end
                if v.Army and not enemyBuildStrength[v.Army] then
                    enemyBuildStrength[v.Army] = {}
                end
                local unitCat = v.Blueprint.CategoriesHash
                local unitDef = v.Blueprint.Defense
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
                                enemyMexes[v.zoneid] = {T1 = 0, T2 = 0, T3 = 0, zoneincome = 0}
                            end
                            if unitCat.TECH1 then
                                enemyMexes[v.zoneid].T1 = enemyMexes[v.zoneid].T1 + 1
                                enemyMexes[v.zoneid].zoneincome = enemyMexes[v.zoneid].zoneincome + GetProductionPerSecondMass(v)
                            elseif unitCat.TECH2 then
                                enemyMexes[v.zoneid].T2 = enemyMexes[v.zoneid].T2 + 1
                                enemyMexes[v.zoneid].zoneincome = enemyMexes[v.zoneid].zoneincome + GetProductionPerSecondMass(v)
                            else
                                enemyMexes[v.zoneid].T3 = enemyMexes[v.zoneid].T3 + 1
                                enemyMexes[v.zoneid].zoneincome = enemyMexes[v.zoneid].zoneincome + GetProductionPerSecondMass(v)
                            end
                        end
                        if not im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id] or im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].time + 10 < time then
                            if not im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id] then
                                im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id]={}
                                if unitCat.MOBILE then
                                    if unitCat.COMMAND then
                                        im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].type='acu'
                                    elseif unitCat.LAND then
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
                                        elseif unitCat.INDIRECTFIRE and unitCat.ARTILLERY then
                                            im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].type='arty'
                                        elseif unitCat.INDIRECTFIRE and unitCat.SILO then
                                            im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].type='silo'
                                        end
                                    elseif unitCat.AIR then
                                        if unitCat.EXPERIMENTAL then
                                            if not aiBrain.EnemyIntel.Experimental[id] then
                                                aiBrain.EnemyIntel.Experimental[id] = {object = v, position=unitPosition }
                                            end
                                        elseif unitCat.BOMBER then
                                            im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].type='bomber'
                                        elseif unitCat.GROUNDATTACK then
                                            im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].type='gunship'
                                        end
                                    elseif unitCat.NAVAL then
                                        if unitCat.NUKE then
                                            if not aiBrain.EnemyIntel.NavalSML[id] then
                                                aiBrain.EnemyIntel.NavalSML[id] = {object = v, Position=unitPosition, Detected=time }
                                            end
                                        end
                                        if unitCat.EXPERIMENTAL and not unitCat.UNTARGETABLE then
                                            if not aiBrain.EnemyIntel.Experimental[id] then
                                                aiBrain.EnemyIntel.Experimental[id] = {object = v, position=unitPosition }
                                            end
                                            im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].type='exp'
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
                                    elseif unitCat.DEFENSE and (unitCat.DIRECTFIRE or unitCat.INDIRECTFIRE) then
                                        im.MapIntelGrid[gridXID][gridZID].EnemyUnits[id].type='defense'
                                        if im.MapIntelGrid[gridXID][gridZID].LandZoneID then
                                            local landZoneID = im.MapIntelGrid[gridXID][gridZID].LandZoneID
                                            if not enemyZoneThreats[landZoneID] then
                                                enemyZoneThreats[landZoneID] = 0
                                            end
                                            enemyZoneThreats[landZoneID] = enemyZoneThreats[landZoneID] + unitDef.SurfaceThreatLevel
                                        end
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
            for k, v in aiBrain.Zones.Land.zones do
                if enemyMexes[v.id] and enemyMexes[v.id].zoneincome then
                    v.zoneincome.enemyincome = enemyMexes[v.id].zoneincome
                elseif v.zoneincome then
                    v.zoneincome.enemyincome = 0
                end
                if enemyZoneThreats[v.id] then
                    v.enemydefensestructurethreat = enemyZoneThreats[v.id]
                else
                    v.enemydefensestructurethreat = 0
                end
            end
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
    local landZones = aiBrain.Zones.Land.zones
    while aiBrain.Status ~= "Defeat" do
        local unitAddedCount = 0
        local needSort = false
        local timeStamp = GetGameTimeSeconds()
        local zoneThreatTotals = {
            Air = {},
            Land = {},
            Naval = {}
        }
        --RNGLOG('Check lastknown')
        for i = 1, table.getn(landZones) do
            landZones[i].gridenemylandthreat = 0
        end
        
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
                    --LOG('basePriority '..tostring(basePriority))
                    local normalizedDistance = distanceToMain / playableSize
                    local distanceFactor = (1 - normalizedDistance) * 250
                    
                    scaledPriority = basePriority * (1 + distanceFactor * distanceExponent / maxPriority)
                    --LOG('scaledPriority '..tostring(scaledPriority))
                    local statusModifier = 1
                    
                    --LOG('angle of enemy units '..angleOfEnemyUnits)
                    --LOG('distance to main '..im.MapIntelGrid[i][k].DistanceToMain)
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
                            local strategicValue = 1
                            local unitBp = b.object.Blueprint
                            local tacticalWeight = 1.0
                            if (unitBp.CategoriesHash.LAND or unitBp.CategoriesHash.HOVER or unitBp.CategoriesHash.AMPHIBIOUS)
                                and unitBp.Defense.SurfaceThreatLevel and unitBp.Defense.SurfaceThreatLevel > 0 then
                                if im.MapIntelGrid[i][k].LandZoneID then
                                    zoneid = im.MapIntelGrid[i][k].LandZoneID
                                    if not zoneThreatTotals['Land'][zoneid] then
                                        zoneThreatTotals['Land'][zoneid] = 0
                                    end
                                    if unitBp.CategoriesHash.COMMAND then
                                        zoneThreatTotals['Land'][zoneid] = zoneThreatTotals['Land'][zoneid] + b.object:EnhancementThreatReturn()
                                    else
                                        zoneThreatTotals['Land'][zoneid] = zoneThreatTotals['Land'][zoneid] + unitBp.Defense.SurfaceThreatLevel
                                    end
                                    local zone
                                    if im.MapIntelGrid[i][k].Water then
                                        zone = aiBrain.Zones.Naval.zones[zoneid]
                                        if zone and zone.teamvalue then
                                            strategicValue = RUtils.EvaluateZonePriority(zone, normalizedDistance)
                                        end
                                    else
                                        zone = aiBrain.Zones.Land.zones[zoneid]
                                        if zone and zone.teamvalue then
                                            strategicValue = RUtils.EvaluateZonePriority(zone, normalizedDistance)
                                        end
                                    end
                                end
                            end
                            priority = (priority * statusModifier * tacticalWeight) + strategicValue
                            --LOG('Strategic value is '..tostring(strategicValue))
                            --LOG('Priority for unit '..tostring(b.object.UnitId).. ' is '..tostring(priority))
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
        local zoneData = aiBrain.Zones.Land.zones
        for id, zonethreat in pairs(zoneThreatTotals.Land) do
            if zoneData[id] then
                zoneData[id].gridenemylandthreat = zonethreat
                --LOG('Setting zone id '..tostring(id)..' to '..tostring(zoneData[id].gridenemylandthreat))
            end
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

--[[
----output example

AssignThreatToFactories(zoneSet, layer)

-- Debug print
for _, pid in ipairs(prodZones) do
    local fmgr = Zones[pid].BuilderManager.FactoryManager
    print(string.format("Zone %d assigned %.2f threat for production", pid, fmgr.ZoneThreatAssignment or 0))
end

function ArmyManagerBuildCondition(aiBrain, builderManager)
    local zone = builderManager.ZoneID
    local threatAssignment = builderManager.FactoryManager.ZoneThreatAssignment or 0
    -- Optionally scale with factory capacity
    local buildRate = builderManager.FactoryManager:GetTotalBuildRate()
    
    if threatAssignment > 0.5 * buildRate then
        return true  -- Build combat units
    end
    return false  -- Save resources for other things
end
]]

-- zonesTable: dictionary of zoneID -> zoneData { edges = {adjacentZoneID, ...} }
-- isZoneSafe: function(zoneID) -> boolean
-- safeZones: set (table as keys) of safe zone IDs (optional, else compute starting from baseZone)
-- baseZoneID: ID of the main base zone
