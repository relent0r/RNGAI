WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * RNGAI: offset aibrain.lua' )
local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetMOARadii()
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local StructureManagerRNG = import('/mods/RNGAI/lua/StructureManagement/StructureManager.lua')
local Mapping = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua')
local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
local GetMarkersRNG = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
local DebugArrayRNG = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').DebugArrayRNG
local AIUtils = import('/lua/ai/AIUtilities.lua')
local AIBehaviors = import('/lua/ai/AIBehaviors.lua')
local PlatoonGenerateSafePathToRNG = import('/lua/AI/aiattackutilities.lua').PlatoonGenerateSafePathToRNG
local GetClosestPathNodeInRadiusByLayerRNG = import('/lua/AI/aiattackutilities.lua').GetClosestPathNodeInRadiusByLayerRNG
local GetEconomyIncome = moho.aibrain_methods.GetEconomyIncome
local GetEconomyRequested = moho.aibrain_methods.GetEconomyRequested
local GetEconomyStored = moho.aibrain_methods.GetEconomyStored
local GetListOfUnits = moho.aibrain_methods.GetListOfUnits
local GetCurrentUnits = moho.aibrain_methods.GetCurrentUnits
local GiveResource = moho.aibrain_methods.GiveResource
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetThreatsAroundPosition = moho.aibrain_methods.GetThreatsAroundPosition
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
local GetConsumptionPerSecondMass = moho.unit_methods.GetConsumptionPerSecondMass
local GetConsumptionPerSecondEnergy = moho.unit_methods.GetConsumptionPerSecondEnergy
local GetProductionPerSecondMass = moho.unit_methods.GetProductionPerSecondMass
local GetProductionPerSecondEnergy = moho.unit_methods.GetProductionPerSecondEnergy
local VDist2Sq = VDist2Sq
local GetEconomyTrend = moho.aibrain_methods.GetEconomyTrend
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local RNGINSERT = table.insert
local RNGGETN = table.getn
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

local RNGAIBrainClass = AIBrain
AIBrain = Class(RNGAIBrainClass) {

    OnCreateAI = function(self, planName)
        RNGAIBrainClass.OnCreateAI(self, planName)
        local per = ScenarioInfo.ArmySetup[self.Name].AIPersonality
        if string.find(per, 'RNG') then
            --RNGLOG('* AI-RNG: This is RNG')
            self.RNG = true
            self.RNGDEBUG = false
        end
        if string.find(per, 'RNGStandardExperimental') then
            --RNGLOG('* AI-RNG: This is RNGEXP')
            self.RNGEXP = true
            self.RNGDEBUG = false
        end
    end,

    OnSpawnPreBuiltUnits = function(self)
        if not self.RNG then
            return RNGAIBrainClass.OnSpawnPreBuiltUnits(self)
        end
        local factionIndex = self:GetFactionIndex()
        local resourceStructures = nil
        local initialUnits = nil
        local posX, posY = self:GetArmyStartPos()

        if factionIndex == 1 then
            resourceStructures = {'UEB1103', 'UEB1103', 'UEB1103', 'UEB1103'}
            initialUnits = {'UEB0101', 'UEB1101', 'UEB1101', 'UEB1101', 'UEB1101'}
        elseif factionIndex == 2 then
            resourceStructures = {'UAB1103', 'UAB1103', 'UAB1103', 'UAB1103'}
            initialUnits = {'UAB0101', 'UAB1101', 'UAB1101', 'UAB1101', 'UAB1101'}
        elseif factionIndex == 3 then
            resourceStructures = {'URB1103', 'URB1103', 'URB1103', 'URB1103'}
            initialUnits = {'URB0101', 'URB1101', 'URB1101', 'URB1101', 'URB1101'}
        elseif factionIndex == 4 then
            resourceStructures = {'XSB1103', 'XSB1103', 'XSB1103', 'XSB1103'}
            initialUnits = {'XSB0101', 'XSB1101', 'XSB1101', 'XSB1101', 'XSB1101'}
        end

        if resourceStructures then
            -- Place resource structures down
            for k, v in resourceStructures do
                local unit = self:CreateResourceBuildingNearest(v, posX, posY)
                local unitBp = unit:GetBlueprint()
                if unit ~= nil and unitBp.Physics.FlattenSkirt then
                    unit:CreateTarmac(true, true, true, false, false)
                end
                if unit ~= nil then
                    if not self.StructurePool then
                        RUtils.CheckCustomPlatoons(self)
                    end
                    local StructurePool = self.StructurePool
                    self:AssignUnitsToPlatoon(StructurePool, {unit}, 'Support', 'none' )
                end
            end
        end

        if initialUnits then
            -- Place initial units down
            for k, v in initialUnits do
                local unit = self:CreateUnitNearSpot(v, posX, posY)
                if unit ~= nil and unit:GetBlueprint().Physics.FlattenSkirt then
                    unit:CreateTarmac(true, true, true, false, false)
                end
            end
        end

        self.PreBuilt = true
    end,

    InitializeSkirmishSystems = function(self)
        if not self.RNG then
            return RNGAIBrainClass.InitializeSkirmishSystems(self)
        end
        --RNGLOG('* AI-RNG: Custom Skirmish System for '..ScenarioInfo.ArmySetup[self.Name].AIPersonality)
        -- Make sure we don't do anything for the human player!!!
        if self.BrainType == 'Human' then
            return
        end

        -- TURNING OFF AI POOL PLATOON, I MAY JUST REMOVE THAT PLATOON FUNCTIONALITY LATER
        local poolPlatoon = self:GetPlatoonUniquelyNamed('ArmyPool')
        if poolPlatoon then
            poolPlatoon:TurnOffPoolAI()
        end
        --local mapSizeX, mapSizeZ = GetMapSize()
        --RNGLOG('Map X size is : '..mapSizeX..'Map Z size is : '..mapSizeZ)
        -- Stores handles to all builders for quick iteration and updates to all
        self.BuilderHandles = {}

        self.MapSize = 10
        local mapSizeX, mapSizeZ = GetMapSize()
        self.MapDimension = math.max(mapSizeX, mapSizeZ)
        if  mapSizeX > 1000 and mapSizeZ > 1000 then
            if self.RNGEXP then
                self.DefaultLandRatio = 0.2
                self.DefaultAirRatio = 0.3
                self.DefaultNavalRatio = 0.2
            else
                self.DefaultLandRatio = 0.5
                self.DefaultAirRatio = 0.4
                self.DefaultNavalRatio = 0.4
            end
            self.MapSize = 20
        elseif mapSizeX > 500 and mapSizeZ > 500 then
            if self.RNGEXP then
                self.DefaultLandRatio = 0.2
                self.DefaultAirRatio = 0.3
                self.DefaultNavalRatio = 0.2
            else
                self.DefaultLandRatio = 0.6
                self.DefaultAirRatio = 0.4
                self.DefaultNavalRatio = 0.4
            end
            --RNGLOG('10 KM Map Check true')
            self.MapSize = 10
        elseif mapSizeX > 200 and mapSizeZ > 200 then
            if self.RNGEXP then
                self.DefaultLandRatio = 0.2
                self.DefaultAirRatio = 0.3
                self.DefaultNavalRatio = 0.2
            else
                self.DefaultLandRatio = 0.7
                self.DefaultAirRatio = 0.3
                self.DefaultNavalRatio = 0.3
            end
            --RNGLOG('5 KM Map Check true')
            self.MapSize = 5
        end
        self.MapCenterPoint = { (ScenarioInfo.size[1] / 2), 0 ,(ScenarioInfo.size[2] / 2) }

        -- Condition monitor for the whole brain
        self.ConditionsMonitor = BrainConditionsMonitor.CreateConditionsMonitor(self)

        -- Economy monitor for new skirmish - stores out econ over time to get trend over 10 seconds
        self.EconomyData = {}
        self.GraphZones = { 
            FirstRun = true,
            HasRun = false
        }
        if self.MapSize <= 10 and self.RNGEXP then
            self.EconomyUpgradeSpendDefault = 0.35
            self.EconomyUpgradeSpend = 0.35
        elseif self.MapSize <= 10 then
            self.EconomyUpgradeSpendDefault = 0.25
            self.EconomyUpgradeSpend = 0.25
        elseif self.RNGEXP then
            self.EconomyUpgradeSpendDefault = 0.35
            self.EconomyUpgradeSpend = 0.35
        else
            self.EconomyUpgradeSpendDefault = 0.30
            self.EconomyUpgradeSpend = 0.30
        end
        self.EconomyTicksMonitor = 80
        self.EconomyCurrentTick = 1
        self.EconomyMonitorThread = self:ForkThread(self.EconomyMonitorRNG)
        self.EconomyOverTimeCurrent = {}
        --self.EconomyOverTimeThread = self:ForkThread(self.EconomyOverTimeRNG)
        self.EngineerAssistManagerActive = false
        self.EngineerAssistManagerEngineerCount = 0
        self.EngineerAssistManagerEngineerCountDesired = 0
        self.EngineerAssistManagerBuildPowerDesired = 5
        self.EngineerAssistManagerBuildPowerRequired = 0
        self.EngineerAssistManagerBuildPower = 0
        self.EngineerAssistManagerFocusCategory = false
        self.EngineerAssistManagerFocusAirUpgrade = false
        self.EngineerAssistManagerFocusLandUpgrade = false
        self.EngineerAssistManagerPriorityTable = {}
        self.EngineerDistributionTable = {
            BuildPower = 0,
            BuildStructure = 0,
            Assist = 0,
            Reclaim = 0,
            ReclaimStructure = 0,
            Expansion = 0,
            Repair = 0,
            Mass = 0,
            Total = 0
        }
        self.ProductionRatios = {
            Land = self.DefaultLandRatio,
            Air = self.DefaultAirRatio,
            Naval = self.DefaultNavalRatio,
        }
        self.earlyFlag = true
        self.cmanager = {
            income = {
                r  = {
                    m = 0,
                    e = 0,
                },
                t = {
                    m = 0,
                    e = 0,
                },
            },
            spend = {
                m = 0,
                e = 0,
            },
            categoryspend = {
                eng = 0,
                fact = {
                    Land = 0,
                    Air = 0,
                    Naval = 0
                },
                silo = 0,
                mex = {
                      T1 = 0,
                      T2 = 0,
                      T3 = 0
                      },
            },
            storage = {
                current = {
                    m = 0,
                    e = 0,
                },
                max = {
                    m = 0,
                    e = 0,
                },
            },
        }
        self.amanager = {
            Current = {
                Land = {
                    T1 = {
                        scout=0,
                        tank=0,
                        arty=0,
                        aa=0
                    },
                    T2 = {
                        tank=0,
                        mml=0,
                        aa=0,
                        shield=0,
                        stealth=0,
                        bot=0
                    },
                    T3 = {
                        tank=0,
                        sniper=0,
                        arty=0,
                        mml=0,
                        aa=0,
                        shield=0,
                        armoured=0
                    }
                },
                Air = {
                    T1 = {
                        scout=0,
                        interceptor=0,
                        bomber=0,
                        gunship=0
                    },
                    T2 = {
                        bomber=0,
                        gunship=0,
                        fighter=0,
                        mercy=0,
                        torpedo=0,
                    },
                    T3 = {
                        scout=0,
                        asf=0,
                        bomber=0,
                        gunship=0,
                        torpedo=0,
                        transport=0
                    }
                },
                Naval = {
                    T1 = {
                        frigate=0,
                        sub=0,
                        shard=0
                    },
                    T2 = {
                        tank=0,
                        mml=0,
                        aa=0,
                        shield=0
                    },
                    T3 = {
                        tank=0,
                        sniper=0,
                        arty=0,
                        mml=0,
                        aa=0,
                        shield=0
                    }
                },
            },
            Total = {
                Land = {
                    T1 = 0,
                    T2 = 0,
                    T3 = 0,
                },
                Air = {
                    T1 = 0,
                    T2 = 0,
                    T3 = 0,
                },
                Naval = {
                    T1 = 0,
                    T2 = 0,
                    T3 = 0,
                }
            },
            Type = {
                Land = {
                    scout=0,
                    tank=0,
                    sniper=0,
                    arty=0,
                    mml=0,
                    aa=0,
                    shield=0,
                    bot=0,
                    armoured=0
                },
                Air = {
                    scout=0,
                    interceptor=0,
                    bomber=0,
                    gunship=0,
                    fighter=0,
                    mercy=0,
                    torpedo=0,
                    asf=0,
                    transport=0,
                },
                Naval = {
                    frigate=0,
                    sub=0,
                    cruiser=0,
                    destroyer=0,
                    battleship=0,
                    shard=0,
                    shield=0
                },
            },
            Ratios = {
                [1] = {
                    Land = {
                        T1 = {
                            scout=15,
                            tank=65,
                            arty=15,
                            aa=12,
                            total=0
                        },
                        T2 = {
                            tank=55,
                            mml=5,
                            bot=20,
                            aa=10,
                            shield=10,
                            total=0
                        },
                        T3 = {
                            tank=30,
                            armoured=40,
                            mml=5,
                            arty=15,
                            aa=10,
                            total=0
                        }
                    },
                    Air = {
                        T1 = {
                            scout=20,
                            interceptor=60,
                            bomber=20,
                            total=0
                        },
                        T2 = {
                            bomber=30,
                            gunship=30,
                            torpedo=0,
                            total=0
                        },
                        T3 = {
                            scout=11,
                            asf=55,
                            bomber=15,
                            gunship=10,
                            transport=5,
                            total=0
                        }
                    },
                    Naval = {
                        T1 = {
                            frigate=70,
                            sub=30,
                            total=0
                        },
                        T2 = {
                            destroyer=70,
                            cruiser=30,
                            subhunter=10,
                            total=0
                        },
                        T3 = {
                            battleship=80,
                            total=0
                        }
                    },
                },
                [2] = {
                    Land = {
                        T1 = {
                            scout=15,
                            tank=65,
                            arty=15,
                            aa=12,
                            total=0
                        },
                        T2 = {
                            tank=75,
                            mml=5,
                            aa=10,
                            shield=10,
                            total=0
                        },
                        T3 = {
                            tank=45,
                            arty=15,
                            aa=10,
                            sniper=30,
                            total=0
                        }
                    },
                    Air = {
                        T1 = {
                            scout=20,
                            interceptor=60,
                            bomber=20,
                            total=0
                        },
                        T2 = {
                            fighter=85,
                            gunship=15,
                            torpedo=0,
                            total=0
                        },
                        T3 = {
                            scout=11,
                            asf=60,
                            bomber=15,
                            gunship=10,
                            torpedo=0,
                            total=0
                        }
                    },
                    Naval = {
                        T1 = {
                            frigate=70,
                            shard= 0,
                            sub=30,
                            total=0
                        },
                        T2 = {
                            destroyer=70,
                            cruiser=30,
                            subhunter=10,
                            total=0
                        },
                        T3 = {
                            battleship=80,
                            total=0
                        }
                    },
                },
                [3] = {
                    Land = {
                        T1 = {
                            scout=15,
                            tank=65,
                            arty=15,
                            aa=12,
                            total=0
                        },
                        T2 = {
                            tank=55,
                            mml=5,
                            bot=25,
                            aa=10,
                            stealth=5,
                            total=0
                        },
                        T3 = {
                            tank=30,
                            armoured=40,
                            arty=15,
                            aa=10,
                            total=0
                        }
                    },
                    Air = {
                        T1 = {
                            scout=15,
                            interceptor=55,
                            bomber=20,
                            gunship=10,
                            total=0
                        },
                        T2 = {
                            bomber=45,
                            gunship=15,
                            torpedo=0,
                            total=0
                        },
                        T3 = {
                            scout=11,
                            asf=60,
                            bomber=15,
                            gunship=10,
                            total=0
                        }
                    },
                    Naval = {
                        T1 = {
                            frigate=70,
                            sub=30,
                            total=0
                        },
                        T2 = {
                            destroyer=70,
                            cruiser=30,
                            subhunter=10,
                            total=0
                        },
                        T3 = {
                            battleship=80,
                            total=0
                        }
                    },
                },
                [4] = {
                    Land = {
                        T1 = {
                            scout=15,
                            tank=65,
                            arty=15,
                            aa=12,
                            total=0
                        },
                        T2 = {
                            tank=75,
                            mml=10,
                            aa=15,
                            total=0
                        },
                        T3 = {
                            tank=45,
                            arty=10,
                            aa=10,
                            sniper=30,
                            shield=5,
                            total=0
                        }
                    },
                    Air = {
                        T1 = {
                            scout=20,
                            interceptor=60,
                            bomber=20,
                            total=0
                        },
                        T2 = {
                            bomber=50,
                            gunship=15,
                            torpedo=0,
                            total=0
                        },
                        T3 = {
                            scout=11,
                            asf=65,
                            bomber=15,
                            torpedo=0,
                            total=0
                        }
                    },
                    Naval = {
                        T1 = {
                            frigate=70,
                            sub=30,
                            total=0
                        },
                        T2 = {
                            destroyer=70,
                            cruiser=30,
                            subhunter=10,
                            total=0
                        },
                        T3 = {
                            battleship=80,
                            total=0
                        }
                    },
                },
                [5] = {
                    Land = {
                        T1 = {
                            scout=15,
                            tank=65,
                            arty=15,
                            aa=12,
                            total=0
                        },
                        T2 = {
                            tank=55,
                            mml=5,
                            bot=20,
                            aa=10,
                            shield=10,
                            total=0
                        },
                        T3 = {
                            tank=30,
                            armoured=40,
                            mml=5,
                            arty=15,
                            aa=10,
                            total=0
                        }
                    },
                    Air = {
                        T1 = {
                            scout=15,
                            interceptor=60,
                            bomber=25,
                            total=0
                        },
                        T2 = {
                            bomber=75,
                            gunship=15,
                            torpedo=0,
                            total=0
                        },
                        T3 = {
                            scout=11,
                            asf=55,
                            bomber=15,
                            gunship=10,
                            total=0
                        }
                    },
                    Naval = {
                        T1 = {
                            frigate=15,
                            sub=60,
                            total=0
                        },
                        T2 = {
                            destroyer=70,
                            cruiser=30,
                            subhunter=10,
                            total=0
                        },
                        T3 = {
                            scout=11,
                            asf=55,
                            bomber=15,
                            gunship=10,
                            transport=5,
                            total=0
                        }
                    },
                },
            },
        }
        self.smanager = {
            fact = {
                Land =
                {
                    T1 = 0,
                    T2 = 0,
                    T3 = 0
                },
                Air = {
                    T1=0,
                    T2=0,
                    T3=0
                },
                Naval= {
                    T1=0,
                    T2=0,
                    T3=0
                }
            },
            --The mex list is indexed by zone so the AI can easily calculate how many mexes it has per zone.
            mex = {
                
            },
            pgen = {
                T1=0,
                T2=0,
                T3=0
            },
            hydro = {

            },
            silo = {
                T2=0,
                T3=0
            },
            fabs= {
                T2=0,
                T3=0
            }
        }
        self.emanager = {
            mex = {

            }
        }

        self.LowEnergyMode = false
        self.EcoManager = {
            EcoManagerTime = 30,
            EcoManagerStatus = 'ACTIVE',
            ExtractorUpgradeLimit = {
                TECH1 = 1,
                TECH2 = 1
            },
            ExtractorsUpgrading = {TECH1 = 0, TECH2 = 0},
            CoreMassMarkerCount = 0,
            TotalCoreExtractors = 0,
            CoreExtractorT3Percentage = 0,
            CoreExtractorT2Count = 0,
            CoreExtractorT3Count = 0,
            EcoMultiplier = 1,
            EcoMassUpgradeTimeout = 300,
            EcoPowerPreemptive = false,
        }
        self.EcoManager.PowerPriorityTable = {
            ENGINEER = 12,
            STATIONPODS = 11,
            TML = 10,
            SHIELD = 8,
            AIR = 9,
            NAVAL = 5,
            RADAR = 3,
            MASSEXTRACTION = 4,
            MASSFABRICATION = 7,
            NUKE = 6,
            LAND = 2,
        }
        self.EcoManager.MassPriorityTable = {
            Advantage = {
                --MASSEXTRACTION = 5,
                TML = 12,
                STATIONPODS = 10,
                ENGINEER = 11,
                AIR = 7,
                NAVAL = 8,
                LAND = 6,
                NUKE = 9,
                },
            Disadvantage = {
                --MASSEXTRACTION = 8,
                TML = 12,
                STATIONPODS = 10,
                ENGINEER = 11,
                NAVAL = 8,
                NUKE = 9,
            }
        }

        self.DefensiveSupport = {}

        --Tactical Monitor
        self.TacticalMonitor = {
            TacticalMonitorStatus = 'ACTIVE',
            TacticalLocationFound = false,
            TacticalLocations = {},
            TacticalTimeout = 37,
            TacticalMonitorTime = 180,
            TacticalMassLocations = {},
            TacticalUnmarkedMassGroups = {},
            TacticalSACUMode = false,
        }
        -- Intel Data
        self.EnemyIntel = {}
        self.EnemyIntel.NavalRange = {
            Position = {},
            Range = 0,
        }
        self.EnemyIntel.FrigateRaid = false
        self.EnemyIntel.FrigateRaidMarkers = {}
        self.EnemyIntel.EnemyCount = 0
        self.EnemyIntel.ACUEnemyClose = false
        self.EnemyIntel.ACU = {}
        self.EnemyIntel.Phase = 1
        self.EnemyIntel.DirectorData = {
            Strategic = {},
            Energy = {},
            Intel = {},
            Defense = {},
            Mass = {},
            Factory = {},
            Combat = {},
        }
        --RNGLOG('Director Data'..repr(self.EnemyIntel.DirectorData))
        --RNGLOG('Director Energy Table '..repr(self.EnemyIntel.DirectorData.Energy))
        self.EnemyIntel.EnemyStartLocations = {}
        self.EnemyIntel.EnemyThreatLocations = {}
        self.EnemyIntel.EnemyThreatRaw = {}
        self.EnemyIntel.ChokeFlag = false
        self.EnemyIntel.EnemyFireBaseDetected = false
        self.EnemyIntel.EnemyAirFireBaseDetected = false
        self.EnemyIntel.ChokePoints = {}
        self.EnemyIntel.EnemyThreatCurrent = {
            Air = 0,
            AntiAir = 0,
            Land = 0,
            Experimental = 0,
            Extractor = 0,
            ExtractorCount = 0,
            Naval = 0,
            NavalSub = 0,
            DefenseAir = 0,
            DefenseSurface = 0,
            DefenseSub = 0,
            ACUGunUpgrades = 0,
        }
        local selfIndex = self:GetArmyIndex()
        for _, v in ArmyBrains do
            self.EnemyIntel.ACU[v:GetArmyIndex()] = {
                Position = {},
                DistanceToBase = 0,
                LastSpotted = 0,
                Threat = 0,
                Hp = 0,
                OnField = false,
                CloseCombat = false,
                Gun = false,
                Ally = IsAlly(selfIndex, v:GetArmyIndex()),
            }
        end

        self.BrainIntel = {}
        local selfStartPosX, selfStartPosY = self:GetArmyStartPos()
        self.BrainIntel.StartPos = { selfStartPosX, selfStartPosY }
        self.BrainIntel.MilitaryRange = BaseMilitaryArea
        self.BrainIntel.ExpansionWatchTable = {}
        self.BrainIntel.DynamicExpansionPositions = {}
        self.BrainIntel.IMAPConfig = {
            OgridRadius = 0,
            IMAPSize = 0,
            ResolveBlocks = 0,
            ThresholdMult = 0,
            Rings = 0,
        }
        self.BrainIntel.AllyCount = 0
        self.BrainIntel.LandPhase = 1
        self.BrainIntel.AirPhase = 1
        self.BrainIntel.NavalPhase = 1
        self.BrainIntel.MassMarker = 0
        self.BrainIntel.MassSharePerPlayer = 0
        self.BrainIntel.AirAttackMode = false
        self.BrainIntel.SelfThreat = {}
        self.BrainIntel.Average = {
            Air = 0,
            Land = 0,
            Experimental = 0,
        }
        self.BrainIntel.SelfThreat = {
            Air = {},
            Extractor = 0,
            ExtractorCount = 0,
            MassMarker = 0,
            MassMarkerBuildable = 0,
            MassMarkerBuildableTable = {},
            AllyExtractorTable = {},
            AllyExtractorCount = 0,
            AllyExtractor = 0,
            AllyLandThreat = 0,
            BaseThreatCaution = false,
            AntiAirNow = 0,
            AirNow = 0,
            LandNow = 0,
            NavalNow = 0,
            NavalSubNow = 0,
        }
        self.BrainIntel.ActiveExpansion = false
        -- Structure Upgrade properties
        self.UpgradeIssued = 0
        self.EarlyQueueCompleted = false
        self.IntelTriggerList = {}
        
        self.UpgradeIssuedPeriod = 100

        if mapSizeX < 1000 and mapSizeZ < 1000  then
            self.UpgradeIssuedLimit = 1
            self.EcoManager.ExtractorUpgradeLimit.TECH1 = 1
        else
            self.UpgradeIssuedLimit = 2
            self.EcoManager.ExtractorUpgradeLimit.TECH1 = 2
        end
        if self.CheatEnabled then
            self.EcoManager.EcoMultiplier = tonumber(ScenarioInfo.Options.BuildMult)
        end
       --LOG('Build Multiplier now set, this impacts many economy checks that look at income '..self.EcoManager.EcoMultiplier)

        self.MapWaterRatio = self:GetMapWaterRatio()
        LOG('Water Ratio is '..self.MapWaterRatio)

        -- Table to holding the starting reclaim
        self.StartReclaimTable = {}
        self.StartReclaimTotal = 0
        self.StartReclaimCurrent = 0
        self.StartReclaimTaken = false
        self.MapReclaimTable = {}
        self.Zones = { }

        self.UpgradeMode = 'Normal'

        -- ACU Support Data
        self.ACUSupport = {}
        self.ACUSupport.EnemyACUClose = 0
        self.ACUMaxSearchRadius = 0
        self.ACUSupport.Supported = false
        self.ACUSupport.PlatoonCount = 0
        self.ACUSupport.Platoons = {}
        self.ACUSupport.Position = {}
        self.ACUSupport.TargetPosition = false
        self.ACUSupport.ReturnHome = true

        -- Misc
        self.ReclaimEnabled = true
        self.ReclaimLastCheck = 0
        
        -- Add default main location and setup the builder managers
        self.NumBases = 0 -- AddBuilderManagers will increase the number

        self.BuilderManagers = {}
        SUtils.AddCustomUnitSupport(self)
        self:AddBuilderManagers(self:GetStartVector3f(), 100, 'MAIN', false)
        -- Generates the zones and updates the resource marker table with Zone IDs
        --IntelManagerRNG.GenerateMapZonesRNG(self)

        if RUtils.InitialMassMarkersInWater(self) then
            --RNGLOG('* AI-RNG: Map has mass markers in water')
            self.MassMarkersInWater = true
        else
            --RNGLOG('* AI-RNG: Map does not have mass markers in water')
            self.MassMarkersInWater = false
        end

        --[[ Below was used prior to Uveso adding the expansion generator to provide expansion in locations with multiple mass markers
        RUtils.TacticalMassLocations(self)
        RUtils.MarkTacticalMassLocations(self)
        local MassGroupMarkers = RUtils.GenerateMassGroupMarkerLocations(self)
        if MassGroupMarkers then
            if RNGGETN(MassGroupMarkers) > 0 then
                RUtils.CreateMarkers('Unmarked Expansion', MassGroupMarkers)
            end
        end]]
        
        self:IMAPConfigurationRNG()
        -- Begin the base monitor process

        self:BaseMonitorInitializationRNG()

        local plat = self:GetPlatoonUniquelyNamed('ArmyPool')
        plat:ForkThread(plat.BaseManagersDistressAIRNG)
        self.DeadBaseThread = self:ForkThread(self.DeadBaseMonitor)
        self.EnemyPickerThread = self:ForkThread(self.PickEnemyRNG)
        self:ForkThread(self.CivilianPDCheckRNG)
        self:ForkThread(self.EcoPowerManagerRNG)
        self:ForkThread(self.EcoPowerPreemptiveRNG)
        self:ForkThread(self.EcoMassManagerRNG)
        self:ForkThread(self.BasePerimeterMonitorRNG)
        self:ForkThread(self.EnemyChokePointTestRNG)
        self:ForkThread(self.EngineerAssistManagerBrainRNG)
        self:ForkThread(self.AllyEconomyHelpThread)
        self:ForkThread(self.HeavyEconomyRNG)
        self:ForkThread(self.FactoryEcoManagerRNG)
        self:ForkThread(RUtils.CountSoonMassSpotsRNG)
        self:ForkThread(RUtils.LastKnownThread)
        self:ForkThread(Mapping.SetMarkerInformation)
        self:ForkThread(IntelManagerRNG.MapReclaimAnalysis)
        self:CalculateMassMarkersRNG()
        self:ForkThread(self.SetupIntelTriggersRNG)
        self:ForkThread(IntelManagerRNG.ExpansionIntelScanRNG)
        self:ForkThread(IntelManagerRNG.InitialNavalAttackCheck)
        self:ForkThread(self.DynamicExpansionRequiredRNG)
        self.ZonesInitialized = false
        self:ForkThread(self.ZoneSetup)
        self.IntelManager = IntelManagerRNG.CreateIntelManager(self)
        self.IntelManager:Run()
        self.StructureManager = StructureManagerRNG.CreateStructureManager(self)
        self.StructureManager:Run()
        
    end,


    TestThread = function(self)
        -- just a test for visually seeing grids
        local startX, startZ = self:GetArmyStartPos()
        local engPos = {startX, 0, startZ}
        local reclaimGrid = {
            {engPos[1], 0 ,engPos[3]},
            {engPos[1], 0 ,engPos[3] + 15},
            {engPos[1] + 15, 0 ,engPos[3] + 15},
            {engPos[1] + 15, 0, engPos[3]},
            {engPos[1] + 15, 0, engPos[3] - 15},
            {engPos[1], 0, engPos[3] - 15},
            {engPos[1] - 15, 0, engPos[3] - 15},
            {engPos[1] - 15, 0, engPos[3]},
            {engPos[1] - 15, 0, engPos[3] + 15},
            {engPos[1], 0 ,engPos[3] + 25},
            {engPos[1] + 15, 0 ,engPos[3] + 25},
            {engPos[1] + 25, 0 ,engPos[3] + 25},
            {engPos[1] + 25, 0 ,engPos[3] + 15},
            {engPos[1] + 25, 0, engPos[3]},
            {engPos[1] + 25, 0, engPos[3] - 15},
            {engPos[1] + 25, 0, engPos[3] - 25},
            {engPos[1] + 15, 0, engPos[3] - 25},
            {engPos[1], 0, engPos[3] - 25},
            {engPos[1] - 15, 0, engPos[3] - 25},
            {engPos[1] - 25, 0, engPos[3] - 25},
            {engPos[1] - 25, 0, engPos[3] - 15},
            {engPos[1] - 25, 0, engPos[3]},
            {engPos[1] - 25, 0, engPos[3] + 15},
            {engPos[1] - 15, 0, engPos[3] + 25},
            {engPos[1] - 25, 0, engPos[3] + 25},
        }
        while true do
            for k, square in reclaimGrid do
                DrawCircle(square, 10, '0000FF')
            end
            WaitTicks(2)
        end

    end,

    drawMainRestricted = function(self)
        while true do
            DrawCircle(self.BuilderManagers['MAIN'].Position, BaseRestrictedArea, '0000FF')
            WaitTicks(2)
        end
    end,

    ZoneSetup = function(self)
        WaitTicks(1)
        self.Zones.Land = MAP:GetZoneSet('RNGLandResourceSet',1)
        self.Zones.Naval = MAP:GetZoneSet('RNGNavalResourceSet',2)
        self.ZonesInitialized = true
        --self:ForkThread(import('/mods/RNGAI/lua/AI/RNGDebug.lua').DrawReclaimGrid)
    end,

    WaitForZoneInitialization = function(self)
        while not self.ZonesInitialized do
           --RNGLOG('Zones table is empty, waiting')
            coroutine.yield(20)
        end
    end,


    EconomyMonitorRNG = function(self)
        -- This over time thread is based on Sprouto's LOUD AI.
        self.EconomyData = { ['EnergyIncome'] = {}, ['EnergyRequested'] = {}, ['EnergyStorage'] = {}, ['EnergyTrend'] = {}, ['MassIncome'] = {}, ['MassRequested'] = {}, ['MassStorage'] = {}, ['MassTrend'] = {}, ['Period'] = 300 }
        -- number of sample points
        -- local point
        local samplerate = 10
        local samples = self.EconomyData['Period'] / samplerate
    
        -- create the table to store the samples
        for point = 1, samples do
            self.EconomyData['EnergyIncome'][point] = 0
            self.EconomyData['EnergyRequested'][point] = 0
            self.EconomyData['EnergyStorage'][point] = 0
            self.EconomyData['EnergyTrend'][point] = 0
            self.EconomyData['MassIncome'][point] = 0
            self.EconomyData['MassRequested'][point] = 0
            self.EconomyData['MassStorage'][point] = 0
            self.EconomyData['MassTrend'][point] = 0
        end    
    
        local RNGMIN = math.min
        local RNGMAX = math.max
    
        -- array totals
        local eIncome = 0
        local mIncome = 0
        local eRequested = 0
        local mRequested = 0
        local eStorage = 0
        local mStorage = 0
        local eTrend = 0
        local mTrend = 0
    
        -- this will be used to multiply the totals
        -- to arrive at the averages
        local samplefactor = 1/samples
    
        local EcoData = self.EconomyData
    
        local EcoDataEnergyIncome = EcoData['EnergyIncome']
        local EcoDataMassIncome = EcoData['MassIncome']
        local EcoDataEnergyRequested = EcoData['EnergyRequested']
        local EcoDataMassRequested = EcoData['MassRequested']
        local EcoDataEnergyTrend = EcoData['EnergyTrend']
        local EcoDataMassTrend = EcoData['MassTrend']
        local EcoDataEnergyStorage = EcoData['EnergyStorage']
        local EcoDataMassStorage = EcoData['MassStorage']
        
        local e,m
    
        while true do
    
            for point = 1, samples do
    
                -- remove this point from the totals
                eIncome = eIncome - EcoDataEnergyIncome[point]
                mIncome = mIncome - EcoDataMassIncome[point]
                eRequested = eRequested - EcoDataEnergyRequested[point]
                mRequested = mRequested - EcoDataMassRequested[point]
                eTrend = eTrend - EcoDataEnergyTrend[point]
                mTrend = mTrend - EcoDataMassTrend[point]
                
                -- insert the new data --
                EcoDataEnergyIncome[point] = GetEconomyIncome( self, 'ENERGY')
                EcoDataMassIncome[point] = GetEconomyIncome( self, 'MASS')
                EcoDataEnergyRequested[point] = GetEconomyRequested( self, 'ENERGY')
                EcoDataMassRequested[point] = GetEconomyRequested( self, 'MASS')
    
                e = GetEconomyTrend( self, 'ENERGY')
                m = GetEconomyTrend( self, 'MASS')
    
                if e then
                    EcoDataEnergyTrend[point] = e
                else
                    EcoDataEnergyTrend[point] = 0.1
                end
                
                if m then
                    EcoDataMassTrend[point] = m
                else
                    EcoDataMassTrend[point] = 0.1
                end
    
                -- add the new data to totals
                eIncome = eIncome + EcoDataEnergyIncome[point]
                mIncome = mIncome + EcoDataMassIncome[point]
                eRequested = eRequested + EcoDataEnergyRequested[point]
                mRequested = mRequested + EcoDataMassRequested[point]
                eTrend = eTrend + EcoDataEnergyTrend[point]
                mTrend = mTrend + EcoDataMassTrend[point]
                
                -- calculate new OverTime values --
                self.EconomyOverTimeCurrent.EnergyIncome = eIncome * samplefactor
                self.EconomyOverTimeCurrent.MassIncome = mIncome * samplefactor
                self.EconomyOverTimeCurrent.EnergyRequested = eRequested * samplefactor
                self.EconomyOverTimeCurrent.MassRequested = mRequested * samplefactor
                self.EconomyOverTimeCurrent.EnergyEfficiencyOverTime = RNGMIN( (eIncome * samplefactor) / (eRequested * samplefactor), 2)
                self.EconomyOverTimeCurrent.MassEfficiencyOverTime = RNGMIN( (mIncome * samplefactor) / (mRequested * samplefactor), 2)
                self.EconomyOverTimeCurrent.EnergyTrendOverTime = eTrend * samplefactor
                self.EconomyOverTimeCurrent.MassTrendOverTime = mTrend * samplefactor
                
                coroutine.yield(samplerate)
            end
        end
    end,
    
    AddBuilderManagers = function(self, position, radius, baseName, useCenter)
        if not self.RNG then
            return RNGAIBrainClass.AddBuilderManagers(self, position, radius, baseName, useCenter)
        end

        -- Set the layer of the builder manager so that factory managers and platoon managers know if we should be graphing to land or naval production.
        -- Used for identifying if we can graph to an enemy factory for multi landmass situations
        local baseLayer = 'Land'
		position[2] = GetTerrainHeight( position[1], position[3] )
        if GetSurfaceHeight( position[1], position[3] ) > position[2] then
            position[2] = GetSurfaceHeight( position[1], position[3] )
			baseLayer = 'Water'
        end
        self:ForkThread(self.GetGraphArea, position, baseName, baseLayer)
        self:ForkThread(self.GetBaseZone, position, baseName, baseLayer)

        self.BuilderManagers[baseName] = {
            FactoryManager = FactoryManager.CreateFactoryBuilderManager(self, baseName, position, radius, useCenter),
            PlatoonFormManager = PlatoonFormManager.CreatePlatoonFormManager(self, baseName, position, radius, useCenter),
            EngineerManager = EngineerManager.CreateEngineerManager(self, baseName, position, radius),
            StrategyManager = StratManager.CreateStrategyManager(self, baseName, position, radius),
            BuilderHandles = {},
            Position = position,
            Layer = baseLayer,
            GraphArea = false,
            BaseType = Scenario.MasterChain._MASTERCHAIN_.Markers[baseName].type or 'MAIN',
        }
        self.NumBases = self.NumBases + 1
    end,

    GetGraphArea = function(self, position, baseName, baseLayer)
        -- This will set the graph area of the factory manager so we don't need to look it up every time
        -- Needs to wait a while for the RNGArea properties to be populated
        local graphAreaSet = false
        while not graphAreaSet do
            local graphArea
            if baseLayer then
                if baseLayer == 'Water' then
                    graphArea = GetClosestPathNodeInRadiusByLayerRNG(position, 30, 'Water')
                else
                    graphArea = GetClosestPathNodeInRadiusByLayerRNG(position, 30, 'Land')
                end
            end
            if not graphArea.RNGArea then
                WARN('Missing RNGArea for builder manager land node or no path markers')
            end
            if graphArea.RNGArea then
                --RNGLOG('Graph Area for buildermanager is '..graphArea.RNGArea)
                graphAreaSet = true
                self.BuilderManagers[baseName].GraphArea = graphArea.RNGArea
            end
            if not graphAreaSet then
                --RNGLOG('Graph Area not set yet')
                coroutine.yield(30)
            end
        end
    end,

    GetBaseZone = function(self, position, baseName, baseLayer)
        -- This will set the zone of the factory manager so we don't need to look it up every time
        -- Needs to wait a while for the RNGArea properties to be populated
        local zone
        local zoneSet = false
        while not zoneSet do
            if baseLayer then
                if baseLayer == 'Water' then
                    zone = MAP:GetZoneID(position,self.Zones.Naval.index)
                else
                    zone = MAP:GetZoneID(position,self.Zones.Land.index)
                end
            end
            if not zone then
                WARN('Missing zone for builder manager land node or no path markers')
            end
            if zone then
                RNGLOG('Zone set for builder manager')
                self.BuilderManagers[baseName].Zone = zone
                RNGLOG('Zone is '..self.BuilderManagers[baseName].Zone)
                zoneSet = true
            else
                RNGLOG('No zone for builder manager')
            end
            coroutine.yield(30)
        end
    end,

    CalculateMassMarkersRNG = function(self)
        local MassMarker = {}
        local massMarkerBuildable = 0
        local markerCount = 0
        local graphCheck = false
        local coreMassMarkers = 0
        local massMarkers = GetMarkersRNG()
        
        for _, v in massMarkers do
            if v.type == 'Mass' then
                if v.RNGArea and not self.GraphZones.FirstRun and not self.GraphZones.HasRun then
                    graphCheck = true
                    if not self.GraphZones[v.RNGArea] then
                        self.GraphZones[v.RNGArea] = {}
                        self.GraphZones[v.RNGArea].MassMarkers = {}
                        if self.GraphZones[v.RNGArea].MassMarkersInZone == nil then
                            self.GraphZones[v.RNGArea].MassMarkersInZone = 0
                        end
                    end
                    RNGINSERT(self.GraphZones[v.RNGArea].MassMarkers, v)
                    self.GraphZones[v.RNGArea].MassMarkersInZone = self.GraphZones[v.RNGArea].MassMarkersInZone + 1
                    if VDist2Sq(v.position[1], v.position[3], self.BrainIntel.StartPos[1], self.BrainIntel.StartPos[2]) < 2500 then
                        coreMassMarkers = coreMassMarkers + 1
                    end
                end
                if CanBuildStructureAt(self, 'ueb1103', v.position) then
                    massMarkerBuildable = massMarkerBuildable + 1
                    RNGINSERT(MassMarker, v)
                end
                markerCount = markerCount + 1
            end
            if not v.zoneid and self.ZonesInitialized then
                if RUtils.PositionOnWater(v.position[1], v.position[3]) then
                    -- tbd define water based zones
                    v.zoneid = 'water'
                else
                    v.zoneid = MAP:GetZoneID(v.position,self.Zones.Land.index)
                end
            end
        end
        if graphCheck then
            self.GraphZones.HasRun = true
            self.EcoManager.CoreMassMarkerCount = coreMassMarkers
            self.BrainIntel.MassSharePerPlayer = markerCount / (self.EnemyIntel.EnemyCount + self.BrainIntel.AllyCount)
        end
        self.BrainIntel.SelfThreat.MassMarker = markerCount
        self.BrainIntel.SelfThreat.MassMarkerBuildable = massMarkerBuildable
        self.BrainIntel.SelfThreat.MassMarkerBuildableTable = MassMarker
        --RNGLOG('self.BrainIntel.SelfThreat.MassMarker '..self.BrainIntel.SelfThreat.MassMarker)
        --RNGLOG('self.BrainIntel.SelfThreat.MassMarkerBuildable '..self.BrainIntel.SelfThreat.MassMarkerBuildable)
    end,

    BaseMonitorThreadRNG = function(self)
        
        while true do
            if self.BaseMonitor.BaseMonitorStatus == 'ACTIVE' then
                self:BaseMonitorCheckRNG()
            end
            coroutine.yield(40)
        end
    end,

    BaseMonitorInitializationRNG = function(self, spec)
        self.BaseMonitor = {
            BaseMonitorStatus = 'ACTIVE',
            BaseMonitorPoints = {},
            AlertSounded = false,
            AlertsTable = {},
            AlertLocation = false,
            AlertSoundedThreat = 0,
            ActiveAlerts = 0,

            PoolDistressRange = 75,
            PoolReactionTime = 7,

            -- Variables for checking a radius for enemy units
            UnitRadiusThreshold = spec.UnitRadiusThreshold or 3,
            UnitCategoryCheck = spec.UnitCategoryCheck or (categories.MOBILE - (categories.SCOUT + categories.ENGINEER)),
            UnitCheckRadius = spec.UnitCheckRadius or 40,

            -- Threat level must be greater than this number to sound a base alert
            AlertLevel = spec.AlertLevel or 0,
            -- Delay time for checking base
            BaseMonitorTime = 11,
            -- Default distance a platoon will travel to help around the base
            DefaultDistressRange = spec.DefaultDistressRange or 75,
            -- Default how often platoons will check if the base is under duress
            PlatoonDefaultReactionTime = spec.PlatoonDefaultReactionTime or 5,
            -- Default duration for an alert to time out
            DefaultAlertTimeout = spec.DefaultAlertTimeout or 5,

            PoolDistressThreshold = 1,

            -- Monitor platoons for help
            PlatoonDistressTable = {},
            ZoneAlertTable = {},
            PlatoonDistressThread = false,
            PlatoonAlertSounded = false,
            ZoneAlertSounded = false,
        }
        self:ForkThread(self.BaseMonitorThreadRNG)
        self:ForkThread(self.TacticalMonitorInitializationRNG)
        self:ForkThread(self.TacticalAnalysisThreadRNG)
        self:ForkThread(self.BaseMonitorZoneThreatThreadRNG)
    end,

    GetStructureVectorsRNG = function(self)
        -- This will get the closest IMAPposition  based on where the structure is. Though I don't think it works on 5km maps because the imap grid is different.
        local structures = GetListOfUnits(self, categories.STRUCTURE - categories.DEFENSE - categories.WALL - categories.MASSEXTRACTION, false)
        local tempGridPoints = {}
        local indexChecker = {}
        for k, v in structures do
            if not v.Dead then
                local pos = AIUtils.GetUnitBaseStructureVector(v)
                if pos then
                    if not indexChecker[pos[1]] then
                        indexChecker[pos[1]] = {}
                    end
                    if not indexChecker[pos[1]][pos[3]] then
                        indexChecker[pos[1]][pos[3]] = true
                        RNGINSERT(tempGridPoints, pos)
                    end
                end
            end
        end
        return tempGridPoints
    end,

    BaseMonitorCheckRNG = function(self)
        
        local gameTime = GetGameTimeSeconds()
        if gameTime < 300 then
            -- default monitor spec
        elseif gameTime > 300 then
            self.BaseMonitor.PoolDistressRange = 130
            self.AlertLevel = 5
        end
        local alertThreat = self.BaseMonitor.AlertLevel
        if self.BasePerimeterMonitor then
            for k, v in self.BasePerimeterMonitor do
                if self.BasePerimeterMonitor[k].LandUnits > 0 then
                    if self.BasePerimeterMonitor[k].LandThreat > alertThreat then
                        if not self.BaseMonitor.AlertsTable[k] then
                            self.BaseMonitor.AlertsTable[k] = {}
                        end
                        if not self.BaseMonitor.AlertsTable[k]['Land'] then
                            self.BaseMonitor.AlertsTable[k]['Land'] = { Location = k, Position = self.BuilderManagers[k].FactoryManager.Location, Threat = self.BasePerimeterMonitor[k].LandThreat, Type = 'Land' }
                            self.BaseMonitor.AlertSounded = true
                            self:ForkThread(self.BaseMonitorAlertTimeoutRNG, self.BuilderManagers[k].FactoryManager.Location, k, 'Land')
                            self.BaseMonitor.ActiveAlerts = self.BaseMonitor.ActiveAlerts + 1
                        end
                    end
                end
                if self.BasePerimeterMonitor[k].AntiSurfaceAirUnits > 0 then
                    if self.BasePerimeterMonitor[k].AirThreat > alertThreat then
                        if not self.BaseMonitor.AlertsTable[k] then
                            self.BaseMonitor.AlertsTable[k] = {}
                        end
                        if not self.BaseMonitor.AlertsTable[k]['Air'] then
                            self.BaseMonitor.AlertsTable[k]['Air'] = { Location = k, Position = self.BuilderManagers[k].FactoryManager.Location, Threat = self.BasePerimeterMonitor[k].AirThreat, Type = 'Air' }
                            self.BaseMonitor.AlertSounded = true
                            self:ForkThread(self.BaseMonitorAlertTimeoutRNG, self.BuilderManagers[k].FactoryManager.Location, k, 'Air')
                            self.BaseMonitor.ActiveAlerts = self.BaseMonitor.ActiveAlerts + 1
                        end
                    end
                end
                if self.BasePerimeterMonitor[k].NavalUnits > 0 then
                    if self.BasePerimeterMonitor[k].NavalThreat > alertThreat then
                        if not self.BaseMonitor.AlertsTable[k] then
                            self.BaseMonitor.AlertsTable[k] = {}
                        end
                        if not self.BaseMonitor.AlertsTable[k]['Naval'] then
                            self.BaseMonitor.AlertsTable[k]['Naval'] = { Location = k, Position = self.BuilderManagers[k].FactoryManager.Location, Threat = self.BasePerimeterMonitor[k].NavalThreat, Type = 'Naval' }
                            self.BaseMonitor.AlertSounded = true
                            self:ForkThread(self.BaseMonitorAlertTimeoutRNG, self.BuilderManagers[k].FactoryManager.Location, k, 'Naval')
                            self.BaseMonitor.ActiveAlerts = self.BaseMonitor.ActiveAlerts + 1
                        end
                    end
                end
            end
        end
    end,

    BaseMonitorAlertTimeoutRNG = function(self, pos, location, type)
        local timeout = self.BaseMonitor.DefaultAlertTimeout
        local threat
        local threshold = self.BaseMonitor.AlertLevel
        local myThreat
        local alertBreak = false
        --RNGLOG('Base monitor raised for '..location..' of type '..type)
        repeat
            WaitSeconds(timeout)
           --RNGLOG('BaseMonitorAlert Timeout Reached')
            if type == 'Land' then
                if self.BasePerimeterMonitor[location].LandUnits and self.BasePerimeterMonitor[location].LandUnits > 0 and self.BasePerimeterMonitor[location].LandThreat > threshold then
                   --RNGLOG('Land Units at base '..self.BasePerimeterMonitor[location].LandUnits)
                   --RNGLOG('Land Threats at base '..self.BasePerimeterMonitor[location].LandThreat)
                    threat = self.BasePerimeterMonitor[location].LandThreat
                    self.BaseMonitor.AlertsTable[location]['Land'].Threat = self.BasePerimeterMonitor[location].LandThreat
                   --RNGLOG('Still land units present, restart AlertTimeout')
                    continue
                else
                   --RNGLOG('No Longer alert threat, cancel base alert')
                    self.BaseMonitor.AlertsTable[location]['Land'] = nil
                    alertBreak = true
                end
            elseif type == 'Air' then
                if self.BasePerimeterMonitor[location].AirUnits and self.BasePerimeterMonitor[location].AirUnits > 0 and self.BasePerimeterMonitor[location].AirThreat > threshold then
                   --RNGLOG('Air Units at base '..self.BasePerimeterMonitor[location].AirUnits)
                   --RNGLOG('Air Threats at base '..self.BasePerimeterMonitor[location].AirThreat)
                    threat = self.BasePerimeterMonitor[location].AirThreat
                    self.BaseMonitor.AlertsTable[location]['Air'].Threat = self.BasePerimeterMonitor[location].AirThreat
                   --RNGLOG('Still air units present, restart AlertTimeout')
                    continue
                else
                   --RNGLOG('No Longer alert threat, cancel base alert')
                    self.BaseMonitor.AlertsTable[location]['Air'] = nil
                    alertBreak = true
                end
            elseif type == 'Naval' then
                if self.BasePerimeterMonitor[location].NavalUnits and self.BasePerimeterMonitor[location].NavalUnits > 0 and self.BasePerimeterMonitor[location].NavalThreat > threshold then
                   --RNGLOG('Naval Units at base '..self.BasePerimeterMonitor[location].NavalUnits)
                   --RNGLOG('Naval Threats at base '..self.BasePerimeterMonitor[location].NavalThreat)
                    threat = self.BasePerimeterMonitor[location].NavalThreat
                    self.BaseMonitor.AlertsTable[location]['Naval'].Threat = self.BasePerimeterMonitor[location].NavalThreat
                   --RNGLOG('Still naval units present, restart AlertTimeout')
                    continue
                else
                   --RNGLOG('No Longer alert threat, cancel base alert')
                    self.BaseMonitor.AlertsTable[location]['Naval'] = nil
                    alertBreak = true
                end
            end
        until alertBreak
        --RNGLOG('Base monitor finished for '..location..' of type '..type)
        --RNGLOG('Alert Table for location '..repr(self.BaseMonitor.AlertsTable[location]))
        if self.BaseMonitor.AlertsTable[location][type] then
            WARNING('BaseMonitor Alert Table exist when it possibly shouldnt'..repr(self.BaseMonitor.AlertsTable[location][type]))
        end
        self.BaseMonitor.ActiveAlerts = self.BaseMonitor.ActiveAlerts - 1
        if self.BaseMonitor.ActiveAlerts == 0 then
            self.BaseMonitor.AlertSounded = false
        end
        --RNGLOG('Number of active alerts = '..self.BaseMonitor.ActiveAlerts)
    end,

    BuildScoutLocationsRNG = function(self)
        local function DrawCirclePoints(points, radius, center)
            RNGLOG('points '..points)
            RNGLOG('radius '..radius)
            RNGLOG('center '..repr(center))
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

        local opponentStarts = {}
        local startLocations = {}
        local startPosMarkers = {}
        local allyStarts = {}
        

        if not self.InterestList then
            self.InterestList = {}
            self.IntelData.HiPriScouts = 0
            self.IntelData.AirHiPriScouts = 0
            self.IntelData.AirLowPriScouts = 0
            

            -- Add each enemy's start location to the InterestList as a new sub table
            self.InterestList.HighPriority = {}
            self.InterestList.LowPriority = {}
            self.InterestList.MustScout = {}
            self.InterestList.PerimeterPoints = {
                Restricted = {},
                Military = {},
                DMZ = {}
            }

            local myArmy = ScenarioInfo.ArmySetup[self.Name]
            if self.BrainIntel.ExpansionWatchTable then
                for _, v in self.BrainIntel.ExpansionWatchTable do
                    -- Add any expansion table locations to the must scout table
                    --RNGLOG('Expansion of type '..v.Type..' found, seeting scout location')
                    RNGINSERT(self.InterestList.MustScout, 
                        {
                            Position = v.Position,
                            LastScouted = 0,
                        }
                    )
                end
            end
            if ScenarioInfo.Options.TeamSpawn == 'fixed' then
                -- Spawn locations were fixed. We know exactly where our opponents are.
                -- Don't scout areas owned by us or our allies.
                local numOpponents = 0
                local enemyStarts = {}
                for i = 1, 16 do
                    local army = ScenarioInfo.ArmySetup['ARMY_' .. i]
                    local startPos = ScenarioUtils.GetMarker('ARMY_' .. i).position
                    if army and startPos then
                        RNGINSERT(startLocations, startPos)
                        if army.ArmyIndex ~= myArmy.ArmyIndex and (army.Team ~= myArmy.Team or army.Team == 1) then
                        -- Add the army start location to the list of interesting spots.
                        opponentStarts['ARMY_' .. i] = startPos
                        numOpponents = numOpponents + 1
                        -- I would rather use army ndexes for the table keys of the enemyStarts so I can easily reference them in queries. To be pondered.
                        RNGINSERT(enemyStarts, {Position = startPos, Index = army.ArmyIndex})
                        RNGINSERT(self.InterestList.HighPriority,
                            {
                                Position = startPos,
                                LastScouted = 0,
                            }
                        )
                        else
                            allyStarts['ARMY_' .. i] = startPos
                        end
                    end
                end

                self.NumOpponents = numOpponents

                -- For each vacant starting location, check if it is closer to allied or enemy start locations (within 100 ogrids)
                -- If it is closer to enemy territory, flag it as high priority to scout.
                local starts = AIUtils.AIGetMarkerLocations(self, 'Start Location')
                for _, loc in starts do
                    -- If vacant
                    if not opponentStarts[loc.Name] and not allyStarts[loc.Name] then
                        local closestDistSq = 999999999
                        local closeToEnemy = false

                        for _, pos in opponentStarts do
                            local distSq = VDist2Sq(pos[1], pos[3], loc.Position[1], loc.Position[3])
                            -- Make sure to scout for bases that are near equidistant by giving the enemies 100 ogrids
                            if distSq-10000 < closestDistSq then
                                closestDistSq = distSq-10000
                                closeToEnemy = true
                            end
                        end

                        for _, pos in allyStarts do
                            local distSq = VDist2Sq(pos[1], pos[3], loc.Position[1], loc.Position[3])
                            if distSq < closestDistSq then
                                closestDistSq = distSq
                                closeToEnemy = false
                                break
                            end
                        end

                        if closeToEnemy then
                            RNGINSERT(self.InterestList.LowPriority,
                                {
                                    Position = loc.Position,
                                    LastScouted = 0,
                                }
                            )
                        end
                    end
                end
                self.EnemyIntel.EnemyStartLocations = enemyStarts
            else -- Spawn locations were random. We don't know where our opponents are. Add all non-ally start locations to the scout list
                local numOpponents = 0
                for i = 1, 16 do
                    local army = ScenarioInfo.ArmySetup['ARMY_' .. i]
                    local startPos = ScenarioUtils.GetMarker('ARMY_' .. i).position
                    if army and startPos then
                        if army.ArmyIndex == myArmy.ArmyIndex or (army.Team == myArmy.Team and army.Team ~= 1) then
                            allyStarts['ARMY_' .. i] = startPos
                        else
                            numOpponents = numOpponents + 1
                        end
                    end
                end

                self.NumOpponents = numOpponents

                -- If the start location is not ours or an ally's, it is suspicious
                local starts = AIUtils.AIGetMarkerLocations(self, 'Start Location')
                for _, loc in starts do
                    -- If vacant
                    if not allyStarts[loc.Name] then
                        RNGINSERT(self.InterestList.LowPriority,
                            {
                                Position = loc.Position,
                                LastScouted = 0,
                            }
                        )
                        RNGINSERT(startLocations, loc.Position)
                    end
                end
                -- Set Start Locations for brain to reference
                --RNGLOG('Start Locations are '..repr(startLocations))
                self.EnemyIntel.EnemyStartLocations = startLocations
            end
            RNGLOG('Perimeter Points Pre '..repr(self.InterestList.PerimeterPoints))
            local perimeterMap = {
                BaseRestrictedArea, 
                BaseMilitaryArea, 
                BaseDMZArea
            }
            for i=1, 3 do
                local tempPoints = DrawCirclePoints(8, perimeterMap[i], {self.BrainIntel.StartPos[1], 0 , self.BrainIntel.StartPos[2]})
                for _, v in tempPoints do
                    if v[1] <= 15 or v[1] >= ScenarioInfo.size[1] - 15 or v[3] <= 15 or v[3] >= ScenarioInfo.size[2] - 15 then
                        continue
                    end
                    if GetTerrainHeight(v[1], v[3]) >= GetSurfaceHeight(v[1], v[3]) then
                        if i == 1 then
                            RNGINSERT(self.InterestList.PerimeterPoints.Restricted, {Position = v, Scout = false})
                        elseif i == 2 then
                            RNGINSERT(self.InterestList.PerimeterPoints.Military, {Position = v, Scout = false})
                        elseif i == 3 then
                            RNGINSERT(self.InterestList.PerimeterPoints.DMZ, {Position = v, Scout = false})
                        end
                    else
                        RNGLOG('check if in water or on mountain failed')
                        RNGLOG('Terrain Height '..GetTerrainHeight(v[1], v[3]))
                        RNGLOG('Surface Height '..GetSurfaceHeight(v[1], v[3]))
                    end
                end
            end
            RNGLOG('Perimeter Points Post '..repr(self.InterestList.PerimeterPoints))
            --RNGLOG('* AI-RNG: EnemyStartLocations : '..repr(aiBrain.EnemyIntel.EnemyStartLocations))
            local massLocations = RUtils.AIGetMassMarkerLocations(self, true)
        
            for _, start in startLocations do
                markersStartPos = AIUtils.AIGetMarkersAroundLocationRNG(self, 'Mass', start, 30)
                for _, marker in markersStartPos do
                    --RNGLOG('* AI-RNG: Start Mass Marker ..'..repr(marker))
                    RNGINSERT(startPosMarkers, marker)
                end
            end
            for k, massMarker in massLocations do
                for c, startMarker in startPosMarkers do
                    if massMarker.Position == startMarker.Position then
                        --RNGLOG('* AI-RNG: Removing Mass Marker Position : '..repr(massMarker.Position))
                        table.remove(massLocations, k)
                    end
                end
            end
            for k, massMarker in massLocations do
                --RNGLOG('* AI-RNG: Inserting Mass Marker Position : '..repr(massMarker.Position))
                RNGINSERT(self.InterestList.LowPriority,
                        {
                            Position = massMarker.Position,
                            LastScouted = 0,
                        }
                    )
            end
            self:ForkThread(self.ParseIntelThreadRNG)
        end
    end,

    UnderEnergyThreshold = function(self)
        if not self.RNG then
            return RNGAIBrainClass.UnderEnergyThreshold(self)
        end
    end,

    OverEnergyThreshold = function(self)
        if not self.RNG then
            return RNGAIBrainClass.OverEnergyThreshold(self)
        end
    end,

    UnderMassThreshold = function(self)
        if not self.RNG then
            return RNGAIBrainClass.UnderMassThreshold(self)
        end
    end,

    OverMassThreshold = function(self)
        if not self.RNG then
            return RNGAIBrainClass.OverMassThreshold(self)
        end
    end,

    PickEnemyRNG = function(self)
        while true do
            self:PickEnemyLogicRNG()
            coroutine.yield(1200)
        end
    end,

    PickEnemyLogicRNG = function(self)
        local ALLBPS = __blueprints
        local armyStrengthTable = {}
        local selfIndex = self:GetArmyIndex()
        local enemyBrains = {}
        local allyCount = 0
        local enemyCount = 0
        local MainPos = self.BuilderManagers.MAIN.Position
        for _, v in ArmyBrains do
            local insertTable = {
                Enemy = true,
                Strength = 0,
                Position = false,
                Distance = false,
                EconomicThreat = 0,
                ACUPosition = {},
                ACULastSpotted = 0,
                Brain = v,
                Team = false,
            }
            -- Share resources with friends but don't regard their strength
            if ArmyIsCivilian(v:GetArmyIndex()) then
                local enemyStructureThreat = self:GetThreatsAroundPosition(MainPos, 16, true, 'Structures', v:GetArmyIndex())
                --RNGLOG('User Structure threat for index '..v:GetArmyIndex()..' '..repr(enemyStructureThreat))
                continue
            elseif IsAlly(selfIndex, v:GetArmyIndex()) then
                self:SetResourceSharing(true)
                allyCount = allyCount + 1
                insertTable.Enemy = false
                insertTable.Team = v.Team
            elseif not IsEnemy(selfIndex, v:GetArmyIndex()) then
                insertTable.Enemy = false
            end
            if insertTable.Enemy == true then
                enemyCount = enemyCount + 1
                insertTable.Team = v.Team
                RNGINSERT(enemyBrains, v)
            end
            local acuPos = {}
            -- Gather economy information of army to guage economy value of the target
            local enemyIndex = v:GetArmyIndex()
            local startX, startZ = v:GetArmyStartPos()
            local ecoThreat = 0

            if insertTable.Enemy == false then
                local ecoStructures = GetUnitsAroundPoint(self, categories.STRUCTURE * (categories.MASSEXTRACTION + categories.MASSPRODUCTION), {startX, 0 ,startZ}, 120, 'Ally')
                for _, v in ecoStructures do
                    local ecoStructThreat = ALLBPS[v.UnitId].Defense.EconomyThreatLevel
                    --RNGLOG('* AI-RNG: Eco Structure'..ecoStructThreat)
                    ecoThreat = ecoThreat + ecoStructThreat
                end
            else
                ecoThreat = 1
            end
            -- Doesn't exist yet!!. Check if the ACU's last position is known.
            --RNGLOG('* AI-RNG: Enemy Index is :'..enemyIndex)
            local acuPos, lastSpotted = RUtils.GetLastACUPosition(self, enemyIndex)
            --RNGLOG('* AI-RNG: ACU Position is has data'..repr(acuPos))
            insertTable.ACUPosition = acuPos
            insertTable.ACULastSpotted = lastSpotted
            
            insertTable.EconomicThreat = ecoThreat
            if insertTable.Enemy then
                local enemyTotalStrength = 0
                local highestEnemyThreat = 0
                local threatPos = {}
                local enemyStructureThreat = self:GetThreatsAroundPosition(MainPos, 16, true, 'Structures', enemyIndex)
                for _, threat in enemyStructureThreat do
                    enemyTotalStrength = enemyTotalStrength + threat[3]
                    if threat[3] > highestEnemyThreat then
                        highestEnemyThreat = threat[3]
                        threatPos = {threat[1],0,threat[2]}
                    end
                end
                if enemyTotalStrength > 0 then
                    insertTable.Strength = enemyTotalStrength
                    insertTable.Position = threatPos
                end

                --RNGLOG('Enemy Index is '..enemyIndex)
                --RNGLOG('Enemy name is '..v.Nickname)
                --RNGLOG('* AI-RNG: First Enemy Pass Strength is :'..insertTable.Strength)
                --RNGLOG('* AI-RNG: First Enemy Pass Position is :'..repr(insertTable.Position))
                if insertTable.Strength == 0 then
                    --RNGLOG('Enemy Strength is zero, using enemy start pos')
                    insertTable.Position = {startX, 0 ,startZ}
                end
            else
                insertTable.Position = {startX, 0 ,startZ}
                insertTable.Strength = ecoThreat
                --RNGLOG('* AI-RNG: First Ally Pass Strength is : '..insertTable.Strength..' Ally Position :'..repr(insertTable.Position))
            end
            armyStrengthTable[v:GetArmyIndex()] = insertTable
        end
        
        self.EnemyIntel.EnemyCount = enemyCount
        self.BrainIntel.AllyCount = allyCount
        local allyEnemy = self:GetAllianceEnemyRNG(armyStrengthTable)
        
        if allyEnemy  then
            --RNGLOG('* AI-RNG: Ally Enemy is true or ACU is close')
            self:SetCurrentEnemy(allyEnemy)
        else
            local findEnemy = false
            if not self:GetCurrentEnemy() then
                findEnemy = true
            else
                local cIndex = self:GetCurrentEnemy():GetArmyIndex()
                -- If our enemy has been defeated or has less than 20 strength, we need a new enemy
                if self:GetCurrentEnemy():IsDefeated() or armyStrengthTable[cIndex].Strength < 20 then
                    findEnemy = true
                end
            end
            local enemyTable = {}
            if findEnemy then
                local enemyStrength = false
                local enemy = false

                for k, v in armyStrengthTable do
                    -- Dont' target self
                    if k == selfIndex then
                        continue
                    end

                    -- Ignore allies
                    if not v.Enemy then
                        continue
                    end

                    -- If we have a better candidate; ignore really weak enemies
                    if enemy and v.Strength < 20 then
                        continue
                    end

                    if v.Strength == 0 then
                        name = v.Brain.Nickname
                        --RNGLOG('* AI-RNG: Name is'..name)
                        --RNGLOG('* AI-RNG: v.strenth is 0')
                        if name ~= 'civilian' then
                            --RNGLOG('* AI-RNG: Inserted Name is '..name)
                            RNGINSERT(enemyTable, v.Brain)
                        end
                        continue
                    end

                    -- The closer targets are worth more because then we get their mass spots
                    local distanceWeight = 0.1
                    local distance = VDist3(self:GetStartVector3f(), v.Position)
                    local threatWeight = (1 / (distance * distanceWeight)) * v.Strength
                    --RNGLOG('* AI-RNG: armyStrengthTable Strength is :'..v.Strength)
                    --RNGLOG('* AI-RNG: Threat Weight is :'..threatWeight)
                    if not enemy or threatWeight > enemyStrength then
                        enemy = v.Brain
                        enemyStrength = threatWeight
                        --RNGLOG('* AI-RNG: Enemy Strength is'..enemyStrength)
                    end
                end

                if enemy then
                    --RNGLOG('* AI-RNG: Enemy is :'..enemy.Name)
                    self:SetCurrentEnemy(enemy)
                else
                    local num = RNGGETN(enemyTable)
                    --RNGLOG('* AI-RNG: Table number is'..num)
                    local ran = math.random(num)
                    --RNGLOG('* AI-RNG: Random Number is'..ran)
                    enemy = enemyTable[ran]
                    --RNGLOG('* AI-RNG: Random Enemy is'..enemy.Name)
                    self:SetCurrentEnemy(enemy)
                end
                
            end
        end
        local selfEnemy = self:GetCurrentEnemy()
        if selfEnemy then
            local enemyIndex = selfEnemy:GetArmyIndex()
            local closest = 9999999
            local expansionName
            local mainDist = VDist2Sq(self.BuilderManagers['MAIN'].Position[1], self.BuilderManagers['MAIN'].Position[3], armyStrengthTable[enemyIndex].Position[1], armyStrengthTable[enemyIndex].Position[3])
            --RNGLOG('Main base Position '..repr(self.BuilderManagers['MAIN'].Position))
            --RNGLOG('Enemy base position '..repr(armyStrengthTable[enemyIndex].Position))
            for k, v in self.BuilderManagers do
                --RNGLOG('build k is '..k)
                if (string.find(k, 'Expansion Area')) or (string.find(k, 'ARMY_')) then
                    if v.FactoryManager:GetNumCategoryFactories(categories.ALLUNITS) > 0 then
                        local exDistance = VDist2Sq(self.BuilderManagers[k].Position[1], self.BuilderManagers[k].Position[3], armyStrengthTable[enemyIndex].Position[1], armyStrengthTable[enemyIndex].Position[3])
                        --RNGLOG('Distance to Enemy for '..k..' is '..exDistance)
                        if (exDistance < closest) and (mainDist > exDistance) then
                            expansionName = k
                            closest = exDistance
                        end
                    end
                end
            end
            if closest < 9999999 and expansionName then
                --RNGLOG('Closest Base to Enemy is '..expansionName..' at a distance of '..closest)
                self.BrainIntel.ActiveExpansion = expansionName
                --RNGLOG('Active Expansion is '..self.BrainIntel.ActiveExpansion)
            end
            local waterNodePos, waterNodeName, waterNodeDist = AIUtils.AIGetClosestMarkerLocationRNG(self, 'Water Path Node', armyStrengthTable[enemyIndex].Position[1], armyStrengthTable[enemyIndex].Position[3])
            if waterNodePos then
                --RNGLOG('Enemy Closest water node pos is '..repr(waterNodePos))
                self.EnemyIntel.NavalRange.Position = waterNodePos
                --RNGLOG('Enemy Closest water node pos distance is '..waterNodeDist)
                self.EnemyIntel.NavalRange.Range = waterNodeDist
            end
            --RNGLOG('Current Naval Range table is '..repr(self.EnemyIntel.NavalRange))
        end
    end,

    ParseIntelThreadRNG = function(self)
        if not self.InterestList or not self.InterestList.MustScout then
            error('Scouting areas must be initialized before calling AIBrain:ParseIntelThread.', 2)
        end
        while true do
            local structures = GetThreatsAroundPosition(self, self.BuilderManagers.MAIN.Position, 16, true, 'StructuresNotMex')
            local gameTime = GetGameTimeSeconds()
            for _, struct in structures do
                local dupe = false
                local newPos = {struct[1], 0, struct[2]}

                for _, loc in self.InterestList.HighPriority do
                    if VDist2Sq(newPos[1], newPos[3], loc.Position[1], loc.Position[3]) < 10000 then
                        dupe = true
                        break
                    end
                end

                if not dupe then
                    -- Is it in the low priority list?
                    for i = 1, RNGGETN(self.InterestList.LowPriority) do
                        local loc = self.InterestList.LowPriority[i]
                        if VDist2Sq(newPos[1], newPos[3], loc.Position[1], loc.Position[3]) < 10000 then
                            -- Found it in the low pri list. Remove it so we can add it to the high priority list.
                            table.remove(self.InterestList.LowPriority, i)
                            break
                        end
                    end

                    RNGINSERT(self.InterestList.HighPriority,
                        {
                            Position = newPos,
                            LastScouted = gameTime,
                        }
                    )
                    -- Sort the list based on low long it has been since it was scouted
                    table.sort(self.InterestList.HighPriority, function(a, b)
                        if a.LastScouted == b.LastScouted then
                            local MainPos = self.BuilderManagers.MAIN.Position
                            local distA = VDist2(MainPos[1], MainPos[3], a.Position[1], a.Position[3])
                            local distB = VDist2(MainPos[1], MainPos[3], b.Position[1], b.Position[3])

                            return distA < distB
                        else
                            return a.LastScouted < b.LastScouted
                        end
                    end)
                end
            end
            for k, v in self.EnemyIntel.ACU do
                local dupe = false
                if not v.Ally and v.HP ~= 0 and v.LastSpotted ~= 0 then
                    RNGLOG('ACU last spotted '..(GetGameTimeSeconds() - v.LastSpotted)..' seconds ago')
                    if (GetGameTimeSeconds() - 30) > v.LastSpotted then
                        for _, loc in self.InterestList.HighPriority do
                            if VDist2Sq(v.Position[1], v.Position[3], loc.Position[1], loc.Position[3]) < 10000 then
                                dupe = true
                                break
                            end
                        end
                        if not dupe then
                            RNGLOG('Insert scout position of last known acu location')
                            RNGINSERT(self.InterestList.HighPriority, { Position = v.Position, LastScouted = gameTime })
                        end
                    end
                end
            end
            coroutine.yield(70)
        end
    end,

    GetAllianceEnemyRNG = function(self, strengthTable)
        local returnEnemy = false
        local myIndex = self:GetArmyIndex()
        local highStrength = strengthTable[myIndex].Strength
        local ACUDist = nil
        self.EnemyIntel.ACUEnemyClose = false
        
        --RNGLOG('* AI-RNG: My Own Strength is'..highStrength)
        for k, v in strengthTable do
            -- It's an enemy, ignore
            if v.Enemy then
                -- dont log this until you want to get a dump of the brain.
                --RNGLOG('EnemyStrength Tables :'..repr(v))
                --LOG('Start pos '..repr(self.BrainIntel.StartPos))
                if v.ACUPosition[1] then
                    if VDist2Sq(v.ACUPosition[1], v.ACUPosition[3], self.BrainIntel.StartPos[1], self.BrainIntel.StartPos[2]) < 19600 then
                       --RNGLOG('* AI-RNG: Enemy ACU is close switching Enemies to :'..v.Brain.Nickname)
                        returnEnemy = v.Brain
                        return returnEnemy
                    elseif self.EnemyIntel.ACU[k].Threat and self.EnemyIntel.ACU[k].Threat < 20 and self.EnemyIntel.ACU[k].OnField then
                       --RNGLOG('* AI-RNG: Enemy ACU has low threat switching Enemies to :'..v.Brain.Nickname)
                        returnEnemy = v.Brain
                        return returnEnemy
                    end
                end
                continue
            end

            -- Ally too weak
            if v.Strength < highStrength then
                continue
            end

            -- If the brain has an enemy, it's our new enemy
            
            local enemy = v.Brain:GetCurrentEnemy()
            if enemy and not enemy:IsDefeated() and v.Strength > 0 then
                highStrength = v.Strength
                returnEnemy = v.Brain:GetCurrentEnemy()
            end
        end
        if returnEnemy then
            --RNGLOG('* AI-RNG: Ally Enemy Returned is : '..returnEnemy.Nickname)
        else
            --RNGLOG('* AI-RNG: returnEnemy is false')
        end
        return returnEnemy
    end,

    BaseMonitorZoneThreatRNG = function(self, zoneid, threat)
        RNGLOG('Create zone alert for zoneid '..zoneid..' with a threat of '..threat)
        if not self.BaseMonitor then
            return
        end

        local found = false
        RNGLOG('Zone Alert table current size '..table.getn(self.BaseMonitor.ZoneAlertTable))
        if self.BaseMonitor.ZoneAlertSounded == false then
            RNGLOG('ZoneAlertSounded is currently false')
            self.BaseMonitor.ZoneAlertTable[zoneid].Threat = threat
        else
            for k, v in self.BaseMonitor.ZoneAlertTable do
                -- If already calling for help, don't add another distress call
                if k == zoneid and v.Threat > 0 then
                   --RNGLOG('Zone ID '..zoneid..'already exist as '..k..' skipping')
                    found = true
                    break
                end
            end
            if not found then
               --RNGLOG('Alert doesnt already exist, adding')
                self.BaseMonitor.ZoneAlertTable[zoneid].Threat = threat
            end
        end
        --RNGLOG('Platoon Distress Table'..repr(self.BaseMonitor.ZoneAlertTable))
    end,

    BaseMonitorPlatoonDistressRNG = function(self, platoon, threat)
        if not self.BaseMonitor then
            return
        end

        local found = false
        if self.BaseMonitor.PlatoonAlertSounded == false then
            RNGINSERT(self.BaseMonitor.PlatoonDistressTable, {Platoon = platoon, Threat = threat})
        else
            for k, v in self.BaseMonitor.PlatoonDistressTable do
                -- If already calling for help, don't add another distress call
                if table.equal(v.Platoon, platoon) then
                    --RNGLOG('platoon.BuilderName '..platoon.BuilderName..'already exist as '..v.Platoon.BuilderName..' skipping')
                    found = true
                    break
                end
            end
            if not found then
                --RNGLOG('Platoon doesnt already exist, adding')
                RNGINSERT(self.BaseMonitor.PlatoonDistressTable, {Platoon = platoon, Threat = threat})
            end
        end
        -- Create the distress call if it doesn't exist
        if not self.BaseMonitor.PlatoonDistressThread then
            self.BaseMonitor.PlatoonDistressThread = self:ForkThread(self.BaseMonitorPlatoonDistressThreadRNG)
        end
        --RNGLOG('Platoon Distress Table'..repr(self.BaseMonitor.PlatoonDistressTable))
    end,

    BasePerimeterMonitorRNG = function(self)
        --[[ 
        This monitors base perimeters for enemy units
        I did this to replace using multiple calls on builder conditions for defensive triggers, but it also generates the base alerting system data.
        The resulting table will look like something like this
        ARMY_3={
            AirThreat=0,
            AirUnits=0,
            AntiSurfaceAirUnits=0,
            LandThreat=0,
            LandUnits=0,
            NavalThreat=0,
            NavalUnits=0
            },
        ]]
        coroutine.yield(Random(5,20))
        local ALLBPS = __blueprints
        local LandCatUnits = categories.LAND + categories.AMPHIBIOUS + categories.COMMAND
        local AirSurfaceCatUnits = categories.MOBILE * categories.AIR * (categories.GROUNDATTACK + categories.BOMBER)
        local perimeterMonitorRadius = BaseRestrictedArea * 1.2
        self.BasePerimeterMonitor = {}
        if self.RNGDEBUG then
            self:ForkThread(self.drawMainRestricted)
        end
        while true do
            for k, v in self.BuilderManagers do
                local landUnits = 0
                local airUnits = 0
                local antiSurfaceAir = 0
                local navalUnits = 0
                local landThreat = 0
                local airThreat = 0
                local navalThreat = 0
                if self.BuilderManagers[k].FactoryManager and RNGGETN(self.BuilderManagers[k].FactoryManager.FactoryList) > 0 then
                    if not self.BasePerimeterMonitor[k] then
                        self.BasePerimeterMonitor[k] = {}
                    end
                    local enemyUnits = self:GetUnitsAroundPoint(categories.ALLUNITS - categories.SCOUT - categories.INSIGNIFICANTUNIT, self.BuilderManagers[k].FactoryManager.Location, perimeterMonitorRadius , 'Enemy')
                    for _, unit in enemyUnits do
                        if unit and not unit.Dead then
                            if ALLBPS[unit.UnitId].CategoriesHash.MOBILE then
                                if EntityCategoryContains(LandCatUnits, unit) then
                                    landUnits = landUnits + 1
                                    landThreat = landThreat + ALLBPS[unit.UnitId].Defense.SurfaceThreatLevel
                                    continue
                                end
                                if EntityCategoryContains(AirSurfaceCatUnits, unit) then
                                    antiSurfaceAir = antiSurfaceAir + 1
                                    airThreat = airThreat + ALLBPS[unit.UnitId].Defense.AirThreatLevel
                                    continue
                                end
                                if ALLBPS[unit.UnitId].CategoriesHash.AIR then
                                    airUnits = airUnits + 1
                                    airThreat = airThreat + ALLBPS[unit.UnitId].Defense.AirThreatLevel
                                    continue
                                end
                                if ALLBPS[unit.UnitId].CategoriesHash.NAVAL then
                                    navalUnits = navalUnits + 1
                                    navalThreat = navalThreat + ALLBPS[unit.UnitId].Defense.SurfaceThreatLevel + ALLBPS[unit.UnitId].Defense.AirThreatLevel + ALLBPS[unit.UnitId].Defense.SubThreatLevel
                                    continue
                                end
                            end
                        end
                    end
                    self.BasePerimeterMonitor[k].LandUnits = landUnits
                    self.BasePerimeterMonitor[k].AirUnits = airUnits
                    self.BasePerimeterMonitor[k].AntiSurfaceAirUnits = antiSurfaceAir
                    self.BasePerimeterMonitor[k].NavalUnits = navalUnits
                    self.BasePerimeterMonitor[k].NavalThreat = navalThreat
                    self.BasePerimeterMonitor[k].AirThreat = airThreat
                    self.BasePerimeterMonitor[k].LandThreat = landThreat
                else
                    if self.BasePerimeterMonitor[k] then
                        self.BasePerimeterMonitor[k] = nil
                    end
                end
                coroutine.yield(2)
            end
            coroutine.yield(20)
        end
    end,

    BaseMonitorZoneThreatThreadRNG = function(self)
        self:WaitForZoneInitialization()
        for k, v in self.Zones.Land.zones do
            self.BaseMonitor.ZoneAlertTable[k] = { Threat = 0 }
        end
        RNGLOG('ZoneAlertTable '..repr(self.BaseMonitor.ZoneAlertTable))
        local ALLBPS = __blueprints
        local Zones = {
            'Land',
        }
        --LOG('BaseMonitorZoneThreatThreadRNG Starting')
        while true do
            local numAlerts = 0
            --LOG('BaseMonitorZoneThreatThreadRNG Looping through zone alert table')
            for k, v in self.BaseMonitor.ZoneAlertTable do
                if v.Threat > 0 then
                    local threat = 0
                    local myThreat = 0
                    if RUtils.PositionOnWater(self.Zones.Land.zones[k].pos[1], self.Zones.Land.zones[k].pos[3]) then
                        threat = GetThreatAtPosition(self, self.Zones.Land.zones[k].pos, self.BrainIntel.IMAPConfig.Rings, true, 'AntiSub')
                        local unitsAtPosition = GetUnitsAroundPoint(self, categories.ANTINAVY * categories.MOBILE,  self.Zones.Land.zones[k].pos, 60, 'Ally')
                        for k, v in unitsAtPosition do
                            if v and not v.Dead then
                                --RNGLOG('Unit ID is '..v.UnitId)
                                bp = ALLBPS[v.UnitId].Defense
                                --RNGLOG(repr(ALLBPS[v.UnitId].Defense))
                                if bp.SubThreatLevel ~= nil then
                                    myThreat = myThreat + bp.SubThreatLevel
                                end
                            end
                        end
                    else
                        threat = self.Zones.Land.zones[k].enemythreat
                        if threat > 0 then
                            local unitsAtPosition = GetUnitsAroundPoint(self, categories.LAND * categories.MOBILE,  self.Zones.Land.zones[k].pos, 60, 'Ally')
                            for k, v in unitsAtPosition do
                                if v and not v.Dead then
                                    --RNGLOG('Unit ID is '..v.UnitId)
                                    bp = ALLBPS[v.UnitId].Defense
                                    --RNGLOG(repr(ALLBPS[v.UnitId].Defense))
                                    if bp.SubThreatLevel ~= nil then
                                        myThreat = myThreat + bp.SurfaceThreatLevel
                                    end
                                end
                            end
                        end
                    end
                    if threat and threat > (myThreat * 1.3) then
                       --RNGLOG('* AI-RNG: Created Threat Alert')
                        v.Threat = threat
                        numAlerts = numAlerts + 1
                    -- Platoon not threatened
                    else
                        --LOG('Setting ZoneAlertTable key of '..k..' to nil')
                        self.BaseMonitor.ZoneAlertTable[k].Threat = 0
                    end
                end
                coroutine.yield(1)
            end
            if numAlerts > 0 then
                --LOG('BaseMonitorZoneThreatThreadRNG numAlerts'..numAlerts)
                self.BaseMonitor.ZoneAlertSounded = true
            else
                self.BaseMonitor.ZoneAlertSounded = false
            end
            --self.BaseMonitor.ZoneAlertTable = self:RebuildTable(self.BaseMonitor.ZoneAlertTable)
            --RNGLOG('Platoon Distress Table'..repr(self.BaseMonitor.PlatoonDistressTable))
            --RNGLOG('BaseMonitor time is '..self.BaseMonitor.BaseMonitorTime)
            WaitSeconds(self.BaseMonitor.BaseMonitorTime)
        end
    end,

    BaseMonitorPlatoonDistressThreadRNG = function(self)
        self.BaseMonitor.PlatoonAlertSounded = true
        local ALLBPS = __blueprints
        while true do
            local numPlatoons = 0
            for k, v in self.BaseMonitor.PlatoonDistressTable do
                if self:PlatoonExists(v.Platoon) then
                    local threat = 0
                    local myThreat = 0
                    local platoonPos = v.Platoon:GetPlatoonPosition()
                    if RUtils.PositionOnWater(platoonPos[1], platoonPos[3]) then
                        threat = GetThreatAtPosition(self, v.Platoon:GetPlatoonPosition(), self.BrainIntel.IMAPConfig.Rings, true, 'AntiSub')
                        local unitsAtPosition = GetUnitsAroundPoint(self, categories.ANTINAVY * categories.MOBILE,  platoonPos, 60, 'Ally')
                        for k, v in unitsAtPosition do
                            if v and not v.Dead then
                                --RNGLOG('Unit ID is '..v.UnitId)
                                bp = ALLBPS[v.UnitId].Defense
                                --RNGLOG(repr(ALLBPS[v.UnitId].Defense))
                                if bp.SubThreatLevel ~= nil then
                                    myThreat = myThreat + bp.SubThreatLevel
                                end
                            end
                        end
                    else
                        threat = GetThreatAtPosition(self, v.Platoon:GetPlatoonPosition(), self.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface')
                        local unitsAtPosition = GetUnitsAroundPoint(self, categories.LAND * categories.MOBILE,  platoonPos, 60, 'Ally')
                        for k, v in unitsAtPosition do
                            if v and not v.Dead then
                                --RNGLOG('Unit ID is '..v.UnitId)
                                bp = ALLBPS[v.UnitId].Defense
                                --RNGLOG(repr(ALLBPS[v.UnitId].Defense))
                                if bp.SubThreatLevel ~= nil then
                                    myThreat = myThreat + bp.SurfaceThreatLevel
                                end
                            end
                        end
                    end
                    --RNGLOG('Platoon Threat Validation')
                    --RNGLOG('* AI-RNG: Threat of attacker'..threat)
                    --RNGLOG('* AI-RNG: Threat of platoon'..myThreat)
                    --RNGLOG('* AI-RNG: Threat of platoon with multiplier'..myThreat * 1.5)
                    -- Platoons still threatened
                    if threat and threat > (myThreat * 1.3) then
                       --RNGLOG('* AI-RNG: Created Threat Alert')
                        v.Threat = threat
                        numPlatoons = numPlatoons + 1
                    -- Platoon not threatened
                    else
                        self.BaseMonitor.PlatoonDistressTable[k] = nil
                        v.Platoon.DistressCall = false
                    end
                else
                    self.BaseMonitor.PlatoonDistressTable[k] = nil
                end
            end

            -- If any platoons still want help; continue sounding
            --RNGLOG('Alerted Platoons '..numPlatoons)
            if numPlatoons > 0 then
                self.BaseMonitor.PlatoonAlertSounded = true
            else
                self.BaseMonitor.PlatoonAlertSounded = false
            end
            self.BaseMonitor.PlatoonDistressTable = self:RebuildTable(self.BaseMonitor.PlatoonDistressTable)
            --RNGLOG('Platoon Distress Table'..repr(self.BaseMonitor.PlatoonDistressTable))
            --RNGLOG('Number of platoon alerts currently '..table.getn(self.BaseMonitor.PlatoonDistressTable))
            --RNGLOG('BaseMonitor time is '..self.BaseMonitor.BaseMonitorTime)
            WaitSeconds(self.BaseMonitor.BaseMonitorTime)
        end
    end,

    BaseMonitorDistressLocationRNG = function(self, position, radius, threshold, movementLayer)
        local returnPos = false
        local returnThreat = 0
        local threatPriority = 0
        local distance

        
        if self.CDRUnit.Caution and VDist2(self.CDRUnit.Position[1], self.CDRUnit.Position[3], position[1], position[3]) < radius
            and self.CDRUnit.CurrentEnemyThreat * 1.3 > self.CDRUnit.CurrentFriendlyThreat then
            -- Commander scared and nearby; help it
            return self.CDRUnit.Position
        end
        if self.BaseMonitor.AlertSounded then
            --RNGLOG('Base Alert Sounded')
            --RNGLOG('There are '..table.getn(self.BaseMonitor.AlertsTable)..' alerts currently')
            --RNGLOG('There are '..self.BaseMonitor.ActiveAlerts.. ' Active alerts')
            --RNGLOG('Movement layer is '..movementLayer)
            local priorityValue = 0
            local threatLayer = false
            if movementLayer == 'Land' or movementLayer == 'Amphibious' or movementLayer == 'Air' then
                threatLayer = 'Land'
            elseif movementLayer == 'Water' then
                threatLayer = 'Naval'
            else
                WARNING('Unknown movement layer passed to BaseMonitorDistressLocations')
            end
            for k, v in self.BaseMonitor.AlertsTable do
                for c, n in v do
                    if c == threatLayer then
                        --RNGLOG('Found Alert of type '..threatLayer)
                        local tempDist = VDist2(position[1], position[3], n.Position[1], n.Position[3])
                        -- stops strange things if the distance is zero
                        if tempDist < 1 then
                            tempDist = 1
                        end
                        if tempDist > radius then
                            continue
                        end
                        -- Not enough threat in location
                        if n.Threat < threshold then
                            continue
                        end
                        priorityValue = 2500 / tempDist * n.Threat
                        if priorityValue > threatPriority then
                            --RNGLOG('We are replacing the following in base monitor')
                            --RNGLOG('threatPriority was '..priorityValue)
                            --RNGLOG('Threat at position was '..n.Threat)
                            --RNGLOG('With position '..repr(n.Position))
                            threatPriority = priorityValue
                            returnPos = n.Position
                            returnThreat = n.Threat
                        end
                    end
                end
            end
        end
        if self.BaseMonitor.PlatoonAlertSounded then
            --RNGLOG('Platoon Alert Sounded')
            local priorityValue = 0
            for k, v in self.BaseMonitor.PlatoonDistressTable do
                if self:PlatoonExists(v.Platoon) then
                    local platPos = v.Platoon:GetPlatoonPosition()
                    if not platPos then
                        self.BaseMonitor.PlatoonDistressTable[k] = nil
                        continue
                    end
                    local tempDist = VDist2(position[1], position[3], platPos[1], platPos[3])
                    -- stops strange things if the distance is zero
                    if tempDist < 1 then
                        tempDist = 1
                    end
                    -- Platoon too far away to help
                    if tempDist > radius then
                        continue
                    end

                    -- Area not scary enough
                    if v.Threat < threshold then
                        continue
                    end
                    priorityValue = 2500 / tempDist * v.Threat
                    if priorityValue > threatPriority then
                        --RNGLOG('We are replacing the following in platoon monitor')
                        --RNGLOG('threatPriority was '..threatPriority)
                        --RNGLOG('Position was '..returnThreat)
                        --RNGLOG('With position '..repr(platPos))
                        threatPriority = priorityValue
                        returnPos = platPos
                        returnThreat = v.Threat
                    end
                end
            end
        end
        if self.BaseMonitor.ZoneAlertSounded then
            --RNGLOG('Zone Alert Sounded')
            local priorityValue = 0
            for k, v in self.BaseMonitor.ZoneAlertTable do
                local zonePos = self.Zones.Land.zones[k].pos
                if not zonePos then
                    RNGLOG('No zone pos, alert table key is getting set to nil')
                    coroutine.yield(1)
                    continue
                end
                local tempDist = VDist2(position[1], position[3], zonePos[1], zonePos[3])
                -- stops strange things if the distance is zero
                if tempDist < 1 then
                    tempDist = 1
                end
                -- Platoon too far away to help
                if tempDist > radius then
                    continue
                end

                -- Area not scary enough
                if v.Threat < threshold then
                    continue
                end
                priorityValue = 2500 / tempDist * v.Threat
                if priorityValue > threatPriority then
                    --RNGLOG('We are replacing the following in platoon monitor')
                    --RNGLOG('threatPriority was '..threatPriority)
                    --RNGLOG('Position was '..returnThreat)
                    --RNGLOG('With position '..repr(platPos))
                    threatPriority = priorityValue
                    returnPos = zonePos
                    returnThreat = v.Threat
                end
            end
        end
        if returnPos then
        -- Get real height
            local height = GetTerrainHeight(returnPos[1], returnPos[3])
            local surfHeight = GetSurfaceHeight(returnPos[1], returnPos[3])
            if surfHeight > height then
                height = surfHeight
            end
            returnPos = {returnPos[1], height, returnPos[3]}
            --RNGLOG('BaseMonitorDistressLocation returning the following')
            --RNGLOG('Return Position '..repr(returnPos))
            --RNGLOG('Return Threat '..returnThreat)
            return returnPos, returnThreat
        end
        coroutine.yield(2)
    end,

    TacticalMonitorInitializationRNG = function(self, spec)
        --RNGLOG('* AI-RNG: Tactical Monitor Is Initializing')
        local ALLBPS = __blueprints
        self:ForkThread(self.TacticalMonitorThreadRNG, ALLBPS)
    end,

    SetupIntelTriggersRNG = function(self)
        coroutine.yield(10)
        RNGLOG('Try to create intel trigger for enemy')
        self:SetupArmyIntelTrigger({
            CallbackFunction = self.ACUDetectionRNG, 
            Type = 'LOSNow', 
            Category = categories.COMMAND,
            Blip = false, 
            Value = true,
            OnceOnly = false, 
        })
    end,

    ACUDetectionRNG = function(self, blip)
        --LOG('ACUDetection Callback has fired')
        local currentGameTime = GetGameTimeSeconds()
        if blip then
            --RNGLOG('* AI-RNG: ACU Detected')
            local unit = blip:GetSource()
            if not unit.Dead then
                --unitDesc = GetBlueprint(v).Description
                --RNGLOG('* AI-RNG: Units is'..unitDesc)
                local enemyIndex = unit:GetAIBrain():GetArmyIndex()
                --RNGLOG('* AI-RNG: EnemyIndex :'..enemyIndex)
                --RNGLOG('* AI-RNG: Curent Game Time : '..currentGameTime)
                --RNGLOG('* AI-RNG: Iterating ACUTable')
                for k, c in self.EnemyIntel.ACU do
                    --RNGLOG('* AI-RNG: Table Index is : '..k)
                    --RNGLOG('* AI-RNG:'..c.LastSpotted)
                    --RNGLOG('* AI-RNG:'..repr(c.Position))
                    if k == enemyIndex then
                        --RNGLOG('* AI-RNG: CurrentGameTime IF is true updating tables')
                        c.Position = unit:GetPosition()
                        c.HP = unit:GetHealth()
                        RNGLOG('Enemy ACU of index '..enemyIndex..' has '..c.HP..' health')
                        acuThreat = self:GetThreatAtPosition(c.Position, self.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
                       --RNGLOG('* AI-RNG: Threat at ACU location is :'..acuThreat)
                        c.Threat = acuThreat
                        c.LastSpotted = currentGameTime
                        --LOG('Enemy ACU Position is set')
                    end
                end
            end
        end
    end,

    OnIntelChange = function(self, blip, reconType, val)
        if not self.RNG then
            return RNGAIBrainClass.OnIntelChange(self, blip, reconType, val)
        end
        if val then
            if reconType == 'LOSNow' then
                if self.IntelTriggerList then
                    for k, v in self.IntelTriggerList do
                        if EntityCategoryContains(v.Category, blip:GetBlueprint().BlueprintId)
                            and (not v.Blip or v.Blip == blip:GetSource()) then
                            v.CallbackFunction(self, blip)
                            if v.OnceOnly then
                                self.IntelTriggerList[k] = nil
                            end
                        end
                    end
                end
            end
        end
    end,

    TacticalMonitorThreadRNG = function(self, ALLBPS)
        --RNGLOG('Monitor Tick Count :'..self.TacticalMonitor.TacticalMonitorTime)
        coroutine.yield(Random(2,10))
        while true do
            if self.TacticalMonitor.TacticalMonitorStatus == 'ACTIVE' then
                --RNGLOG('* AI-RNG: Tactical Monitor Is Active')
                self:SelfThreatCheckRNG(ALLBPS)
                self:EnemyThreatCheckRNG(ALLBPS)
                self:TacticalMonitorRNG(ALLBPS)
                if true then
                    local EnergyIncome = GetEconomyIncome(self,'ENERGY')
                    local MassIncome = GetEconomyIncome(self,'MASS')
                    local EnergyRequested = GetEconomyRequested(self,'ENERGY')
                    local MassRequested = GetEconomyRequested(self,'MASS')
                    local EnergyEfficiency = math.min(EnergyIncome / EnergyRequested, 2)
                    local MassEfficiency = math.min(MassIncome / MassRequested, 2)
                   --RNGLOG('Eco Stats for :'..self.Nickname)
                   --RNGLOG('Game Time '..GetGameTimeSeconds())
                   --RNGLOG('MassStorage :'..GetEconomyStoredRatio(self, 'MASS')..' Energy Storage :'..GetEconomyStoredRatio(self, 'ENERGY'))
                   --RNGLOG('Mass Efficiency :'..MassEfficiency..'Energy Efficiency :'..EnergyEfficiency)
                   --RNGLOG('Mass Efficiency OverTime :'..self.EconomyOverTimeCurrent.MassEfficiencyOverTime..' Energy Efficiency Overtime:'..self.EconomyOverTimeCurrent.EnergyEfficiencyOverTime)
                   --RNGLOG('MassTrend :'..GetEconomyTrend(self, 'MASS')..' Energy Trend :'..GetEconomyTrend(self, 'ENERGY'))
                   --RNGLOG('Mass Trend OverTime :'..self.EconomyOverTimeCurrent.MassTrendOverTime..' Energy Trend Overtime:'..self.EconomyOverTimeCurrent.EnergyTrendOverTime)
                   --RNGLOG('Mass Income :'..MassIncome..' Energy Income :'..EnergyIncome)
                   --RNGLOG('Mass Income OverTime :'..self.EconomyOverTimeCurrent.MassIncome..' Energy Income Overtime:'..self.EconomyOverTimeCurrent.EnergyIncome)
                    local poolPlatoon = self:GetPlatoonUniquelyNamed('ArmyPool')
                    RNGLOG('ArmyPool Engineer count is '..poolPlatoon:PlatoonCategoryCount(categories.ENGINEER))
                    RNGLOG('DistributionTable '..repr(self.EngineerDistributionTable))
                    local reclaimRatio = self.EngineerDistributionTable.Reclaim / self.EngineerDistributionTable.Total
                    RNGLOG('Engineer Reclaim Ratio '..reclaimRatio)
                    local assistRatio = self.EngineerDistributionTable.Assist / self.EngineerDistributionTable.Total
                    RNGLOG('Engineer Assist Ratio '..reclaimRatio)
                    RNGLOG('Current Engineer Assist Build Power Required '..self.EngineerAssistManagerBuildPowerRequired..' for '..self.Nickname)
                    RNGLOG('Current Engineer Assist Builder Power '..self.EngineerAssistManagerBuildPower..' for '..self.Nickname)
                    --RNGLOG('BasePerimeterMonitor table')
                    --RNGLOG(repr(self.BasePerimeterMonitor))
                    if self.BaseMonitor.AlertSounded then
                       --RNGLOG('Base Monitor Alert is on')
                    end
                    RNGLOG('ACU Table '..repr(self.EnemyIntel.ACU))
                    RNGLOG('Core Mass Marker Count '..self.EcoManager.CoreMassMarkerCount)
                    RNGLOG('Core Extractor T3 percentage '..self.EcoManager.CoreExtractorT3Percentage)
                    RNGLOG('SManager Dump '..repr(self.smanager))
                    --[[for k, v in self.Zones.Land.zones do
                        for k1,v2 in v.edges do
                           --RNGLOG('Zone Edge '..v2.zone.id..' is '..v2.distance..' from '..v.id)
                        end
                        if v.friendlythreat > 0 then
                           --RNGLOG('Friend Threat at zone '..v.id)
                           --RNGLOG('Key for zone is '..k)
                           --RNGLOG('Friendly Threat is '..v.friendlythreat)
                        end
                        if v.enemythreat > 0 then
                           --RNGLOG('Enemy Threat at zone '..v.id)
                           --RNGLOG('Key for zone is '..k)
                           --RNGLOG('Enemy Threat is '..v.enemythreat)
                        end
                    end]]
                    --RNGLOG('Friendly Mex Table '..repr(self.smanager.mex))
                    --RNGLOG('Friendly Hydro Table '..repr(self.smanager.hydrocarbon))
                    --RNGLOG('Ally Extractor Table '..repr(self.BrainIntel.SelfThreat.AllyExtractorTable))
                    --RNGLOG('Enemy Mex Table '..repr(self.emanager.mex))
                    --[[if self.GraphZones.HasRun then
                       --RNGLOG('We should have graph zones now')
                        for k, v in self.BuilderManagers do
                            if v.GraphArea then
                               --RNGLOG('Graph Area for '..k.. ' is '..v.GraphArea)
                            else
                               --RNGLOG('No Graph Area for base '..k)
                            end
                        end
                    end]]
                    local mexSpend = (self.cmanager.categoryspend.mex.T1 + self.cmanager.categoryspend.mex.T2 + self.cmanager.categoryspend.mex.T3) or 0
                    RNGLOG('Current Mex Upgrade Spend is '..mexSpend)
                    RNGLOG('Current Amount we could be spending '..self.cmanager.income.r.m*0.35)
                    --LOG('Spend - Mex Upgrades '..self.cmanager.categoryspend.fact['Land'] / (self.cmanager.income.r.m - mexSpend)..' Should be less than'..self.ProductionRatios['Land'])
                    --RNGLOG('ARMY '..self.Nickname..' eco numbers:'..repr(self.cmanager))
                    --RNGLOG('ARMY '..self.Nickname..' Current Army numbers:'..repr(self.amanager.Current))
                    --RNGLOG('ARMY '..self.Nickname..' Total Army numbers:'..repr(self.amanager.Total))
                    --RNGLOG('ARMY '..self.Nickname..' Type Army numbers:'..repr(self.amanager.Type))
                   --RNGLOG('Current Land Ratio is '..self.ProductionRatios['Land'])
                   --RNGLOG('I am spending approx land '..repr(self.cmanager.categoryspend.fact.Land))
                   --RNGLOG('I should be spending approx land '..self.cmanager.income.r.m * self.ProductionRatios['Land'])
                   --RNGLOG('Current Air Ratio is '..self.ProductionRatios['Air'])
                   --RNGLOG('I am spending approx air '..repr(self.cmanager.categoryspend.fact.Air))
                   --RNGLOG('I should be spending approx air '..self.cmanager.income.r.m * self.ProductionRatios['Air'])
                   --RNGLOG('Current Naval Ratio is '..self.ProductionRatios['Naval'])
                   --RNGLOG('I am spending approx Naval '..repr(self.cmanager.categoryspend.fact.Naval))
                   --RNGLOG('I should be spending approx Naval '..self.cmanager.income.r.m * self.ProductionRatios['Naval'])
                    --RNGLOG('My AntiAir Threat : '..self.BrainIntel.SelfThreat.AntiAirNow..' Enemy AntiAir Threat : '..self.EnemyIntel.EnemyThreatCurrent.AntiAir)
                    --RNGLOG('My Air Threat : '..self.BrainIntel.SelfThreat.AirNow..' Enemy Air Threat : '..self.EnemyIntel.EnemyThreatCurrent.Air)
                    --RNGLOG('My Land Threat : '..(self.BrainIntel.SelfThreat.LandNow + self.BrainIntel.SelfThreat.AllyLandThreat)..' Enemy Land Threat : '..self.EnemyIntel.EnemyThreatCurrent.Land)
                    --RNGLOG(' My Naval Sub Threat : '..self.BrainIntel.SelfThreat.NavalSubNow..' Enemy Naval Sub Threat : '..self.EnemyIntel.EnemyThreatCurrent.NavalSub)
                    --local factionIndex = self:GetFactionIndex()
                    --RNGLOG('Air Current Ratio T1 Fighter: '..(self.amanager.Current['Air']['T1']['interceptor'] / self.amanager.Total['Air']['T1']))
                    --RNGLOG('Air Current Production Ratio Desired T1 Fighter : '..(self.amanager.Ratios[factionIndex]['Air']['T1']['interceptor']/self.amanager.Ratios[factionIndex]['Air']['T1'].total))
                    --RNGLOG('Air Current Ratio T1 Bomber: '..(self.amanager.Current['Air']['T1']['bomber'] / self.amanager.Total['Air']['T1']))
                    --RNGLOG('Air Current Production Ratio Desired T1 Bomber : '..(self.amanager.Ratios[factionIndex]['Air']['T1']['bomber']/self.amanager.Ratios[factionIndex]['Air']['T1'].total))
                    if self.EnemyIntel.ChokeFlag then
                       --RNGLOG('Choke Flag is true')
                    else
                       --RNGLOG('Choke Flag is false')
                    end
                    --RNGLOG('Graph Zone Table '..repr(self.GraphZones))
                    --RNGLOG('Total Mass Markers according to infect'..self.BrainIntel.MassMarker)
                    --RNGLOG('Total Mass Markers according to count '..self.BrainIntel.SelfThreat.MassMarker)
                end
            end
            coroutine.yield(self.TacticalMonitor.TacticalMonitorTime)
        end
    end,

    TacticalAnalysisThreadRNG = function(self)
        local ALLBPS = __blueprints
        coroutine.yield(Random(150,200))
        while true do
            if self.TacticalMonitor.TacticalMonitorStatus == 'ACTIVE' then
                RNGLOG('Run TacticalThreatAnalysisRNG')
                self:ForkThread(IntelManagerRNG.TacticalThreatAnalysisRNG, self)
            end
            self:CalculateMassMarkersRNG()
            local enemyCount = 0
            if self.EnemyIntel.EnemyCount > 0 then
                enemyCount = self.EnemyIntel.EnemyCount
            end
            if self.BrainIntel.SelfThreat.LandNow > (self.EnemyIntel.EnemyThreatCurrent.Land / enemyCount) * 1.3 and (not self.EnemyIntel.ChokeFlag) then
                --RNGLOG('Land Threat Higher, shift ratio to 0.5')
                if not self.RNGEXP then
                    self.ProductionRatios.Land = 0.5
                end
            elseif not self.EnemyIntel.ChokeFlag then
                --RNGLOG('Land Threat Lower, shift ratio to 0.6')
                self.ProductionRatios.Land = self.DefaultLandRatio
            end
            if self.BrainIntel.SelfThreat.AirNow > (self.EnemyIntel.EnemyThreatCurrent.Air / enemyCount) and (not self.EnemyIntel.ChokeFlag) then
                --RNGLOG('Air Threat Higher, shift ratio to 0.4')
                if not self.RNGEXP then
                    self.ProductionRatios.Air = 0.4
                end
            elseif not self.EnemyIntel.ChokeFlag then
                --RNGLOG('Air Threat lower, shift ratio to 0.5')
                self.ProductionRatios.Air = self.DefaultAirRatio
            end
            if self.BrainIntel.SelfThreat.NavalNow > (self.EnemyIntel.EnemyThreatCurrent.Naval / enemyCount) and (not self.EnemyIntel.ChokeFlag) then
                if not self.RNGEXP then
                    self.ProductionRatios.Naval = 0.4
                end
            elseif not self.EnemyIntel.ChokeFlag then
                self.ProductionRatios.Naval = self.DefaultNavalRatio
            end
            RNGLOG('aiBrain.EnemyIntel.EnemyCount + aiBrain.BrainIntel.AllyCount'..self.EnemyIntel.EnemyCount..' '..self.BrainIntel.AllyCount)
            RNGLOG('Mass Marker Count '..self.BrainIntel.SelfThreat.MassMarker)
            RNGLOG('self.BrainIntel.SelfThreat.ExtractorCount '..self.BrainIntel.SelfThreat.ExtractorCount)
            RNGLOG('self.BrainIntel.MassSharePerPlayer '..self.BrainIntel.MassSharePerPlayer)
            if self.BrainIntel.SelfThreat.ExtractorCount > self.BrainIntel.MassSharePerPlayer then
                if self.EconomyUpgradeSpend < 0.35 then
                    RNGLOG('Increasing EconomyUpgradeSpend to 0.36')
                    self.EconomyUpgradeSpend = 0.36
                end
            elseif self.EconomyUpgradeSpend > 0.35 then
                self.EconomyUpgradeSpend = self.EconomyUpgradeSpendDefault
            end
            if self.BrainIntel.AirPhase < 2 then
                if self.smanager.fact.Air.T2 > 0 then
                    self.BrainIntel.AirPhase = 2
                end
            elseif self.BrainIntel.AirPhase < 3 then
                if self.smanager.fact.Air.T3 > 0 then
                    self.BrainIntel.AirPhase = 3
                end
            end
            if self.BrainIntel.LandPhase < 2 then
                if self.smanager.fact.Land.T2 > 0 then
                    self.BrainIntel.LandPhase = 2
                end
            elseif self.BrainIntel.LandPhase < 3 then
                if self.smanager.fact.Land.T3 > 0 then
                    self.BrainIntel.LandPhase = 3
                end
            end
            if self.BrainIntel.NavalPhase < 2 then
                if self.smanager.fact.Naval.T2 > 0 then
                    self.BrainIntel.NavalPhase = 2
                end
            elseif self.BrainIntel.NavalPhase < 3 then
                if self.smanager.fact.Naval.T3 > 0 then
                    self.BrainIntel.NavalPhase = 3
                end
            end
            RNGLOG('Current Air Phase is '..self.BrainIntel.AirPhase)
            RNGLOG('Current Land Phase is '..self.BrainIntel.LandPhase)
            RNGLOG('Current Naval Phase is '..self.BrainIntel.NavalPhase)

            --RNGLOG('(self.EnemyIntel.EnemyCount + self.BrainIntel.AllyCount) / self.BrainIntel.SelfThreat.MassMarkerBuildable'..self.BrainIntel.SelfThreat.MassMarkerBuildable / (self.EnemyIntel.EnemyCount + self.BrainIntel.AllyCount))
            --RNGLOG('self.EnemyIntel.EnemyCount '..self.EnemyIntel.EnemyCount)
            --RNGLOG('self.BrainIntel.AllyCount '..self.BrainIntel.AllyCount)
            --RNGLOG('self.BrainIntel.SelfThreat.MassMarkerBuildable'..self.BrainIntel.SelfThreat.MassMarkerBuildable)
            coroutine.yield(600)
        end
    end,

    EnemyThreatCheckRNG = function(self, ALLBPS)
        local selfIndex = self:GetArmyIndex()
        local enemyBrains = {}
        local enemyAirThreat = 0
        local enemyAntiAirThreat = 0
        local enemyNavalThreat = 0
        local enemyLandThreat = 0
        local enemyNavalSubThreat = 0
        local enemyExtractorthreat = 0
        local enemyExtractorCount = 0
        local enemyDefenseAir = 0
        local enemyDefenseSurface = 0
        local enemyDefenseSub = 0
        local enemyACUGun = 0

        --RNGLOG('Starting Threat Check at'..GetGameTick())
        for index, brain in ArmyBrains do
            if IsEnemy(selfIndex, brain:GetArmyIndex()) then
                RNGINSERT(enemyBrains, brain)
            end
        end
        if next(enemyBrains) then
            for k, enemy in enemyBrains do

                local gunBool = false
                local acuHealth = 0
                local lastSpotted = 0
                local enemyIndex = enemy:GetArmyIndex()
                if not ArmyIsCivilian(enemyIndex) then
                    local enemyAir = GetListOfUnits( enemy, categories.MOBILE * categories.AIR - categories.TRANSPORTFOCUS - categories.SATELLITE - categories.INSIGNIFICANTUNIT, false, false)
                    for _,v in enemyAir do
                        -- previous method of getting unit ID before the property was added.
                        --local unitbpId = v:GetUnitId()
                        --RNGLOG('Unit blueprint id test only on dev branch:'..v.UnitId)
                        bp = ALLBPS[v.UnitId].Defense
            
                        enemyAirThreat = enemyAirThreat + bp.AirThreatLevel + bp.SubThreatLevel + bp.SurfaceThreatLevel
                        enemyAntiAirThreat = enemyAntiAirThreat + bp.AirThreatLevel
                    end
                    coroutine.yield(1)
                    local enemyExtractors = GetListOfUnits( enemy, categories.STRUCTURE * categories.MASSEXTRACTION, false, false)
                    for _,v in enemyExtractors do
                        bp = ALLBPS[v.UnitId].Defense

                        enemyExtractorthreat = enemyExtractorthreat + bp.EconomyThreatLevel
                        enemyExtractorCount = enemyExtractorCount + 1
                    end
                    coroutine.yield(1)
                    local enemyNaval = GetListOfUnits( enemy, categories.NAVAL * ( categories.MOBILE + categories.DEFENSE ), false, false )
                    for _,v in enemyNaval do
                        bp = ALLBPS[v.UnitId].Defense
                        --RNGLOG('NavyThreat unit is '..v.UnitId)
                        --RNGLOG('NavyThreat is '..bp.SubThreatLevel)
                        enemyNavalThreat = enemyNavalThreat + bp.AirThreatLevel + bp.SubThreatLevel + bp.SurfaceThreatLevel
                        enemyNavalSubThreat = enemyNavalSubThreat + bp.SubThreatLevel
                    end
                    coroutine.yield(1)
                    local enemyLand = GetListOfUnits( enemy, categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.COMMAND - categories.INSIGNIFICANTUNIT , false, false)
                    for _,v in enemyLand do
                        bp = ALLBPS[v.UnitId].Defense
                        enemyLandThreat = enemyLandThreat + bp.SurfaceThreatLevel
                    end
                    coroutine.yield(1)
                    local enemyDefense = GetListOfUnits( enemy, categories.STRUCTURE * categories.DEFENSE - categories.SHIELD, false, false )
                    for _,v in enemyDefense do
                        bp = ALLBPS[v.UnitId].Defense
                        --RNGLOG('DefenseThreat unit is '..v.UnitId)
                        --RNGLOG('DefenseThreat is '..bp.SubThreatLevel)
                        enemyDefenseAir = enemyDefenseAir + bp.AirThreatLevel
                        enemyDefenseSurface = enemyDefenseSurface + bp.SurfaceThreatLevel
                        enemyDefenseSub = enemyDefenseSub + bp.SubThreatLevel
                    end
                    coroutine.yield(1)
                    if self.EnemyIntel.Phase < 2 then
                        if GetCurrentUnits( enemy, categories.STRUCTURE * categories.FACTORY * categories.TECH2) > 0 then
                            RNGLOG('Enemy has moved to T2')
                            self.EnemyIntel.Phase = 2
                        end
                    elseif self.EnemyIntel.Phase < 3 then
                        if GetCurrentUnits( enemy, categories.STRUCTURE * categories.FACTORY * categories.TECH3) > 0 then
                            RNGLOG('Enemy has moved to T3')
                            self.EnemyIntel.Phase = 3
                        end
                    end
                    local enemyACU = GetListOfUnits( enemy, categories.COMMAND, false, false )
                    for _,v in enemyACU do
                        local factionIndex = enemy:GetFactionIndex()
                        if factionIndex == 1 then
                            if v:HasEnhancement('HeavyAntiMatterCannon') then
                                enemyACUGun = enemyACUGun + 1
                                gunBool = true
                            end
                        elseif factionIndex == 2 then
                            if v:HasEnhancement('CrysalisBeam') then
                                enemyACUGun = enemyACUGun + 1
                                gunBool = true
                            end
                        elseif factionIndex == 3 then
                            if v:HasEnhancement('CoolingUpgrade') then
                                enemyACUGun = enemyACUGun + 1
                                gunBool = true
                            end
                        elseif factionIndex == 4 then
                            if v:HasEnhancement('RateOfFire') then
                                enemyACUGun = enemyACUGun + 1
                                gunBool = true
                            end
                        end
                        if self.CheatEnabled then
                            acuHealth = v:GetHealth()
                            lastSpotted = GetGameTimeSeconds()
                        end
                    end
                    if gunBool then
                        self.EnemyIntel.ACU[enemyIndex].Gun = true
                        --RNGLOG('Gun Upgrade Present on army '..enemy.Nickname)
                    else
                        self.EnemyIntel.ACU[enemyIndex].Gun = false
                    end
                    if self.CheatEnabled then
                        self.EnemyIntel.ACU[enemyIndex].HP = acuHealth
                        self.EnemyIntel.ACU[enemyIndex].LastSpotted = lastSpotted
                        --RNGLOG('Cheat is enabled and acu has '..acuHealth..' Health '..'Brain intel says '..self.EnemyIntel.ACU[enemyIndex].HP)
                    end
                end
            end
        end
        self.EnemyIntel.EnemyThreatCurrent.ACUGunUpgrades = enemyACUGun
        self.EnemyIntel.EnemyThreatCurrent.Air = enemyAirThreat
        self.EnemyIntel.EnemyThreatCurrent.AntiAir = enemyAntiAirThreat
        self.EnemyIntel.EnemyThreatCurrent.Extractor = enemyExtractorthreat
        self.EnemyIntel.EnemyThreatCurrent.ExtractorCount = enemyExtractorCount
        self.EnemyIntel.EnemyThreatCurrent.Naval = enemyNavalThreat
        self.EnemyIntel.EnemyThreatCurrent.NavalSub = enemyNavalSubThreat
        self.EnemyIntel.EnemyThreatCurrent.Land = enemyLandThreat
        self.EnemyIntel.EnemyThreatCurrent.DefenseAir = enemyDefenseAir
        self.EnemyIntel.EnemyThreatCurrent.DefenseSurface = enemyDefenseSurface
        self.EnemyIntel.EnemyThreatCurrent.DefenseSub = enemyDefenseSub
        --RNGLOG('Completing Threat Check'..GetGameTick())
    end,

    SelfThreatCheckRNG = function(self, ALLBPS)
        -- Get AI strength
        local selfIndex = self:GetArmyIndex()
        local GetPosition = moho.entity_methods.GetPosition
        local bp
        coroutine.yield(1)
        local allyBrains = {}
        for index, brain in ArmyBrains do
            if index ~= self:GetArmyIndex() then
                if IsAlly(selfIndex, brain:GetArmyIndex()) then
                    RNGINSERT(allyBrains, brain)
                end
            end
        end
        local allyExtractors = {}
        local allyExtractorCount = 0
        local allyExtractorthreat = 0
        local allyLandThreat = 0
        --RNGLOG('Number of Allies '..RNGGETN(allyBrains))
        coroutine.yield(1)
        if next(allyBrains) then
            for k, ally in allyBrains do
                local allyExtractorList = GetListOfUnits( ally, categories.STRUCTURE * categories.MASSEXTRACTION, false, false)
                for _,v in allyExtractorList do
                    if not v.Dead and not v.zoneid and self.ZonesInitialized then
                        --LOG('unit has no zone')
                        local mexPos = GetPosition(v)
                        if RUtils.PositionOnWater(mexPos[1], mexPos[3]) then
                            -- tbd define water based zones
                            v.zoneid = 'water'
                        else
                            v.zoneid = MAP:GetZoneID(mexPos,self.Zones.Land.index)
                            --LOG('Unit zone is '..unit.zoneid)
                        end
                    end
                    if not allyExtractors[v.zoneid] then
                        --LOG('Trying to add unit to zone')
                        allyExtractors[v.zoneid] = {T1 = 0,T2 = 0,T3 = 0,}
                    end
                    if ALLBPS[v.UnitId].CategoriesHash.TECH1 then
                        allyExtractors[v.zoneid].T1=allyExtractors[v.zoneid].T1+1
                    elseif ALLBPS[v.UnitId].CategoriesHash.TECH2 then
                        allyExtractors[v.zoneid].T2=allyExtractors[v.zoneid].T2+1
                    elseif ALLBPS[v.UnitId].CategoriesHash.TECH3 then
                        allyExtractors[v.zoneid].T3=allyExtractors[v.zoneid].T3+1
                    end

                    allyExtractorthreat = allyExtractorthreat + ALLBPS[v.UnitId].Defense.EconomyThreatLevel
                    allyExtractorCount = allyExtractorCount + 1
                end
                local allylandThreat = GetListOfUnits( ally, categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.COMMAND , false, false)
                
                for _,v in allylandThreat do
                    allyLandThreat = allyLandThreat + ALLBPS[v.UnitId].Defense.SurfaceThreatLevel
                end
            end
        end
        self.BrainIntel.SelfThreat.AllyExtractorTable = allyExtractors
        self.BrainIntel.SelfThreat.AllyExtractorCount = allyExtractorCount + self.BrainIntel.SelfThreat.ExtractorCount
        self.BrainIntel.SelfThreat.AllyExtractor = allyExtractorthreat + self.BrainIntel.SelfThreat.Extractor
        self.BrainIntel.SelfThreat.AllyLandThreat = allyLandThreat
        --RNGLOG('AllyExtractorCount is '..self.BrainIntel.SelfThreat.AllyExtractorCount)
        --RNGLOG('SelfExtractorCount is '..self.BrainIntel.SelfThreat.ExtractorCount)
        --RNGLOG('AllyExtractorThreat is '..self.BrainIntel.SelfThreat.AllyExtractor)
        --RNGLOG('SelfExtractorThreat is '..self.BrainIntel.SelfThreat.Extractor)
        coroutine.yield(1)
    end,

    IMAPConfigurationRNG = function(self)
        -- Used to configure imap values, used for setting threat ring sizes depending on map size to try and get a somewhat decent radius
        local maxmapdimension = math.max(ScenarioInfo.size[1],ScenarioInfo.size[2])

        if maxmapdimension == 256 then
            self.BrainIntel.IMAPConfig.OgridRadius = 22.5
            self.BrainIntel.IMAPConfig.IMAPSize = 32
            self.BrainIntel.IMAPConfig.Rings = 2
        elseif maxmapdimension == 512 then
            self.BrainIntel.IMAPConfig.OgridRadius = 22.5
            self.BrainIntel.IMAPConfig.IMAPSize = 32
            self.BrainIntel.IMAPConfig.Rings = 2
        elseif maxmapdimension == 1024 then
            self.BrainIntel.IMAPConfig.OgridRadius = 45.0
            self.BrainIntel.IMAPConfig.IMAPSize = 64
            self.BrainIntel.IMAPConfig.Rings = 1
        elseif maxmapdimension == 2048 then
            self.BrainIntel.IMAPConfig.OgridRadius = 89.5
            self.BrainIntel.IMAPConfig.IMAPSize = 128
            self.BrainIntel.IMAPConfig.Rings = 0
        else
            self.BrainIntel.IMAPConfig.OgridRadius = 180.0
            self.BrainIntel.IMAPConfig.IMAPSize = 256
            self.BrainIntel.IMAPConfig.Rings = 0
        end
    end,

    TacticalMonitorRNG = function(self, ALLBPS)
        -- Tactical Monitor function. Keeps an eye on the battlefield and takes points of interest to investigate.
        coroutine.yield(Random(1,7))
        --RNGLOG('* AI-RNG: Tactical Monitor Threat Pass')
        local enemyBrains = {}
        local multiplier
        local enemyStarts = self.EnemyIntel.EnemyStartLocations
        local factionIndex = self:GetFactionIndex()
        local startX, startZ = self:GetArmyStartPos()
        --RNGLOG('Upgrade Mode is  '..self.UpgradeMode)
        if self.CheatEnabled then
            multiplier = self.EcoManager.EcoMultiplier
        else
            multiplier = 1
        end
        local gameTime = GetGameTimeSeconds()
        --RNGLOG('gameTime is '..gameTime..' Upgrade Mode is '..self.UpgradeMode)
        if self.earlyFlag and gameTime < (360 / multiplier) then
            self.amanager.Ratios[factionIndex].Land.T1.arty = 0
            self.amanager.Ratios[factionIndex].Land.T1.aa = 0
        elseif self.earlyFlag then
            self.amanager.Ratios[factionIndex].Land.T1.arty = 15
            self.amanager.Ratios[factionIndex].Land.T1.aa = 12
            self.earlyFlag = false
        end
        if self.BrainIntel.SelfThreat.AirNow < (self.EnemyIntel.EnemyThreatCurrent.Air / self.EnemyIntel.EnemyCount) then
            RNGLOG('Less than enemy air threat, increase mobile aa numbers')
            self.amanager.Ratios[factionIndex].Land.T1.aa = 20
            self.amanager.Ratios[factionIndex].Land.T2.aa = 20
            self.amanager.Ratios[factionIndex].Land.T2.aa = 20
        else
            RNGLOG('More than enemy air threat, decrease mobile aa numbers')
            self.amanager.Ratios[factionIndex].Land.T1.aa = 10
            self.amanager.Ratios[factionIndex].Land.T2.aa = 10
            self.amanager.Ratios[factionIndex].Land.T2.aa = 10
        end

        if self.EnemyIntel.EnemyCount < 2 and gameTime < (240 / multiplier) then
            self.UpgradeMode = 'Caution'
        elseif gameTime > (240 / multiplier) and self.UpgradeMode == 'Caution' then
            --RNGLOG('Setting UpgradeMode to Normal')
            self.UpgradeMode = 'Normal'
            self.UpgradeIssuedLimit = 1
        elseif gameTime > (240 / multiplier) and self.UpgradeIssuedLimit == 1 and self.UpgradeMode == 'Aggresive' then
            self.UpgradeIssuedLimit = self.UpgradeIssuedLimit + 1
        end
        self.EnemyIntel.EnemyThreatLocations = {}

        -- debug, remove later on
        if enemyStarts then
            --RNGLOG('* AI-RNG: Enemy Start Locations :'..repr(enemyStarts))
        end
        local selfIndex = self:GetArmyIndex()
        local potentialThreats = {}
        local threatTypes = {
            'Land',
            'AntiAir',
            'Naval',
            'StructuresNotMex',
            --'AntiSurface'
        }
        -- Get threats for each threat type listed on the threatTypes table. Full map scan.
        for _, t in threatTypes do
            rawThreats = GetThreatsAroundPosition(self, self.BuilderManagers.MAIN.Position, 16, true, t)
            for _, raw in rawThreats do
                local threatRow = {posX=raw[1], posZ=raw[2], rThreat=raw[3], rThreatType=t}
                RNGINSERT(potentialThreats, threatRow)
            end
        end
        --RNGLOG('Potential Threats :'..repr(potentialThreats))
        coroutine.yield(2)
        local phaseTwoThreats = {}
        local threatLimit = 20
        -- Set a raw threat table that is replaced on each loop so we can get a snapshot of current enemy strength across the map.
        self.EnemyIntel.EnemyThreatRaw = potentialThreats

        -- Remove threats that are too close to the enemy base so we are focused on whats happening in the battlefield.
        -- Also set if the threat is on water or not
        -- Set the time the threat was identified so we can flush out old entries
        -- If you want the full map thats what EnemyThreatRaw is for.
        if next(potentialThreats) then
            local threatLocation = {}
            for _, threat in potentialThreats do
                --RNGLOG('* AI-RNG: Threat is'..repr(threat))
                if threat.rThreat > threatLimit then
                    --RNGLOG('* AI-RNG: Tactical Potential Interest Location Found at :'..repr(threat))
                    if RUtils.PositionOnWater(threat.posX, threat.posZ) then
                        onWater = true
                    else
                        onWater = false
                    end
                    threatLocation = {Position = {threat.posX, threat.posZ}, EnemyBaseRadius = false, Threat=threat.rThreat, ThreatType=threat.rThreatType, PositionOnWater=onWater }
                    RNGINSERT(phaseTwoThreats, threatLocation)
                end
            end
            --RNGLOG('* AI-RNG: Pre Sorted Potential Valid Threat Locations :'..repr(phaseTwoThreats))
            for _, threat in phaseTwoThreats do
                for q, pos in enemyStarts do
                    --RNGLOG('* AI-RNG: Distance Between Threat and Start Position :'..VDist2Sq(threat.posX, threat.posZ, pos[1], pos[3]))
                    if VDist2Sq(threat.Position[1], threat.Position[2], pos.Position[1], pos.Position[3]) < 10000 then
                        threat.EnemyBaseRadius = true
                    end
                end
            end
            --[[for Index_1, value_1 in phaseTwoThreats do
                for Index_2, value_2 in phaseTwoThreats do
                    -- no need to check against self
                    if Index_1 == Index_2 then 
                        continue
                    end
                    -- check if we have the same position
                    --RNGLOG('* AI-RNG: checking '..repr(value_1.Position)..' == '..repr(value_2.Position))
                    if value_1.Position[1] == value_2.Position[1] and value_1.Position[2] == value_2.Position[2] then
                        --RNGLOG('* AI-RNG: eual position '..repr(value_1.Position)..' == '..repr(value_2.Position))
                        if value_1.EnemyBaseRadius == false then
                            --RNGLOG('* AI-RNG: deleating '..repr(value_1))
                            phaseTwoThreats[Index_1] = nil
                            break
                        elseif value_2.EnemyBaseRadius == false then
                            --RNGLOG('* AI-RNG: deleating '..repr(value_2))
                            phaseTwoThreats[Index_2] = nil
                            break
                        else
                            --RNGLOG('* AI-RNG: Both entires have true, deleting nothing')
                        end
                    end
                end
            end]]
            --RNGLOG('* AI-RNG: second table pass :'..repr(potentialThreats))
            local currentGameTime = GetGameTimeSeconds()
            for _, threat in phaseTwoThreats do
                threat.InsertTime = currentGameTime
                RNGINSERT(self.EnemyIntel.EnemyThreatLocations, threat)
            end
            --RNGLOG('* AI-RNG: Final Valid Threat Locations :'..repr(self.EnemyIntel.EnemyThreatLocations))
        end
        coroutine.yield(2)

        local landThreatAroundBase = 0
        --RNGLOG(repr(self.EnemyIntel.EnemyThreatLocations))
        if next(self.EnemyIntel.EnemyThreatLocations) then
            for k, threat in self.EnemyIntel.EnemyThreatLocations do
                if threat.ThreatType == 'Land' then
                    local threatDistance = VDist2Sq(startX, startZ, threat.Position[1], threat.Position[2])
                    if threatDistance < 32400 then
                        landThreatAroundBase = landThreatAroundBase + threat.Threat
                    end
                end
            end
            --RNGLOG('Total land threat around base '..landThreatAroundBase)
            if (gameTime < 900) and (landThreatAroundBase > 30) then
                --RNGLOG('BaseThreatCaution True')
                self.BrainIntel.SelfThreat.BaseThreatCaution = true
            elseif (gameTime > 900) and (landThreatAroundBase > 60) then
                --RNGLOG('BaseThreatCaution True')
                self.BrainIntel.SelfThreat.BaseThreatCaution = true
            else
                --RNGLOG('BaseThreatCaution False')
                self.BrainIntel.SelfThreat.BaseThreatCaution = false
            end
        end
        
        if (gameTime > 1200 and self.BrainIntel.SelfThreat.AllyExtractorCount > self.BrainIntel.SelfThreat.MassMarker / 1.5) or self.EnemyIntel.ChokeFlag then
            --RNGLOG('Switch to agressive upgrade mode')
            self.UpgradeMode = 'Aggressive'
            self.EcoManager.ExtractorUpgradeLimit.TECH1 = 2
        elseif gameTime > 1200 then
            --RNGLOG('Switch to normal upgrade mode')
            self.UpgradeMode = 'Normal'
            self.EcoManager.ExtractorUpgradeLimit.TECH1 = 1
        end
        
        --RNGLOG('Ally Count is '..self.BrainIntel.AllyCount)
        --RNGLOG('Enemy Count is '..self.EnemyIntel.EnemyCount)
        --RNGLOG('Eco Costing Multiplier is '..self.EcoManager.EcoMultiplier)
        --RNGLOG('Current Self Sub Threat :'..self.BrainIntel.SelfThreat.NavalSubNow)
        --RNGLOG('Current Self Naval Threat :'..self.BrainIntel.SelfThreat.NavalNow)
        --RNGLOG('Current Self Land Threat :'..self.BrainIntel.SelfThreat.LandNow)
        --RNGLOG('Current Enemy Sub Threat :'..self.EnemyIntel.EnemyThreatCurrent.NavalSub)
        --RNGLOG('Current Self Air Threat :'..self.BrainIntel.SelfThreat.AirNow)
        --RNGLOG('Current Self AntiAir Threat :'..self.BrainIntel.SelfThreat.AntiAirNow)
        --RNGLOG('Current Enemy Air Threat :'..self.EnemyIntel.EnemyThreatCurrent.Air)
        --RNGLOG('Current Enemy AntiAir Threat :'..self.EnemyIntel.EnemyThreatCurrent.AntiAir)
        --RNGLOG('Current Enemy Extractor Threat :'..self.EnemyIntel.EnemyThreatCurrent.Extractor)
        --RNGLOG('Current Enemy Extractor Count :'..self.EnemyIntel.EnemyThreatCurrent.ExtractorCount)
        --RNGLOG('Current Self Extractor Threat :'..self.BrainIntel.SelfThreat.Extractor)
        --RNGLOG('Current Self Extractor Count :'..self.BrainIntel.SelfThreat.ExtractorCount)
        --RNGLOG('Current Mass Marker Count :'..self.BrainIntel.SelfThreat.MassMarker)
        --RNGLOG('Current Defense Air Threat :'..self.EnemyIntel.EnemyThreatCurrent.DefenseAir)
        --RNGLOG('Current Defense Sub Threat :'..self.EnemyIntel.EnemyThreatCurrent.DefenseSub)
        --RNGLOG('Current Enemy Land Threat :'..self.EnemyIntel.EnemyThreatCurrent.Land)
        --RNGLOG('Current Number of Enemy Gun ACUs :'..self.EnemyIntel.EnemyThreatCurrent.ACUGunUpgrades)
        coroutine.yield(2)
    end,

    CheckDirectorTargetAvailable = function(self, threatType, platoonThreat, platoonType, strikeDamage, platoonDPS, platoonPosition)
        local potentialTarget = false
        local targetType = false
        local potentialTargetValue = 0
        if platoonType then
            RNGLOG('CheckDirectorTargetAvailable type is '..platoonType)
        else
            RNGLOG('No platoonType sent to director, what sort of platoon is this?')
        end

        if strikeDamage then
            RNGLOG('Strike damage for attack is '..strikeDamage)
        else
            RNGLOG('No StrikeDamage passed for a threat type of '..threatType)
        end
        if platoonDPS then
            RNGLOG('PlatoonDPS damage for attack is '..platoonDPS)
        else
            RNGLOG('No PlatoonDPS passed for a threat type of '..threatType)
        end

        local enemyACUIndexes = {}

        for k, v in self.EnemyIntel.ACU do
            RNGLOG('EnemyIntel.ACU loop')
            if not v.Ally and v.HP ~= 0 and v.LastSpotted ~= 0 then
                RNGLOG('EnemyIntel.ACU loop non ally found')
                RNGLOG('ACU has '..v.HP..' last spotted at '..v.LastSpotted..' our threat is '..platoonThreat)
                RNGLOG('ACU last spotted '..(GetGameTimeSeconds() - v.LastSpotted)..' seconds ago')
                if platoonType == 'GUNSHIP' and platoonDPS then
                    RNGLOG('EnemyIntel.ACU loop gunship platoon with a dps of '..platoonDPS)
                    if ((v.HP / platoonDPS) < 15 or v.HP < 2000) and (GetGameTimeSeconds() - 120) < v.LastSpotted then
                        RNGLOG('ACU Target valid, adding to index list')
                        RNGINSERT(enemyACUIndexes, { Index = k, Position = v.Position } )
                        local scoutRequired = true
                        for c, b in self.InterestList.MustScout do
                            if b.ACUIndex == k then
                                RNGLOG('ACU Already due to be scouted')
                                scoutRequired = false
                                break
                            end
                        end
                        if scoutRequired then
                            RNGLOG('Adding ACU to must scout list')
                            RNGINSERT(self.InterestList.MustScout, { Position = v.Position, LastScouted = 0, ACUIndex = k })
                        end
                    end
                elseif platoonType == 'BOMBER' and strikeDamage then
                    if strikeDamage > v.HP * 0.80 then
                        RNGINSERT(enemyACUIndexes, { Index = k, Position = v.Position })
                        local scoutRequired = true
                        for c, b in self.InterestList.MustScout do
                            if b.ACUIndex == k then
                                RNGLOG('ACU Already due to be scouted')
                                scoutRequired = false
                                break
                            end
                        end
                        if scoutRequired then
                            RNGLOG('Adding ACU to must scout list')
                            RNGINSERT(self.InterestList.MustScout, { Position = v.Position, LastScouted = 0, ACUIndex = k })
                        end
                    end
                end
            end
        end

        if next(enemyACUIndexes) then
            for k, v in enemyACUIndexes do
                local acuUnits = GetUnitsAroundPoint(self, categories.COMMAND, v.Position, 120, 'Enemy')
                for c, b in acuUnits do
                    if not b.Dead and b:GetAIBrain():GetArmyIndex() == v.Index then
                        potentialTarget = b
                        potentialTargetValue = 10000
                        RNGLOG('Enemy ACU returned as potential target for Director')
                    end
                end
            end
        end
        

        if not potentialTarget then
            if self.EnemyIntel.DirectorData.Intel and next(self.EnemyIntel.DirectorData.Intel) then
                for k, v in self.EnemyIntel.DirectorData.Intel do
                    --RNGLOG('Intel Target Data ')
                    --RNGLOG('Air Threat Around unit is '..v.Air)
                    --RNGLOG('Land Threat Around unit is '..v.Land)
                    --RNGLOG('Enemy Index of unit is '..v.EnemyIndex)
                    --RNGLOG('Unit ID is '..v.Object.UnitId)
                    if v.Value > potentialTargetValue and v.Object and (not v.Object.Dead) and (not v.Shielded) then
                        if threatType and platoonThreat then
                            if threatType == 'AntiAir' then
                                if v.Air > platoonThreat then
                                    continue
                                end
                                if platoonType == 'BOMBER' and strikeDamage then
                                    if strikeDamage > 0 and v.HP / 3 > strikeDamage then
                                        RNGLOG('Not enough strike damage HP vs strikeDamage '..v.HP..' '..strikeDamage)
                                        continue
                                    end
                                elseif platoonType == 'GUNSHIP' and platoonDPS then
                                    if (v.HP / platoonDPS) > 15 then
                                        RNGLOG('Not enough dps to kill in under 10 seconds '..v.HP..' '..platoonDPS)
                                        continue
                                    end
                                else
                                    RNGLOG('This Air platoon had no gunship or bomber value set wtf')
                                end
                            elseif threatType == 'Land' then
                                if v.Land > platoonThreat then
                                    continue
                                end
                            end
                        end
                        potentialTargetValue = v.Value
                        potentialTarget = v.Object
                    end
                end
            end
            if self.EnemyIntel.DirectorData.Energy and next(self.EnemyIntel.DirectorData.Energy) then
                for k, v in self.EnemyIntel.DirectorData.Energy do
                    --RNGLOG('Energy Target Data ')
                    --RNGLOG('Air Threat Around unit is '..v.Air)
                    --RNGLOG('Land Threat Around unit is '..v.Land)
                    --RNGLOG('Enemy Index of unit is '..v.EnemyIndex)
                    --RNGLOG('Unit ID is '..v.Object.UnitId)
                    if v.Value > potentialTargetValue and v.Object and not v.Object.Dead and (not v.Shielded) then
                        if threatType and platoonThreat then
                            if threatType == 'AntiAir' then
                                if v.Air > platoonThreat then
                                    continue
                                end
                                if platoonType == 'BOMBER' and strikeDamage then
                                    if strikeDamage > 0 and v.HP / 3 > strikeDamage then
                                        RNGLOG('Not enough strike damage HP vs strikeDamage '..v.HP..' '..strikeDamage)
                                        continue
                                    end
                                elseif platoonType == 'GUNSHIP' and platoonDPS then
                                    if (v.HP / platoonDPS) > 15 then
                                        RNGLOG('Not enough dps to kill in under 10 seconds '..v.HP..' '..platoonDPS)
                                        continue
                                    end
                                else
                                    RNGLOG('This Air platoon had no gunship or bomber value set wtf')
                                end
                            elseif threatType == 'Land' then
                                if v.Land > platoonThreat then
                                    continue
                                end
                            end
                        end
                        potentialTargetValue = v.Value
                        potentialTarget = v.Object
                    end
                end
            end
            if self.EnemyIntel.DirectorData.Factory and next(self.EnemyIntel.DirectorData.Factory) then
                for k, v in self.EnemyIntel.DirectorData.Factory do
                    --RNGLOG('Energy Target Data ')
                    --RNGLOG('Air Threat Around unit is '..v.Air)
                    --RNGLOG('Land Threat Around unit is '..v.Land)
                    --RNGLOG('Enemy Index of unit is '..v.EnemyIndex)
                    --RNGLOG('Unit ID is '..v.Object.UnitId)
                    
                    if v.Value > potentialTargetValue and v.Object and not v.Object.Dead and (not v.Shielded) then
                        if threatType and platoonThreat then
                            if threatType == 'AntiAir' then
                                if v.Air > platoonThreat then
                                    continue
                                end
                                if platoonType == 'BOMBER' and strikeDamage then
                                    if strikeDamage > 0 and v.HP / 3 > strikeDamage then
                                        RNGLOG('Not enough strike damage HP vs strikeDamage '..v.HP..' '..strikeDamage)
                                        continue
                                    end
                                elseif platoonType == 'GUNSHIP' and platoonDPS then
                                    if (v.HP / platoonDPS) > 15 then
                                        RNGLOG('Not enough dps to kill in under 10 seconds '..v.HP..' '..platoonDPS)
                                        continue
                                    end
                                else
                                    RNGLOG('This Air platoon had no gunship or bomber value set wtf')
                                end
                            elseif threatType == 'Land' then
                                if v.Land > platoonThreat then
                                    continue
                                end
                            end
                        end
                        potentialTargetValue = v.Value
                        potentialTarget = v.Object
                    end
                end
            end
            if self.EnemyIntel.DirectorData.Strategic and next(self.EnemyIntel.DirectorData.Strategic) then
                for k, v in self.EnemyIntel.DirectorData.Strategic do
                    --RNGLOG('Energy Target Data ')
                    --RNGLOG('Air Threat Around unit is '..v.Air)
                    --RNGLOG('Land Threat Around unit is '..v.Land)
                    --RNGLOG('Enemy Index of unit is '..v.EnemyIndex)
                    --RNGLOG('Unit ID is '..v.Object.UnitId)
                    if v.Value > potentialTargetValue and v.Object and not v.Object.Dead and (not v.Shielded) then
                        if threatType and platoonThreat then
                            if threatType == 'AntiAir' then
                                if v.Air > platoonThreat then
                                    continue
                                end
                                if platoonType == 'BOMBER' and strikeDamage then
                                    if strikeDamage > 0 and v.HP / 3 > strikeDamage then
                                        RNGLOG('Not enough strike damage HP vs strikeDamage '..v.HP..' '..strikeDamage)
                                        continue
                                    end
                                elseif platoonType == 'GUNSHIP' and platoonDPS then
                                    if (v.HP / platoonDPS) > 15 then
                                        RNGLOG('Not enough dps to kill in under 10 seconds '..v.HP..' '..platoonDPS)
                                        continue
                                    end
                                else
                                    RNGLOG('This Air platoon had no gunship or bomber value set wtf')
                                end
                            elseif threatType == 'Land' then
                                if v.Land > platoonThreat then
                                    continue
                                end
                            end
                        end
                        potentialTargetValue = v.Value
                        potentialTarget = v.Object
                    end
                end
            end
        end
        if not potentialTarget then
            local closestMex = false
            local airThreat = false
            for _, v in self.lastknown do
                if v.type == 'mex' and not v.object.Dead then
                    if EntityCategoryContains(categories.TECH2 + categories.TECH3, v.object) then
                        if platoonType == 'BOMBER' and strikeDamage and strikeDamage > 0 and v.object:GetHealth() / 3 < strikeDamage then
                            local positionThreat = GetThreatAtPosition(self, v.Position, self.BrainIntel.IMAPConfig.Rings, true, threatType)
                            if not airThreat or positionThreat < airThreat then
                                airThreat = positionThreat
                                closestMex = v.object
                                if airThreat == 0 then
                                    break
                                end
                            end
                        elseif platoonType == 'GUNSHIP' and platoonDPS and (v.object:GetHealth() / platoonDPS) <= 15 then
                            local positionThreat = GetThreatAtPosition(self, v.Position, self.BrainIntel.IMAPConfig.Rings, true, threatType)
                            if not airThreat or positionThreat < airThreat then
                                airThreat = positionThreat
                                closestMex = v.object
                                if airThreat == 0 then
                                    break
                                end
                            end
                        end
                    end
                end
            end
            if closestMex then
                RNGLOG('We have a mex to target from the director')
                potentialTarget = closestMex
            end
        end
        if potentialTarget and not potentialTarget.Dead then
           --RNGLOG('Target being returned is '..potentialTarget.UnitId)
            if strikeDamage then
               --RNGLOG('Strike Damage for target is '..strikeDamage)
            else
               --RNGLOG('No Strike Damage was passed for this target strike')
            end
            return potentialTarget
        end
        return false
    end,

    EcoMassManagerRNG = function(self)
    -- Watches for low power states
        while true do
            if self.EcoManager.EcoManagerStatus == 'ACTIVE' then
                if GetGameTimeSeconds() < 240 then
                    coroutine.yield(50)
                    continue
                end
                local massStateCaution = self:EcoManagerMassStateCheck()
                local unitTypePaused = false
                
                if massStateCaution then
                    --RNGLOG('massStateCaution State Caution is true')
                    local massCycle = 0
                    local unitTypePaused = {}
                    while massStateCaution do
                        local massPriorityTable = {}
                        local priorityNum = 0
                        local priorityUnit = false
                        --RNGLOG('Threat Stats Self + ally :'..self.BrainIntel.SelfThreat.LandNow + self.BrainIntel.SelfThreat.AllyLandThreat..'Enemy : '..self.EnemyIntel.EnemyThreatCurrent.Land)
                        if (self.BrainIntel.SelfThreat.LandNow + self.BrainIntel.SelfThreat.AllyLandThreat) > (self.EnemyIntel.EnemyThreatCurrent.Land * 1.3) then
                            massPriorityTable = self.EcoManager.MassPriorityTable.Advantage
                            --RNGLOG('Land threat advantage mass priority table')
                        else
                            massPriorityTable = self.EcoManager.MassPriorityTable.Disadvantage
                            --RNGLOG('Land thread disadvantage mass priority table')
                        end
                        massCycle = massCycle + 1
                        for k, v in massPriorityTable do
                            local priorityUnitAlreadySet = false
                            for l, b in unitTypePaused do
                                if k == b then
                                    priorityUnitAlreadySet = true
                                end
                            end
                            if priorityUnitAlreadySet then
                                --RNGLOG('priorityUnit already in unitTypePaused, skipping')
                                continue
                            end
                            if v > priorityNum then
                                priorityNum = v
                                priorityUnit = k
                            end
                        end
                        if priorityUnit == 'ENGINEER' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            --RNGLOG('Engineer added to unitTypePaused')
                            local Engineers = GetListOfUnits(self, ( categories.ENGINEER + categories.SUBCOMMANDER ) - categories.STATIONASSISTPOD - categories.COMMAND, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, Engineers, 'pause', 'MASS')
                        elseif priorityUnit == 'STATIONPODS' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local StationPods = GetListOfUnits(self, categories.STATIONASSISTPOD, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, StationPods, 'pause', 'MASS')
                        elseif priorityUnit == 'AIR' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local AirFactories = GetListOfUnits(self, (categories.STRUCTURE * categories.FACTORY * categories.AIR) * (categories.TECH1 + categories.SUPPORTFACTORY), false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, AirFactories, 'pause', 'MASS')
                        elseif priorityUnit == 'LAND' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local LandFactories = GetListOfUnits(self, (categories.STRUCTURE * categories.FACTORY * categories.LAND) * (categories.TECH1 + categories.SUPPORTFACTORY), false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, LandFactories, 'pause', 'MASS')
                        elseif priorityUnit == 'NAVAL' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local NavalFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.NAVAL, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, NavalFactories, 'pause', 'MASS')
                        elseif priorityUnit == 'MASSEXTRACTION' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local Extractors = GetListOfUnits(self, categories.STRUCTURE * categories.MASSEXTRACTION - categories.EXPERIMENTAL, false, false)
                            --RNGLOG('Number of mass extractors'..RNGGETN(Extractors))
                            self:EcoSelectorManagerRNG(priorityUnit, Extractors, 'pause', 'MASS')
                        elseif priorityUnit == 'NUKE' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local Nukes = GetListOfUnits(self, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL), false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, Nukes, 'pause', 'MASS')
                        elseif priorityUnit == 'TML' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local TMLs = GetListOfUnits(self, categories.STRUCTURE * categories.TACTICALMISSILEPLATFORM, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, TMLs, 'pause', 'MASS')
                        end
                        coroutine.yield(20)
                        massStateCaution = self:EcoManagerMassStateCheck()
                        if massStateCaution then
                            --RNGLOG('Power State Caution still true after first pass')
                            if massCycle > 8 then
                                --RNGLOG('Power Cycle Threashold met, waiting longer')
                                coroutine.yield(100)
                                massCycle = 0
                            end
                        else
                            --RNGLOG('Power State Caution is now false')
                        end
                        coroutine.yield(5)
                        --RNGLOG('unitTypePaused table is :'..repr(unitTypePaused))
                    end
                    for k, v in unitTypePaused do
                        if v == 'ENGINEER' then
                            local Engineers = GetListOfUnits(self, ( categories.ENGINEER + categories.SUBCOMMANDER ) - categories.STATIONASSISTPOD - categories.COMMAND, false, false)
                            self:EcoSelectorManagerRNG(v, Engineers, 'unpause', 'MASS')
                        elseif v == 'STATIONPODS' then
                            local StationPods = GetListOfUnits(self, categories.STATIONASSISTPOD, false, false)
                            self:EcoSelectorManagerRNG(v, StationPods, 'unpause', 'MASS')
                        elseif v == 'AIR' then
                            local AirFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.AIR, false, false)
                            self:EcoSelectorManagerRNG(v, AirFactories, 'unpause', 'MASS')
                        elseif v == 'LAND' then
                            local LandFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.LAND, false, false)
                            self:EcoSelectorManagerRNG(v, LandFactories, 'unpause', 'MASS')
                        elseif v == 'NAVAL' then
                            local NavalFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.NAVAL, false, false)
                            self:EcoSelectorManagerRNG(v, NavalFactories, 'unpause', 'MASS')
                        elseif v == 'MASSEXTRACTION' then
                            local Extractors = GetListOfUnits(self, categories.STRUCTURE * categories.MASSEXTRACTION - categories.EXPERIMENTAL, false, false)
                            self:EcoSelectorManagerRNG(v, Extractors, 'unpause', 'MASS')
                        elseif v == 'NUKE' then
                            local Nukes = GetListOfUnits(self, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL), false, false)
                            self:EcoSelectorManagerRNG(v, Nukes, 'unpause', 'MASS')
                        elseif v == 'TML' then
                            local TMLs = GetListOfUnits(self, categories.STRUCTURE * categories.TACTICALMISSILEPLATFORM, false, false)
                            self:EcoSelectorManagerRNG(v, TMLs, 'unpause', 'MASS')
                        end
                    end
                    massStateCaution = false
                end
            end
            coroutine.yield(20)
        end
    end,

    --[[EcoManagerPowerStateCheck = function(self)

        local stallTime = GetEconomyStored(self, 'ENERGY') / ((GetEconomyRequested(self, 'ENERGY') * 10) - (GetEconomyIncome(self, 'ENERGY') * 10))
        --RNGLOG('Time to stall for '..stallTime)
        if stallTime >= 0.0 then
            if stallTime < 20 then
                return true
            elseif stallTime > 20 then
                return false
            end
        end
        return false
    end,]]

    EcoManagerMassStateCheck = function(self)
        if GetEconomyTrend(self, 'MASS') <= 0.0 and GetEconomyStored(self, 'MASS') <= 200 then
            return true
        end
        return false
    end,

    EcoManagerPowerStateCheck = function(self)
        if GetEconomyTrend(self, 'ENERGY') <= 0.0 and GetEconomyStoredRatio(self, 'ENERGY') <= 0.2 then
            return true
        end
        return false
    end,
    
    EcoPowerManagerRNG = function(self)
        -- Watches for low power states
        while true do
            if self.EcoManager.EcoManagerStatus == 'ACTIVE' then
                if GetGameTimeSeconds() < 240 then
                    coroutine.yield(50)
                    continue
                end
                local powerStateCaution = self:EcoManagerPowerStateCheck()
                local unitTypePaused = false
                
                if powerStateCaution then
                    --RNGLOG('Power State Caution is true')
                    local powerCycle = 0
                    local unitTypePaused = {}
                    while powerStateCaution do
                        local priorityNum = 0
                        local priorityUnit = false
                        powerCycle = powerCycle + 1
                        for k, v in self.EcoManager.PowerPriorityTable do
                            local priorityUnitAlreadySet = false
                            for l, b in unitTypePaused do
                                if k == b then
                                    priorityUnitAlreadySet = true
                                end
                            end
                            if priorityUnitAlreadySet then
                                --RNGLOG('priorityUnit already in unitTypePaused, skipping')
                                continue
                            end
                            if v > priorityNum then
                                priorityNum = v
                                priorityUnit = k
                            end
                        end
                        --RNGLOG('Doing anti power stall stuff for :'..priorityUnit)
                        if priorityUnit == 'ENGINEER' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            --RNGLOG('Engineer added to unitTypePaused')
                            local Engineers = GetListOfUnits(self, ( categories.ENGINEER + categories.SUBCOMMANDER ) - categories.STATIONASSISTPOD - categories.COMMAND , false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, Engineers, 'pause', 'ENERGY')
                        elseif priorityUnit == 'STATIONPODS' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local StationPods = GetListOfUnits(self, categories.STATIONASSISTPOD, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, StationPods, 'pause', 'ENERGY')
                        elseif priorityUnit == 'AIR' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local AirFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.AIR, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, AirFactories, 'pause', 'ENERGY')
                        elseif priorityUnit == 'LAND' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local LandFactories = GetListOfUnits(self, (categories.STRUCTURE * categories.FACTORY * categories.LAND) * (categories.TECH1 + categories.SUPPORTFACTORY), false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, LandFactories, 'pause', 'ENERGY')
                        elseif priorityUnit == 'NAVAL' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local NavalFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.NAVAL, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, NavalFactories, 'pause', 'ENERGY')
                        elseif priorityUnit == 'SHIELD' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local Shields = GetListOfUnits(self, categories.STRUCTURE * categories.SHIELD - categories.EXPERIMENTAL, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, Shields, 'pause', 'ENERGY')
                        elseif priorityUnit == 'TML' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local TMLs = GetListOfUnits(self, categories.STRUCTURE * categories.TACTICALMISSILEPLATFORM, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, TMLs, 'pause', 'ENERGY')
                        elseif priorityUnit == 'RADAR' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local Radars = GetListOfUnits(self, categories.STRUCTURE * (categories.RADAR + categories.SONAR), false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, Radars, 'pause', 'ENERGY')
                        elseif priorityUnit == 'MASSFABRICATION' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local MassFabricators = GetListOfUnits(self, categories.STRUCTURE * categories.MASSFABRICATION, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, MassFabricators, 'pause', 'ENERGY')
                        elseif priorityUnit == 'NUKE' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local Nukes = GetListOfUnits(self, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL), false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, Nukes, 'pause', 'ENERGY')
                        end
                        coroutine.yield(20)
                        powerStateCaution = self:EcoManagerPowerStateCheck()
                        if powerStateCaution then
                            --RNGLOG('Power State Caution still true after first pass')
                            if powerCycle > 11 then
                                --RNGLOG('Power Cycle Threashold met, waiting longer')
                                coroutine.yield(100)
                                powerCycle = 0
                            end
                        else
                            --RNGLOG('Power State Caution is now false')
                        end
                        coroutine.yield(5)
                        --RNGLOG('unitTypePaused table is :'..repr(unitTypePaused))
                    end
                    for k, v in unitTypePaused do
                        if v == 'ENGINEER' then
                            local Engineers = GetListOfUnits(self, ( categories.ENGINEER + categories.SUBCOMMANDER ) - categories.STATIONASSISTPOD - categories.COMMAND, false, false)
                            self:EcoSelectorManagerRNG(v, Engineers, 'unpause', 'ENERGY')
                        elseif v == 'STATIONPODS' then
                            local StationPods = GetListOfUnits(self, categories.STATIONASSISTPOD, false, false)
                            self:EcoSelectorManagerRNG(v, StationPods, 'unpause', 'ENERGY')
                        elseif v == 'AIR' then
                            local AirFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.AIR, false, false)
                            self:EcoSelectorManagerRNG(v, AirFactories, 'unpause', 'ENERGY')
                        elseif v == 'LAND' then
                            local LandFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.LAND, false, false)
                            self:EcoSelectorManagerRNG(v, LandFactories, 'unpause', 'ENERGY')
                        elseif v == 'NAVAL' then
                            local NavalFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.NAVAL, false, false)
                            self:EcoSelectorManagerRNG(v, NavalFactories, 'unpause', 'ENERGY')
                        elseif v == 'SHIELD' then
                            local Shields = GetListOfUnits(self, categories.STRUCTURE * categories.SHIELD - categories.EXPERIMENTAL, false, false)
                            self:EcoSelectorManagerRNG(v, Shields, 'unpause', 'ENERGY')
                        elseif v == 'MASSFABRICATION' then
                            local MassFabricators = GetListOfUnits(self, categories.STRUCTURE * categories.MASSFABRICATION, false, false)
                            self:EcoSelectorManagerRNG(v, MassFabricators, 'unpause', 'ENERGY')
                        elseif v == 'NUKE' then
                            local Nukes = GetListOfUnits(self, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL), false, false)
                            self:EcoSelectorManagerRNG(v, Nukes, 'unpause', 'ENERGY')
                        elseif v == 'TML' then
                            local TMLs = GetListOfUnits(self, categories.STRUCTURE * categories.TACTICALMISSILEPLATFORM, false, false)
                            self:EcoSelectorManagerRNG(v, TMLs, 'unpause', 'ENERGY')
                        end
                    end
                    powerStateCaution = false
                end
            end
            coroutine.yield(20)
        end
    end,

    EcoPowerPreemptiveRNG = function(self)
        local ALLBPS = __blueprints
        local multiplier = self.EcoManager.EcoMultiplier
        coroutine.yield(Random(1,7))
        while true do
            coroutine.yield(50)
            local buildingTable = GetListOfUnits(self, categories.ENGINEER + categories.STRUCTURE * (categories.FACTORY + categories.RADAR + categories.MASSEXTRACTION), false)
            local potentialPowerConsumption = 0
            for k, v in buildingTable do
                if not v.Dead and not v.BuildCompleted then
                    if EntityCategoryContains(categories.ENGINEER, v) then
                        if v.UnitBeingBuilt then
                            if ALLBPS[v.UnitId].Economy.BuildRate > 100 then
                                if ALLBPS[v.UnitBeingBuilt.UnitId].CategoriesHash.NUKE and v:GetFractionComplete() < 0.6 then
                                    RNGLOG('Nuke Launcher being built')
                                    potentialPowerConsumption = potentialPowerConsumption + (4000 * multiplier)
                                    continue
                                end
                                if EntityCategoryContains(categories.TECH3 * categories.ANTIMISSILE, v.UnitBeingBuilt) and v:GetFractionComplete() < 0.6 then
                                    RNGLOG('Anti Nuke Launcher being built')
                                    potentialPowerConsumption = potentialPowerConsumption + (1200 * multiplier)
                                    continue
                                end
                                if EntityCategoryContains(categories.TECH3 * categories.MASSFABRICATION, v.UnitBeingBuilt) and v:GetFractionComplete() < 0.6 then
                                    RNGLOG('Mass Fabricator being built')
                                    potentialPowerConsumption = potentialPowerConsumption + (1000 * multiplier)
                                    continue
                                end
                                if EntityCategoryContains(categories.STRUCTURE * categories.SHIELD, v.UnitBeingBuilt) and v:GetFractionComplete() < 0.6 then
                                    RNGLOG('Shield being built')
                                    potentialPowerConsumption = potentialPowerConsumption + (200 * multiplier)
                                    continue
                                end
                            end
                        end
                    elseif EntityCategoryContains(categories.TECH3 * categories.AIR, v) then
                            if v:GetFractionComplete() < 0.6 then
                                RNGLOG('T3 Air Being Built')
                                potentialPowerConsumption = potentialPowerConsumption + (1800 * multiplier)
                                continue
                            else
                                v.BuildCompleted = true
                            end
                    elseif EntityCategoryContains(categories.TECH2 * categories.AIR, v) then
                        if v:GetFractionComplete() < 0.6 then
                            RNGLOG('T2 Air Being Built')
                            potentialPowerConsumption = potentialPowerConsumption + (200 * multiplier)
                            continue
                        else
                            v.BuildCompleted = true
                        end
                    elseif ALLBPS[v.UnitId].CategoriesHash.MASSEXTRACTION then
                        if v:GetFractionComplete() < 0.6 then
                            RNGLOG('Extractors being upgraded')
                            potentialPowerConsumption = potentialPowerConsumption + (ALLBPS[v.UnitId].Economy.BuildCostEnergy / ALLBPS[v.UnitId].Economy.BuildTime * ALLBPS[v.UnitId].Economy.BuildRate)
                            continue
                        else
                            v.BuildCompleted = true
                        end
                    elseif ALLBPS[v.UnitId].CategoriesHash.RADAR then
                        if v:GetFractionComplete() < 0.6 then
                            RNGLOG('Radar being upgraded')
                            potentialPowerConsumption = potentialPowerConsumption + (ALLBPS[v.UnitId].Economy.BuildCostEnergy / ALLBPS[v.UnitId].Economy.BuildTime * ALLBPS[v.UnitId].Economy.BuildRate)
                            continue
                        else
                            v.BuildCompleted = true
                        end
                    end
                end
            end
            if potentialPowerConsumption > 0 then
                RNGLOG('PowerConsumption of things being built '..potentialPowerConsumption)
                RNGLOG('Energy Income Over Time '..self.EconomyOverTimeCurrent.EnergyIncome * 10)
                RNGLOG('Energy Requested Over Time '..self.EconomyOverTimeCurrent.EnergyRequested * 10)
                RNGLOG('Potential Extra Power Consumption '..potentialPowerConsumption)
                if (GetEconomyIncome(self,'ENERGY') * 10) - (GetEconomyRequested(self,'ENERGY') * 10) - potentialPowerConsumption < 0 then
                    RNGLOG('Powerconsumption will not support what we are currently building')
                    self.EcoManager.EcoPowerPreemptive = true
                    continue
                end
            end
            self.EcoManager.EcoPowerPreemptive = false
        end
    end,

    FactoryEcoManagerRNG = function(self)
        coroutine.yield(Random(1,7))
        while true do
            if self.EcoManager.EcoManagerStatus == 'ACTIVE' then
                if GetGameTimeSeconds() < 240 then
                    coroutine.yield(50)
                    continue
                end
                local massStateCaution = self:EcoManagerMassStateCheck()
                local unitTypePaused = false
                local factType = 'Land'
                if massStateCaution then
                    if self.cmanager.categoryspend.fact['Land'] > (self.cmanager.income.r.m * self.ProductionRatios['Land']) then
                        local deficit = self.cmanager.categoryspend.fact['Land'] - (self.cmanager.income.r.m * self.ProductionRatios['Land'])
                        --RNGLOG('Land Factory Deficit is '..deficit)
                        if self.BuilderManagers then
                            for k, v in self.BuilderManagers do
                                if self.BuilderManagers[k].FactoryManager then
                                    if RNGGETN(self.BuilderManagers[k].FactoryManager.FactoryList) > 1 then
                                        for _, f in self.BuilderManagers[k].FactoryManager.FactoryList do
                                            if not f.Upgrading then
                                                if EntityCategoryContains(categories.TECH1 * categories.LAND, f) then
                                                    if not f.Offline then
                                                        f.Offline = true
                                                        --RNGLOG('Land T1 Factory Taken offline')
                                                        deficit = deficit - 5
                                                    end
                                                end
                                                if deficit <= 0 then
                                                    break
                                                end
                                            end
                                        end
                                        --RNGLOG('Finished T1 Loop Land Factory Deficit is '..deficit)
                                        if deficit <= 0 then
                                            break
                                        end
                                        for _, f in self.BuilderManagers[k].FactoryManager.FactoryList do
                                            if not f.Upgrading then
                                                if EntityCategoryContains(categories.TECH2 * categories.LAND, f) then
                                                    if not f.Offline then
                                                        f.Offline = true
                                                        --RNGLOG('Land T2 Factory Taken offline')
                                                        deficit = deficit - 8
                                                    end
                                                end
                                                if deficit <= 0 then
                                                    break
                                                end
                                            end
                                        end
                                        --RNGLOG('Finished T2 Loop Land Factory Deficit is '..deficit)
                                        if deficit <= 0 then
                                            break
                                        end
                                        for _, f in self.BuilderManagers[k].FactoryManager.FactoryList do
                                            if not f.Upgrading then
                                                if EntityCategoryContains(categories.TECH3 * categories.LAND, f) then
                                                    if not f.Offline then
                                                        f.Offline = true
                                                        --RNGLOG('Land T3 Factory Taken offline')
                                                        deficit = deficit - 17
                                                    end
                                                end
                                                if deficit <= 0 then
                                                    break
                                                end
                                            end
                                        end
                                        --RNGLOG('Finished T3 Loop Land Factory Deficit is '..deficit)
                                    end
                                end
                                if deficit <= 0 then
                                    break
                                end
                            end
                        end
                    end
                    if self.cmanager.categoryspend.fact['Air'] > (self.cmanager.income.r.m * self.ProductionRatios['Air']) then
                        local deficit = self.cmanager.categoryspend.fact['Air'] - (self.cmanager.income.r.m * self.ProductionRatios['Air'])
                        --RNGLOG('Air Factory Deficit is '..deficit)
                        if self.BuilderManagers then
                            for k, v in self.BuilderManagers do
                                if self.BuilderManagers[k].FactoryManager then
                                    if RNGGETN(self.BuilderManagers[k].FactoryManager.FactoryList) > 1 then
                                        for _, f in self.BuilderManagers[k].FactoryManager.FactoryList do
                                            if not f.Upgrading then
                                                if EntityCategoryContains(categories.TECH1 * categories.AIR, f) then
                                                    if not f.Offline then
                                                        f.Offline = true
                                                        --RNGLOG('Air T1 Factory Taken offline')
                                                        deficit = deficit - 4
                                                    end
                                                end
                                                if deficit <= 0 then
                                                    break
                                                end
                                            end
                                        end
                                        --RNGLOG('Finished T1 Loop Air Factory Deficit is '..deficit)
                                        if deficit <= 0 then
                                            break
                                        end
                                        for _, f in self.BuilderManagers[k].FactoryManager.FactoryList do
                                            if not f.Upgrading then
                                                if EntityCategoryContains(categories.TECH2 * categories.AIR, f) then
                                                    if not f.Offline then
                                                        f.Offline = true
                                                        --RNGLOG('Air T2 Factory Taken offline')
                                                        deficit = deficit - 7
                                                    end
                                                end
                                                if deficit <= 0 then
                                                    break
                                                end
                                            end
                                        end
                                        --RNGLOG('Finished T2 Loop Air Factory Deficit is '..deficit)
                                        if deficit <= 0 then
                                            break
                                        end
                                        for _, f in self.BuilderManagers[k].FactoryManager.FactoryList do
                                            if not f.Upgrading then
                                                if EntityCategoryContains(categories.TECH3 * categories.AIR, f) then
                                                    if not f.Offline then
                                                        f.Offline = true
                                                        --RNGLOG('Air T3 Factory Taken offline')
                                                        deficit = deficit - 17
                                                    end
                                                end
                                                if deficit <= 0 then
                                                    break
                                                end
                                            end
                                        end
                                        --RNGLOG('Finished T3 Loop Air Factory Deficit is '..deficit)
                                    end
                                end
                                if deficit <= 0 then
                                    break
                                end
                            end
                        end
                    end
                    if self.cmanager.categoryspend.fact['Naval'] > (self.cmanager.income.r.m * self.ProductionRatios['Naval']) then
                        local deficit = self.cmanager.categoryspend.fact['Naval'] - (self.cmanager.income.r.m * self.ProductionRatios['Naval'])
                        --RNGLOG('Naval Factory Deficit is '..deficit)
                        if self.BuilderManagers then
                            for k, v in self.BuilderManagers do
                                if self.BuilderManagers[k].FactoryManager then
                                    if RNGGETN(self.BuilderManagers[k].FactoryManager.FactoryList) > 1 then
                                        for _, f in self.BuilderManagers[k].FactoryManager.FactoryList do
                                            if not f.Upgrading then
                                                if EntityCategoryContains(categories.TECH1 * categories.NAVAL, f) then
                                                    if not f.Offline then
                                                        f.Offline = true
                                                        --RNGLOG('Naval T1 Factory Taken offline')
                                                        deficit = deficit - 4
                                                    end
                                                end
                                                if deficit <= 0 then
                                                    break
                                                end
                                            end
                                        end
                                        --RNGLOG('Finished T1 Loop Naval Factory Deficit is '..deficit)
                                        if deficit <= 0 then
                                            break
                                        end
                                        for _, f in self.BuilderManagers[k].FactoryManager.FactoryList do
                                            if not f.Upgrading then
                                                if EntityCategoryContains(categories.TECH2 * categories.NAVAL, f) then
                                                    if not f.Offline then
                                                        f.Offline = true
                                                        --RNGLOG('Naval T2 Factory Taken offline')
                                                        deficit = deficit - 10
                                                    end
                                                end
                                                if deficit <= 0 then
                                                    break
                                                end
                                            end
                                        end
                                        --RNGLOG('Finished T2 Loop Naval Factory Deficit is '..deficit)
                                        if deficit <= 0 then
                                            break
                                        end
                                        for _, f in self.BuilderManagers[k].FactoryManager.FactoryList do
                                            if EntityCategoryContains(categories.TECH3 * categories.NAVAL, f) then
                                                if not f.Upgrading then
                                                    if not f.Offline then
                                                        f.Offline = true
                                                        --RNGLOG('Naval T3 Factory Taken offline')
                                                        deficit = deficit - 20
                                                    end
                                                end
                                            end
                                            if deficit <= 0 then
                                                break
                                            end
                                        end
                                        --RNGLOG('Finished T3 Loop Naval Factory Deficit is '..deficit)
                                    end
                                end
                                if deficit <= 0 then
                                    break
                                end
                            end
                        end
                    end
                end
                if self.cmanager.categoryspend.fact['Land'] < (self.cmanager.income.r.m * self.ProductionRatios['Land']) then
                    local surplus = (self.cmanager.income.r.m * self.ProductionRatios['Land']) - self.cmanager.categoryspend.fact['Land']
                    --RNGLOG('Land Factory Surplus is '..surplus)
                    if self.BuilderManagers then
                        for k, v in self.BuilderManagers do
                            if self.BuilderManagers[k].FactoryManager then
                                if RNGGETN(self.BuilderManagers[k].FactoryManager.FactoryList) > 1 then
                                    for _, f in self.BuilderManagers[k].FactoryManager.FactoryList do
                                        if not f.Upgrading then
                                            if EntityCategoryContains(categories.TECH3 * categories.LAND, f) then
                                                if f.Offline then
                                                    f.Offline = false
                                                    --RNGLOG('Land T1 Factory put online')
                                                    surplus = surplus - 5
                                                end
                                            elseif EntityCategoryContains(categories.TECH2 * categories.LAND, f) then
                                                if f.Offline then
                                                    f.Offline = false
                                                    --RNGLOG('Land T2 Factory put online')
                                                    surplus = surplus - 8
                                                end
                                            elseif EntityCategoryContains(categories.TECH1 * categories.LAND, f) then
                                                if f.Offline then
                                                    f.Offline = false
                                                    --RNGLOG('Land T3 Factory put online')
                                                    surplus = surplus - 17
                                                end
                                            end
                                        end
                                        if surplus <= 0 then
                                            break
                                        end
                                    end
                                end
                            end
                            if surplus <= 0 then
                                break
                            end
                        end
                    end
                end
                if self.cmanager.categoryspend.fact['Air'] < (self.cmanager.income.r.m * self.ProductionRatios['Air']) then
                    local surplus = (self.cmanager.income.r.m * self.ProductionRatios['Air']) - self.cmanager.categoryspend.fact['Air']
                    --RNGLOG('Air Factory Surplus is '..surplus)
                    if self.BuilderManagers then
                        for k, v in self.BuilderManagers do
                            if self.BuilderManagers[k].FactoryManager then
                                if RNGGETN(self.BuilderManagers[k].FactoryManager.FactoryList) > 1 then
                                    for _, f in self.BuilderManagers[k].FactoryManager.FactoryList do
                                        if not f.Upgrading then
                                            if EntityCategoryContains(categories.TECH3 * categories.AIR, f) then
                                                if f.Offline then
                                                    f.Offline = false
                                                    --RNGLOG('Air T1 Factory put online')
                                                    surplus = surplus - 4
                                                end
                                            elseif EntityCategoryContains(categories.TECH2 * categories.AIR, f) then
                                                if f.Offline then
                                                    f.Offline = false
                                                    --RNGLOG('Air T2 Factory put online')
                                                    surplus = surplus - 7
                                                end
                                            elseif EntityCategoryContains(categories.TECH1 * categories.AIR, f) then
                                                if f.Offline then
                                                    f.Offline = false
                                                    --RNGLOG('Air T3 Factory put online')
                                                    surplus = surplus - 17
                                                end
                                            end
                                            if surplus <= 0 then
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                            if surplus <= 0 then
                                break
                            end
                        end
                    end
                end
                if self.cmanager.categoryspend.fact['Naval'] < (self.cmanager.income.r.m * self.ProductionRatios['Naval']) then
                    local surplus = (self.cmanager.income.r.m * self.ProductionRatios['Naval']) - self.cmanager.categoryspend.fact['Naval']
                    --RNGLOG('Naval Factory Surplus is '..surplus)
                    if self.BuilderManagers then
                        for k, v in self.BuilderManagers do
                            if self.BuilderManagers[k].FactoryManager then
                                if RNGGETN(self.BuilderManagers[k].FactoryManager.FactoryList) > 1 then
                                    for _, f in self.BuilderManagers[k].FactoryManager.FactoryList do
                                        if not f.Upgrading then
                                            if EntityCategoryContains(categories.TECH3 * categories.NAVAL, f) then
                                                if f.Offline then
                                                    f.Offline = false
                                                    --RNGLOG('Naval T1 Factory put online')
                                                    surplus = surplus - 4
                                                end
                                            elseif EntityCategoryContains(categories.TECH2 * categories.NAVAL, f) then
                                                if f.Offline then
                                                    f.Offline = false
                                                    --RNGLOG('Naval T2 Factory put online')
                                                    surplus = surplus - 10
                                                end
                                            elseif EntityCategoryContains(categories.TECH1 * categories.NAVAL, f) then
                                                if f.Offline then
                                                    f.Offline = false
                                                    --RNGLOG('Naval T3 Factory put online')
                                                    surplus = surplus - 20
                                                end
                                            end
                                            if surplus <= 0 then
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                            if surplus <= 0 then
                                break
                            end
                        end
                    end
                end
            end
            --debug
            --[[
            local factories = GetListOfUnits(self, categories.FACTORY * categories.LAND, false, true)
            local offlineFactoryCount = 0
            local onlineFactoryCount = 0
            for k, v in factories do
                if v and not v.Dead then
                    if v.Offline then
                        offlineFactoryCount = offlineFactoryCount + 1
                    else
                        onlineFactoryCount = onlineFactoryCount + 1
                    end
                end
            end
           --RNGLOG('Offline Factory Count '..offlineFactoryCount)
           --RNGLOG('Online Factory Count '..onlineFactoryCount)]]

            coroutine.yield(20)
        end
    end,
    
    EcoSelectorManagerRNG = function(self, priorityUnit, units, action, type)
        --RNGLOG('Eco selector manager for '..priorityUnit..' is '..action..' Type is '..type)
        
        for k, v in units do
            if v.Dead then continue end
            if priorityUnit == 'ENGINEER' then
                --RNGLOG('Priority Unit Is Engineer')
                if action == 'unpause' then
                    if not v:IsPaused() then continue end
                    --RNGLOG('Unpausing Engineer')
                    v:SetPaused(false)
                    continue
                end
                if EntityCategoryContains( categories.STRUCTURE * (categories.TACTICALMISSILEPLATFORM + categories.ANTIMISSILE + categories.MASSSTORAGE + categories.ENERGYSTORAGE + categories.SHIELD + categories.GATE) , v.UnitBeingBuilt) then
                    v:SetPaused(true)
                    continue
                end
                if not v.PlatoonHandle.PlatoonData.Assist.AssisteeType then continue end
                if not v.UnitBeingAssist then continue end
                if v:IsPaused() then continue end
                if type == 'ENERGY' and not EntityCategoryContains(categories.STRUCTURE * categories.ENERGYPRODUCTION, v.UnitBeingAssist) then
                    --RNGLOG('Pausing Engineer')
                    v:SetPaused(true)
                    continue
                elseif type == 'MASS' then
                    v:SetPaused(true)
                    continue
                end
            elseif priorityUnit == 'STATIONPODS' then
                --RNGLOG('Priority Unit Is STATIONPODS')
                if action == 'unpause' then
                    if not v:IsPaused() then continue end
                    --RNGLOG('Unpausing STATIONPODS Factory')
                    v:SetPaused(false)
                    continue
                end
                if not v.UnitBeingBuilt then continue end
                if EntityCategoryContains(categories.ENGINEER * categories.TECH1, v.UnitBeingBuilt) then continue end
                if RNGGETN(units) == 1 then continue end
                if v:IsPaused() then continue end
                --RNGLOG('pausing STATIONPODS')
                v:SetPaused(true)
                continue
            elseif priorityUnit == 'AIR' then
                --RNGLOG('Priority Unit Is AIR')
                if action == 'unpause' then
                    if not v:IsPaused() then continue end
                    --RNGLOG('Unpausing Air Factory')
                    v:SetPaused(false)
                    continue
                end
                if not v.UnitBeingBuilt then continue end
                if EntityCategoryContains(categories.ENGINEER, v.UnitBeingBuilt) then continue end
                --if RNGGETN(units) == 1 then continue end
                if v:IsPaused() then continue end
                --RNGLOG('pausing AIR')
                v:SetPaused(true)
                continue
            elseif priorityUnit == 'NAVAL' then
                --RNGLOG('Priority Unit Is NAVAL')
                if action == 'unpause' then
                    if not v:IsPaused() then continue end
                    --RNGLOG('Unpausing Naval Factory')
                    v:SetPaused(false)
                    continue
                end
                if not v.UnitBeingBuilt then continue end
                if EntityCategoryContains(categories.ENGINEER, v.UnitBeingBuilt) then continue end
                if RNGGETN(units) == 1 then continue end
                if v:IsPaused() then continue end
                --RNGLOG('pausing NAVAL')
                v:SetPaused(true)
                continue
            elseif priorityUnit == 'LAND' then
                --RNGLOG('Priority Unit Is LAND')
                if action == 'unpause' then
                    if not v:IsPaused() then continue end
                    --RNGLOG('Unpausing Land Factory')
                    v:SetPaused(false)
                    continue
                end
                if not v.UnitBeingBuilt then continue end
                if EntityCategoryContains(categories.ENGINEER, v.UnitBeingBuilt) then continue end
                if RNGGETN(units) <= 2 then continue end
                if v:IsPaused() then continue end
                --RNGLOG('pausing LAND')
                v:SetPaused(true)
                continue
            elseif priorityUnit == 'MASSFABRICATION' or priorityUnit == 'SHIELD' or priorityUnit == 'RADAR' then
                --RNGLOG('Priority Unit Is MASSFABRICATION or SHIELD')
                if action == 'unpause' then
                    if v.MaintenanceConsumption then continue end
                    --RNGLOG('Unpausing MASSFABRICATION or SHIELD')
                    v:OnProductionUnpaused()
                    continue
                end
                if v.Dead then continue end
                if v:GetFractionComplete() ~= 1 then continue end
                if not v.MaintenanceConsumption then continue end
                --RNGLOG('pausing MASSFABRICATION or SHIELD '..v.UnitId)
                v:OnProductionPaused()
            elseif priorityUnit == 'NUKE' then
                --RNGLOG('Priority Unit Is Nuke')
                if action == 'unpause' then
                    if not v:IsPaused() then continue end
                    --RNGLOG('Unpausing Nuke')
                    v:SetPaused(false)
                    continue
                end
                if v.Dead then continue end
                if v:GetFractionComplete() ~= 1 then continue end
                if v:IsPaused() then continue end
                --RNGLOG('pausing Nuke')
                v:SetPaused(true)
                continue
            elseif priorityUnit == 'TML' then
                --RNGLOG('Priority Unit Is TML')
                if action == 'unpause' then
                    if not v:IsPaused() then continue end
                    --RNGLOG('Unpausing TML')
                    v:SetPaused(false)
                    continue
                end
                if v.Dead then continue end
                if v:GetFractionComplete() ~= 1 then continue end
                if v:IsPaused() then continue end
                --RNGLOG('pausing TML')
                v:SetPaused(true)
                continue
            elseif priorityUnit == 'MASSEXTRACTION' and action == 'unpause' then
                if not v:IsPaused() then continue end
                v:SetPaused( false )
                --RNGLOG('Unpausing Extractor')
                continue
            end
            if priorityUnit == 'MASSEXTRACTION' and action == 'pause' then
                local upgradingBuilding = {}
                local upgradingBuildingNum = 0
                --RNGLOG('Mass Extractor pause action, gathering upgrading extractors')
                for k, v in units do
                    if v
                        and not v.Dead
                        and not v:BeenDestroyed()
                        and not v:GetFractionComplete() < 1
                    then
                        if v:IsUnitState('Upgrading') then
                            if not v:IsPaused() then
                                RNGINSERT(upgradingBuilding, v)
                                --RNGLOG('Upgrading Extractor not paused found')
                                upgradingBuildingNum = upgradingBuildingNum + 1
                            end
                        end
                    end
                end
                --RNGLOG('Mass Extractor pause action, checking if more than one is upgrading')
                local upgradingTableSize = RNGGETN(upgradingBuilding)
                --RNGLOG('Number of upgrading extractors is '..upgradingBuildingNum)
                if upgradingBuildingNum > 1 then
                    --RNGLOG('pausing all but one upgrading extractor')
                    --RNGLOG('UpgradingTableSize is '..upgradingTableSize)
                    for i=1, (upgradingTableSize - 1) do
                        upgradingBuilding[i]:SetPaused( true )
                        --UpgradingBuilding:SetCustomName('Upgrading paused')
                        --RNGLOG('Upgrading paused')
                    end
                end
            end
        end
    end,

    EnemyChokePointTestRNG = function(self)
        local selfIndex = self:GetArmyIndex()
        local selfStartPos = self.BuilderManagers['MAIN'].Position
        local enemyTestTable = {}

        coroutine.yield(Random(80,100))
        if self.EnemyIntel.EnemyCount > 0 then
            for index, brain in ArmyBrains do
                if IsEnemy(selfIndex, index) and not ArmyIsCivilian(index) then
                    local posX, posZ = brain:GetArmyStartPos()
                    self.EnemyIntel.ChokePoints[index] = {
                        CurrentPathThreat = 0,
                        NoPath = false,
                        StartPosition = {posX, 0, posZ},
                    }
                end
            end
        end

        while true do
            if self.EnemyIntel.EnemyCount > 0 then
                for k, v in self.EnemyIntel.ChokePoints do
                    if not v.NoPath then
                        local path, reason, totalThreat = PlatoonGenerateSafePathToRNG(self, 'Land', selfStartPos, v.StartPosition, 1, nil, nil, true)
                        if path then
                           --RNGLOG('Choke point test Total Threat for path is '..totalThreat)
                            self.EnemyIntel.ChokePoints[k].CurrentPathThreat = (totalThreat / RNGGETN(path))
                           --RNGLOG('We have a path to the enemy start position with an average of '..(totalThreat / RNGGETN(path)..' threat'))

                            if self.EnemyIntel.EnemyCount > 0 then
                                --RNGLOG('Land Now Should be Greater than EnemyThreatcurrent divided by enemies')
                                --RNGLOG('LandNow '..self.BrainIntel.SelfThreat.LandNow)
                               --RNGLOG('EnemyThreatCurrent for Land is '..self.EnemyIntel.EnemyThreatCurrent.Land)
                               --RNGLOG('Enemy Count is '..self.EnemyIntel.EnemyCount)
                               --RNGLOG('EnemyThreatcurrent divided by enemies '..(self.EnemyIntel.EnemyThreatCurrent.Land / self.EnemyIntel.EnemyCount))
                               --RNGLOG('EnemyDenseThreatSurface '..self.EnemyIntel.EnemyThreatCurrent.DefenseSurface..' should be greater than LandNow'..self.BrainIntel.SelfThreat.LandNow)
                               --RNGLOG('Total Threat '..totalThreat..' Should be greater than LandNow '..self.BrainIntel.SelfThreat.LandNow)
                                if self.EnemyIntel.EnemyFireBaseDetected then
                                   --RNGLOG('Firebase flag is true')
                                else
                                   --RNGLOG('Firebase flag is false')
                                end
                                if self.BrainIntel.SelfThreat.LandNow > (self.EnemyIntel.EnemyThreatCurrent.Land / self.EnemyIntel.EnemyCount) 
                                and (self.EnemyIntel.EnemyThreatCurrent.DefenseSurface + self.EnemyIntel.EnemyThreatCurrent.DefenseAir) > self.BrainIntel.SelfThreat.LandNow
                                and totalThreat > self.BrainIntel.SelfThreat.LandNow 
                                and self.EnemyIntel.EnemyFireBaseDetected then
                                    self.EnemyIntel.ChokeFlag = true
                                    self.ProductionRatios.Land = 0.2
                                    self.ProductionRatios.Air = 0.2
                                    self.ProductionRatios.Naval = 0.2
                                   --RNGLOG('ChokeFlag is true')
                                elseif self.EnemyIntel.ChokeFlag then
                                   --RNGLOG('ChokeFlag is false')
                                    self.EnemyIntel.ChokeFlag = false
                                    self.ProductionRatios.Land = self.DefaultLandRatio
                                end
                            end
                        elseif (not path and reason) then
                            --RNGLOG('We dont have a path to the enemy start position, setting NoPath to true')
                            --RNGLOG('Reason is '..reason)
                            self.EnemyIntel.ChokePoints[k].NoPath = true
                        else
                            WARN('AI-RNG : Chokepoint test has unexpected return')
                        end
                    end
                    --RNGLOG('Current enemy chokepoint data for index '..k)
                    --RNGLOG(repr(self.EnemyIntel.ChokePoints[k]))
                    coroutine.yield(20)
                end
            end
            coroutine.yield(1200)
        end
    end,

    EngineerAssistManagerBrainRNG = function(self, type)
        coroutine.yield(1800)
        local state
        while true do
            local massStorage = GetEconomyStored( self, 'MASS')
            local energyStorage = GetEconomyStored( self, 'ENERGY')
            local CoreMassNumberAchieved = false
            if self.EconomyOverTimeCurrent.EnergyTrendOverTime < 25.0 then
                state = 'Energy'
                self.EngineerAssistManagerPriorityTable = {
                    {cat = categories.STRUCTURE * categories.ENERGYPRODUCTION, type = 'Completion'}, 
                    {cat = categories.MASSEXTRACTION, type = 'Upgrade'}, 
                    {cat = categories.STRUCTURE * categories.FACTORY, type = 'Upgrade' }, 
                    {cat = categories.STRUCTURE * categories.FACTORY, type = 'Completion'},
                    {cat = categories.FACTORY * categories.AIR, type = 'AssistFactory'}, 
                    {cat = categories.MOBILE * categories.EXPERIMENTAL, type = 'Completion'},
                    {cat = categories.STRUCTURE * categories.MASSSTORAGE, type = 'Completion'}
                }
            elseif self.EngineerAssistManagerFocusAirUpgrade then
                state = 'Air'
                self.EngineerAssistManagerPriorityTable = {
                    {cat = categories.FACTORY * categories.AIR - categories.SUPPORTFACTORY, type = 'Upgrade'}, 
                    {cat = categories.MASSEXTRACTION, type = 'Upgrade'}, 
                    {cat = categories.STRUCTURE * categories.ENERGYPRODUCTION, type = 'Completion'}, 
                    {cat = categories.STRUCTURE * categories.FACTORY, type = 'Completion'},
                    {cat = categories.MOBILE * categories.EXPERIMENTAL, type = 'Completion'},
                    {cat = categories.STRUCTURE * categories.MASSSTORAGE, type = 'Completion'} 
                }
            elseif self.EngineerAssistManagerFocusLandUpgrade then
                state = 'Land'
                self.EngineerAssistManagerPriorityTable = {
                    {cat = categories.FACTORY * categories.LAND - categories.SUPPORTFACTORY, type = 'Upgrade'}, 
                    {cat = categories.MASSEXTRACTION, type = 'Upgrade'}, 
                    {cat = categories.STRUCTURE * categories.ENERGYPRODUCTION, type = 'Completion'}, 
                    {cat = categories.STRUCTURE * categories.FACTORY, type = 'Completion'},
                    {cat = categories.MOBILE * categories.EXPERIMENTAL, type = 'Completion'},
                    {cat = categories.STRUCTURE * categories.MASSSTORAGE, type = 'Completion'}
                }
            else
                state = 'Mass'
                self.EngineerAssistManagerPriorityTable = {
                    {cat = categories.MASSEXTRACTION, type = 'Upgrade'}, 
                    {cat = categories.STRUCTURE * categories.ENERGYPRODUCTION, type = 'Completion'}, 
                    {cat = categories.STRUCTURE * categories.FACTORY, type = 'Upgrade' }, 
                    {cat = categories.STRUCTURE * categories.FACTORY, type = 'Completion'},
                    {cat = categories.FACTORY * categories.AIR, type = 'AssistFactory'}, 
                    {cat = categories.MOBILE * categories.EXPERIMENTAL, type = 'Completion'},
                    {cat = categories.STRUCTURE * categories.MASSSTORAGE, type = 'Completion'}
                }
            end
            RNGLOG('EngineerAssistManager State is '..state)
            RNGLOG('Current EngineerAssistManager build power '..self.EngineerAssistManagerBuildPower..' build power required '..self.EngineerAssistManagerBuildPowerRequired)
            --RNGLOG('EngineerAssistManagerRNGMass Storage is : '..massStorage)
            --RNGLOG('EngineerAssistManagerRNG Energy Storage is : '..energyStorage)
            if self.RNGEXP and self.EconomyOverTimeCurrent.MassEfficiencyOverTime > 0.9 then
                if self.EngineerAssistManagerBuildPower <= 30 and self.EngineerAssistManagerBuildPowerRequired <= 26 then
                    self.EngineerAssistManagerBuildPowerRequired = self.EngineerAssistManagerBuildPowerRequired + 5
                end
                --RNGLOG('EngineerAssistManager is Active')
                self.EngineerAssistManagerActive = true
            elseif massStorage > 150 and energyStorage > 150 then
                if self.EngineerAssistManagerBuildPower <= 30 and self.EngineerAssistManagerBuildPowerRequired <= 26 then
                    self.EngineerAssistManagerBuildPowerRequired = self.EngineerAssistManagerBuildPowerRequired + 5
                end
                --RNGLOG('EngineerAssistManager is Active')
                self.EngineerAssistManagerActive = true
            elseif self.EcoManager.CoreMassPush and self.EngineerAssistManagerBuildPower <= 60 then
                RNGLOG('CoreMassPush is true')
                self.EngineerAssistManagerBuildPowerRequired = 60
            elseif not CoreMassNumberAchieved and self.EcoManager.CoreExtractorT3Count > 2 then
                CoreMassNumberAchieved = true
                self.EngineerAssistManagerBuildPowerRequired = 16
            elseif self.EconomyOverTimeCurrent.MassEfficiencyOverTime > 0.6 and self.EngineerAssistManagerBuildPower <= 0 and self.EngineerAssistManagerBuildPowerRequired < 6 then
                RNGLOG('EngineerAssistManagerBuildPower being set to 5')
                self.EngineerAssistManagerActive = true
                self.EngineerAssistManagerBuildPowerRequired = 5
            elseif self.EngineerAssistManagerBuildPower == self.EngineerAssistManagerBuildPowerRequired and self.EconomyOverTimeCurrent.MassEfficiencyOverTime > 0.9 then
                RNGLOG('EngineerAssistManagerBuildPower matches EngineerAssistManagerBuildPowerRequired, not add or removal')
                coroutine.yield(30)
            else
                if self.EngineerAssistManagerBuildPowerRequired > 5 then
                    self.EngineerAssistManagerBuildPowerRequired = self.EngineerAssistManagerBuildPowerRequired - 1
                end
                --self.EngineerAssistManagerActive = false
            end
            coroutine.yield(10)
        end
    end,

    AllyEconomyHelpThread = function(self)
        local selfIndex = self:GetArmyIndex()
        coroutine.yield(180)
        while true do
            if GetEconomyStoredRatio(self, 'ENERGY') > 0.95 and GetEconomyTrend(self, 'ENERGY') > 10 then
                for index, brain in ArmyBrains do
                    if index ~= selfIndex then
                        if IsAlly(selfIndex, brain:GetArmyIndex()) then
                            if GetEconomyStoredRatio(brain, 'ENERGY') < 0.01 then
                                --RNGLOG('Transfer Energy to team mate')
                                local amount
                                amount = GetEconomyStored( self, 'ENERGY') / 8
                                GiveResource(self, 'ENERGY', amount)
                            end
                        end
                    end
                end
            end
            coroutine.yield(100)
        end
    end,

    HeavyEconomyRNG = function(self)

        coroutine.yield(Random(80,100))
        --RNGLOG('Heavy Economy thread starting '..self.Nickname)
        -- This section is for debug
        --[[
        self.cmanager = {income={r={m=0,e=0},t={m=0,e=0}},spend={m=0},storage={max={m=0,e=0},current={m=0,e=0}},categoryspend={fac={l=0,a=0,n=0},mex={t1=0,t2=0,t3=0},eng={t1=0,t2=0,t3=0,com=0},silo={t2=0,t3=0}}}
        self.amanager = {t1={scout=0,tank=0,arty=0,aa=0},t2={tank=0,mml=0,aa=0,shield=0},t3={tank=0,sniper=0,arty=0,mml=0,aa=0,shield=0},total={t1=0,t2=0,t3=0}}
        self.smanager={fac={l={t1=0,t2=0,t3=0},a={t1=0,t2=0,t3=0},n={t1=0,t2=0,t3=0}},mex={t1=0,t2=0,t3=0},pgen={t1=0,t2=0,t3=0},silo={t2=0,t3=0},fabs={t2=0,t3=0}}
        ]]



        while not self.defeat do
            --RNGLOG('heavy economy loop started')
            self:HeavyEconomyForkRNG()
            coroutine.yield(50)
        end
    end,

    HeavyEconomyForkRNG = function(self)
        local units = GetListOfUnits(self, categories.SELECTABLE, false, true)
        local factionIndex = self:GetFactionIndex()
        local GetPosition = moho.entity_methods.GetPosition
        local ALLBPS = __blueprints
        --RNGLOG('units grabbed')
        local factories = {Land={T1=0,T2=0,T3=0},Air={T1=0,T2=0,T3=0},Naval={T1=0,T2=0,T3=0}}
        local extractors = { }
        local hydros = { }
        local fabs = {T2=0,T3=0}
        local coms = {acu=0,sacu=0}
        local pgens = {T1=0,T2=0,T3=0,hydro=0}
        local silo = {T2=0,T3=0}
        local armyLand={T1={scout=0,tank=0,arty=0,aa=0},T2={tank=0,mml=0,aa=0,shield=0,bot=0},T3={tank=0,sniper=0,arty=0,mml=0,aa=0,shield=0,armoured=0}}
        local armyLandType={scout=0,tank=0,sniper=0,arty=0,mml=0,aa=0,shield=0,bot=0,armoured=0}
        local armyLandTiers={T1=0,T2=0,T3=0}
        local armyAir={T1={scout=0,interceptor=0,bomber=0,gunship=0,transport=0},T2={fighter=0,bomber=0,gunship=0,mercy=0,transport=0},T3={scout=0,asf=0,bomber=0,gunship=0,torpedo=0,transport=0}}
        local armyAirType={scout=0,interceptor=0,bomber=0,asf=0,gunship=0,fighter=0,torpedo=0,transport=0,mercy=0}
        local armyAirTiers={T1=0,T2=0,T3=0}
        local armyNaval={T1={frigate=0,sub=0,shard=0},T2={destroyer=0,cruiser=0,subhunter=0,transport=0},T3={battleship=0}}
        local armyNavalType={frigate=0,sub=0,shard=0,destroyer=0,cruiser=0,subhunter=0,battleship=0}
        local armyNavalTiers={T1=0,T2=0,T3=0}
        local launcherspend = {T2=0,T3=0}
        local facspend = {Land=0,Air=0,Naval=0}
        local mexspend = {T1=0,T2=0,T3=0}
        local engspend = {T1=0,T2=0,T3=0,com=0}
        local rincome = {m=0,e=0}
        local tincome = {m=GetEconomyIncome(self, 'MASS')*10,e=GetEconomyIncome(self, 'ENERGY')*10}
        local storage = {max = {m=GetEconomyStored(self, 'MASS')/GetEconomyStoredRatio(self, 'MASS'),e=GetEconomyStored(self, 'ENERGY')/GetEconomyStoredRatio(self, 'ENERGY')},current={m=GetEconomyStored(self, 'MASS'),e=GetEconomyStored(self, 'ENERGY')}}
        local tspend = {m=0,e=0}
        local mainBaseExtractors = {T1=0,T2=0,T3=0}
        local engineerDistribution = { BuildPower = 0, BuildStructure = 0, Assist = 0, Reclaim = 0, Expansion = 0, Mass = 0, Repair = 0, ReclaimStructure = 0, Total = 0 }
        local totalLandThreat = 0
        local totalAirThreat = 0
        local totalAntiAirThreat = 0
        local totalEconomyThreat = 0
        local totalNavalThreat = 0
        local totalNavalSubThreat = 0
        local totalExtractorCount = 0
        for _,z in self.amanager.Ratios[factionIndex] do
            for _,c in z do
                c.total=0
                for i,v in c do
                    if i=='total' then continue end
                    c.total=c.total+v
                end
            end
        end

        for _,unit in units do
            if unit and not unit.Dead then 
                local spendm=GetConsumptionPerSecondMass(unit)
                local spende=GetConsumptionPerSecondEnergy(unit)
                local producem=GetProductionPerSecondMass(unit)
                local producee=GetProductionPerSecondEnergy(unit)
                tspend.m=tspend.m+spendm
                tspend.e=tspend.e+spende
                rincome.m=rincome.m+producem
                rincome.e=rincome.e+producee
                if ALLBPS[unit.UnitId].CategoriesHash.MASSEXTRACTION then
                    totalEconomyThreat = totalEconomyThreat + ALLBPS[unit.UnitId].Defense.EconomyThreatLevel
                    totalExtractorCount = totalExtractorCount + 1
                    if not unit.zoneid and self.ZonesInitialized then
                        --LOG('unit has no zone')
                        local mexPos = GetPosition(unit)
                        if RUtils.PositionOnWater(mexPos[1], mexPos[3]) then
                            -- tbd define water based zones
                            unit.zoneid = 'water'
                        else
                            unit.zoneid = MAP:GetZoneID(mexPos,self.Zones.Land.index)
                            --LOG('Unit zone is '..unit.zoneid)
                        end
                    end
                    if not extractors[unit.zoneid] then
                        --LOG('Trying to add unit to zone')
                        extractors[unit.zoneid] = {T1 = 0,T2 = 0,T3 = 0,}
                    end
                    if ALLBPS[unit.UnitId].CategoriesHash.TECH1 then
                        extractors[unit.zoneid].T1=extractors[unit.zoneid].T1+1
                        mexspend.T1=mexspend.T1+spendm
                        if unit.MAINBASE then
                            mainBaseExtractors.T1 = mainBaseExtractors.T1 + 1
                        end
                    elseif ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                        extractors[unit.zoneid].T2=extractors[unit.zoneid].T2+1
                        mexspend.T2=mexspend.T2+spendm
                        if unit.MAINBASE then
                            mainBaseExtractors.T2 = mainBaseExtractors.T2 + 1
                        end
                    elseif ALLBPS[unit.UnitId].CategoriesHash.TECH3 then
                        extractors[unit.zoneid].T3=extractors[unit.zoneid].T3+1
                        mexspend.T3=mexspend.T3+spendm
                        if unit.MAINBASE then
                            mainBaseExtractors.T3 = mainBaseExtractors.T3 + 1
                        end
                    end
                elseif EntityCategoryContains(categories.COMMAND+categories.SUBCOMMANDER,unit) then
                    if ALLBPS[unit.UnitId].CategoriesHash.COMMAND then
                        coms.acu=coms.acu+1
                        engspend.com=engspend.com+spendm
                    elseif ALLBPS[unit.UnitId].CategoriesHash.SUBCOMMANDER then
                        coms.sacu=coms.sacu+1
                        engspend.com=engspend.com+spendm
                    end
                elseif ALLBPS[unit.UnitId].CategoriesHash.MASSFABRICATION then
                    if ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                        fabs.T2=fabs.T2+1
                    elseif ALLBPS[unit.UnitId].CategoriesHash.TECH3 then
                        fabs.T3=fabs.T3+1
                    end
                elseif ALLBPS[unit.UnitId].CategoriesHash.ENGINEER then
                    if unit.JobType then
                        --LOG('Engineer Job Type '..unit.JobType)
                        engineerDistribution[unit.JobType] = engineerDistribution[unit.JobType] + 1
                        engineerDistribution.Total = engineerDistribution.Total + 1
                    end
                    if ALLBPS[unit.UnitId].CategoriesHash.TECH1 then
                        engspend.T1=engspend.T1+spendm
                    elseif ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                        engspend.T2=engspend.T2+spendm
                    elseif ALLBPS[unit.UnitId].CategoriesHash.TECH3 then
                        engspend.T3=engspend.T3+spendm
                    end
                elseif ALLBPS[unit.UnitId].CategoriesHash.FACTORY then
                    if ALLBPS[unit.UnitId].CategoriesHash.LAND then
                        facspend.Land=facspend.Land+spendm
                        if ALLBPS[unit.UnitId].CategoriesHash.TECH1 then
                            factories.Land.T1=factories.Land.T1+1
                        elseif ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                            factories.Land.T2=factories.Land.T2+1
                        elseif ALLBPS[unit.UnitId].CategoriesHash.TECH3 then
                            factories.Land.T3=factories.Land.T3+1
                        end
                    elseif ALLBPS[unit.UnitId].CategoriesHash.AIR then
                        facspend.Air=facspend.Air+spendm
                        if ALLBPS[unit.UnitId].CategoriesHash.TECH1 then
                            factories.Air.T1=factories.Air.T1+1
                        elseif ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                            factories.Air.T2=factories.Air.T2+1
                        elseif ALLBPS[unit.UnitId].CategoriesHash.TECH3 then
                            factories.Air.T3=factories.Air.T3+1
                        end
                    elseif ALLBPS[unit.UnitId].CategoriesHash.NAVAL then
                        facspend.Naval=facspend.Naval+spendm
                        if ALLBPS[unit.UnitId].CategoriesHash.TECH1 then
                            factories.Naval.T1=factories.Naval.T1+1
                        elseif ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                            factories.Naval.T2=factories.Naval.T2+1
                        elseif ALLBPS[unit.UnitId].CategoriesHash.TECH3 then
                            factories.Naval.T3=factories.Naval.T3+1
                        end
                    end
                elseif ALLBPS[unit.UnitId].CategoriesHash.ENERGYPRODUCTION then
                    if ALLBPS[unit.UnitId].CategoriesHash.HYDROCARBON then
                        --LOG('HydroCarbon detected, adding zone data')
                        if not unit.zoneid and self.ZonesInitialized then
                            --LOG('unit has no zone')
                            local hydroPos = GetPosition(unit)
                            unit.zoneid = MAP:GetZoneID(hydroPos,self.Zones.Land.index)
                            --LOG('Unit zone is '..unit.zoneid)
                        end
                        if not hydros[unit.zoneid] then
                            --LOG('Trying to add unit to zone')
                            hydros[unit.zoneid] = { hydrocarbon = 0 }
                        end
                        hydros[unit.zoneid].hydrocarbon=hydros[unit.zoneid].hydrocarbon+1
                    elseif ALLBPS[unit.UnitId].CategoriesHash.TECH1 then
                        pgens.T1=pgens.T1+1
                    elseif ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                        pgens.T2=pgens.T2+1
                    elseif ALLBPS[unit.UnitId].CategoriesHash.TECH3 then
                        pgens.T3=pgens.T3+1
                    end
                elseif ALLBPS[unit.UnitId].CategoriesHash.LAND then
                    totalLandThreat = totalLandThreat + ALLBPS[unit.UnitId].Defense.SurfaceThreatLevel
                    if ALLBPS[unit.UnitId].CategoriesHash.TECH1 then
                        armyLandTiers.T1=armyLandTiers.T1+1
                        if ALLBPS[unit.UnitId].CategoriesHash.SCOUT then
                            armyLand.T1.scout=armyLand.T1.scout+1
                            armyLandType.scout=armyLandType.scout+1
                        elseif EntityCategoryContains(categories.DIRECTFIRE - categories.ANTIAIR, unit) then
                            armyLand.T1.tank=armyLand.T1.tank+1
                            armyLandType.tank=armyLandType.tank+1
                        elseif EntityCategoryContains(categories.INDIRECTFIRE - categories.ANTIAIR, unit) then
                            armyLand.T1.arty=armyLand.T1.arty+1
                            armyLandType.arty=armyLandType.arty+1
                        elseif ALLBPS[unit.UnitId].CategoriesHash.ANTIAIR then
                            armyLand.T1.aa=armyLand.T1.aa+1
                            armyLandType.aa=armyLandType.aa+1
                        end
                    elseif ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                        armyLandTiers.T2=armyLandTiers.T2+1
                        if EntityCategoryContains(categories.DIRECTFIRE - categories.BOT - categories.ANTIAIR,unit) then
                            armyLand.T2.tank=armyLand.T2.tank+1
                            armyLandType.tank=armyLandType.tank+1
                        elseif EntityCategoryContains(categories.DIRECTFIRE * categories.BOT - categories.ANTIAIR,unit) then
                            armyLand.T2.bot=armyLand.T2.bot+1
                            armyLandType.bot=armyLandType.bot+1
                        elseif ALLBPS[unit.UnitId].CategoriesHash.SILO then
                            armyLand.T2.mml=armyLand.T2.mml+1
                            armyLandType.mml=armyLandType.mml+1
                        elseif ALLBPS[unit.UnitId].CategoriesHash.ANTIAIR then
                            armyLand.T2.aa=armyLand.T2.aa+1
                            armyLandType.aa=armyLandType.aa+1
                        elseif ALLBPS[unit.UnitId].CategoriesHash.SHIELD then
                            armyLand.T2.shield=armyLand.T2.shield+1
                            armyLandType.shield=armyLandType.shield+1
                        end
                    elseif ALLBPS[unit.UnitId].CategoriesHash.TECH3 then
                        armyLandTiers.T3=armyLandTiers.T3+1
                        if ALLBPS[unit.UnitId].CategoriesHash.SNIPER then
                            armyLand.T3.sniper=armyLand.T3.sniper+1
                            armyLandType.sniper=armyLandType.sniper+1
                        elseif EntityCategoryContains(categories.DIRECTFIRE * (categories.xel0305 + categories.xrl0305),unit) then
                            armyLand.T3.armoured=armyLand.T3.armoured+1
                            armyLandType.armoured=armyLandType.armoured+1
                        elseif EntityCategoryContains(categories.DIRECTFIRE - categories.xel0305 - categories.xrl0305 - categories.ANTIAIR,unit) then
                            armyLand.T3.tank=armyLand.T3.tank+1
                            armyLandType.tank=armyLandType.tank+1
                        elseif ALLBPS[unit.UnitId].CategoriesHash.SILO then
                            armyLand.T3.mml=armyLand.T3.mml+1
                            armyLandType.mml=armyLandType.mml+1
                        elseif ALLBPS[unit.UnitId].CategoriesHash.INDIRECTFIRE then
                            armyLand.T3.arty=armyLand.T3.arty+1
                            armyLandType.arty=armyLandType.arty+1
                        elseif ALLBPS[unit.UnitId].CategoriesHash.ANTIAIR then
                            armyLand.T3.aa=armyLand.T3.aa+1
                            armyLandType.aa=armyLandType.aa+1
                        elseif ALLBPS[unit.UnitId].CategoriesHash.SHIELD then
                            armyLand.T3.shield=armyLand.T3.shield+1
                            armyLandType.shield=armyLandType.shield+1
                        end
                    end
                elseif ALLBPS[unit.UnitId].CategoriesHash.AIR then
                    totalAirThreat = totalAirThreat + ALLBPS[unit.UnitId].Defense.AirThreatLevel + ALLBPS[unit.UnitId].Defense.SubThreatLevel + ALLBPS[unit.UnitId].Defense.SurfaceThreatLevel
                    if ALLBPS[unit.UnitId].CategoriesHash.TECH1 then
                        armyAirTiers.T1=armyAirTiers.T1+1
                        if ALLBPS[unit.UnitId].CategoriesHash.SCOUT then
                            armyAir.T1.scout=armyAir.T1.scout+1
                            armyAirType.scout=armyAirType.scout+1
                        elseif ALLBPS[unit.UnitId].CategoriesHash.ANTIAIR then
                            totalAntiAirThreat = totalAntiAirThreat + ALLBPS[unit.UnitId].Defense.AirThreatLevel
                            armyAir.T1.interceptor=armyAir.T1.interceptor+1
                            armyAirType.interceptor=armyAirType.interceptor+1
                        elseif ALLBPS[unit.UnitId].CategoriesHash.BOMBER then
                            armyAir.T1.bomber=armyAir.T1.bomber+1
                            armyAirType.bomber=armyAirType.bomber+1
                        elseif EntityCategoryContains(categories.GROUNDATTACK - categories.EXPERIMENTAL,unit) then
                            armyAir.T1.gunship=armyAir.T1.gunship+1
                            armyAirType.gunship=armyAirType.gunship+1
                        elseif ALLBPS[unit.UnitId].CategoriesHash.TRANSPORTFOCUS then
                            armyAir.T1.transport=armyAir.T1.transport+1
                            armyAirType.transport=armyAirType.transport+1
                        end
                    elseif ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                        armyAirTiers.T2=armyAirTiers.T2+1
                        if EntityCategoryContains(categories.BOMBER - categories.daa0206,unit) then
                            armyAir.T2.bomber=armyAir.T2.bomber+1
                            armyAirType.bomber=armyAirType.bomber+1
                        elseif EntityCategoryContains(categories.xaa0202 - categories.EXPERIMENTAL,unit) then
                            totalAntiAirThreat = totalAntiAirThreat + ALLBPS[unit.UnitId].Defense.AirThreatLevel
                            armyAir.T2.fighter=armyAir.T2.fighter+1
                            armyAirType.fighter=armyAirType.fighter+1
                        elseif EntityCategoryContains(categories.GROUNDATTACK - categories.EXPERIMENTAL,unit) then
                            armyAir.T2.gunship=armyAir.T2.gunship+1
                            armyAirType.gunship=armyAirType.gunship+1
                        elseif EntityCategoryContains(categories.ANTINAVY - categories.EXPERIMENTAL,unit) then
                            armyAir.T2.torpedo=armyAir.T2.torpedo+1
                            armyAirType.torpedo=armyAirType.torpedo+1
                        elseif EntityCategoryContains(categories.daa0206,unit) then
                            armyAir.T2.mercy=armyAir.T2.mercy+1
                            armyAirType.mercy=armyAirType.mercy+1
                        elseif ALLBPS[unit.UnitId].CategoriesHash.TRANSPORTFOCUS then
                            armyAir.T2.transport=armyAir.T2.transport+1
                            armyAirType.transport=armyAirType.transport+1
                        end
                    elseif ALLBPS[unit.UnitId].CategoriesHash.TECH3 then
                        armyAirTiers.T3=armyAirTiers.T3+1
                        if ALLBPS[unit.UnitId].CategoriesHash.SCOUT then
                            armyAir.T3.scout=armyAir.T3.scout+1
                            armyAirType.scout=armyAirType.scout+1
                        elseif EntityCategoryContains(categories.ANTIAIR - categories.BOMBER - categories.GROUNDATTACK ,unit) then
                            totalAntiAirThreat = totalAntiAirThreat + ALLBPS[unit.UnitId].Defense.AirThreatLevel
                            armyAir.T3.asf=armyAir.T3.asf+1
                            armyAirType.asf=armyAirType.asf+1
                        elseif ALLBPS[unit.UnitId].CategoriesHash.BOMBER then
                            armyAir.T3.bomber=armyAir.T3.bomber+1
                            armyAirType.bomber=armyAirType.bomber+1
                        elseif EntityCategoryContains(categories.GROUNDATTACK - categories.EXPERIMENTAL,unit) then
                            armyAir.T3.gunship=armyAir.T3.gunship+1
                            armyAirType.gunship=armyAirType.gunship+1
                        elseif ALLBPS[unit.UnitId].CategoriesHash.TRANSPORTFOCUS then
                            armyAir.T3.transport=armyAir.T3.transport+1
                            armyAirType.transport=armyAirType.transport+1
                        elseif EntityCategoryContains(categories.ANTINAVY - categories.EXPERIMENTAL,unit) then
                            armyAir.T3.torpedo=armyAir.T3.torpedo+1
                            armyAirType.torpedo=armyAirType.torpedo+1
                        end
                    end
                elseif ALLBPS[unit.UnitId].CategoriesHash.NAVAL then
                    totalNavalThreat = totalNavalThreat + ALLBPS[unit.UnitId].Defense.AirThreatLevel + ALLBPS[unit.UnitId].Defense.SubThreatLevel + ALLBPS[unit.UnitId].Defense.SurfaceThreatLevel
                    totalNavalSubThreat = totalNavalSubThreat + ALLBPS[unit.UnitId].Defense.SubThreatLevel
                    if ALLBPS[unit.UnitId].CategoriesHash.TECH1 then
                        armyNavalTiers.T1=armyNavalTiers.T1+1
                        if ALLBPS[unit.UnitId].CategoriesHash.FRIGATE then
                            armyNaval.T1.frigate=armyNaval.T1.frigate+1
                            armyNavalType.frigate=armyNavalType.frigate+1
                        elseif ALLBPS[unit.UnitId].CategoriesHash.T1SUBMARINE then
                            armyNaval.T1.sub=armyNaval.T1.sub+1
                            armyNavalType.sub=armyNavalType.sub+1
                        elseif EntityCategoryContains(categories.uas0102,unit) then
                            armyNaval.T1.shard=armyNaval.T1.shard+1
                            armyNavalType.shard=armyNavalType.shard+1
                        end
                    elseif ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                        armyNavalTiers.T2=armyNavalTiers.T2+1
                        if ALLBPS[unit.UnitId].CategoriesHash.DESTROYER then
                            armyNaval.T2.destroyer=armyNaval.T2.destroyer+1
                            armyNavalType.destroyer=armyNavalType.destroyer+1
                        elseif ALLBPS[unit.UnitId].CategoriesHash.CRUISER then
                            armyNaval.T2.cruiser=armyNaval.T2.cruiser+1
                            armyNavalType.cruiser=armyNavalType.cruiser+1
                        elseif EntityCategoryContains(categories.T2SUBMARINE + categories.xes0102,unit) then
                            armyNaval.T2.subhunter=armyNaval.T2.subhunter+1
                            armyNavalType.subhunter=armyNavalType.subhunter+1
                        end
                    --[[elseif EntityCategoryContains(categories.TECH3,unit) then
                        armyNavalTiers.T3=armyNavalTiers.T3+1
                        if EntityCategoryContains(categories.SCOUT,unit) then
                            armyNaval.T3.scout=armyNaval.T3.scout+1
                            armyNavalType.scout=armyNavalType.scout+1
                        elseif EntityCategoryContains(categories.ANTIAIR - categories.BOMBER - categories.GROUNDATTACK ,unit) then
                            armyNaval.T3.asf=armyNaval.T3.asf+1
                            armyNavalType.asf=armyNavalType.asf+1
                        elseif EntityCategoryContains(categories.BOMBER,unit) then
                            armyNaval.T3.bomber=armyNaval.T3.bomber+1
                            armyNavalType.bomber=armyNavalType.bomber+1
                        elseif EntityCategoryContains(categories.GROUNDATTACK - categories.EXPERIMENTAL,unit) then
                            armyNaval.T3.gunship=armyNaval.T3.gunship+1
                            armyNavalType.gunship=armyNavalType.gunship+1
                        elseif EntityCategoryContains(categories.TRANSPORTFOCUS,unit) then
                            armyNaval.T3.transport=armyNaval.T3.transport+1
                            armyNavalType.transport=armyNavalType.transport+1
                        elseif EntityCategoryContains(categories.ANTINAVY - categories.EXPERIMENTAL,unit) then
                            armyNaval.T3.torpedo=armyNaval.T3.torpedo+1
                            armyNavalType.torpedo=armyNavalType.torpedo+1
                        end]]
                    end
                elseif ALLBPS[unit.UnitId].CategoriesHash.SILO then
                    if ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                        silo.T2=silo.T2+1
                        launcherspend.T2=launcherspend.T2+spendm
                    elseif ALLBPS[unit.UnitId].CategoriesHash.TECH3 then
                        silo.T3=silo.T3+1
                        launcherspend.T3=launcherspend.T3+spendm
                    end
                end
            end
        end
        self.cmanager.income.r.m=rincome.m
        self.cmanager.income.r.e=rincome.e
        self.cmanager.income.t.m=tincome.m
        self.cmanager.income.t.e=tincome.e
        self.cmanager.spend.m=tspend.m
        self.cmanager.spend.e=tspend.e
        self.cmanager.categoryspend.eng=engspend
        self.cmanager.categoryspend.fact=facspend
        self.cmanager.categoryspend.silo=launcherspend
        self.cmanager.categoryspend.mex=mexspend
        self.cmanager.storage.current.m=storage.current.m
        self.cmanager.storage.current.e=storage.current.e
        if storage.current.m>0 and storage.current.e>0 then
            self.cmanager.storage.max.m=storage.max.m
            self.cmanager.storage.max.e=storage.max.e
        end
        self.amanager.Current.Land=armyLand
        self.amanager.Total.Land=armyLandTiers
        self.amanager.Type.Land=armyLandType
        self.amanager.Current.Air=armyAir
        self.amanager.Total.Air=armyAirTiers
        self.amanager.Type.Air=armyAirType
        self.amanager.Current.Naval=armyNaval
        self.amanager.Total.Naval=armyNavalTiers
        self.amanager.Type.Naval=armyNavalType
        self.BrainIntel.SelfThreat.LandNow = totalLandThreat
        self.BrainIntel.SelfThreat.AirNow = totalAirThreat
        self.BrainIntel.SelfThreat.AntiAirNow = totalAntiAirThreat
        self.BrainIntel.SelfThreat.NavalNow = totalNavalThreat
        self.BrainIntel.SelfThreat.NavalSubNow = totalNavalSubThreat
        self.BrainIntel.SelfThreat.ExtractorCount = totalExtractorCount
        self.BrainIntel.SelfThreat.Extractor = totalEconomyThreat
        self.EngineerDistributionTable = engineerDistribution
        self.smanager={fact=factories,mex=extractors,silo=silo,fabs=fabs,pgen=pgens,hydrocarbon=hydros}
        local totalCoreExtractors = mainBaseExtractors.T1 + mainBaseExtractors.T2 + mainBaseExtractors.T3
        if totalCoreExtractors > 0 then
            RNGLOG('Mainbase T1 Extractors '..mainBaseExtractors.T1)
            RNGLOG('Mainbase T2 Extractors '..mainBaseExtractors.T2)
            RNGLOG('Mainbase T3 Extractors '..mainBaseExtractors.T3)
            self.EcoManager.CoreExtractorT3Percentage = mainBaseExtractors.T3 / totalCoreExtractors
            self.EcoManager.CoreExtractorT2Count = mainBaseExtractors.T2 or 0
            self.EcoManager.CoreExtractorT3Count = mainBaseExtractors.T3 or 0
            self.EcoManager.TotalCoreExtractors = totalCoreExtractors or 0
        end
    end,

--[[
    GetManagerCount = function(self, type)
        if not self.RNG then
            return RNGAIBrainClass.GetManagerCount(self, type)
        end
        local count = 0
        for k, v in self.BuilderManagers do
            if type then
               --RNGLOG('BuilderManager Type is '..k)
                if type == 'Start Location' and not (string.find(k, 'ARMY_') or string.find(k, 'Large Expansion')) then
                    continue
                elseif type == 'Naval Area' and not (string.find(k, 'Naval Area')) then
                    continue
                elseif type == 'Expansion Area' and (not (string.find(k, 'Expansion Area') or string.find(k, 'EXPANSION_AREA')) or string.find(k, 'Large Expansion')) then
                    continue
                end
            end

            if v.EngineerManager:GetNumCategoryUnits('Engineers', categories.ALLUNITS) <= 0 and v.FactoryManager:GetNumCategoryFactories(categories.ALLUNITS) <= 0 then
                continue
            end

            count = count + 1
        end
       --RNGLOG('Type is '..type..' Count is '..count)
        return count
    end,]]

    

    CivilianPDCheckRNG = function(self)
        -- This will momentarily reveal civilian structures at the start of the game so that the AI can detect threat from PD's
        --RNGLOG('Reveal Civilian PD')
        coroutine.yield(2)
        local AIIndex = self:GetArmyIndex()
        for i,v in ArmyBrains do
            local brainIndex = v:GetArmyIndex()
            if ArmyIsCivilian(brainIndex) then
                --RNGLOG('Found Civilian brain')
                local real_state = IsAlly(AIIndex, brainIndex) and 'Ally' or IsEnemy(AIIndex, brainIndex) and 'Enemy' or 'Neutral'
                --RNGLOG('Set Alliance to Ally')
                SetAlliance(AIIndex, brainIndex, 'Ally')
                coroutine.yield(5)
                --RNGLOG('Set Alliance back to '..real_state)
                SetAlliance(AIIndex, brainIndex, real_state)
            end
        end
    end,

    DynamicExpansionRequiredRNG = function(self)

        -- What does this shit do?
        -- Its going to look at the expansion table which holds information on expansion markers.
        -- Then its going to see what the mass value of the graph zone is so we can see if its even worth looking
        -- Then if its worth it we'll see if we have an expansion in this zone and if not then we should look to establish a presense
        -- But what if an enemy already has structure threat around the expansion marker?
        -- Then we are going to try and create a dynamic expansion in the zone somewhere so we can try and take it.
        -- By default if someone already has the expansion marker the AI will give up. But that doesn't stop humans and it shouldn't stop us.
        -- When debuging, dont repr the expansions as they might have a unit assigned to them.
        coroutine.yield(Random(300,500))
        while true do
            local structureThreat
            local potentialExpansionZones = {}
            for k, v in self.BrainIntel.ExpansionWatchTable do
                local invalidZone = false
                if v.Zone then
                    if self.GraphZones then
                        if self.GraphZones[v.Zone].MassMarkersInZone > 5 then
                            for c, b in self.BuilderManagers do
                                if b.GraphArea and b.GraphArea == v.Zone then
                                    invalidZone = true
                                    break
                                end
                            end
                        else
                            invalidZone = true
                        end
                    end
                    if not invalidZone then
                        if not potentialExpansionZones[v.Zone] then
                            potentialExpansionZones[v.Zone] = {}
                            potentialExpansionZones[v.Zone].Expansions = {}
                            RNGINSERT(potentialExpansionZones[v.Zone].Expansions, v)
                        end
                    end
                end
            end
            --RNGLOG('These are the potentialExpansionZones')
            --RNGLOG('Mass Markers Per Zone')
            local foundMarker = false
            local loc = false
            self.BrainIntel.DynamicExpansionPositions = {}
            --RNGLOG('Graph Zones '..repr(self.GraphZones))
            for k, v in potentialExpansionZones do
                if v.Expansions then
                    for c, b in v.Expansions do
                       --RNGLOG('Position for expansion is ')
                       --RNGLOG(repr(b.Position))
                        local distance, highest
                        for n, m in self.GraphZones[k].MassMarkers do
                            distance = VDist2Sq(b.Position[1], b.Position[3], m.position[1], m.position[3])
                            if not highest or distance > highest then
                                loc = m.position
                                highest = distance
                            end
                        end
                        if loc then
                           --RNGLOG('Mass Marker Found')
                            foundMarker = true
                            break
                        else
                           --RNGLOG('No marker found for expansion in zone '..k)
                        end
                    end
                end
                table.insert(self.BrainIntel.DynamicExpansionPositions, {Zone = k, Position = loc})
            end
            if foundMarker then
               --RNGLOG('Marker we could have a dynamic expansion on the following positions')
               --RNGLOG(repr(self.BrainIntel.DynamicExpansionPositions))
            end
            coroutine.yield(100)
        end
    end,
}
