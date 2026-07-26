local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG
local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
local RNGAIGLOBALS = import("/mods/RNGAI/lua/AI/RNGAIGlobals.lua")
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local GetEconomyIncome = moho.aibrain_methods.GetEconomyIncome
local GetEconomyRequested = moho.aibrain_methods.GetEconomyRequested
local GetEconomyStored = moho.aibrain_methods.GetEconomyStored
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local GetEconomyTrend = moho.aibrain_methods.GetEconomyTrend
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint

local RNGGETN = table.getn
local RNGINSERT = table.insert
local RNGREMOVE = table.remove
local RNGSORT = table.sort

local WeakValueTable = { __mode = 'v' }

StructureManager = Class {
    Create = function(self, brain)
        self.Brain = brain
        self.Initialized = false
        self.Debug = false
        self.LabelMassDrain = {}
        self.Factories = {
            -- Reminder about the keys being tech level
            LAND = {
                {
                    Units = {},
                    Total = 0,
                    UpgradingCount = 0
                },
                {
                    Units = {},
                    Total = 0,
                    UpgradingCount = 0,
                    HQCount = {
                        ['ueb0201'] = 0,
                        ['uab0201'] = 0,
                        ['urb0201'] = 0,
                        ['xsb0201'] = 0
                    }
                },
                {
                    Units = {},
                    Total = 0,
                    UpgradingCount = 0,
                    HQCount = {
                        ['ueb0301'] = 0,
                        ['uab0301'] = 0,
                        ['urb0301'] = 0,
                        ['xsb0301'] = 0
                    }
                }
            },
            AIR = {
                {
                    Units = {},
                    Total = 0,
                    UpgradingCount = 0
                },
                {
                    Units = {},
                    Total = 0,
                    UpgradingCount = 0,
                    HQCount = {
                        ['ueb0202'] = 0,
                        ['uab0202'] = 0,
                        ['urb0202'] = 0,
                        ['xsb0202'] = 0
                    }
                },
                {
                    Units = {},
                    Total = 0,
                    UpgradingCount = 0,
                    HQCount = {
                        ['ueb0302'] = 0,
                        ['uab0302'] = 0,
                        ['urb0302'] = 0,
                        ['xsb0302'] = 0
                    }
                }
            },
            NAVAL = {
                {
                    Units = {},
                    Total = 0,
                    UpgradingCount = 0
                },
                {
                    Units = {},
                    Total = 0,
                    UpgradingCount = 0,
                    HQCount = {
                        ['ueb0103'] = 0,
                        ['uab0103'] = 0,
                        ['urb0103'] = 0,
                        ['xsb0103'] = 0
                    }
                },
                {
                    Units = {},
                    Total = 0,
                    UpgradingCount = 0,
                    HQCount = {
                        ['ueb0103'] = 0,
                        ['uab0103'] = 0,
                        ['urb0103'] = 0,
                        ['xsb0103'] = 0
                    }
                }
            }
        }
        self.SupportUpgradeTable = {
            LAND = {
                T2 = {
                    ['ueb0101'] = 'zeb9501',
                    ['uab0101'] = 'zab9501',
                    ['urb0101'] = 'zrb9501',
                    ['xsb0101'] = 'zsb9501'
                },
                T3 = {
                    ['ueb0201'] = 'zeb9601',
                    ['uab0201'] = 'zab9601',
                    ['urb0201'] = 'zrb9601',
                    ['xsb0201'] = 'zsb9601'
                }
            },
            AIR = {
                T2 = {
                    ['ueb0102'] = 'zeb9502',
                    ['uab0102'] = 'zab9502',
                    ['urb0102'] = 'zrb9502',
                    ['xsb0102'] = 'zsb9502'
                },
                T3 = {
                    ['ueb0202'] = 'zeb9602',
                    ['uab0202'] = 'zab9602',
                    ['urb0202'] = 'zrb9602',
                    ['xsb0202'] = 'zsb9602'
                }
            },
            NAVAL = {
                T2 = {
                    ['ueb0103'] = 'zeb9503',
                    ['uab0103'] = 'zab9503',
                    ['urb0103'] = 'zrb9503',
                    ['xsb0103'] = 'zsb9503'
                },
                T3 = {
                    ['ueb0203'] = 'zeb9603',
                    ['uab0203'] = 'zab9603',
                    ['urb0203'] = 'zrb9603',
                    ['xsb0203'] = 'zsb9603'
                }
            },
        }
        self.ZoneStructures = {}
        self.ShieldCoverage = {}
        self.TMDRequired = false
        self.StructuresRequiringTMD = {}
        self.ShieldsRequired = false
        self.StructuresRequiringShields = {}
        self.ExtractorUpgradeQueue = {}
        self.UpgradeConfig = {
            Shield = {
                Category = categories.STRUCTURE * categories.SHIELD * categories.TECH2,
                MaxUpgrading = 2,
                MinEnergyTech = categories.TECH3 * categories.ENERGYPRODUCTION,
                Econ = { storage = { 0.07, 0.9 }, trend = 0.0 },
            },
            Radar = {
                T1 = {
                    Category = categories.STRUCTURE * categories.RADAR * categories.TECH1,
                    TargetTechCategory = categories.TECH2 + categories.TECH3, 
                    Econ = { storage = { 0.05, 0.8 }, efficiency = 0.9 },
                    MaintenanceCost = 150,
                },
                T2 = {
                    Category = categories.STRUCTURE * categories.RADAR * categories.TECH2, 
                    TargetTechCategory = categories.TECH3 * categories.OMNI,
                    Econ = { storage = { 0.05, 0.8 }, efficiency = 0.9 },
                    MaintenanceCost = 2000,
                }
            },
            Sonar = {
                T1 = {
                    Category = categories.STRUCTURE * categories.SONAR * categories.TECH1,
                    TargetTechCategory = categories.TECH2 + categories.TECH3,
                    Econ = { storage = { 0.05, 0.8 } },
                    MaintenanceCost = 100,
                },
                T2 = {
                    Category = categories.STRUCTURE * categories.SONAR * categories.TECH2,
                    TargetTechCategory = categories.TECH3 * categories.SONAR,
                    Econ = { storage = { 0.05, 0.8 } },
                    MaintenanceCost = 500,
                }
            }
        }
        self.UpgradingStructures = {}
    end,

    Run = function(self)
       --LOG('RNGAI : StructureManager Starting')
        self:ForkThread(self.FactoryDataCaptureRNG)
        self:ForkThread(self.EcoExtractorUpgradeCheckRNG, self.Brain)
        self:ForkThread(self.EcoTacticalThread, self.Brain) -- tbd
        self:ForkThread(self.CheckDefensiveCoverage)
        self:ForkThread(self.StructureUpgradeThreadRNG)
        if self.Debug then
            self:ForkThread(self.StructureDebugThread)
        end
        self.Initialized = true
       --LOG('RNGAI : StructureManager Started')
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

    EcoTacticalThread = function(self, aiBrain)
        while not aiBrain.ZonesInitialized do
            coroutine.yield(20)
        end

        local zoneTypes = {
            'Land',
            'Naval'
        }

        while aiBrain.Status ~= 'Defeat' do
            local globalSafeZones = {}
            local globalZoneUpgradeBias = {}
            local frontlineDefenseRatio = {}
            
            local totalAlliedZonesCount = 0
            local totalZonesCount = 0

            for _, layer in ipairs(zoneTypes) do
                local zoneSet = aiBrain.Zones[layer].zones
                
                -- Keep layer data strict and isolated
                local layerAlliedZones = {}
                local allyZonesList = {}

                -- Correctly count total zones in this specific layer table layout
                for _, zone in pairs(zoneSet) do
                    totalZonesCount = totalZonesCount + 1
                    if zone.status == 'Allied' then
                        layerAlliedZones[zone.id] = zone
                        table.insert(allyZonesList, zone)
                        totalAlliedZonesCount = totalAlliedZonesCount + 1
                    end
                end

                -- Execute safety sweep with layer-pure lists
                local barrier, zoneDepths, layerSafeZones, layerUpgradeBias = RUtils.ComputeSafetyState(aiBrain, allyZonesList, zoneSet, layer)

                -- Merge into global tracking maps
                for id, _ in pairs(layerSafeZones) do
                    globalSafeZones[id] = true
                end

                for id, bias in pairs(layerUpgradeBias) do
                    globalZoneUpgradeBias[id] = bias
                end

                -- Frontline defense calculation
                local defendedFrontlines = 0
                local totalFrontlines = 0

                for _, zone in ipairs(allyZonesList) do
                    local zoneID = zone.id
                    if zoneDepths[zoneID] == 1 then  -- Purely tracking this layer's frontier depth
                        local defenseAllocated = zone.platoonallocations.friendlydirectfireallocatedthreat or 0
                        local defensePresent = zone.friendlydirectfireantisurfacethreat or 0
                        local defense = defenseAllocated + defensePresent
                        local threat = zone.gridenemylandthreat or 0

                        if defense > threat * 1.25 then
                            defendedFrontlines = defendedFrontlines + 1
                        end
                        totalFrontlines = totalFrontlines + 1
                    end
                end

                frontlineDefenseRatio[layer] = totalFrontlines > 0 and (defendedFrontlines / totalFrontlines) or 0
                if layer == 'Land' then aiBrain.EcoManager.LandZoneDepths = zoneDepths end
            end

            local safeZoneCount = 0
            for _ in pairs(globalSafeZones) do
                safeZoneCount = safeZoneCount + 1
            end

            --LOG('Total Zones: '..tostring(totalZonesCount))
            --LOG('Allied Zones: '..tostring(totalAlliedZonesCount))
            --LOG('Safe Zones: '..tostring(safeZoneCount))
            
            aiBrain.EcoManager.SafeMassZones = globalSafeZones
            aiBrain.EcoManager.ZoneUpgradeBias = globalZoneUpgradeBias
            
            -- Land frontline security status now safely resolves
            aiBrain.EcoManager.TacticalGreedAllowed = (safeZoneCount > 0 and frontlineDefenseRatio['Land'] > 0.5)

            --LOG('TacticalGreedAllowed: '..tostring(aiBrain.EcoManager.TacticalGreedAllowed))
            --LOG(string.format("[RNGLOG] Final Verification - LandFrontlineRatio: %.2f", frontlineDefenseRatio['Land'] or 0))

            coroutine.yield(60)
        end
    end,


    RegisterZoneStructure = function(self, unit)
        if unit and not unit.Dead then
            if not unit['rngdata'] then
                unit['rngdata'] = {}
            end
            local rngData = unit['rngdata']
            if not rngData.ZoneType or not rngData.ZoneID then
                --LOG('No zone id')
                local unitPos = unit:GetPosition()
                if RUtils.PositionOnWater(unitPos[1], unitPos[3]) then
                    rngData.ZoneID = MAP:GetZoneID(unitPos,self.Brain.Zones.Naval.index)
                    rngData.ZoneType = 'Naval'
                else
                    rngData.ZoneID = MAP:GetZoneID(unitPos,self.Brain.Zones.Land.index)
                    rngData.ZoneType = 'Land'
                end
                if not rngData.ZoneID then
                    WARN('RegisterZoneStructure: MAP:GetZoneID returned nil for '..repr(unit.UnitId))
                    return
                end
                --LOG('zone id was set to '..tostring(rngData.ZoneID))
            end
            rngData.StructureType = self:GetStructureType(unit)
            self.ZoneStructures[rngData.ZoneID] = self.ZoneStructures[rngData.ZoneID] or {}
            self.ZoneStructures[rngData.ZoneID][rngData.StructureType] = self.ZoneStructures[rngData.ZoneID][rngData.StructureType] or {}
            if not self.ZoneStructures[rngData.ZoneID][rngData.StructureType][unit.EntityId] then
                self.ZoneStructures[rngData.ZoneID][rngData.StructureType][unit.EntityId] = unit
                --LOG('Registered structure: '..rngData.StructureType..' in zone '..rngData.ZoneID)
            end
        end
    end,

    RemoveZoneStructure = function(self, unit)
        local rngData = unit.rngdata
        if rngData and rngData.ZoneID and rngData.StructureType then
            local zoneTable = self.ZoneStructures[rngData.ZoneID]
            if zoneTable then
                local structTable = zoneTable[rngData.StructureType]
                if structTable and structTable[unit.EntityId] then
                    structTable[unit.EntityId] = nil
                    --LOG('Removed structure '..rngData.StructureType..' from zone '..rngData.ZoneID)
                    if rngData.StructureType == 'EXTRACTOR' then
                        self:ForkThread(self.CheckZoneLoss, rngData.ZoneID, rngData.ZoneType)
                    end
                end
            end
        end
    end,

    CheckZoneLoss = function(self, zoneId, zoneType)
        local zone
        local aiBrain = self.Brain
        if zoneType == 'Naval' then
            zone = aiBrain.Zones.Naval.zones[zoneId]
        else
            zone = aiBrain.Zones.Land.zones[zoneId]
        end
        if zone then
            local extractorTable = self.ZoneStructures[zoneId]['EXTRACTOR']
            local extractorCount = 0
            for _, v in extractorTable do
                if v and not v.Dead then
                    extractorCount = extractorCount + 1
                end
            end
            if extractorCount == 0 then
                local defenseZoneRequired = RUtils.DetermineDefensiveInterceptZone(aiBrain, aiBrain.BrainIntel.StartPos, zoneId, 'land')
                if defenseZoneRequired then
                    local pdCount = 0
                    if self.ZoneStructures[defenseZoneRequired]['TECH1POINTDEFENSE'] then
                        for _, v in self.ZoneStructures[defenseZoneRequired]['TECH1POINTDEFENSE'] do
                            if v and not v.Dead then
                                pdCount = pdCount + 1
                            end
                        end
                    end
                    if pdCount < 1 then
                        local zonePos
                        if zoneType == 'Naval' then
                            zonePos = aiBrain.Zones.Naval.zones[defenseZoneRequired].pos
                        else
                            zonePos = aiBrain.Zones.Land.zones[defenseZoneRequired].pos
                        end
                        if zonePos then
                            if not aiBrain.IntelManager:IsExistingStructureRequestPresent(zonePos, 15, 'TECH1POINTDEFENSE') then
                                aiBrain.IntelManager:RequestStructureNearPosition(zonePos, 15, 'TECH1POINTDEFENSE')
                            end
                        end
                    end
                end
            end
        end
    end,
    
    AddZoneStructure = function(self, unit)
        if not self.Initialized or not RNGAIGLOBALS.ZoneGenerationComplete then
            --LOG('Not initialized yet, go to wait')
            self:ForkThread(function()
                local timeout = 0
                while not self.Initialized or not RNGAIGLOBALS.ZoneGenerationComplete do
                    coroutine.yield(10)
                    timeout = timeout + 1
                    if timeout > 50 then
                        WARN("AI-RNG: Deferred AddZoneStructure timed out.")
                        return
                    end
                end
                self:RegisterZoneStructure(unit)
            end)
        else
            self:RegisterZoneStructure(unit)
        end
    end,

    GetStructureType = function(self, unit)
        local cat = unit.Blueprint.CategoriesHash

        if cat.RADAR then
            return 'RADAR'
        elseif cat.SONAR then
            return 'SONAR'
        elseif cat.TACTICALMISSILEDEFENSE then
            return 'TACTICALMISSILEDEFENSE'
        elseif cat.SHIELD then
            return 'SHIELD'
        elseif cat.ARTILLERY then
            return 'ARTILLERY'
        elseif cat.ANTIAIR then
            return 'ANTIAIR'
        elseif cat.DEFENSE and cat.DIRECTFIRE and cat.TECH1 and not cat.ANTIAIR then
            return 'TECH1POINTDEFENSE'
        elseif cat.TECH3 and cat.STRUCTURE and cat.DEFENSE and cat.ANTIMISSILE then
            return 'SMD'
        elseif cat.FACTORY then
            return 'FACTORY'
        elseif cat.MASSEXTRACTION then
            return 'EXTRACTOR'
        elseif cat.ENERGYPRODUCTION then
            return 'ENERGYPRODUCTION'
        end

        return 'UNKNOWN_' .. unit.Blueprint.BlueprintId

    end,

    FactoryDataCaptureRNG = function(self)
        -- Lets try be smart about how we do this
        -- This captures the current factory states, replaces all those builder conditions
        -- Note it uses the factory managers rather than getlistofunits
        -- This means we won't capture factories that are potentially given in fullshare
        -- So I might need to manage that somewhere else
        -- Or maybe we should just use getlistofunits instead but then we won't know which base they are in.. tbd
        local function GetFactoryPhase(brainName, factoryTable)
            local highestHQ = 1
            local upgradingTier = nil
            for tier = 3, 1, -1 do
                local tierData = factoryTable[tier]
                if tierData then
                    -- HQ check (only meaningful for T2 and T3)
                    if tier >= 2 and tierData.HQCount then
                        for id, count in tierData.HQCount do
                            if count > 0 and tier > highestHQ then
                                highestHQ = tier
                            end
                        end
                    end
                    -- Upgrading check
                    if tierData.UpgradingCount and tierData.UpgradingCount > 0 then
                        upgradingTier = tier
                    end
                end
            end
            --LOG('Final highestHQ = ' .. highestHQ .. ', upgradingTier = ' .. tostring(upgradingTier))
            if upgradingTier and upgradingTier >= highestHQ then
                local phase = upgradingTier + 0.5
                --LOG('Returning phase ' .. phase .. ' due to upgrade in progress')
                return phase
            end
            --LOG('Returning phase ' .. highestHQ)
            return highestHQ
        end
        coroutine.yield(Random(5,20))
        local myArmy = ScenarioInfo.ArmySetup[self.Brain.Name]
        local teamReference = self.Brain.TeamReference
        if teamReference then
            self.Team = myArmy.Team
            if not RNGAIGLOBALS.HighestTeamAirPhase[teamReference] then
                RNGAIGLOBALS.HighestTeamAirPhase[teamReference] = 1
            end
            if not RNGAIGLOBALS.HighestTeamLandPhase[teamReference] then
                RNGAIGLOBALS.HighestTeamLandPhase[teamReference] = 1
            end
            if not RNGAIGLOBALS.HighestTeamNavalPhase[teamReference] then
                RNGAIGLOBALS.HighestTeamNavalPhase[teamReference] = 1
            end
        end
        local buildMultiplier = 1.0
        if self.Brain.CheatEnabled then
            buildMultiplier = self.Brain.EcoManager.BuildMultiplier
        end
        while true do
            -- Create a table rather than a million locals
            local FactoryData = {
                T2LANDHQCount = {
                    ['ueb0201'] = 0,
                    ['uab0201'] = 0,
                    ['urb0201'] = 0,
                    ['xsb0201'] = 0
                },
                T3LANDHQCount = {
                    ['ueb0301'] = 0,
                    ['uab0301'] = 0,
                    ['urb0301'] = 0,
                    ['xsb0301'] = 0
                },
                T2AIRHQCount = {
                    ['ueb0202'] = 0,
                    ['uab0202'] = 0,
                    ['urb0202'] = 0,
                    ['xsb0202'] = 0
                },
                T3AIRHQCount = {
                    ['ueb0302'] = 0,
                    ['uab0302'] = 0,
                    ['urb0302'] = 0,
                    ['xsb0302'] = 0
                },
                T2NAVALHQCount = {
                    ['ueb0203'] = 0,
                    ['uab0203'] = 0,
                    ['urb0203'] = 0,
                    ['xsb0203'] = 0
                },
                T3NAVALHQCount = {
                    ['ueb0303'] = 0,
                    ['uab0303'] = 0,
                    ['urb0303'] = 0,
                    ['xsb0303'] = 0
                },
                T1LANDApproxConsumption = 0,
                T2LANDApproxConsumption = 0,
                T3LANDApproxConsumption = 0,
                T1AIRApproxConsumption = 0,
                T2AIRApproxConsumption = 0,
                T3AIRApproxConsumption = 0,
                T1NAVALApproxConsumption = 0,
                T2NAVALApproxConsumption = 0,
                T3NAVALApproxConsumption = 0,
                T1LANDUpgrading = 0,
                T2LANDUpgrading = 0,
                T1AIRUpgrading = 0,
                T2AIRUpgrading = 0,
                T1NAVALUpgrading = 0,
                T2NAVALUpgrading = 0,
                T1LAND = {},
                TotalT1LAND = 0,
                T2LAND = {},
                TotalT2LAND = 0,
                T3LAND = {},
                TotalT3LAND = 0,
                T1AIR = {},
                TotalT1AIR = 0,
                T2AIR = {},
                TotalT2AIR = 0,
                T3AIR = {},
                TotalT3AIR = 0,
                T1NAVAL = {},
                TotalT1NAVAL = 0,
                T2NAVAL = {},
                TotalT2NAVAL = 0,
                T3NAVAL = {},
                TotalT3NAVAL = 0,
            }
            local labelMassDrain = {
            }
            for baseName, manager in self.Brain.BuilderManagers do
                if baseName ~= 'FLOATING' then
                    if manager.FactoryManager.FactoryList and not table.empty(manager.FactoryManager.FactoryList) then
                        local massToFactoryValues = manager.BaseSettings.MassToFactoryValues
                        local landFactoryBuildRate = 0
                        local airFactoryBuildRate = 0
                        local navalFactoryBuildRate = 0
                        local localT1LandUpgradingCount = 0
                        local localT1AirUpgradingCount = 0
                        local localT1NavalUpgradingCount = 0
                        local localT2LandUpgradingCount = 0
                        local localT2AirUpgradingCount = 0
                        local localT2NavalUpgradingCount = 0
                        for c, unit in manager.FactoryManager.FactoryList do
                            local unitCat = unit.Blueprint.CategoriesHash
                            if not IsDestroyed(unit) then
                                if unitCat.LAND then
                                    if unitCat.TECH1 then
                                        RNGINSERT(FactoryData.T1LAND, unit)
                                        if unit:IsUnitState('Upgrading') then
                                            localT1LandUpgradingCount = localT1LandUpgradingCount + 1
                                        else
                                            landFactoryBuildRate = landFactoryBuildRate + ((unit.Blueprint.Economy.BuildRate or 0) * buildMultiplier)
                                        end
                                        FactoryData.TotalT1LAND = FactoryData.TotalT1LAND + 1
                                        FactoryData.T1LANDApproxConsumption = FactoryData.T1LANDApproxConsumption + massToFactoryValues.T1LandValue
                                        if unit.Label then
                                            if not labelMassDrain[unit.Label] then
                                                labelMassDrain[unit.Label] = {
                                                    Land = 0,
                                                    Air = 0,
                                                    Naval = 0
                                                }
                                            end
                                            labelMassDrain[unit.Label].Land = labelMassDrain[unit.Label].Land + massToFactoryValues.T1LandValue
                                        end
                                    elseif unitCat.TECH2 then
                                        RNGINSERT(FactoryData.T2LAND, unit)
                                        if not unitCat.SUPPORTFACTORY then
                                            if not FactoryData.T2LANDHQCount[unit.UnitId] then
                                                FactoryData.T2LANDHQCount[unit.UnitId] = 0
                                            end
                                            FactoryData.T2LANDHQCount[unit.UnitId] = FactoryData.T2LANDHQCount[unit.UnitId] + 1
                                        end
                                        if unit:IsUnitState('Upgrading') then
                                            localT2LandUpgradingCount = localT2LandUpgradingCount + 1
                                        else
                                            landFactoryBuildRate = landFactoryBuildRate + ((unit.Blueprint.Economy.BuildRate or 0) * buildMultiplier)
                                        end
                                        FactoryData.TotalT2LAND = FactoryData.TotalT2LAND + 1
                                        FactoryData.T2LANDApproxConsumption = FactoryData.T2LANDApproxConsumption + massToFactoryValues.T2LandValue
                                        if unit.Label then
                                            if not labelMassDrain[unit.Label] then
                                                labelMassDrain[unit.Label] = {
                                                    Land = 0,
                                                    Air = 0,
                                                    Naval = 0
                                                }
                                            end
                                            labelMassDrain[unit.Label].Land = labelMassDrain[unit.Label].Land + massToFactoryValues.T2LandValue
                                        end
                                    elseif unitCat.TECH3 then
                                        RNGINSERT(FactoryData.T3LAND, unit)
                                        if not unitCat.SUPPORTFACTORY then
                                            if not FactoryData.T3LANDHQCount[unit.UnitId] then
                                                FactoryData.T3LANDHQCount[unit.UnitId] = 0
                                            end
                                            FactoryData.T3LANDHQCount[unit.UnitId] = FactoryData.T3LANDHQCount[unit.UnitId] + 1
                                        end
                                        landFactoryBuildRate = landFactoryBuildRate + ((unit.Blueprint.Economy.BuildRate or 0) * buildMultiplier)
                                        FactoryData.TotalT3LAND = FactoryData.TotalT3LAND + 1
                                        FactoryData.T3LANDApproxConsumption = FactoryData.T3LANDApproxConsumption + massToFactoryValues.T3LandValue
                                        if unit.Label then
                                            if not labelMassDrain[unit.Label] then
                                                labelMassDrain[unit.Label] = {
                                                    Land = 0,
                                                    Air = 0,
                                                    Naval = 0
                                                }
                                            end
                                            labelMassDrain[unit.Label].Land = labelMassDrain[unit.Label].Land + massToFactoryValues.T3LandValue
                                        end
                                    end
                                elseif unitCat.AIR then

                                    if unitCat.TECH1 then
                                        RNGINSERT(FactoryData.T1AIR, unit)
                                        if unit:IsUnitState('Upgrading') then
                                            localT1AirUpgradingCount = localT1AirUpgradingCount + 1
                                        else
                                            airFactoryBuildRate = airFactoryBuildRate + ((unit.Blueprint.Economy.BuildRate or 0) * buildMultiplier)
                                        end
                                        FactoryData.TotalT1AIR = FactoryData.TotalT1AIR + 1
                                        FactoryData.T1AIRApproxConsumption = FactoryData.T1AIRApproxConsumption + massToFactoryValues.T1AirValue
                                        if unit.Label then
                                            if not labelMassDrain[unit.Label] then
                                                labelMassDrain[unit.Label] = {
                                                    Land = 0,
                                                    Air = 0,
                                                    Naval = 0
                                                }
                                            end
                                            labelMassDrain[unit.Label].Air = labelMassDrain[unit.Label].Air + massToFactoryValues.T1AirValue
                                        end
                                    elseif unitCat.TECH2 then
                                        RNGINSERT(FactoryData.T2AIR, unit)
                                        if not unitCat.SUPPORTFACTORY then
                                            if not FactoryData.T2AIRHQCount[unit.UnitId] then
                                                FactoryData.T2AIRHQCount[unit.UnitId] = 0
                                            end
                                            FactoryData.T2AIRHQCount[unit.UnitId] = FactoryData.T2AIRHQCount[unit.UnitId] + 1
                                        end
                                        if unit:IsUnitState('Upgrading') then
                                            localT2AirUpgradingCount = localT2AirUpgradingCount + 1
                                        else
                                            airFactoryBuildRate = airFactoryBuildRate + ((unit.Blueprint.Economy.BuildRate or 0) * buildMultiplier)
                                        end
                                        FactoryData.TotalT2AIR = FactoryData.TotalT2AIR + 1
                                        FactoryData.T2AIRApproxConsumption = FactoryData.T2AIRApproxConsumption + massToFactoryValues.T2AirValue
                                        if unit.Label then
                                            if not labelMassDrain[unit.Label] then
                                                labelMassDrain[unit.Label] = {
                                                    Land = 0,
                                                    Air = 0,
                                                    Naval = 0
                                                }
                                            end
                                            labelMassDrain[unit.Label].Air = labelMassDrain[unit.Label].Air + massToFactoryValues.T2AirValue
                                        end
                                    elseif unitCat.TECH3 then
                                        RNGINSERT(FactoryData.T3AIR, unit)
                                        if not unitCat.SUPPORTFACTORY then
                                            if not FactoryData.T3AIRHQCount[unit.UnitId] then
                                                FactoryData.T3AIRHQCount[unit.UnitId] = 0
                                            end
                                            FactoryData.T3AIRHQCount[unit.UnitId] = FactoryData.T3AIRHQCount[unit.UnitId] + 1
                                        end
                                        airFactoryBuildRate = airFactoryBuildRate + ((unit.Blueprint.Economy.BuildRate or 0) * buildMultiplier)
                                        FactoryData.TotalT3AIR = FactoryData.TotalT3AIR + 1
                                        FactoryData.T3AIRApproxConsumption = FactoryData.T3AIRApproxConsumption + massToFactoryValues.T3AirValue
                                        if unit.Label then
                                            if not labelMassDrain[unit.Label] then
                                                labelMassDrain[unit.Label] = {
                                                    Land = 0,
                                                    Air = 0,
                                                    Naval = 0
                                                }
                                            end
                                            labelMassDrain[unit.Label].Air = labelMassDrain[unit.Label].Air + massToFactoryValues.T3AirValue
                                        end
                                    end
                                elseif unitCat.NAVAL then
                                    if unitCat.TECH1 then
                                        RNGINSERT(FactoryData.T1NAVAL, 1, unit)
                                        if unit:IsUnitState('Upgrading') then
                                            localT1NavalUpgradingCount = localT1NavalUpgradingCount + 1
                                        else
                                            navalFactoryBuildRate = navalFactoryBuildRate + ((unit.Blueprint.Economy.BuildRate or 0) * buildMultiplier)
                                        end
                                        FactoryData.TotalT1NAVAL = FactoryData.TotalT1NAVAL + 1
                                        FactoryData.T1NAVALApproxConsumption = FactoryData.T1NAVALApproxConsumption + massToFactoryValues.T1NavalValue
                                        if unit.Label then
                                            if not labelMassDrain[unit.Label] then
                                                labelMassDrain[unit.Label] = {
                                                    Land = 0,
                                                    Air = 0,
                                                    Naval = 0
                                                }
                                            end
                                            labelMassDrain[unit.Label].Naval = labelMassDrain[unit.Label].Naval + massToFactoryValues.T1NavalValue
                                        end
                                    elseif unitCat.TECH2 then
                                        RNGINSERT(FactoryData.T2NAVAL, unit)
                                        if not unitCat.SUPPORTFACTORY then
                                            if not FactoryData.T2NAVALHQCount[unit.UnitId] then
                                                FactoryData.T2NAVALHQCount[unit.UnitId] = 0
                                            end
                                            FactoryData.T2NAVALHQCount[unit.UnitId] = FactoryData.T2NAVALHQCount[unit.UnitId] + 1
                                        end
                                        if unit:IsUnitState('Upgrading') then
                                            localT2NavalUpgradingCount = localT2NavalUpgradingCount + 1
                                        else
                                            navalFactoryBuildRate = navalFactoryBuildRate + ((unit.Blueprint.Economy.BuildRate or 0) * buildMultiplier)
                                        end
                                        FactoryData.TotalT2NAVAL = FactoryData.TotalT2NAVAL + 1
                                        FactoryData.T2NAVALApproxConsumption = FactoryData.T2NAVALApproxConsumption + massToFactoryValues.T2NavalValue
                                        if unit.Label then
                                            if not labelMassDrain[unit.Label] then
                                                labelMassDrain[unit.Label] = {
                                                    Land = 0,
                                                    Air = 0,
                                                    Naval = 0
                                                }
                                            end
                                            labelMassDrain[unit.Label].Naval = labelMassDrain[unit.Label].Naval + massToFactoryValues.T2NavalValue
                                        end
                                    elseif unitCat.TECH3 then
                                        RNGINSERT(FactoryData.T3NAVAL, unit)
                                        if not unitCat.SUPPORTFACTORY then
                                            if not FactoryData.T3NAVALHQCount[unit.UnitId] then
                                                FactoryData.T3NAVALHQCount[unit.UnitId] = 0
                                            end
                                            FactoryData.T3NAVALHQCount[unit.UnitId] = FactoryData.T3NAVALHQCount[unit.UnitId] + 1
                                        end
                                        navalFactoryBuildRate = navalFactoryBuildRate + ((unit.Blueprint.Economy.BuildRate or 0) * buildMultiplier)
                                        FactoryData.TotalT3NAVAL = FactoryData.TotalT3NAVAL + 1
                                        FactoryData.T3NAVALApproxConsumption = FactoryData.T3NAVALApproxConsumption + massToFactoryValues.T3NavalValue
                                        if unit.Label then
                                            if not labelMassDrain[unit.Label] then
                                                labelMassDrain[unit.Label] = {
                                                    Land = 0,
                                                    Air = 0,
                                                    Naval = 0
                                                }
                                            end
                                            labelMassDrain[unit.Label].Naval = labelMassDrain[unit.Label].Naval + massToFactoryValues.T3NavalValue
                                        end
                                    end
                                end
                            end
                        end
                        manager.FactoryManager.LandBuildRate = landFactoryBuildRate
                        manager.FactoryManager.AirBuildRate = airFactoryBuildRate
                        manager.FactoryManager.NavalBuildRate = navalFactoryBuildRate
                        manager.FactoryManager.T1LANDUpgradingCount = localT1LandUpgradingCount
                        manager.FactoryManager.T2LANDUpgradingCount = localT2LandUpgradingCount
                        manager.FactoryManager.T1AIRUpgradingCount = localT1AirUpgradingCount
                        manager.FactoryManager.T2AIRUpgradingCount = localT2AirUpgradingCount
                        manager.FactoryManager.T1NAVALUpgradingCount = localT1NavalUpgradingCount
                        manager.FactoryManager.T2NAVALUpgradingCount = localT2NavalUpgradingCount
                        FactoryData.T1LANDUpgrading = FactoryData.T1LANDUpgrading + localT1LandUpgradingCount
                        FactoryData.T2LANDUpgrading = FactoryData.T2LANDUpgrading + localT2LandUpgradingCount
                        FactoryData.T1AIRUpgrading = FactoryData.T1AIRUpgrading + localT1AirUpgradingCount
                        FactoryData.T2AIRUpgrading = FactoryData.T2AIRUpgrading + localT2AirUpgradingCount
                        FactoryData.T1NAVALUpgrading = FactoryData.T1NAVALUpgrading + localT1NavalUpgradingCount
                        FactoryData.T2NAVALUpgrading = FactoryData.T2NAVALUpgrading + localT2NavalUpgradingCount
                        --LOG('Land BuildRate for '..tostring(baseName)..' is '..tostring(manager.FactoryManager.LandBuildRate))
                        --LOG('Air BuildRate for '..tostring(baseName)..' is '..tostring(manager.FactoryManager.AirBuildRate))
                        --LOG('Naval BuildRate for '..tostring(baseName)..' is '..tostring(manager.FactoryManager.NavalBuildRate))
                    end
                    if manager.BaseSettings.MassToFactoryValues then
                        if baseName == 'MAIN' then
                            manager.BaseSettings.MassToFactoryValues = {
                                T1LandValue = 4,
                                T2LandValue = 10,
                                T3LandValue = 23,
                                T1AirValue = 3.5,
                                T2AirValue = 10,
                                T3AirValue = 25,
                                T1NavalValue = 4,
                                T2NavalValue = 16,
                                T3NavalValue = 30,
                            }
                        elseif self.Brain.BrainIntel.ActiveExpansion and self.Brain.BrainIntel.ActiveExpansion == baseName then
                            manager.BaseSettings.MassToFactoryValues = {
                                T1LandValue = 4,
                                T2LandValue = 10,
                                T3LandValue = 23,
                                T1AirValue = 3.5,
                                T2AirValue = 10,
                                T3AirValue = 25,
                                T1NavalValue = 4,
                                T2NavalValue = 16,
                                T3NavalValue = 30,
                            }
                        elseif manager.Layer == 'Water' then
                            manager.BaseSettings.MassToFactoryValues = {
                                T1LandValue = 7,
                                T2LandValue = 25,
                                T3LandValue = 45,
                                T1AirValue = 7,
                                T2AirValue = 25,
                                T3AirValue = 45,
                                T1NavalValue = 5,
                                T2NavalValue = 24,
                                T3NavalValue = 45,
                            }
                        else
                            manager.BaseSettings.MassToFactoryValues = {
                                T1LandValue = 4.5,
                                T2LandValue = 14,
                                T3LandValue = 22.5,
                                T1AirValue = 4.5,
                                T2AirValue = 14,
                                T3AirValue = 22.5,
                                T1NavalValue = 5,
                                T2NavalValue = 15,
                                T3NavalValue = 22.5,
                            }
                        end
                    else
                        LOG('AI: No MassToFactoryValues table for base '..tostring(baseName)..' are we still waiting for the base to initialize?')
                    end
                end
            end
            self.Factories.LAND[1].UpgradingCount = FactoryData.T1LANDUpgrading
            self.Factories.LAND[1].Total = FactoryData.TotalT1LAND
            self.Factories.LAND[2].UpgradingCount = FactoryData.T2LANDUpgrading
            self.Factories.LAND[2].Total = FactoryData.TotalT2LAND
            self.Factories.LAND[2].HQCount = FactoryData.T2LANDHQCount
            self.Factories.LAND[3].HQCount = FactoryData.T3LANDHQCount
            self.Factories.LAND[3].Total = FactoryData.TotalT3LAND
            self.Factories.AIR[1].UpgradingCount = FactoryData.T1AIRUpgrading
            self.Factories.AIR[1].Total = FactoryData.TotalT1AIR
            self.Factories.AIR[2].UpgradingCount = FactoryData.T2AIRUpgrading
            self.Factories.AIR[2].Total = FactoryData.TotalT2AIR
            self.Factories.AIR[2].HQCount = FactoryData.T2AIRHQCount
            self.Factories.AIR[3].HQCount = FactoryData.T3AIRHQCount
            self.Factories.AIR[3].Total = FactoryData.TotalT3AIR
            self.Factories.NAVAL[1].UpgradingCount = FactoryData.T1NAVALUpgrading
            self.Factories.NAVAL[1].Total = FactoryData.TotalT1NAVAL
            self.Factories.NAVAL[2].UpgradingCount = FactoryData.T2NAVALUpgrading
            self.Factories.NAVAL[2].Total = FactoryData.TotalT2NAVAL
            self.Factories.NAVAL[2].HQCount = FactoryData.T2NAVALHQCount
            self.Factories.NAVAL[3].HQCount = FactoryData.T3NAVALHQCount
            self.Factories.NAVAL[3].Total = FactoryData.TotalT3NAVAL
            self.LabelMassDrain = labelMassDrain
            local totalLandApproxConsumption = FactoryData.T1LANDApproxConsumption + FactoryData.T2LANDApproxConsumption + FactoryData.T3LANDApproxConsumption
            local totalAirApproxConsumption = FactoryData.T1AIRApproxConsumption + FactoryData.T2AIRApproxConsumption + FactoryData.T3AIRApproxConsumption
            local totalNavalApproxConsumption = FactoryData.T1NAVALApproxConsumption + FactoryData.T2NAVALApproxConsumption + FactoryData.T3NAVALApproxConsumption
            self.Brain.EcoManager.ApproxLandFactoryMassConsumption = totalLandApproxConsumption
            self.Brain.EcoManager.ApproxAirFactoryMassConsumption = totalAirApproxConsumption
            self.Brain.EcoManager.ApproxNavalFactoryMassConsumption = totalNavalApproxConsumption
            self.Brain.EcoManager.ApproxFactoryMassConsumption = totalLandApproxConsumption + totalAirApproxConsumption + totalNavalApproxConsumption
            if self.Brain.BrainIntel.PlayerStrategy.T3AirRush and FactoryData.TotalT3AIR > 0 then
                self.Brain.BrainIntel.PlayerStrategy.T3AirRush = false
            end
            if teamReference > 1 then
                local airPhase = GetFactoryPhase(self.Brain.Nickname, self.Factories.AIR)
                local landPhase = GetFactoryPhase(self.Brain.Nickname, self.Factories.LAND)
                local navalPhase = GetFactoryPhase(self.Brain.Nickname, self.Factories.NAVAL)
                local currentAir = RNGAIGLOBALS.HighestTeamAirPhase[teamReference] or 1
                local currentLand = RNGAIGLOBALS.HighestTeamLandPhase[teamReference] or 1
                local currentNaval = RNGAIGLOBALS.HighestTeamNavalPhase[teamReference] or 1
                RNGAIGLOBALS.HighestTeamAirPhase[teamReference] = math.max(currentAir, airPhase)
                RNGAIGLOBALS.HighestTeamLandPhase[teamReference] = math.max(currentLand, landPhase)
                RNGAIGLOBALS.HighestTeamNavalPhase[teamReference] = math.max(currentNaval, navalPhase)
            end
            --LOG('Structure Manager')
            --LOG('Number of upgrading T1 Land '..self.Factories.LAND[1].UpgradingCount)
            --LOG('Number of upgrading T2 Land '..self.Factories.LAND[2].UpgradingCount)
            --LOG('Number of HQs T2 Land '..repr(self.Factories.LAND[2].HQCount))
            --LOG('Number of HQs T3 Land '..repr(self.Factories.LAND[3].HQCount))
            --LOG('Number of upgrading T1 Air '..self.Factories.AIR[1].UpgradingCount)
            --LOG('Number of upgrading T2 Air '..self.Factories.AIR[2].UpgradingCount)
            --LOG('Number of HQs T2 Air '..repr(self.Factories.AIR[2].HQCount))
            --LOG('Number of HQs T3 Air '..repr(self.Factories.AIR[3].HQCount))
            --LOG('Number of upgrading T1 NAVAL '..self.Factories.NAVAL[1].UpgradingCount)
            --LOG('Number of upgrading T2 NAVAL '..self.Factories.NAVAL[2].UpgradingCount)
            --LOG('Number of HQs T2 Naval '..repr(self.Factories.NAVAL[2].HQCount))
            --LOG('Number of HQs T3 Naval '..repr(self.Factories.NAVAL[3].HQCount))
            self:ValidateFactoryUpgradeRNG()
            coroutine.yield(30)
        end
    end,

    GetClosestFactory = function(self, base, type, tech, hqFlag)

        if base == 'ANY' then
            local unitPos
            local DistanceToBase
            local LowestDistanceToBase
            local lowestUnit
            for k, v in self.Brain.BuilderManagers do
                if v.Layer ~= 'Water' and k ~= 'FLOATING' and k ~= 'MAIN' then
                    local basePosition = self.Brain.BuilderManagers[k].Position
                    local factoryList = self.Brain.BuilderManagers[k].FactoryManager.FactoryList
                    if factoryList then
                        for _, fact in factoryList do
                            if fact and not fact.Dead and fact.Blueprint.CategoriesHash[type] and fact.Blueprint.CategoriesHash[tech] then
                                if hqFlag then
                                    if not fact.Blueprint.CategoriesHash.SUPPORTFACTORY then
                                        if not fact:IsUnitState('Upgrading') then
                                            unitPos = fact:GetPosition()
                                            DistanceToBase = VDist2Sq(basePosition[1] or 0, basePosition[3] or 0, unitPos[1] or 0, unitPos[3] or 0)
                                            if not LowestDistanceToBase or DistanceToBase < LowestDistanceToBase then
                                                LowestDistanceToBase = DistanceToBase
                                                lowestUnit = fact
                                                --RNGLOG('Lowest Distance Factory added')
                                            end
                                        end
                                    end
                                else
                                    if not fact:IsUnitState('Upgrading') then
                                        unitPos = fact:GetPosition()
                                        DistanceToBase = VDist2Sq(basePosition[1] or 0, basePosition[3] or 0, unitPos[1] or 0, unitPos[3] or 0)
                                        if not LowestDistanceToBase or DistanceToBase < LowestDistanceToBase then
                                            LowestDistanceToBase = DistanceToBase
                                            lowestUnit = fact
                                            --RNGLOG('Lowest Distance Factory added')
                                        end
                                    end
                                end
                            end
                        end
                    else
                        WARN('No factory list found during factory upgrade cycle '..base)
                    end
                    if lowestUnit then
                        return lowestUnit
                    end
                    return false
                end
            end
        end

        if base == 'NAVAL' then
            --RNGLOG('Naval upgrade wanted, finding closest base')
            local closestBase = false
            local closestDistance = 0
            for k, v in self.Brain.BuilderManagers do
                if v.Layer == 'Water' then
                    --RNGLOG('Found Water manager')
                    local baseDistance = VDist3Sq(v.Position, self.Brain.BuilderManagers['MAIN'].Position)
                    if not closestBase or baseDistance < closestDistance then
                        local factoryList = v.FactoryManager.FactoryList
                        if factoryList then
                            for _, b in factoryList do
                                if b.Blueprint.CategoriesHash[type] and b.Blueprint.CategoriesHash[tech] then
                                    if hqFlag then
                                        if not b.Blueprint.CategoriesHash.SUPPORTFACTORY then
                                            --RNGLOG('Found correct tech factory manager')
                                            --RNGLOG('This should upgrade now')
                                            closestBase = v
                                            closestDistance = baseDistance
                                            base = k
                                            break
                                        end
                                    else
                                        --RNGLOG('Found correct tech factory manager')
                                        --RNGLOG('This should upgrade now')
                                        closestBase = v
                                        closestDistance = baseDistance
                                        base = k
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        local basePosition = self.Brain.BuilderManagers[base].Position
        local factoryList = self.Brain.BuilderManagers[base].FactoryManager.FactoryList
        local unitPos
        local DistanceToBase
        local LowestDistanceToBase
        local lowestUnit
        if factoryList then
            for _, fact in factoryList do
                if fact and not fact.Dead and fact.Blueprint.CategoriesHash[type] and fact.Blueprint.CategoriesHash[tech] then
                    if hqFlag then
                        if not fact.Blueprint.CategoriesHash.SUPPORTFACTORY then
                            if not fact:IsUnitState('Upgrading') then
                                unitPos = fact:GetPosition()
                                DistanceToBase = VDist2Sq(basePosition[1] or 0, basePosition[3] or 0, unitPos[1] or 0, unitPos[3] or 0)
                                if not LowestDistanceToBase or DistanceToBase < LowestDistanceToBase then
                                    LowestDistanceToBase = DistanceToBase
                                    lowestUnit = fact
                                    --RNGLOG('Lowest Distance Factory added')
                                end
                            end
                        end
                    else
                        if not fact:IsUnitState('Upgrading') then
                            unitPos = fact:GetPosition()
                            DistanceToBase = VDist2Sq(basePosition[1] or 0, basePosition[3] or 0, unitPos[1] or 0, unitPos[3] or 0)
                            if not LowestDistanceToBase or DistanceToBase < LowestDistanceToBase then
                                LowestDistanceToBase = DistanceToBase
                                lowestUnit = fact
                                --RNGLOG('Lowest Distance Factory added')
                            end
                        end
                    end
                end
            end
        else
            WARN('No factory list found during factory upgrade cycle '..base)
        end
        if lowestUnit then
            return lowestUnit
        end
        return false
    end,

    ValidateFactoryUpgradeRNG = function(self)
        local totalLandT2HQCount = 0
        local totalLandT3HQCount = 0
        local totalAirT2HQCount = 0
        local totalAirT3HQCount = 0
        local totalNavalT2HQCount = 0
        local totalNavalT3HQCount = 0
        local factionIndex = self.Brain:GetFactionIndex()
        local multiplier = self.Brain.EcoManager.EcoMultiplier
        local activeExpansion = false
        for _, v in self.Factories.LAND[2].HQCount do
            totalLandT2HQCount = totalLandT2HQCount + v
        end
        for _, v in self.Factories.LAND[3].HQCount do
            totalLandT3HQCount = totalLandT3HQCount + v
        end
        for _, v in self.Factories.AIR[2].HQCount do
            totalAirT2HQCount = totalAirT2HQCount + v
        end
        for _, v in self.Factories.AIR[3].HQCount do
            totalAirT3HQCount = totalAirT3HQCount + v
        end
        for _, v in self.Factories.NAVAL[2].HQCount do
            totalNavalT2HQCount = totalNavalT2HQCount + v
        end
        for _, v in self.Factories.NAVAL[3].HQCount do
            totalNavalT3HQCount = totalNavalT3HQCount + v
        end
        local aiBrain = self.Brain
        local teamReference = aiBrain.TeamReference

        -- HQ Upgrades
        local mexSpend = aiBrain.EcoManager.TotalMexSpend or 0
        local actualMexIncome = aiBrain.cmanager.income.r.m - mexSpend
        local massEfficiencyOverTime = aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime
        local energyEfficiencyOverTime = aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime
        local disableForT3AirRushStrategy = aiBrain.BrainIntel.PlayerStrategy.T3AirRush
        local maxMainSupportLandUpgrades = 2
        local mainFmgr = aiBrain.BuilderManagers['MAIN'].FactoryManager
        local mainZoneThreatAssignment = mainFmgr and mainFmgr.ZoneThreatAssignment or 0
        if mainZoneThreatAssignment > 150 then
            maxMainSupportLandUpgrades = 1
        elseif mainZoneThreatAssignment > 50 then
            maxMainSupportLandUpgrades = 2
        end
        --RNGLOG('Actual Mex Income '..actualMexIncome)
        --LOG('Highest Team phase is '..tostring(RNGAIGLOBALS.HighestTeamAirPhase[teamReference]))
        local avgSat = math.max(math.min(aiBrain.BrainIntel.AverageSaturation or 1.0, 1.0), 0.0)
        local rawGravity = aiBrain.BrainIntel.GlobalEconomicGravity or 0

        local t2LandPass = false
        if totalLandT2HQCount < 1 and totalLandT3HQCount < 1 and self.Factories.LAND[1].UpgradingCount < 1 and self.Factories.LAND[1].Total > 0 and not disableForT3AirRushStrategy then
            if aiBrain:GetCurrentUnits(categories.ENGINEER * categories.TECH1) > 2 then
                -- TUNING 1: The divisor (10) determines how aggressively gravity raises the ceiling.
                -- TUNING 2: The clamp max (33) sets the absolute highest mass income requirement possible.
                local baseCeiling = math.max(18, math.min(18 + (rawGravity / 10), 28))
                local scaledIncomeTarget = baseCeiling + (1.0 - avgSat) * (28 - baseCeiling)
                local distanceByPass = (aiBrain.EnemyIntel.ClosestEnemyBase and aiBrain.EnemyIntel.ClosestEnemyBase > 422500 ) and actualMexIncome >= (15 * multiplier) and aiBrain.EconomyOverTimeCurrent.EnergyIncome > 26.0
                if (not aiBrain.RNGEXP and (actualMexIncome > (scaledIncomeTarget * multiplier) or aiBrain.EnemyIntel.EnemyCount > 1 and actualMexIncome > (15 * multiplier)))
                or aiBrain.RNGEXP and (actualMexIncome > (18 * multiplier) or aiBrain.EnemyIntel.EnemyCount > 1 and actualMexIncome > (15 * multiplier)) and aiBrain.EconomyOverTimeCurrent.EnergyIncome > 26.0 
                or aiBrain.EnemyIntel.LandPhase > 1 and actualMexIncome > (12 * multiplier) and aiBrain.EconomyOverTimeCurrent.EnergyIncome > 26.0 
                or distanceByPass then
                    if (distanceByPass or (massEfficiencyOverTime >= 1.015 or GetEconomyStored(aiBrain, 'MASS') >= 250 or self.EnemyIntel.LandPhase > 1 and massEfficiencyOverTime >= 0.7 )) 
                    and (energyEfficiencyOverTime >= 0.8 or aiBrain.EnemyIntel.LandPhase > 1 and energyEfficiencyOverTime >= 0.6) then
                        local EnergyEfficiency = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
                        local MassEfficiency = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
                        if (distanceByPass or MassEfficiency >= 1.015 or aiBrain.EnemyIntel.LandPhase > 1 and MassEfficiency >= 0.7) and (EnergyEfficiency >= 0.8 or ((distanceByPass or aiBrain.EnemyIntel.LandPhase > 1) and EnergyEfficiency >= 0.6)) then
                            local factoryToUpgrade = self:GetClosestFactory('MAIN', 'LAND', 'TECH1')
                            if factoryToUpgrade and not factoryToUpgrade.Dead then
                                self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade, 'LAND')
                                t2LandPass = true
                                coroutine.yield(20)
                            end
                        end
                    end
                end
            end
        end
        if not t2LandPass and totalLandT2HQCount < 1 and totalLandT3HQCount < 1 and self.Factories.LAND[1].UpgradingCount < 1 and self.Factories.LAND[1].Total > 0 then
            if aiBrain:GetCurrentUnits(categories.ENGINEER * categories.TECH1) > 2 then
                if GetEconomyStored(aiBrain, 'MASS') >= 920 and (GetEconomyStored(aiBrain, 'ENERGY') >= 2990 or energyEfficiencyOverTime >= 0.8) then
                    --RNGLOG('Factory T2 Upgrade HQ Excess Check passed')
                    local factoryToUpgrade = self:GetClosestFactory('MAIN', 'LAND', 'TECH1')
                    if factoryToUpgrade and not factoryToUpgrade.Dead then
                        --RNGLOG('Structure Manager Triggering T2 Land HQ Upgrade')
                        self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade, 'LAND')
                        t2LandPass = true
                        coroutine.yield(20)
                    end
                end
            end
        end
        local t2AirPass = false
        if (not aiBrain.RNGEXP) and totalAirT2HQCount < 1 and totalAirT3HQCount < 1 and self.Factories.AIR[1].UpgradingCount < 1 and self.Factories.AIR[1].Total > 0 then
            --RNGLOG('Factory T1 Air Upgrade HQ Check passed')
            if self.Factories.LAND[2].Total > 0 then
                if massEfficiencyOverTime >= 1.025 and energyEfficiencyOverTime >= 1.05 then
                    local EnergyEfficiency = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
                    local MassEfficiency = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
                    if MassEfficiency >= 1.025 and EnergyEfficiency >= 1.0 then
                        local factoryToUpgrade = self:GetClosestFactory('MAIN', 'AIR', 'TECH1')
                        if factoryToUpgrade and not factoryToUpgrade.Dead then
                            --RNGLOG('Structure Manager Triggering T2 Air HQ Upgrade')
                            self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade, 'AIR')
                            t2AirPass = true
                            coroutine.yield(20)
                        end
                    end
                end
            end
        end
        local t2AirRush = (aiBrain.amanager.Demand.Air.T2.torpedo > 0 or aiBrain.RNGEXP or aiBrain.BrainIntel.PlayerRole.AirPlayer or (factionIndex == 2 and actualMexIncome > (25 * multiplier)) or ((teamReference and RNGAIGLOBALS.HighestTeamAirPhase[teamReference] < 1.5 or not teamReference and aiBrain.BrainIntel.AirPhase < 1.5) and aiBrain.EnemyIntel.AirPhase > 1))
        --LOG('AI '..tostring(aiBrain.Nickname))
        --LOG('Is t2 AirRush true?'..tostring(t2AirRush))
        if t2AirRush and totalAirT2HQCount < 1 and totalAirT3HQCount < 1 and self.Factories.AIR[1].UpgradingCount < 1 then
            local navalRiskOverride = false
            local hasNavalProduction = self.Factories.NAVAL[1].Total > 0 or self.Factories.NAVAL[2].Total > 0 or self.Factories.NAVAL[3].Total > 0
            if not hasNavalProduction and aiBrain.amanager.Demand.Air.T2.torpedo > 0 then
                navalRiskOverride = true
            end
            --LOG('Air Player T2 factory upgrade checking if massEfficiencyOverTime '..tostring(massEfficiencyOverTime)..' energyEfficiencyOverTime '..tostring(energyEfficiencyOverTime))
            if aiBrain:GetCurrentUnits(categories.ENGINEER * categories.TECH1) > 2 then
                if aiBrain.EconomyOverTimeCurrent.EnergyIncome > 32.0 and (massEfficiencyOverTime >= 0.8 or (navalRiskOverride and massEfficiencyOverTime >= 0.6)) and (t2AirRush and energyEfficiencyOverTime >= 0.85 or energyEfficiencyOverTime >= 1.05) then
                    --LOG('Factory Upgrade efficiency over time check passed for air upgrade')
                    local EnergyEfficiency = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
                    local MassEfficiency = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
                    --LOG('Air Player first factory upgrade checking if massEfficiency '..tostring(MassEfficiency)..' energyEfficiency '..tostring(EnergyEfficiency))
                    if (MassEfficiency >= 0.8 or (navalRiskOverride and MassEfficiency >= 0.6)) and (t2AirRush and EnergyEfficiency >= 0.85 or EnergyEfficiency >= 1.05)  then
                        local factoryToUpgrade = self:GetClosestFactory('MAIN', 'AIR', 'TECH1')
                        if factoryToUpgrade and not factoryToUpgrade.Dead then
                            self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade, 'AIR')
                            t2AirPass = true
                            coroutine.yield(20)
                        end
                    end
                end
            end
        end
        if not t2LandPass and (totalLandT2HQCount > 0 or totalLandT3HQCount > 0) and self.Factories.LAND[1].Total > 0 and self.Factories.LAND[2].Total < 11 then
            --RNGLOG('Factory T1 Upgrade Support Check passed')
            --LOG('RNGAI_UPGRADE_AUDIT | Base: MAIN | Upgrading: '..self.Factories['LAND'][1].UpgradingCount..' | Threat: '..(self.Brain.BuilderManagers['MAIN'].FactoryManager.ZoneThreatAssignment or 0))
            if self.Factories.LAND[1].UpgradingCount < 1 then
                --RNGLOG('Factory T1 Upgrade Less than 1 Factory Upgrading')
                if actualMexIncome > (23 * multiplier) and aiBrain.EconomyOverTimeCurrent.MassTrendOverTime >= 0.0 and aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime >= 0.0 then
                    if massEfficiencyOverTime >= 0.95 and energyEfficiencyOverTime >= 1.0 then
                        --RNGLOG('Factory Upgrade efficiency over time check passed')
                        local EnergyEfficiency = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
                        local MassEfficiency = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
                        if MassEfficiency >= 0.95 and EnergyEfficiency >= 1.0 then
                            --RNGLOG('Factory Upgrade efficiency check passed, get closest factory')
                            local factoryToUpgrade = self:GetClosestFactory('MAIN', 'LAND', 'TECH1')
                            if not factoryToUpgrade then
                                factoryToUpgrade = self:GetClosestFactory('ANY', 'LAND', 'TECH1')
                            end
                            if factoryToUpgrade and not factoryToUpgrade.Dead then
                                --RNGLOG('Structure Manager Triggering T2 Land Support Upgrade')
                                self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade)
                                t2LandPass = true
                                coroutine.yield(20)
                            end
                        end
                    end
                end
            end
            if self.Factories.LAND[1].UpgradingCount < maxMainSupportLandUpgrades then
                --RNGLOG('Factory T1 Upgrade Less than 2 Factory Upgrading')
                if GetEconomyStored(aiBrain, 'MASS') >= 1300 and GetEconomyStored(aiBrain, 'ENERGY') >= 3990 then
                    local factoryToUpgrade = self:GetClosestFactory('MAIN', 'LAND', 'TECH1')
                    if factoryToUpgrade and not factoryToUpgrade.Dead then
                        --RNGLOG('Structure Manager Triggering T2 Land HQ Upgrade')
                        self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade)
                        t2LandPass = true
                        coroutine.yield(20)
                    end
                end
            end
        end
        if not t2AirPass and (totalAirT2HQCount > 0 or totalAirT3HQCount > 0) and self.Factories.AIR[1].Total > 0 and self.Factories.AIR[2].Total < 8 then
            --RNGLOG('Factory Air T2 Upgrade Support Check passed')
            if self.Factories.AIR[2].UpgradingCount < 1 then
                --RNGLOG('Factory Air T2 Upgrade Less than 1 Factory Upgrading')
                if aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime >= 0.0 then
                    if massEfficiencyOverTime >= 0.95 and energyEfficiencyOverTime >= 1.1 then
                        --RNGLOG('Factory Upgrade efficiency over time check passed')
                        local EnergyEfficiency = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
                        local MassEfficiency = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
                        if MassEfficiency >= 0.95 and EnergyEfficiency >= 1.1 then
                            --RNGLOG('Factory Upgrade efficiency check passed, get closest factory')
                            local factoryToUpgrade = self:GetClosestFactory('MAIN', 'AIR', 'TECH1')
                            if not factoryToUpgrade then
                                factoryToUpgrade = self:GetClosestFactory('ANY', 'AIR', 'TECH1')
                            end
                            if factoryToUpgrade and not factoryToUpgrade.Dead then
                                --RNGLOG('Structure Manager Triggering T2 Air Support Upgrade')
                                self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade)
                                t2AirPass = true
                                coroutine.yield(20)
                            end
                        end
                    end
                end
            end
        end
        local t3LandPass = false
        if totalLandT3HQCount < 1 and totalLandT2HQCount > 0 and self.Factories.LAND[2].UpgradingCount < 1 and self.Factories.LAND[2].Total > 0 then
            if aiBrain:GetCurrentUnits(categories.ENGINEER * categories.TECH2) > 2 then
                if (actualMexIncome > (50 * multiplier) or aiBrain.EnemyIntel.EnemyCount > 1 and actualMexIncome > (35 * multiplier) or aiBrain.EnemyIntel.LandPhase > 2 and actualMexIncome > (26 * multiplier)) and aiBrain.EconomyOverTimeCurrent.EnergyIncome > 100.0 then
                    --RNGLOG('Factory Upgrade actual mex income passed '..actualMexIncome)
                    if (massEfficiencyOverTime >= 1.015 or aiBrain.EnemyIntel.LandPhase > 2 and massEfficiencyOverTime >= 0.7) and (energyEfficiencyOverTime >= 1.0 or self.EnemyIntel.LandPhase > 2 and energyEfficiencyOverTime >= 0.6) then
                        --RNGLOG('Factory Upgrade efficiency over time check passed')
                        local EnergyEfficiency = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
                        local MassEfficiency = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
                        if (MassEfficiency >= 1.0 or ( aiBrain.BrainIntel.LandPhase > 2 and MassEfficiency >= 0.7 )) and (EnergyEfficiency >= 1.0 or self.EnemyIntel.LandPhase > 2 and EnergyEfficiency >= 0.6) then
                            --RNGLOG('Factory Upgrade efficiency check passed, get closest factory')
                            local factoryToUpgrade = self:GetClosestFactory('MAIN', 'LAND', 'TECH2', true)
                            if factoryToUpgrade and not factoryToUpgrade.Dead then
                                --RNGLOG('Structure Manager Triggering T3 Land HQ Upgrade')
                                self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade, 'LAND')
                                t3LandPass = true
                                coroutine.yield(20)
                            end
                        end
                    end
                end
            end
        end
        if not t3LandPass and totalLandT3HQCount < 1 and totalLandT2HQCount > 0 and self.Factories.LAND[2].UpgradingCount < 1 and self.Factories.LAND[2].Total > 0 then
            if aiBrain:GetCurrentUnits(categories.ENGINEER * categories.TECH2) > 2 then
                if GetEconomyStored(aiBrain, 'MASS') >= 1800 and GetEconomyStored(aiBrain, 'ENERGY') >= 9000 then
                    --RNGLOG('Factory T2 HQ Upgrade Excess Storage Check Passed')
                    local factoryToUpgrade = self:GetClosestFactory('MAIN', 'LAND', 'TECH2', true)
                    if factoryToUpgrade and not factoryToUpgrade.Dead then
                        --RNGLOG('Structure Manager Triggering T3 Land HQ Upgrade')
                        self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade, 'LAND')
                        t3LandPass = true
                        coroutine.yield(20)
                    end
                end
            end
        end
        local t3AirPass = false
        if (not aiBrain.RNGEXP) and totalAirT3HQCount < 1 and totalAirT2HQCount > 0 and self.Factories.AIR[2].UpgradingCount < 1 and self.Factories.AIR[2].Total > 0 then
            --RNGLOG('Factory T2 Air Upgrade HQ Check passed')
            if aiBrain.EconomyOverTimeCurrent.MassIncome > (5.0 * multiplier) and aiBrain.EconomyOverTimeCurrent.EnergyIncome > 150.0 then
                --RNGLOG('Factory Upgrade Income Over time check passed')
                if GetEconomyIncome(aiBrain,'MASS') >= (5.0 * multiplier) and GetEconomyIncome(aiBrain,'ENERGY') >= 150.0 then
                    --RNGLOG('Factory Upgrade Income check passed')
                    if massEfficiencyOverTime>= 1.015 and energyEfficiencyOverTime >= 1.0 then
                        --RNGLOG('Factory Upgrade efficiency over time check passed')
                        local EnergyEfficiency = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
                        local MassEfficiency = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
                        if MassEfficiency >= 1.015 and EnergyEfficiency >= 1.00 then
                            --RNGLOG('Factory Upgrade efficiency check passed, get closest factory')
                            local factoryToUpgrade = self:GetClosestFactory('MAIN', 'AIR', 'TECH2', true)
                            if factoryToUpgrade and not factoryToUpgrade.Dead then
                                --RNGLOG('Structure Manager Triggering T3 Air HQ Upgrade')
                                self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade, 'AIR')
                                t3AirPass = true
                                coroutine.yield(20)
                            end
                        end
                    end
                end
            end
        end
        local t3AirRush = aiBrain.BrainIntel.PlayerRole.AirPlayer or ((teamReference and RNGAIGLOBALS.HighestTeamAirPhase[teamReference] < 2.5 or not teamReference and aiBrain.BrainIntel.AirPhase < 2.5) and aiBrain.EnemyIntel.AirPhase > 2)
        if not t3AirPass and t3AirRush and totalAirT3HQCount < 1 and totalAirT2HQCount > 0 and self.Factories.AIR[2].UpgradingCount < 1 and self.Factories.AIR[2].Total > 0 then
            --LOG('Air Player T3 factory upgrade checking if massEfficiencyOverTime '..tostring(massEfficiencyOverTime)..' energyEfficiencyOverTime '..tostring(energyEfficiencyOverTime))
            if aiBrain.EconomyOverTimeCurrent.MassIncome > (2.5 * multiplier) and aiBrain.EconomyOverTimeCurrent.EnergyIncome > 100.0 then
                --RNGLOG('Factory Upgrade Income Over time check passed')
                if GetEconomyIncome(aiBrain,'MASS') >= (2.5 * multiplier) and GetEconomyIncome(aiBrain,'ENERGY') >= 100.0 then
                    --RNGLOG('Factory Upgrade Income check passed')
                    if massEfficiencyOverTime >= 0.9 and energyEfficiencyOverTime >= 0.9 then
                        --RNGLOG('Factory Upgrade efficiency over time check passed')
                        local EnergyEfficiency = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
                        local MassEfficiency = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
                        if MassEfficiency >= 0.9 and EnergyEfficiency >= 0.9 then
                            --RNGLOG('Factory Upgrade efficiency check passed, get closest factory')
                            local factoryToUpgrade = self:GetClosestFactory('MAIN', 'AIR', 'TECH2', true)
                            if factoryToUpgrade and not factoryToUpgrade.Dead then
                                --RNGLOG('Structure Manager Triggering T3 Air HQ Upgrade')
                                self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade, 'AIR')
                                t3AirPass = true
                                coroutine.yield(20)
                            end
                        end
                    end
                end
            end
        end
        if not t3AirPass and totalAirT3HQCount < 1 and totalAirT2HQCount > 0 and self.Factories.AIR[2].UpgradingCount < 1 and self.Factories.AIR[2].Total > 0 then
            --RNGLOG('Factory T2 Upgrade HQ Check passed')
            if GetGameTimeSeconds() > (600 / multiplier) then
                if GetEconomyStored(aiBrain, 'MASS') >= 1800 and GetEconomyStored(aiBrain, 'ENERGY') >= 14000 then
                    --RNGLOG('Factory T2 HQ Upgrade Excess Storage Check Passed')
                    local factoryToUpgrade = self:GetClosestFactory('MAIN', 'AIR', 'TECH2', true)
                    if factoryToUpgrade and not factoryToUpgrade.Dead then
                        --RNGLOG('Structure Manager Triggering T3 Air HQ Upgrade')
                        self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade, 'AIR')
                        t3AirPass = true
                        coroutine.yield(20)
                    end
                end
            end
        end
        if not t3LandPass and totalLandT3HQCount > 0 and self.Factories.LAND[2].Total > 0 and self.Factories.LAND[3].Total < 11 then
            --RNGLOG('Factory T2 Upgrade Support Check passed')
            if self.Factories.LAND[2].UpgradingCount < 1 then
                --RNGLOG('Factory T2 Upgrade Less than 1 Factory Upgrading')
                if actualMexIncome > (50 * multiplier) and aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime >= 0.0 then
                    if massEfficiencyOverTime >= 1.0 and energyEfficiencyOverTime >= 1.0 then
                        --RNGLOG('Factory Upgrade efficiency over time check passed')
                        local EnergyEfficiency = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
                        local MassEfficiency = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
                        if MassEfficiency >= 1.0 and EnergyEfficiency >= 1.0 then
                            --RNGLOG('Factory Upgrade efficiency check passed, get closest factory')
                            local factoryToUpgrade = self:GetClosestFactory('MAIN', 'LAND', 'TECH2')
                            if not factoryToUpgrade then
                                factoryToUpgrade = self:GetClosestFactory('ANY', 'LAND', 'TECH2')
                            end
                            if factoryToUpgrade and not factoryToUpgrade.Dead then
                                --RNGLOG('Structure Manager Triggering T3 Land Support Upgrade')
                                self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade)
                                t3LandPass = true
                                coroutine.yield(20)
                            end
                        end
                    end
                end
            end
            if self.Factories.LAND[2].UpgradingCount < 2 then
                if GetGameTimeSeconds() > (600 / multiplier) then
                    --RNGLOG('Factory T1 Upgrade Less than 2 Factory Upgrading')
                    if GetEconomyStored(aiBrain, 'MASS') >= 1800 and GetEconomyStored(aiBrain, 'ENERGY') >= 9000 then
                        local factoryToUpgrade = self:GetClosestFactory('MAIN', 'LAND', 'TECH2')
                        if factoryToUpgrade and not factoryToUpgrade.Dead then
                            --RNGLOG('Structure Manager Triggering T3 Land Support Upgrade')
                            self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade)
                            t3LandPass = true
                            coroutine.yield(20)
                        end
                    end
                end
            end
        end
        
        if not t3AirPass and totalAirT3HQCount > 0 and self.Factories.AIR[2].Total > 0 and self.Factories.AIR[3].Total < 11 then
            --RNGLOG('Factory T2 Upgrade Support Check passed')
            if self.Factories.AIR[2].UpgradingCount < 1 then
                --RNGLOG('Factory T2 Upgrade Less than 1 Factory Upgrading')
                if aiBrain.EconomyOverTimeCurrent.MassTrendOverTime >= 0.0 and aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime >= 0.0 then
                    if massEfficiencyOverTime >= 1.05 and energyEfficiencyOverTime >= 1.2 then
                        --RNGLOG('Factory Upgrade efficiency over time check passed')
                        local EnergyEfficiency = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
                        local MassEfficiency = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
                        if MassEfficiency >= 1.05 and EnergyEfficiency >= 1.2 then
                            --RNGLOG('Factory Upgrade efficiency check passed, get closest factory')
                            local factoryToUpgrade = self:GetClosestFactory('MAIN', 'AIR', 'TECH2')
                            if not factoryToUpgrade then
                                factoryToUpgrade = self:GetClosestFactory('ANY', 'AIR', 'TECH2')
                            end
                            if factoryToUpgrade and not factoryToUpgrade.Dead then
                                --RNGLOG('Structure Manager Triggering T3 Air Support Upgrade')
                                self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade)
                                t3LandPass = true
                                coroutine.yield(20)
                            end
                        end
                    end
                end
            end
            if self.Factories.AIR[2].UpgradingCount < 2 then
                if GetGameTimeSeconds() > (600 / multiplier) then
                    --RNGLOG('Factory T1 Upgrade Less than 2 Factory Upgrading')
                    if GetEconomyStored(aiBrain, 'MASS') >= 1800 and GetEconomyStoredRatio(aiBrain, 'ENERGY') > 0.95 and energyEfficiencyOverTime >= 1.3 then
                        local factoryToUpgrade = self:GetClosestFactory('MAIN', 'AIR', 'TECH2')
                        if factoryToUpgrade and not factoryToUpgrade.Dead then
                            --RNGLOG('Structure Manager Triggering T3 Air Support Upgrade')
                            self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade)
                            t3AirPass = true
                            coroutine.yield(20)
                        end
                    end
                end
            end
        end
        local t2NavalPass = false
        if totalNavalT2HQCount < 1 and totalNavalT3HQCount < 1 and self.Factories.NAVAL[1].UpgradingCount < 1 and self.Factories.NAVAL[1].Total > 0 then
            if aiBrain:GetCurrentUnits(categories.ENGINEER * categories.TECH1) > 2 then
                if (actualMexIncome > (30 * multiplier) or (aiBrain.BrainIntel.PlayerRole.NavalPlayer or aiBrain.EnemyIntel.NavalPhase > 1) and actualMexIncome > (23 * multiplier)) and aiBrain.EconomyOverTimeCurrent.EnergyIncome > 50.0 then
                    if massEfficiencyOverTime >= 1.015 and energyEfficiencyOverTime >= 1.0 or aiBrain.EnemyIntel.NavalPhase > 1 and massEfficiencyOverTime >= 0.8 and energyEfficiencyOverTime >= 1.0 then
                        local EnergyEfficiency = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
                        local MassEfficiency = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
                        if MassEfficiency >= 1.015 and EnergyEfficiency >= 1.0 or (aiBrain.BrainIntel.PlayerRole.NavalPlayer or aiBrain.EnemyIntel.NavalPhase > 1) and MassEfficiency >= 0.8 and EnergyEfficiency >= 1.0 then
                            local factoryToUpgrade = self:GetClosestFactory('NAVAL', 'NAVAL', 'TECH1')
                            if factoryToUpgrade and not factoryToUpgrade.Dead then
                                self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade, 'NAVAL')
                                t2NavalPass = true
                                coroutine.yield(20)
                            end
                        end
                    end
                end
            end
        end
        if not t2NavalPass and (totalNavalT2HQCount > 0 or totalNavalT3HQCount > 0) and self.Factories.NAVAL[1].Total > 0 and self.Factories.NAVAL[2].Total < 4 then
            --RNGLOG('Factory T1 Upgrade Support Check passed')
            if self.Factories.NAVAL[1].UpgradingCount < 1 then
                --RNGLOG('Factory T1 Upgrade Less than 1 Factory Upgrading')
                if aiBrain.EconomyOverTimeCurrent.MassTrendOverTime >= 0.0 and aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime >= 0.0 then
                    if massEfficiencyOverTime >= 1.015 and energyEfficiencyOverTime >= 1.0 then
                        --RNGLOG('Factory Upgrade efficiency over time check passed')
                        local EnergyEfficiency = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
                        local MassEfficiency = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
                        if MassEfficiency >= 1.015 and EnergyEfficiency >= 1.0 then
                            --RNGLOG('Factory Upgrade efficiency check passed, get closest factory')
                            local factoryToUpgrade = self:GetClosestFactory('NAVAL', 'NAVAL', 'TECH1')
                            if factoryToUpgrade and not factoryToUpgrade.Dead then
                                --RNGLOG('Structure Manager Triggering T2 Land Support Upgrade')
                                self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade)
                                t2NavalPass = true
                                coroutine.yield(20)
                            end
                        end
                    end
                end
            end
            if self.Factories.NAVAL[1].UpgradingCount < 2 then
                --RNGLOG('Factory T1 Upgrade Less than 2 Factory Upgrading')
                if GetEconomyStored(aiBrain, 'MASS') >= 1300 and GetEconomyStored(aiBrain, 'ENERGY') >= 3990 then
                    local factoryToUpgrade = self:GetClosestFactory('NAVAL', 'NAVAL', 'TECH1')
                    if factoryToUpgrade and not factoryToUpgrade.Dead then
                        --RNGLOG('Structure Manager Triggering T2 Land HQ Upgrade')
                        self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade)
                        t2LandPass = true
                        coroutine.yield(20)
                    end
                end
            end
        end
        local t3NavalPass = false
        if totalNavalT3HQCount < 1 and totalNavalT2HQCount > 0 and self.Factories.NAVAL[2].UpgradingCount < 1 and self.Factories.NAVAL[2].Total > 1 then
            if aiBrain:GetCurrentUnits(categories.ENGINEER * categories.TECH2) > 2 then
                if (actualMexIncome > (80 * multiplier) or (aiBrain.BrainIntel.PlayerRole.NavalPlayer or aiBrain.EnemyIntel.NavalPhase > 2) and actualMexIncome > (60 * multiplier)) and aiBrain.EconomyOverTimeCurrent.EnergyIncome > 150.0 then
                    if massEfficiencyOverTime >= 1.025 and energyEfficiencyOverTime >= 1.05 or aiBrain.EnemyIntel.NavalPhase > 2 and massEfficiencyOverTime >= 0.8 and energyEfficiencyOverTime >= 1.0 then
                        local EnergyEfficiency = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
                        local MassEfficiency = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
                        if MassEfficiency >= 1.05 and EnergyEfficiency >= 1.05 or (aiBrain.BrainIntel.PlayerRole.NavalPlayer or aiBrain.EnemyIntel.NavalPhase > 2) and MassEfficiency >= 0.8 and EnergyEfficiency >= 1.0 then
                            local factoryToUpgrade = self:GetClosestFactory('NAVAL', 'NAVAL', 'TECH2', true)
                            if factoryToUpgrade and not factoryToUpgrade.Dead then
                                self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade, 'NAVAL')
                                t3NavalPass = true
                                coroutine.yield(20)
                            end
                        end
                    end
                end
            end
        end
        if not t3NavalPass and totalNavalT3HQCount > 0 and self.Factories.NAVAL[2].Total > 0 and self.Factories.NAVAL[3].Total < 2 then
            --RNGLOG('Factory T2 Upgrade Support Check passed')
            if self.Factories.NAVAL[2].UpgradingCount < 1 then
                --RNGLOG('Factory T2 Upgrade Less than 1 Factory Upgrading')
                if aiBrain.EconomyOverTimeCurrent.MassTrendOverTime >= 0.0 and aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime >= 0.0 then
                    if massEfficiencyOverTime >= 1.015 and energyEfficiencyOverTime >= 1.1 then
                        --RNGLOG('Factory Upgrade efficiency over time check passed')
                        local EnergyEfficiency = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
                        local MassEfficiency = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
                        if MassEfficiency >= 1.05 and EnergyEfficiency >= 1.1 then
                            --RNGLOG('Factory Upgrade efficiency check passed, get closest factory')
                            local factoryToUpgrade = self:GetClosestFactory('NAVAL', 'NAVAL', 'TECH2')
                            if factoryToUpgrade and not factoryToUpgrade.Dead then
                                --RNGLOG('Structure Manager Triggering T3 Air Support Upgrade')
                                self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade)
                                t3NavalPass = true
                                coroutine.yield(20)
                            end
                        end
                    end
                end
            end
            if self.Factories.NAVAL[2].UpgradingCount < 2 then
                if GetGameTimeSeconds() > (600 / multiplier) then
                    --RNGLOG('Factory T1 Upgrade Less than 2 Factory Upgrading')
                    if GetEconomyStored(aiBrain, 'MASS') >= 1800 and GetEconomyStoredRatio(aiBrain, 'ENERGY') > 0.95 and energyEfficiencyOverTime >= 1.2 then
                        local factoryToUpgrade = self:GetClosestFactory('NAVAL', 'NAVAL', 'TECH2')
                        if factoryToUpgrade and not factoryToUpgrade.Dead then
                            --RNGLOG('Structure Manager Triggering T3 Air Support Upgrade')
                            self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade)
                            t3NavalPass = true
                            coroutine.yield(20)
                        end
                    end
                end
            end
        end
        local expansionPass = false
        for _, v in aiBrain.BuilderManagers do
            if v.FactoryManager.LocationType == aiBrain.BrainIntel.ActiveExpansion and v.FactoryManager.LocationActive then
                --RNGLOG('ActiveExpansion during buildermanager loop is '..v.FactoryManager.LocationType)
                activeExpansion = v.FactoryManager.LocationType
                local mainZoneThreatAssignment = v.FactoryManager.ZoneThreatAssignment or 0
                local maxSupportLandUpgrades = 3
                if mainZoneThreatAssignment > 150 then
                    maxSupportLandUpgrades = 1
                elseif mainZoneThreatAssignment > 50 then
                    maxSupportLandUpgrades = 2
                end
                --RNGLOG('Active Expansion is '..activeExpansion)
                local activeExpansionPass = false
                if (totalLandT2HQCount > 0 or totalLandT3HQCount > 0) and self.Factories.LAND[1].Total > 0 and self.Factories.LAND[2].Total < 11 then
                    --RNGLOG('Factory T1 Upgrade Support Check passed')
                    --RNGLOG('Performing Upgrade Check '..activeExpansion)
                    --RNGLOG('T2 Factory count at active expansion '..self:LocationFactoryCountRNG(aiBrain, categories.LAND * categories.FACTORY * categories.TECH2, activeExpansion))
                    if self:LocationFactoryCountRNG(aiBrain, categories.LAND * categories.FACTORY * categories.TECH2, activeExpansion) < 2 then
                        --LOG('RNGAI_UPGRADE_AUDIT | Base: '..tostring(v.FactoryManager.LocationType)..' | Upgrading: '..self.Factories['LAND'][1].UpgradingCount..' | Threat: '..(v.FactoryManager.ZoneThreatAssignment or 0))
                        if self.Factories.LAND[1].UpgradingCount < 3 and v.FactoryManager.T1LANDUpgradingCount < maxSupportLandUpgrades then
                            --RNGLOG('Factory T1 Upgrade Less than 1 Factory Upgrading')
                            local t2Rush = false
                            if RUtils.DefensiveClusterCheck(aiBrain, v.FactoryManager.Location) then
                                --RNGLOG('DefensiveClusterCheck detected close to expansion')
                                t2Rush = true
                            end
                            if massEfficiencyOverTime >= 0.95 and energyEfficiencyOverTime >= 1.0 or t2Rush then
                                --RNGLOG('Factory Upgrade efficiency over time check passed')
                                local EnergyEfficiency = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
                                local MassEfficiency = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
                                if MassEfficiency >= 0.95 and EnergyEfficiency >= 1.0 or t2Rush then
                                    --RNGLOG('Factory Upgrade efficiency check passed, get closest factory')
                                    local factoryToUpgrade = self:GetClosestFactory(activeExpansion, 'LAND', 'TECH1')
                                    if factoryToUpgrade and not factoryToUpgrade.Dead then
                                        --RNGLOG('Structure Manager Triggering T2 Land Support Upgrade')
                                        self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade)
                                        activeExpansionPass = true
                                        coroutine.yield(20)
                                    end
                                end
                            end
                        end
                        if self.Factories.LAND[1].UpgradingCount < 3 and v.FactoryManager.T1LANDUpgradingCount < maxSupportLandUpgrades then
                            --RNGLOG('Factory T1 Upgrade Less than 2 Factory Upgrading')
                            if GetEconomyStored(aiBrain, 'MASS') >= 1300 and GetEconomyStored(aiBrain, 'ENERGY') >= 3990 then
                                local factoryToUpgrade = self:GetClosestFactory(activeExpansion, 'LAND', 'TECH1')
                                if factoryToUpgrade and not factoryToUpgrade.Dead then
                                    --RNGLOG('Structure Manager Triggering T2 Land HQ Upgrade')
                                    self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade)
                                    activeExpansionPass = true
                                    coroutine.yield(20)
                                end
                            end
                        end
                    end
                end
                if not activeExpansionPass and totalLandT3HQCount > 0 and self.Factories.LAND[2].Total > 0 then
                    if self:LocationFactoryCountRNG(aiBrain, categories.LAND * categories.FACTORY * categories.TECH2, activeExpansion) > 0 then
                        if self.Factories.LAND[2].UpgradingCount < 3 and v.FactoryManager.T2LANDUpgradingCount < maxSupportLandUpgrades then
                            --RNGLOG('Factory T1 Upgrade Less than 1 Factory Upgrading')
                            if massEfficiencyOverTime >= 1.0 and energyEfficiencyOverTime >= 1.0 then
                                --RNGLOG('Factory Upgrade efficiency over time check passed')
                                local EnergyEfficiency = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
                                local MassEfficiency = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
                                if MassEfficiency >= 1.0 and EnergyEfficiency >= 1.0 then
                                    --RNGLOG('Factory Upgrade efficiency check passed, get closest factory')
                                    local factoryToUpgrade = self:GetClosestFactory(activeExpansion, 'LAND', 'TECH2')
                                    if factoryToUpgrade and not factoryToUpgrade.Dead then
                                        --RNGLOG('Structure Manager Triggering T2 Land Support Upgrade')
                                        self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade)
                                        activeExpansionPass = true
                                        coroutine.yield(20)
                                    end
                                end
                            end
                        end
                        if self.Factories.LAND[2].UpgradingCount < 3 and v.FactoryManager.T2LANDUpgradingCount < maxSupportLandUpgrades then
                            --RNGLOG('Factory T1 Upgrade Less than 2 Factory Upgrading')
                            if GetEconomyStored(aiBrain, 'MASS') >= 1300 and GetEconomyStored(aiBrain, 'ENERGY') >= 3990 then
                                local factoryToUpgrade = self:GetClosestFactory(activeExpansion, 'LAND', 'TECH2')
                                if factoryToUpgrade and not factoryToUpgrade.Dead then
                                    --RNGLOG('Structure Manager Triggering T2 Land HQ Upgrade')
                                    self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade)
                                    activeExpansionPass = true
                                    coroutine.yield(20)
                                end
                            end
                        end
                    end
                end
            elseif v.FactoryManager.LocationType and v.FactoryManager.LocationActive then
                local locationType = v.FactoryManager.LocationType
                local mainZoneThreatAssignment = v.FactoryManager.ZoneThreatAssignment or 0
                local maxSupportLandUpgrades = 3
                if mainZoneThreatAssignment > 150 then
                    maxSupportLandUpgrades = 1
                elseif mainZoneThreatAssignment > 50 then
                    maxSupportLandUpgrades = 2
                end

                if not expansionPass then
                    if (totalLandT2HQCount > 0 or totalLandT3HQCount > 0) and self.Factories.LAND[1].Total > 0 and self.Factories.LAND[2].Total < 11 then
                        --RNGLOG('Factory T1 Upgrade Support Check passed')
                        --RNGLOG('Performing Upgrade Check '..activeExpansion)
                        --RNGLOG('T2 Factory count at active expansion '..self:LocationFactoryCountRNG(aiBrain, categories.LAND * categories.FACTORY * categories.TECH2, activeExpansion))
                        if self:LocationFactoryCountRNG(aiBrain, categories.LAND * categories.FACTORY * categories.TECH2, locationType) < 2 then
                            if self.Factories.LAND[1].UpgradingCount < 3 and v.FactoryManager.T1LANDUpgradingCount < maxSupportLandUpgrades then
                                --RNGLOG('Factory T1 Upgrade Less than 1 Factory Upgrading')
                                local t2Rush = false
                                if RUtils.DefensiveClusterCheck(aiBrain, v.FactoryManager.Location) then
                                    --RNGLOG('DefensiveClusterCheck detected close to expansion')
                                    t2Rush = true
                                end
                                if massEfficiencyOverTime >= 1.0 and energyEfficiencyOverTime >= 1.0 or t2Rush then
                                    --RNGLOG('Factory Upgrade efficiency over time check passed')
                                    local EnergyEfficiency = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
                                    local MassEfficiency = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
                                    if MassEfficiency >= 1.0 and EnergyEfficiency >= 1.0 or t2Rush then
                                        --RNGLOG('Factory Upgrade efficiency check passed, get closest factory')
                                        local factoryToUpgrade = self:GetClosestFactory(locationType, 'LAND', 'TECH1')
                                        if factoryToUpgrade and not factoryToUpgrade.Dead then
                                            --RNGLOG('Structure Manager Triggering T2 Land Support Upgrade')
                                            self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade)
                                            expansionPass = true
                                            coroutine.yield(20)
                                        end
                                    end
                                end
                            end
                            if self.Factories.LAND[1].UpgradingCount < 3 and v.FactoryManager.T1LANDUpgradingCount < maxSupportLandUpgrades then
                                --RNGLOG('Factory T1 Upgrade Less than 2 Factory Upgrading')
                                if GetEconomyStored(aiBrain, 'MASS') >= 1300 and GetEconomyStored(aiBrain, 'ENERGY') >= 3990 then
                                    local factoryToUpgrade = self:GetClosestFactory(locationType, 'LAND', 'TECH1')
                                    if factoryToUpgrade and not factoryToUpgrade.Dead then
                                        --RNGLOG('Structure Manager Triggering T2 Land HQ Upgrade')
                                        self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade)
                                        expansionPass = true
                                        coroutine.yield(20)
                                    end
                                end
                            end
                        end
                    end
                    if not expansionPass and totalLandT3HQCount > 0 and self.Factories.LAND[2].Total > 0 then
                        if self:LocationFactoryCountRNG(aiBrain, categories.LAND * categories.FACTORY * categories.TECH2, locationType) > 0 then
                            if self.Factories.LAND[2].UpgradingCount < 3 and v.FactoryManager.T2LANDUpgradingCount < maxSupportLandUpgrades then
                                --RNGLOG('Factory T1 Upgrade Less than 1 Factory Upgrading')
                                if massEfficiencyOverTime >= 1.0 and energyEfficiencyOverTime >= 1.0 then
                                    --RNGLOG('Factory Upgrade efficiency over time check passed')
                                    local EnergyEfficiency = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
                                    local MassEfficiency = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
                                    if MassEfficiency >= 1.0 and EnergyEfficiency >= 1.0 then
                                        --RNGLOG('Factory Upgrade efficiency check passed, get closest factory')
                                        local factoryToUpgrade = self:GetClosestFactory(locationType, 'LAND', 'TECH2')
                                        if factoryToUpgrade and not factoryToUpgrade.Dead then
                                            --RNGLOG('Structure Manager Triggering T2 Land Support Upgrade')
                                            self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade)
                                            expansionPass = true
                                            coroutine.yield(20)
                                        end
                                    end
                                end
                            end
                            if self.Factories.LAND[2].UpgradingCount < 3 and v.FactoryManager.T2LANDUpgradingCount < maxSupportLandUpgrades then
                                --RNGLOG('Factory T1 Upgrade Less than 2 Factory Upgrading')
                                if GetEconomyStored(aiBrain, 'MASS') >= 1300 and GetEconomyStored(aiBrain, 'ENERGY') >= 3990 then
                                    local factoryToUpgrade = self:GetClosestFactory(locationType, 'LAND', 'TECH2')
                                    if factoryToUpgrade and not factoryToUpgrade.Dead then
                                        --RNGLOG('Structure Manager Triggering T2 Land HQ Upgrade')
                                        self:ForkThread(self.UpgradeFactoryRNG, factoryToUpgrade)
                                        expansionPass = true
                                        coroutine.yield(20)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return false
    end,

    UpgradeFactoryRNG = function(self, unit, hq)
        --RNGLOG('UpgradeFactory Fork started')
        local ALLBPS = __blueprints
        local unitCat = unit.Blueprint.CategoriesHash
        local supportUpgradeID
        local followupUpgradeID = false
        --RNGLOG('Factory to upgrade unit id is '..unit.UnitId)
        local upgradeID = unit.Blueprint.General.UpgradesTo
        --RNGLOG('Upgrade ID for unit is '..unit.Blueprint.General.UpgradesTo)
        if upgradeID then
            if ALLBPS[upgradeID].General.UpgradesTo then
                followupUpgradeID = ALLBPS[upgradeID].General.UpgradesTo
            end
        end
        if not upgradeID then
            WARN('No upgrade ID in blueprint for factory upgrade, aborting upgrade')
            coroutine.yield(20)
            return
        end
        --RNGLOG('Upgrade Factory has triggered ')
        --RNGLOG('Default upgrade bp is '..upgradeID..' checking for support upgrade replacement')
        if upgradeID then
            if unitCat.LAND then
                if unitCat.TECH1 then
                    if self.Factories.LAND[2].HQCount[upgradeID] > 0 then
                        supportUpgradeID = self.SupportUpgradeTable.LAND.T2[unit.UnitId]
                    elseif followupUpgradeID and self.Factories.LAND[3].HQCount[followupUpgradeID] > 0 then
                        supportUpgradeID = self.SupportUpgradeTable.LAND.T2[unit.UnitId]
                    end
                elseif unitCat.TECH2 then
                    if self.Factories.LAND[3].HQCount[upgradeID] > 0 then
                        supportUpgradeID = self.SupportUpgradeTable.LAND.T3[unit.UnitId]
                    end
                end
            elseif unitCat.AIR then
                if unitCat.TECH1 then
                    if self.Factories.AIR[2].HQCount[upgradeID] > 0 then
                        supportUpgradeID = self.SupportUpgradeTable.AIR.T2[unit.UnitId]
                    elseif followupUpgradeID and self.Factories.AIR[3].HQCount[followupUpgradeID] > 0 then
                        supportUpgradeID = self.SupportUpgradeTable.AIR.T2[unit.UnitId]
                    end
                elseif unitCat.TECH2 then
                    if self.Factories.AIR[3].HQCount[upgradeID] > 0 then
                        supportUpgradeID = self.SupportUpgradeTable.AIR.T3[unit.UnitId]
                    end
                end
            elseif unitCat.NAVAL then
                if unitCat.TECH1 then
                    if self.Factories.NAVAL[2].HQCount[upgradeID] > 0 then
                        supportUpgradeID = self.SupportUpgradeTable.NAVAL.T2[unit.UnitId]
                    elseif followupUpgradeID and self.Factories.NAVAL[3].HQCount[followupUpgradeID] > 0 then
                        supportUpgradeID = self.SupportUpgradeTable.NAVAL.T2[unit.UnitId]
                    end
                elseif unitCat.TECH2 then
                    if self.Factories.NAVAL[3].HQCount[upgradeID] > 0 then
                        supportUpgradeID = self.SupportUpgradeTable.NAVAL.T3[unit.UnitId]
                    end
                end
            end
            if supportUpgradeID then
                --RNGLOG('Support Upgrade ID found '..supportUpgradeID)
                upgradeID = supportUpgradeID
            end
        end
        if upgradeID then
            --RNGLOG('Issuing Upgrade Command for factory')
            IssueClearCommands({unit})
            coroutine.yield(2)
            IssueUpgrade({unit}, upgradeID)
            local manager = self.Brain.BuilderManagers[unit.LocationType]
            if manager then
                local m = manager.FactoryManager
                local unitCats = unit.Blueprint.CategoriesHash
                -- Increment the local base count
                if unitCats.LAND then
                    if unitCats.TECH1 then
                        m.T1LANDUpgradingCount = (m.T1LANDUpgradingCount or 0) + 1
                        self.Factories.LAND[1].UpgradingCount = self.Factories.LAND[1].UpgradingCount + 1
                    elseif unitCats.TECH2 then
                        m.T2LANDUpgradingCount = (m.T2LANDUpgradingCount or 0) + 1
                        self.Factories.LAND[2].UpgradingCount = self.Factories.LAND[2].UpgradingCount + 1
                    end
                elseif unitCats.AIR then
                    if unitCats.TECH1 then
                        m.T1AIRUpgradingCount = (m.T1AIRUpgradingCount or 0) + 1
                        self.Factories.AIR[1].UpgradingCount = self.Factories.AIR[1].UpgradingCount + 1
                    elseif unitCats.TECH2 then
                        m.T2AIRUpgradingCount = (m.T2AIRUpgradingCount or 0) + 1
                        self.Factories.AIR[2].UpgradingCount = self.Factories.AIR[2].UpgradingCount + 1
                    end
                elseif unitCats.NAVAL then
                    if unitCats.TECH1 then
                        m.T1NAVALUpgradingCount = (m.T1NAVALUpgradingCount or 0) + 1
                        self.Factories.NAVAL[1].UpgradingCount = self.Factories.NAVAL[1].UpgradingCount + 1
                    elseif unitCats.TECH2 then
                        m.T2NAVALUpgradingCount = (m.T2NAVALUpgradingCount or 0) + 1
                        self.Factories.NAVAL[2].UpgradingCount = self.Factories.NAVAL[2].UpgradingCount + 1
                    end
                end
            end
            coroutine.yield(10)
            if (not IsDestroyed(unit)) and (not IsDestroyed(unit.UnitBeingBuilt)) then
                local upgradedFactory = unit.UnitBeingBuilt
                local fractionComplete = upgradedFactory:GetFractionComplete()
                unit.Upgrading = true
                if hq == 'LAND' then
                    self.Brain:RequestEngineerAssistFocus('StructureManager', 'LandUpgrade', 95, 60, false)
                elseif hq =='AIR' then
                    self.Brain:RequestEngineerAssistFocus('StructureManager', 'AirUpgrade', 95, 60, false)
                end
                while upgradedFactory and not IsDestroyed(upgradedFactory) and fractionComplete < 1 do
                    fractionComplete = upgradedFactory:GetFractionComplete()
                    coroutine.yield(20)
                end
                if not table.empty(self.Brain.EnemyIntel.TML) then
                    for _, v in self.Brain.EnemyIntel.TML do
                        self.UnitTMLCheck(upgradedFactory, v)
                    end
                end
                local tmdUnits = self.Brain:GetUnitsAroundPoint(categories.STRUCTURE * categories.ANTIMISSILE, upgradedFactory:GetPosition(), 40, 'Ally')
                --LOG('Number TMD around Upgraded Factory '..table.getn(tmdUnits))
                if not table.empty(tmdUnits) then
                    for _, v in tmdUnits do
                        local defenseRadius = v.Blueprint.Weapon[1].MaxRadius - 2
                        if VDist3Sq(upgradedFactory:GetPosition(), v:GetPosition()) < defenseRadius * defenseRadius then
                            if not upgradedFactory['rngdata'].TMDInRange then
                                upgradedFactory['rngdata'].TMDInRange = setmetatable({}, WeakValueTable)
                            end
                            --LOG('Found TMD that is protecting this unit, add to TMDInRange table')
                            upgradedFactory['rngdata'].TMDInRange[v.EntityId] = v
                        end
                    end
                end
                if hq == 'AIR' then
                    if self.Brain.BrainIntel.PlayerStrategy.T3AirRush and upgradedFactory.Blueprint.CategoriesHash.TECH3 then
                        self.Brain.BrainIntel.PlayerStrategy.T3AirRush = false
                    end
                end
                unit.Upgrading = false
            end
        end
    end,

    LocationFactoryCountRNG = function(self, aiBrain, category, locationType)
        local factoryCount = 0
        if aiBrain.BuilderManagers[locationType].FactoryManager.LocationActive then
            factoryCount = factoryCount + aiBrain.BuilderManagers[locationType].FactoryManager:GetNumCategoryFactories(category)
        end
        return factoryCount
    end,

    EcoExtractorUpgradeCheckRNG = function(self, aiBrain)
    -- Keep track of how many extractors are currently upgrading
    -- Right now this is less about making the best decision to upgrade and more about managing the economy while that upgrade is happening.
        coroutine.yield(Random(5,20))
        local ALLBPS = __blueprints
        local extractorTable = {
            TECH1 = 'ueb1103',
            TECH2 = 'ueb1202',
            TECH3 = 'ueb1302'
        }
        local buildMultiplier = aiBrain.EcoManager.BuildMultiplier
        local tech1Consumption
        local tech2Consumption
        if ALLBPS[extractorTable.TECH1] and ALLBPS[extractorTable.TECH2] and ALLBPS[extractorTable.TECH3] then
            local t1Extractor = ALLBPS[extractorTable.TECH1].Economy
            local t2Extractor = ALLBPS[extractorTable.TECH2].Economy
            local t3Extractor = ALLBPS[extractorTable.TECH3].Economy
            if t2Extractor.BuildCostMass and t2Extractor.BuildTime and t1Extractor.BuildRate then
                tech1Consumption = t2Extractor.BuildCostMass / t2Extractor.BuildTime * (t1Extractor.BuildRate * buildMultiplier)
            end
            if t3Extractor.BuildCostMass and t3Extractor.BuildTime and t2Extractor.BuildRate then
                tech2Consumption = t3Extractor.BuildCostMass / t3Extractor.BuildTime * (t2Extractor.BuildRate * buildMultiplier)
            end
        end
        aiBrain.EcoManager.ExtractorValues.TECH1.ConsumptionValue = tech1Consumption or 10
        aiBrain.EcoManager.ExtractorValues.TECH2.ConsumptionValue = tech2Consumption or 24
        
        while true do
            local brainIntel = aiBrain.BrainIntel
            local multiplier = aiBrain.EcoManager.EcoMultiplier
            local baseUpgradeTime = 380
            if aiBrain.LowResourceMapProfile then
                baseUpgradeTime = 240
            end
            local upgradeTrigger = false
            local upgradeSpend = aiBrain.cmanager.income.r.m * aiBrain.EconomyUpgradeSpend
            --LOG('Upgrade spend ratio is '..tostring(aiBrain.EconomyUpgradeSpend)..' and allowed spend is '..tostring(upgradeSpend)..' player is '..tostring(aiBrain.Nickname))
            if upgradeSpend > 4 or GetGameTimeSeconds() > (baseUpgradeTime / multiplier) or aiBrain.BrainIntel.PlayerRole.AirPlayer or aiBrain.BrainIntel.PlayerRole.ExperimentalPlayer or self.BrainIntel.HighestPhase > 1 then
                upgradeTrigger = true
            end
            --LOG('Total income '..tostring(aiBrain.cmanager.income.r.m))
            --LOG('Economy Upgrade spend ratio '..tostring(aiBrain.EconomyUpgradeSpend))
            --LOG('Allowed Upgrade spend '..tostring(upgradeSpend))
            --LOG('Tech2 with consumption multiplier is '..tostring(tech2Consumption * 2.2))
            
            local extractorsDetail, extractorTable, totalSpend = self.ExtractorsBeingUpgraded(self, aiBrain)
            aiBrain.EcoManager.TotalExtractors.TECH1 = extractorsDetail.TECH1
            aiBrain.EcoManager.TotalExtractors.TECH2 = extractorsDetail.TECH2
            aiBrain.EcoManager.ExtractorsUpgrading.TECH1 = extractorsDetail.TECH1Upgrading
            --LOG('Current number of upgrading T1 extractors '..tostring(extractorsDetail.TECH1Upgrading))
            aiBrain.EcoManager.ExtractorsUpgrading.TECH2 = extractorsDetail.TECH2Upgrading
            --LOG('Current number of upgrading T2 extractors '..tostring(extractorsDetail.TECH2Upgrading))
            aiBrain.EcoManager.ExtractorValues.TECH1.TeamValue = extractorsDetail.TECH1Value
            aiBrain.EcoManager.ExtractorValues.TECH2.TeamValue = extractorsDetail.TECH2Value
            local currentEnergyEfficiency = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
            local currentMassEfficiency = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
            -- Logging starts here
            --[[
            local currentTime = GetGameTimeSeconds()
            LOG('{ "GameTime" : '..tostring(currentTime)..', "Nickname": "'..tostring(aiBrain.Nickname)..'" }')
            LOG('{ "GameTime" : '..tostring(currentTime)..', "CoreT3Extractors" : "'..tostring(aiBrain.EcoManager.CoreExtractorT3Count)..'" }')
            LOG('{ "GameTime" : '..tostring(currentTime)..', "CoreExtractorsTotal" : "'..tostring(aiBrain.EcoManager.TotalCoreExtractors)..'" }')
            LOG('TotalExtractorSpend : '..tostring(totalSpend))
            LOG('{ "GameTime" : '..tostring(currentTime)..', "TotalAllowedExtractorSpend" : "'..tostring(upgradeSpend)..'" }')
            LOG('AvailableExtractorUpgradeSpend'..tostring(upgradeSpend - totalSpend))
            LOG('{ "GameTime" : '..tostring(currentTime)..', "CurrentT3ExtractorUpgradeSpend" : "'..tostring(tech2Consumption)..'" }')
            LOG('T1ExtractorUpgradeCount '..tostring(extractorsDetail.TECH1Upgrading))
            LOG('T2ExtractorUpgradeCount '..tostring(extractorsDetail.TECH2Upgrading))
            LOG('Current T2 to T1 extractor ratio '..tostring(extractorsDetail.TECH2 / extractorsDetail.TECH1))
            LOG('Tech1 extractors '..tostring(extractorsDetail.TECH1))
            LOG('Tech2 extractors '..tostring(extractorsDetail.TECH2))
            ]]

            if aiBrain.EcoManager.CoreExtractorT3Count < 3 and aiBrain.EcoManager.TotalCoreExtractors > 2 and aiBrain.cmanager.income.r.m > (140 * multiplier) and (aiBrain.smanager.Current.Structure.fact.Land.T3 > 0 or aiBrain.smanager.Current.Structure.fact.Air.T3 > 0) and aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= 1.0 and currentEnergyEfficiency >= 1.0 then
                aiBrain.EcoManager.CoreMassPush = true
                --RNGLOG('Assist Focus is Mass extraction')
                aiBrain.EngineerAssistManagerFocusCategory = categories.MASSEXTRACTION
                aiBrain.EngineerAssistManagerFocusCategoryLookup = 'Mass'
            elseif aiBrain.EcoManager.CoreMassPush then
                aiBrain.EcoManager.CoreMassPush = false
                --RNGLOG('Assist Focus is set to false from Extractor upgrade manager')
                if aiBrain.EngineerAssistManagerFocusCategory == categories.MASSEXTRACTION then
                    aiBrain.EngineerAssistManagerFocusCategory = false
                    aiBrain.EngineerAssistManagerFocusCategoryLookup = nil
                end
            end

            local massEfficiencyOverTime = aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime
            local massStorage = GetEconomyStored( aiBrain, 'MASS')
            local energyEfficiencyOverTime = aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime
            local energyStorage = GetEconomyStored( aiBrain, 'ENERGY')
            local coreExtractorT2Count = aiBrain.EcoManager.CoreExtractorT2Count
            --LOG('Energy Efficiency over time '..tostring(energyEfficiencyOverTime))
            --LOG('Energy Efficiency '..tostring(currentEnergyEfficiency))
            local massBuffer = 1500
            if brainIntel.AverageSaturation and brainIntel.AverageSaturation < 0.5 then
                massBuffer = 800
            end

            if aiBrain.EcoManager.CoreMassPush and extractorsDetail.TECH2Upgrading < 1 and aiBrain.cmanager.income.r.m > (140 * multiplier) then
                --LOG('Trigger all tiers true '..tostring(aiBrain.Nickname))
                self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, true)
                coroutine.yield(50)
                continue
            end
            if aiBrain.EcoManager.TacticalGreedAllowed 
            and aiBrain.EcoManager.CoreExtractorT3Count < aiBrain.EcoManager.CoreMassMarkerCount
            and coreExtractorT2Count > 0 
            and extractorsDetail.TECH2Upgrading < 1 
            and energyEfficiencyOverTime > 1.0 
            and currentEnergyEfficiency >= 1.0 
            and energyStorage > 4000 then
                --LOG('Tactical Greed Triggered: Advancing core extractor to T3 due to secure map state.')
                self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, true)
                coroutine.yield(60)
                continue
            end
            if massStorage > massBuffer and aiBrain.EcoManager.CoreExtractorT3Count < aiBrain.EcoManager.CoreMassMarkerCount
            and coreExtractorT2Count > 0
            and aiBrain.BrainIntel.SelfThreat.ExtractorCount > aiBrain.BrainIntel.MassSharePerPlayer 
            and extractorsDetail.TECH2Upgrading < aiBrain.EcoManager.CoreMassMarkerCount 
            and energyEfficiencyOverTime > 1.1 and currentEnergyEfficiency >= 1.1 and energyStorage > 8000 then
                --LOG('We Could upgrade an extractor now with over time of 1.1 and energy storage of 8000 '..tostring(aiBrain.Nickname))
                self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, true)
                coroutine.yield(60)
                continue
            elseif (coreExtractorT2Count + aiBrain.EcoManager.CoreExtractorT3Count >= aiBrain.EcoManager.TotalCoreExtractors and (upgradeSpend > tech2Consumption * 2.2) or 
            coreExtractorT2Count + aiBrain.EcoManager.CoreExtractorT3Count >= 4 and (upgradeSpend > tech2Consumption * 2.2)) 
            and extractorsDetail.TECH2Upgrading < 1 and aiBrain.BrainIntel.SelfThreat.ExtractorCount > aiBrain.BrainIntel.MassSharePerPlayer  
            and coreExtractorT2Count > 0
            and energyStorage > 8000 and energyEfficiencyOverTime > 1.1 and currentEnergyEfficiency >= 1.1 then
                --LOG('Extractor upgrade triggered due to massshareperplayer being higher than average '..tostring(aiBrain.Nickname))
                self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, true)
                coroutine.yield(60)
                continue
            elseif massStorage > 2500 and energyStorage > 8000 and energyEfficiencyOverTime > 1.1 and currentEnergyEfficiency >= 1.1 and extractorsDetail.TECH2Upgrading < 2 then
                --LOG('We Could upgrade an extractor now with over time '..tostring(aiBrain.Nickname))
                self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, true)
                coroutine.yield(60)
                continue
            end
            if extractorsDetail.TECH1Upgrading < 5 and extractorsDetail.TECH2Upgrading < 2 and upgradeTrigger and (totalSpend < upgradeSpend or massStorage > 800) and 
                   energyEfficiencyOverTime >= 1.0 and currentEnergyEfficiency >= 1.0 and not aiBrain.BrainIntel.PlayerRole.SpamPlayer and extractorsDetail.TECH2 > 0 and 
                   upgradeSpend > tech2Consumption * 2.1 then
                        --LOG('We Could upgrade a t2 extractor now with over time and we are not already upgrading t2 '..tostring(aiBrain.Nickname))
                        self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, true)
                        coroutine.yield(25)
            elseif extractorsDetail.TECH1Upgrading < 4 and extractorsDetail.TECH2Upgrading < 1 and upgradeTrigger and 
                   (totalSpend < upgradeSpend or massStorage > 600 or upgradeSpend > tech2Consumption) and energyEfficiencyOverTime >= 1.0 and currentEnergyEfficiency >= 1.0 and not aiBrain.BrainIntel.PlayerRole.SpamPlayer and extractorsDetail.TECH2 > 0 and 
                   (extractorsDetail.TECH1 == 0 or (extractorsDetail.TECH2 / extractorsDetail.TECH1 >= 1.2)) then
                        --LOG('We Could upgrade a t2 extractor now with over time ratio 1.2 and we are not already upgrading t2 '..tostring(aiBrain.Nickname))
                        --LOG('Upgrade spend at the time was '..tostring(upgradeSpend))
                        --LOG('Tech2 consumption at the time was '..tostring(tech2Consumption))
                        self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, true)
                        coroutine.yield(25)
            elseif extractorsDetail.TECH1Upgrading < 3 and extractorsDetail.TECH2Upgrading < 1 and upgradeTrigger and (totalSpend < upgradeSpend or massStorage > 600) and 
                   energyEfficiencyOverTime >= 1.0 and currentEnergyEfficiency >= 1.0 and not aiBrain.BrainIntel.PlayerRole.SpamPlayer and extractorsDetail.TECH1 > 0 and extractorsDetail.TECH2 > 0 and 
                   ((extractorsDetail.TECH1 / extractorsDetail.TECH2 >= 1.7) or upgradeSpend < 15) and (upgradeSpend < tech2Consumption) then
                        --LOG('We Could upgrade a t1 extractor now with over time ratio 1.7 and we are not already upgrading t2')
                        self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, false)
                        coroutine.yield(25)
            elseif extractorsDetail.TECH1 > 0 and extractorsDetail.TECH1Upgrading < 1 and extractorsDetail.TECH2Upgrading > 0 and upgradeTrigger and totalSpend < upgradeSpend 
                   and energyEfficiencyOverTime >= 1.0 and currentEnergyEfficiency >= 1.0 and not aiBrain.BrainIntel.PlayerRole.SpamPlayer then
                    --LOG('Upgrading the minimum number t1 ')
                    self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, false)
                    coroutine.yield(50)
            elseif extractorsDetail.TECH1 > 0 and extractorsDetail.TECH1Upgrading < 4 and upgradeTrigger and (totalSpend < upgradeSpend or massStorage > 450) 
                   and energyEfficiencyOverTime >= 1.0 and currentEnergyEfficiency >= 1.0 and not aiBrain.BrainIntel.PlayerRole.SpamPlayer and massStorage < 2500 then
                    --LOG('Upgrading if we have less than 5 t1 upgrading t1')
                    self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, false)
                    coroutine.yield(50)
            elseif massStorage > 500 and energyStorage > 3000 and extractorsDetail.TECH2Upgrading < 2 and coreExtractorT2Count + aiBrain.EcoManager.CoreExtractorT3Count >= aiBrain.EcoManager.TotalCoreExtractors 
                   and massEfficiencyOverTime >= 1.015 and energyEfficiencyOverTime >= 1.1 and currentEnergyEfficiency >= 1.1 and currentMassEfficiency >= 1.015 then
                    --LOG('We Could upgrade an extractor now with storage and efficiency t2 '..tostring(aiBrain.Nickname))
                    self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, true)
                    coroutine.yield(25)
            elseif massStorage > 2500 and energyStorage > 8000 and massEfficiencyOverTime >= 0.8 and energyEfficiencyOverTime >= 0.9 and currentEnergyEfficiency >= 1.05 and currentMassEfficiency > 0.8 then
                    --LOG('We could update an extractor because we have alot of mass storage '..tostring(aiBrain.Nickname))
                    self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, true)
                    coroutine.yield(25)
            elseif extractorsDetail.TECH1 > 0 and extractorsDetail.TECH1Upgrading < 8 and extractorsDetail.TECH2Upgrading > 0 and upgradeTrigger and totalSpend < upgradeSpend 
                and energyEfficiencyOverTime >= 1.0 and currentEnergyEfficiency >= 1.0 and not aiBrain.BrainIntel.PlayerRole.SpamPlayer then
                --LOG('Upgrading the minimum number t1 ')
                 self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, false)
                 coroutine.yield(25)
            end
            coroutine.yield(25)
        end
    end,

    StructureSiloCheck = function(self, structure, optionalUnit)
        local defended = true
        local TMLInRange = 0
        local TMDCount = 0
        local structurePos = structure:GetPosition()
        local structureZones = self.Brain.Zones.Land
        if not structure['rngdata'] then
            structure['rngdata'] = {}
        end
        local structureData = structure['rngdata']
        if not structureData['TMLInRange'] then
            structureData['TMLInRange'] = setmetatable({}, WeakValueTable)
        end
        if not structureData['TMDInRange'] then
            structureData['TMDInRange'] = setmetatable({}, WeakValueTable)
        end
        if structure and not optionalUnit then
            local zoneId = MAP:GetZoneID(structurePos, structureZones.index)
            local currentZone = structureZones.zones[zoneId]
            if currentZone.enemySilos and currentZone.enemySilos > 0 then
                if not structureData.TMDInRange then
                    defended = false
                else
                    for _, c in structureData.TMDInRange do
                        if not c.Dead then
                            TMDCount = TMDCount + 1
                        end
                    end
                    if (math.ceil(currentZone.enemySilos / 2)) > TMDCount then
                        --LOG('More TML than TMD, TML count is '..tostring(TMLInRange)..' TMD Count '..tostring(TMDCount))
                        defended = false
                    end
                end
            end
        end
        if structureData.TMLInRange and not table.empty(structureData.TMLInRange) then
            for k, v in pairs(structureData.TMLInRange) do
                if not self.Brain.EnemyIntel.TML[k] or self.Brain.EnemyIntel.TML[k].object.Dead then
                    structureData.TMLInRange[k] = nil
                    continue
                end   
                TMLInRange = TMLInRange + 1 
            end
            if not structureData.TMDInRange then
                defended = false
            else
                for _, c in structureData.TMDInRange do
                    if not c.Dead then
                        TMDCount = TMDCount + 1
                    end
                end
                if TMLInRange > TMDCount then
                    --LOG('More TML than TMD, TML count is '..tostring(TMLInRange)..' TMD Count '..tostring(TMDCount))
                    defended = false
                end
            end
            --LOG('TMLInRange '..tostring(TMLInRange)..' TMDCount '..tostring(TMDCount))
        elseif optionalUnit then
            local tmlTable = self.Brain.EnemyIntel.TML
            if tmlTable[optionalUnit.EntityId] and tmlTable[optionalUnit.EntityId].object and not tmlTable[optionalUnit.EntityId].object.Dead then
                local tmlPos = tmlTable[optionalUnit.EntityId].object:GetPosition()
                if tmlPos[1] and structurePos[1] then
                    local dx = tmlPos[1] - structurePos[1]
                    local dz = tmlPos[3] - structurePos[3]
                    local distance = dx * dx + dz * dz
                    local tmlRange = tmlTable[optionalUnit.EntityId].object.Blueprint.Weapon[1].MaxRadius or 256
                    if distance <= tmlRange * tmlRange then
                        TMLInRange = TMLInRange + 1
                        structureData.TMLInRange[optionalUnit.EntityId] = optionalUnit
                    end
                    for _, c in structureData.TMDInRange do
                        if not c.Dead then
                            TMDCount = TMDCount + 1
                        end
                    end
                    if TMLInRange > TMDCount then
                        --LOG('More TML than TMD, TML count is '..tostring(TMLInRange)..' TMD Count '..tostring(TMDCount))
                        defended = false
                    end
                end
                --LOG('TMLInRange '..tostring(TMLInRange)..' TMDCount '..tostring(TMDCount))
            else
                --LOG('tmlTable did not return anything for its object')
            end
        end
        return defended
    end,

    StructureShieldCheck = function(self, structure)
        local defended = false
        if structure['rngdata'].ShieldsInRange and not table.empty(structure['rngdata'].ShieldsInRange) then
            for _, v in pairs(structure['rngdata'].ShieldsInRange) do
                if v and not v.Dead then
                    defended = true
                    break
                end    
            end
        end
        return defended
    end,

    ValidateExtractorUpgradeRNG = function(self, aiBrain, extractorTable, allTiers)
        local bestZone, bestExtractor
        local highestScore
        local basePosition = aiBrain.BuilderManagers['MAIN'].Position
        local homeZone = self.BuilderManagers['MAIN'].ZoneID
        local ecoManager = aiBrain.EcoManager
        local intelManager = aiBrain.IntelManager
        local myArmyIndex = aiBrain:GetArmyIndex()
        
        -- Data derived from EcoTacticalThread
        local safeZones = ecoManager.SafeMassZones or {} 
        local zoneBias = ecoManager.ZoneUpgradeBias or {}
        
        -- Data derived from IntelManager.ComputeContainmentState
        local frontLineZones = intelManager.CurrentFrontLineZones or {}
        
        local zoneExtractors = {
            Land = {},
            Naval = {},
        }
        
        -- Flatten the extractor table based on tier criteria
        for tier, extractors in extractorTable do
            if allTiers or tier == "TECH1" then
                for _, c in extractors do
                    if c and not c.Dead and c.InitialDelayCompleted and not c:IsPaused() then
                        local zoneID = c.zoneid
                        local layer = c.Water and 'Naval' or 'Land'
                        if zoneID and layer then
                            zoneExtractors[layer][zoneID] = zoneExtractors[layer][zoneID] or {}
                            table.insert(zoneExtractors[layer][zoneID], c)
                        end
                    end
                end
            end
        end
        
        -- Evaluate zones
        for layer, zones in zoneExtractors do
            local zoneGroup = aiBrain.Zones[layer]
            for zoneID, extractors in zones do
                local zone = zoneGroup.zones[zoneID]
                local zoneScore = 0
                local isFrontline = frontLineZones[zoneID]

                if zone then
                    -- The order of this is important. Since it can otherwise skip the frontlinezones check.
                    -- 1. Check for the absolute Safest (highest score)
                    if homeZone and zoneID == homeZone and not isFrontline then
                        zoneScore = 2750
                    elseif safeZones[zoneID] then
                        zoneScore = 2000

                    -- 2. Check for Active Danger (must be done before rewarding base proximity)
                    elseif frontLineZones[zoneID] then
                        -- If it's a frontline, the maximum score it gets is 500, regardless of proximity.
                        zoneScore = 500

                    -- 3. Check for Safe Base Proximity (The NEW logic - only if not a frontline)
                    elseif zone.startpositionclose and zone.bestarmy == myArmyIndex and not isFrontline then
                        -- This zone is safe (passed the frontline check) AND is part of our core cluster.
                        zoneScore = 1800

                    -- 4. Default/Unsecured cases
                    else
                        if zone.status == 'Allied' then
                            zoneScore = 0
                        else
                            zoneScore = -2000
                        end
                    end

                    -- 2. Threat Assessment (Local + Adjacent)
                    -- Heavy penalty for threat in the specific zone
                    local localThreat = (zone.enemylandthreat or 0) + (zone.enemystructurethreat or 0) + ((zone.enemyairthreat or 0) * 0.5)
                    
                    -- Check adjacent zones (Edges) to prevent upgrading right next to a massive enemy push
                    local adjacentThreat = 0
                    if zone.edges then
                        for _, edge in ipairs(zone.edges) do
                            local adjZone = edge.zone
                            if adjZone then
                                adjacentThreat = adjacentThreat + (adjZone.enemylandthreat or 0) + (adjZone.enemystructurethreat or 0)
                            end
                        end
                    end
                    -- Didn't know this was a thing, thanks gemini for explaining it.
                    -- In Lua, the and and or operators do not return true or false like in many other languages; they return one of their operands. This behavior allows them to be used for conditional assignment
                    local adjacentMultiplier = (zone.startpositionclose and zone.bestarmy == myArmyIndex) and 5 or 2

                    local threatPenalty = (localThreat * 10) + (adjacentThreat * adjacentMultiplier)
                    zoneScore = zoneScore - threatPenalty
                    
                    -- 3. Upgrade Bias (Strategic Priority from EcoManager)
                    -- This leverages your existing logic that determines where the AI wants to focus
                    if zoneBias[zoneID] then
                        zoneScore = zoneScore + (zoneBias[zoneID] * 100)
                    end

                    -- 4. Resource Density Bonus 
                    -- Prefer zones with multiple mexes (cluster protection efficiency)
                    if zone.resourcevalue then
                        zoneScore = zoneScore + (zone.resourcevalue * 50)
                    end

                    -- 5. Distance Penalty (Tie-breaker)
                    -- Prefer closer to main base if all else is equal (easier to defend/rebuild)
                    local zoneDist = VDist2Sq(basePosition[1], basePosition[3], zone.pos[1], zone.pos[3])
                    zoneScore = zoneScore - (math.sqrt(zoneDist) * 0.5)

                elseif zoneID == -1 then
                    -- Handle extractors with no valid zone (rare/error case)
                    zoneScore = -5000
                end

                -- Select the best extractor from this zone
                for _, ex in extractors do
                    -- If the zone score is good, pick this extractor.
                    -- We iterate all to ensure we process the whole list, but the score is primarily zone-based.
                    if not highestScore or zoneScore > highestScore then
                        highestScore = zoneScore
                        bestExtractor = ex
                        bestZone = zoneID
                    end
                end
            end
        end
    
        -- Upgrade the selected extractor if one was found
        if bestExtractor then
            local extractorPos = bestExtractor:GetPosition()
            local distanceToBase = VDist2Sq(basePosition[1], basePosition[3], extractorPos[1],extractorPos[3])
            bestExtractor.DistanceToBase = distanceToBase
            if not aiBrain.ExtractorUpgradeThread then
                aiBrain.ExtractorUpgradeThread = self:ForkThread(self.UpgradeManagementThread, aiBrain)
            end
            -- Trigger the upgrade process
            self:ForkThread(self.AddExtractorToUpgradeQueue, aiBrain, bestExtractor, distanceToBase)
            -- RNGLOG('Added Extractor for upgrade in Zone '..tostring(bestZone)..' with Score: '..tostring(highestScore))
        else
            -- RNGLOG('No valid extractor found for upgrade.')
        end
    end,

    AddExtractorToUpgradeQueue = function(self, aiBrain, extractorUnit, distanceToBase)
        local upgradeID = extractorUnit.Blueprint.General.UpgradesTo or false
        if upgradeID then
            IssueUpgrade({extractorUnit}, upgradeID)
            table.insert(self.ExtractorUpgradeQueue, {
                ExtractorUnit = extractorUnit,
                TimeAdded = GetGameTimeSeconds(),
                DistanceToMain = distanceToBase,
                ZoneID = extractorUnit.zoneid,
                BypassEcoManager = false
            })
        end
    end,

    UpgradeManagementThread = function(self, aiBrain)
        while true do
            coroutine.yield(20)
            local upgradeManagementQueue = self.ExtractorUpgradeQueue
            local t1Consumption = aiBrain.EcoManager.ExtractorValues.TECH1.ConsumptionValue
            local t2Consumption = aiBrain.EcoManager.ExtractorValues.TECH2.ConsumptionValue
            local upgradeSpend = aiBrain.cmanager.income.r.m * aiBrain.EconomyUpgradeSpend
            local currentConsumption = 0
            local currentTime = GetGameTimeSeconds()
            -- Check if there are extractors in the queue
            if not table.empty(upgradeManagementQueue) then
                local currentTableSize = 0
                -- Sort the queue if necessary based on priority (e.g., distance to base, zone, etc.)
                table.sort(upgradeManagementQueue, function(a, b)
                    return a.DistanceToMain < b.DistanceToMain -- Prioritize closer extractors, for example
                end)
                --LOG('Upgrade queue sorted')
                local massStored = GetEconomyStored(aiBrain, 'MASS')
                local massTrend = GetEconomyTrend(aiBrain, 'MASS')
                local energyStored = GetEconomyStored(aiBrain, 'ENERGY')
                -- Loop through all extractors in the queue
                for i = table.getn(upgradeManagementQueue), 1, -1 do
                    local extractorInfo = upgradeManagementQueue[i]
                    currentTableSize = currentTableSize + 1
                    --LOG('Loop through extractor '..i)
                    local extractorUnit = extractorInfo.ExtractorUnit
                    local upgradedExtractor = extractorUnit.UnitBeingBuilt
                    if extractorUnit and not extractorUnit.Dead and upgradedExtractor and not upgradedExtractor.Dead then
                        local fractionComplete = upgradedExtractor:GetFractionComplete()
                        local unitCats = extractorUnit.Blueprint.CategoriesHash

                        if fractionComplete < 1 then
                            --LOG('fractionComplete is less than 1')
                            if unitCats.TECH1 then
                                currentConsumption = currentConsumption + t1Consumption
                            else
                                currentConsumption = currentConsumption + t2Consumption
                            end
                            --LOG('Current consumption is '..tostring(currentConsumption))
                            --LOG('Available spend '..tostring(upgradeSpend))
                            -- Check if economy supports continuing upgrades
                            if not extractorInfo.bypassEcoManager and fractionComplete < 0.65 then
                                --LOG('Performing economy management on extractor')
                                if energyStored < 200 or (massTrend <= 0.0 and massStored <= 150 and currentConsumption > upgradeSpend and i~= 1) then
                                    if not extractorUnit.Dead and not extractorUnit:IsPaused() then
                                        extractorUnit:SetPaused(true)
                                        --LOG('Pause Extractor')
                                    end
                                else
                                    if not extractorUnit.Dead and extractorUnit:IsPaused() then
                                        if aiBrain.EcoManager.ExtractorsUpgrading.TECH1 > 1 or aiBrain.EcoManager.ExtractorsUpgrading.TECH2 > 0 then
                                            if currentConsumption < upgradeSpend then
                                                extractorUnit:SetPaused(false)
                                            elseif aiBrain.EcoManager.ExtractorsUpgrading.TECH2 > 0 and unitCats.TECH1 then
                                                extractorUnit:SetPaused(false)
                                            elseif massStored > 250 then
                                                extractorUnit:SetPaused(false)
                                            end
                                        elseif not extractorUnit.Dead then
                                            extractorUnit:SetPaused(false)
                                        end
                                    end
                                end
                            end
                        end

                        -- Check upgrade timeout logic
                        if not extractorInfo.BypassEcoManager and currentTime - extractorInfo.TimeAdded > aiBrain.EcoManager.EcoMassUpgradeTimeout and energyStored > 500 then
                            --LOG('Bypassing eco manager for extractor')
                            extractorInfo.BypassEcoManager = true
                            if not extractorUnit.Dead and extractorUnit:IsPaused() then
                                extractorUnit:SetPaused(false)
                            end
                        end
                        -- If upgrade is complete, remove from the queue
                        if fractionComplete >= 1 then
                            table.remove(upgradeManagementQueue, i)
                        end
                    elseif extractorUnit.Dead or upgradedExtractor.Dead then
                        table.remove(upgradeManagementQueue, i)
                    end
                end
                --LOG('Table size at end is '..tostring(currentTableSize))
            end
    
        end
    end,

    ExtractorInitialDelay = function(self, aiBrain, unit)
        local initial_delay = 0
        local multiplier = 1
        local ecoStartTime = GetGameTimeSeconds()
        local ecoTimeOut = 300
        unit.InitialDelayCompleted = false
        unit.InitialDelayStarted = true
        if aiBrain.CheatEnabled then
            multiplier = aiBrain.EcoManager.EcoMultiplier
        else
            multiplier = 1
        end
        local maxDelay = (60 / multiplier)
        --LOG('Initial Delay loop starting')
        while initial_delay < maxDelay do
            if not unit.Dead and GetEconomyStored( aiBrain, 'ENERGY') >= 250 and unit:GetFractionComplete() == 1 then
                initial_delay = initial_delay + 10
                if (GetGameTimeSeconds() - ecoStartTime) > ecoTimeOut then
                    initial_delay = maxDelay
                end
            end
            --RNGLOG('* AI-RNG: Initial Delay loop trigger for '..aiBrain.Nickname..' is : '..initial_delay..' out of 90')
            coroutine.yield(100)
        end
        unit.InitialDelayCompleted = true
    end,

    ExtractorsBeingUpgraded = function(self, aiBrain)
        -- Returns number of extractors upgrading
        local ALLBPS = __blueprints
        local extractors = aiBrain:GetListOfUnits(categories.MASSEXTRACTION, true)
        local tech1ExtNumBuilding = 0
        local tech2ExtNumBuilding = 0
        local tech1ExtValue = 0
        local tech2ExtValue = 0
        local tech1Total = 0
        local tech2Total = 0
        local tech3Total = 0
        local totalSpend = 0
        local extractorTable = {
            TECH1 = {},
            TECH2 = {},
        }
        local multiplier
        if aiBrain.CheatEnabled then
            multiplier = aiBrain.EcoManager.BuildMultiplier
        else
            multiplier = 1
        end

        -- own armyIndex
        local armyIndex = aiBrain:GetArmyIndex()
        -- loop over all units and search for upgrading units
        for _, extractor in extractors do
            if not IsDestroyed(extractor) and extractor:GetAIBrain():GetArmyIndex() == armyIndex and extractor:GetFractionComplete() == 1 then
                if not extractor.InitialDelayStarted then
                    self:ForkThread(self.ExtractorInitialDelay, aiBrain, extractor)
                end
                if extractor.Blueprint.CategoriesHash.TECH1 then
                    tech1Total = tech1Total + 1
                    if extractor:IsUnitState('Upgrading') then
                        local upgradeId = extractor.Blueprint.General.UpgradesTo
                        totalSpend = totalSpend +  (ALLBPS[upgradeId].Economy.BuildCostMass / ALLBPS[upgradeId].Economy.BuildTime * (extractor.Blueprint.Economy.BuildRate * multiplier))
                        extractor.Upgrading = true
                        tech1ExtNumBuilding = tech1ExtNumBuilding + 1
                    else
                        extractor.Upgrading = false
                        local extractorValue = extractor.teamvalue or 1
                        tech1ExtValue = tech1ExtValue + math.min(1, extractorValue)
                        RNGINSERT(extractorTable.TECH1, extractor)
                    end
                elseif extractor.Blueprint.CategoriesHash.TECH2 then
                    tech2Total = tech2Total + 1
                    if extractor:IsUnitState('Upgrading') then
                        local upgradeId = extractor.Blueprint.General.UpgradesTo
                        totalSpend = totalSpend + (ALLBPS[upgradeId].Economy.BuildCostMass / ALLBPS[upgradeId].Economy.BuildTime * (extractor.Blueprint.Economy.BuildRate * multiplier))
                        extractor.Upgrading = true
                        tech2ExtNumBuilding = tech2ExtNumBuilding + 1
                    else
                        extractor.Upgrading = false
                        local extractorValue = extractor.teamvalue or 1
                        tech2ExtValue = tech2ExtValue + math.min(1, extractorValue)
                        RNGINSERT(extractorTable.TECH2, extractor)
                    end
                elseif extractor.Blueprint.CategoriesHash.TECH3 then
                    tech3Total = tech3Total + 1
                end
            end
        end
        aiBrain.EcoManager.TotalMexSpend = totalSpend
        return {TECH1 = tech1Total, TECH1Upgrading = tech1ExtNumBuilding, TECH1Value = tech1ExtValue, TECH2 = tech2Total, TECH2Upgrading = tech2ExtNumBuilding, TECH2Value = tech2ExtValue, TECH3 = tech3Total }, extractorTable, totalSpend
    end,

    CheckDefensiveCoverage = function(self)
        coroutine.yield(math.random(50, 100))
        while self.Brain.Status ~= "Defeat" do
            coroutine.yield(60)
            local structures = self.Brain:GetListOfUnits(
                ((categories.MASSEXTRACTION + categories.FACTORY) - categories.TECH1 + categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3)) 
                + (categories.STRUCTURE * categories.STRATEGIC * categories.TECH3),
                true
            )
            local tmdRequired = {}
            local shieldRequired = {}
            for _, v in structures do
                local isTMDDefended = self:StructureSiloCheck(v)
                if not isTMDDefended then
                    RNGINSERT(tmdRequired, {Unit = v, Assigned = false, AssignedEngineer = nil})
                end
                local isShieldDefended = self:StructureShieldCheck(v)
                if not isShieldDefended then
                    RNGINSERT(shieldRequired, v)
                end
                coroutine.yield(1)
            end
            if not table.empty(tmdRequired) then
                --LOG('Set TMD Required on structure manager for ai '..tostring(self.Brain.Nickname))
                self.TMDRequired = true
                self.StructuresRequiringTMD = tmdRequired
            else
                --LOG('Set TMD Not Required for '..tostring(self.Brain.Nickname))
                self.TMDRequired = false
            end
            if not table.empty(shieldRequired) then
                --LOG('Set TMD Required on structure manager')
                self.ShieldsRequired = true
                self.StructuresRequiringShields = shieldRequired
            else
                self.ShieldsRequired = false
            end
            if self.Brain.BuilderManagers['MAIN'].EngineerManager then
                self:CheckSMDAssistRequirements(self.Brain, self.Brain.BuilderManagers['MAIN'].EngineerManager)
            end
        end
    end,

    CheckSMDAssistRequirements = function(self, aiBrain, engineerManager)
        local currentSMDs = engineerManager:GetUnits('AntiNuke', categories.STRUCTURE)
        local currentMissiles = 0
        local smdPresent = 0
        for _, unit in currentSMDs do
            if not unit.Dead then
                smdPresent = smdPresent + 1
                --LOG('ssd exist, count '..tostring(smdPresent)..' unit id is '..tostring(unit.UnitId)..' entityid is '..tostring(unit.EntityId))
                local ammoCount = unit:GetTacticalSiloAmmoCount()
                --LOG('Ammo count '..tostring(ammoCount))
                -- If no missiles are loaded and the unit is actually building one
                if ammoCount > 0 then
                    currentMissiles = currentMissiles + 1
                    --LOG('We have a missile already')
                    break
                end
            end
        end
        if smdPresent > 0 and currentMissiles == 0 then
            --LOG('Requesting SMD assist for '..tostring(aiBrain.Nickname))
            aiBrain:RequestEngineerAssistFocus('SMDLoading', 'SMDLoading', 950, 120, false)
        elseif aiBrain.EngineerAssistManagerRequests and aiBrain.EngineerAssistManagerRequests['SMDLoading'] then
            --LOG('Flush SMD assist request for '..tostring(aiBrain.Nickname))
            aiBrain.EngineerAssistManagerRequests['SMDLoading'] = nil
        end
    end,

    ValidateTML = function(self, aiBrain, tml)
        if not tml.validated then
            --LOG('ValidateTML unit has not been validated')
            local extractors = aiBrain:GetListOfUnits((categories.STRUCTURE * categories.FACTORY) + (categories.STRUCTURE * categories.MASSEXTRACTION - categories.TECH1 - categories.EXPERIMENTAL) , false, false)
            for _, b in extractors do
                self.UnitTMLCheck(b, tml)
            end
            tml.validated = true
        end
    end,
    
    UnitTMLCheck = function(unit, tml)
        --LOG('Distance to TML is '..VDist3Sq(unit:GetPosition(), tml.position)..' cutoff is '..(tml.range * tml.range))
        if not unit.Dead and VDist3Sq(unit:GetPosition(), tml.position) < tml.range * tml.range then
            --LOG('ValidateTML there is a unit that is in range')
            if not unit['rngdata'].TMLInRange then
                unit['rngdata'].TMLInRange = {}
            end
            unit['rngdata'].TMLInRange[tml.object.EntityId] = tml.object
        end
    end,

    StructureUpgradeThreadRNG = function(self)
        local aiBrain = self.Brain
        coroutine.yield(math.random(30, 60))

        while aiBrain.Status ~= 'Defeat' do
            local im = aiBrain.IntelManager
            
            -- 1. Get current Economy Profile (Standard, Wealthy, or Stalled)
            -- This helps the managers decide if they can 'batch' multiple upgrades
            local profile, econState = self:GetEconProfile(aiBrain)
            
            -- 2. Process Shield Upgrades
            -- Shields are handled separately because they are often position-critical
            --if im.StrategyFlags.T3ShieldsAllowed then
            --    if self:CheckGlobalEcon(aiBrain, self.UpgradeConfig.SHIELD.Econ) then
            --        self:ManageShieldUpgrades(aiBrain, im)
            --    end
            --end

            -- 3. Unified Intelligence Pass (Radar + Sonar)
            -- This replaces the 4 separate IF blocks you had.
            -- It handles Land/Naval separation and tiering internally.
            self:ManageIntelligenceUpgrades(aiBrain, im, profile, econState)

            coroutine.yield(50) -- Standard 5s tick
        end
    end,

    GetEconProfile = function(self, aiBrain)
        local econ = aiBrain.EconomyOverTimeCurrent
        local econState = {
            MassStorageRatio = GetEconomyStoredRatio(aiBrain, 'MASS'),
            EnergyStorageRatio = GetEconomyStoredRatio(aiBrain, 'ENERGY'),
            MassEfficiencyOverTime = econ.MassEfficiencyOverTime or 0,
            EnergyEfficiencyOverTime = econ.EnergyEfficiencyOverTime or 0,
            MassTrendOverTime = aiBrain.EconomyOverTimeCurrent.MassTrendOverTime or 0,
            EnergyTrendOverTime = aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime or 0,
        }
        --LOG('GetEconProfile check for '..tostring(aiBrain.Nickname))
        --LOG('MassStorageRatio : '..tostring(econState.MassStorageRatio)..' EnergyStorageRatio : '..tostring(econState.EnergyStorageRatio)..' MassEfficiency : '..tostring(econState.MassEfficiencyOverTime)..' EnergyEfficnecy : '..tostring(econState.EnergyEfficiencyOverTime))

        -- PROFILE: WEALTHY
        -- If we are overflowing and efficient, we allow 'Batching' (multiple upgrades per tick)
        if econState.MassStorageRatio > 0.65 and econState.EnergyStorageRatio >= 1.0 and econState.MassEfficiencyOverTime > 1.05 and econState.EnergyEfficiencyOverTime > 1.2 then
            --LOG('EconProfile is Wealthy')
            return 'Wealthy', econState
        end

        -- PROFILE: STALLED
        -- If we are dangerously low, we block all non-emergency upgrades
        if econState.MassStorageRatio < 0.05 or econState.EnergyStorageRatio < 0.45 or econState.MassEfficiencyOverTime < 0.5 or econState.EnergyEfficiencyOverTime < 0.5 then
            --LOG('EconProfile is Stalled')
            return 'Stalled', econState
        end

        -- PROFILE: STANDARD
        -- Normal operation (one upgrade per tick max)
        --LOG('EconProfile is Standard')
        return 'Standard', econState
    end,

    ManageIntelligenceUpgrades = function(self, aiBrain, im, profile, econState)
        local mainZoneID = aiBrain.BuilderManagers['MAIN'].ZoneID
        --LOG('Manageintelligenceupgrades, main zone is '..tostring(mainZoneID))
        
        -- Process Land (Radar) and Naval (Sonar) independently
        local layerConfigs = {
            { 
                ZoneTable = aiBrain.Zones.Land.zones, 
                ZoneType = 'Land',
                ThreatKey = 'enemyantisurfacethreat' 
            },
            { 
                ZoneTable = aiBrain.Zones.Naval.zones, 
                ZoneType = 'Naval',
                ThreatKey = 'enemynavalthreat' -- As assigned in AssignIMAPThreat
            }
        }
        local countTable = self:GetIntelUpgradingCount(aiBrain)
        local currentUpgradingDrain = 0
        -- Placeholder: Assuming we add 'Maintenance' to your config
        -- Hardcoded taxes for audit: T2 (250), T3 (2000)
        local cfg = self.UpgradeConfig
        local futureEnergyCost = (countTable.RadarT1 * cfg.Radar.T1.MaintenanceCost) + (countTable.RadarT2 * cfg.Radar.T2.MaintenanceCost) + (countTable.SonarT1 * cfg.Sonar.T1.MaintenanceCost) + (countTable.SonarT2 * cfg.Sonar.T2.MaintenanceCost)
        local netTrend = econState.EnergyTrendOverTime - futureEnergyCost

        local maxRTier = 0 -- Default to Emergency Only
        if netTrend > cfg.Radar.T2.MaintenanceCost then maxRTier = 2
        elseif netTrend > cfg.Radar.T1.MaintenanceCost then maxRTier = 1 end

        local maxSTier = 0
        if netTrend > cfg.Sonar.T2.MaintenanceCost then maxSTier = 2
        elseif netTrend > cfg.Sonar.T1.MaintenanceCost then maxSTier = 1 end

        --RNGLOG(string.format("TIER_LIMITS: NetTrend=%0.1f | MaxRadar=%d | MaxSonar=%d", netTrend, maxRTier, maxSTier))

        local intelUpgradeCount = 0
        for _, config in layerConfigs do
            -- Sort zones within this layer by threat/importance
            local sortedZones = self:GetPrioritizedLayerZones(config.ZoneTable, mainZoneID, config.ThreatKey)
            
            for _, zone in sortedZones do
                intelUpgradeCount = intelUpgradeCount + self:ProcessZoneUpgrades(aiBrain, zone, config.ZoneType, im, profile, econState, futureEnergyCost)
                if intelUpgradeCount > 1 then
                    break
                end
                coroutine.yield(1)
            end
        end
    end,

    GetAppropriateIntelConfig = function(self, intelType, im, currentTech)
        local cfg = self.UpgradeConfig[intelType]
        if not cfg then return nil end

        -- If unit is T1, check if we are allowed to go to T2+
        if currentTech == 'TECH1' and (im.StrategyFlags['T2'..intelType..'Allowed'] or im.StrategyFlags['T3'..intelType..'Allowed']) then
            return cfg.T1
        end

        -- If unit is T2, check if we are allowed to go to T3
        if currentTech == 'TECH2' and im.StrategyFlags['T3'..intelType..'Allowed'] then
            return cfg.T2
        end

        return nil
    end,

    ProcessZoneUpgrades = function(self, aiBrain, zone, envType, im, profile, econState, futureEnergyCost)
        local intel = zone.intelassignment
        if not intel then return 0 end

        local intelType = (envType == 'Naval') and 'Sonar' or 'Radar'
        local searchTable = (intelType == 'Sonar') and (intel.SonarUnits or {}) or (intel.RadarUnits or {})
        
        for _, unit in searchTable do
            if not unit.Dead and not unit:IsUnitState('Upgrading') and unit.Blueprint.General.UpgradesTo then
                local currentTech = unit.Blueprint.CategoriesHash.TECH1 and 'TECH1' or 'TECH2'
                local upgradeConfig = self:GetAppropriateIntelConfig(intelType, im, currentTech)
                
                if upgradeConfig then
                    local isEmergency = (envType == 'Naval') and (zone.enemynavalthreat or 0) > 15 or (zone.enemyantisurfacethreat or 0) > 40

                    if self:CheckGlobalEcon(aiBrain, upgradeConfig, isEmergency, econState, futureEnergyCost) then
                        -- Capture specific unit data to avoid redundant engine calls downstream
                        local unitPos = unit:GetPosition()
                        local unitId = unit.EntityId
                        local targetTech = (currentTech == 'TECH1') and 'TECH2' or 'TECH3'

                        -- Use the unit's actual position instead of the zone's center
                        if not self:IsUpgradeRedundant(aiBrain, unitId, unitPos, intelType, targetTech) then
                            if self:IssueStructureUpgrade(unit) then
                                return 1
                            end
                        end
                    end
                end
            end
        end
        return 0
    end,

    CheckGlobalEcon = function(self, aiBrain, upgradeConfig, isEmergency, econState, futureEnergyCost)
        local scaledMaint = upgradeConfig.MaintenanceCost / 10
        local nTrend = (econState.EnergyTrendOverTime or 0) - ((futureEnergyCost or 0) / 10)

        local hasBudget = (nTrend > (scaledMaint * 0.75)) or (isEmergency and (nTrend > (scaledMaint * 0.25) and (econState.EnergyStorageRatio or 0) > 0.6))
        if not hasBudget then
            return false
        end
        local econConfig = upgradeConfig.Econ
        
        if econState.MassStorageRatio < econConfig.storage[1] or econState.EnergyStorageRatio < econConfig.storage[2] then
            return false
        end

        if econConfig.efficiency then
            if econState.MassEfficiencyOverTime < econConfig.efficiency then
                return false
            end
        end
        
        return true
    end,

    IsUpgradeRedundant = function(self, aiBrain, unitId, unitPos, intelType, targetTech)
        local redundancyMultiplier = 0.64 
        
        -- 1. Check existing finished units via Brain Tables
        local techLevelsToCheck = (targetTech == 'TECH2') and {'TECH2', 'TECH3'} or {'TECH3'}
        for _, tier in techLevelsToCheck do
            local existingRadars = aiBrain.Radars[tier] or {}
            for _, other in existingRadars do
                if other and not other.Dead and other.EntityId ~= unitId then
                    local range = other.Blueprint.Intel[intelType .. 'Radius']
                    if range then
                        local thresholdSq = redundancyMultiplier * (range * range)
                        local op = other:GetPosition() 
                        local dx, dz = unitPos[1] - op[1], unitPos[3] - op[3]
                        
                        if (dx * dx + dz * dz) < thresholdSq then
                            --LOG('Radar upgrade no required, distance is '..tostring(dx * dx + dz * dz)..' threshold is '..tostring(thresholdSq))
                            return true
                        end
                    end
                end
            end
        end

        -- 2. Check "Intent" from Structure Manager
        for entityID, upgradingUnit in self.UpgradingStructures do
            if not upgradingUnit.Dead and entityID ~= unitId then
                local upgradeID = upgradingUnit.Blueprint.General.UpgradesTo
                if upgradeID then
                    local targetBP = __blueprints[upgradeID]
                    local isHighEnough = (targetTech == 'TECH2' and (targetBP.CategoriesHash.TECH2 or targetBP.CategoriesHash.TECH3)) 
                                         or (targetTech == 'TECH3' and targetBP.CategoriesHash.TECH3)
                    
                    if isHighEnough and targetBP.Intel[intelType .. 'Radius'] then
                        local range = targetBP.Intel[intelType .. 'Radius']
                        local thresholdSq = redundancyMultiplier * (range * range)
                        local op = upgradingUnit:GetPosition()
                        local dx, dz = unitPos[1] - op[1], unitPos[3] - op[3]
                        
                        if (dx * dx + dz * dz) < thresholdSq then
                            --LOG('Radar upgrade no required, distance is '..tostring(dx * dx + dz * dz)..' threshold is '..tostring(thresholdSq))
                            return true
                        end
                    end
                end
            end
        end
        --LOG('Radar Upgrade is required')
        return false
    end,

    GetUpgradeCandidateInZone = function(self, zone, category)
        local intel = zone.intelassignment
        if not intel then return nil end
        
        -- Determine which table to search based on the requested category
        local searchTable = EntityCategoryContains(categories.SONAR, category) 
                            and (intel.SonarUnits or {}) 
                            or (intel.RadarUnits or {})

        for _, unit in searchTable do
            -- 1. Is it the right type (e.g. T1 Radar)?
            -- 2. Is it alive?
            -- 3. Is it already upgrading?
            if not unit.Dead and EntityCategoryContains(category, unit) then
                if not unit:IsUnitState('Upgrading') then
                    -- Bonus check: ensure the unit actually HAS an upgrade path
                    if unit.Blueprint.General.UpgradesTo then
                        return unit
                    end
                end
            end
        end
        return nil
    end,

    ManageShieldUpgrades = function(self, aiBrain)
        local config = self.UpgradeConfig.SHIELD
        
        -- 1. Global Capacity Check (Equivalent to HaveLessThanUnitsInCategoryBeingUpgradedRNG)
        -- We check if we are already at the max concurrent upgrade limit for shields
        local currentUpgrading = self:GetUpgradingCount(aiBrain, categories.STRUCTURE * categories.SHIELD)
        if currentUpgrading >= config.MaxUpgrading then 
            return 
        end

        -- 2. Tech Prerequisite Check (Equivalent to UnitsGreaterAtLocation T3 Energy)
        -- Your builder requires T3 Power to be present before upgrading T2 shields.
        -- We can check the Brain's recorded position for 'LocationType' or iterate zones.
        local t3PowerCount = aiBrain:GetNumUnitsAroundPoint(config.MinEnergyTech, aiBrain:GetArmyStartPos(), 100, 'Ally')
        if t3PowerCount < 1 then
            return
        end

        -- 3. Zone-Aware Candidate Selection
        -- Iterate through your custom ZoneStructures table
        for zoneId, zoneData in self.ZoneStructures do
            -- Future Logic: You can insert zone-specific threat checks here
            -- e.g., if zoneData.enemystructurethreat > 0 then
            
            local candidate = self:GetUpgradeCandidate(zoneId, config.Category)
            
            if candidate then
                local upgradeID = candidate.Blueprint.General.UpgradesTo
                
                -- Final sanity check on the unit state
                if upgradeID and not candidate:IsUnitState('Upgrading') then
                    -- Check for 'T2Shield4' template vs 'T2Shield' logic 
                    -- as seen in your RNGAIShieldBuilders.lua
                    IssueUpgrade({candidate}, upgradeID)
                    
                    -- We return after one issue to respect the 'InstanceCount' 
                    -- and prevent a massive mass stall in a single tick.
                    return 
                end
            end
        end
    end,

    GetUpgradingCount = function(self, aiBrain, category)
        local units = aiBrain:GetListOfUnits(category, false)
        local count = 0
        for _, v in units do
            if not v.Dead and v:IsUnitState('Upgrading') then
                count = count + 1
            end
        end
        return count
    end,

    GetUpgradeCandidate = function(self, zoneId, category)
        -- This uses your ZoneStructures table for high-speed lookup
        if self.ZoneStructures[zoneId] and self.ZoneStructures[zoneId].Units then
            for _, unit in self.ZoneStructures[zoneId].Units do
                if not unit.Dead and EntityCategoryContains(category, unit) and not unit:IsUnitState('Upgrading') then
                    -- Future logic: check zoneData.enemystructurethreat here
                    return unit
                end
            end
        end
        return nil
    end,

    IssueStructureUpgrade = function(self, unit)
        if not unit or unit.Dead or unit:IsUnitState('Upgrading') then return false end
        
        local upgradeID = unit.Blueprint.General.UpgradesTo
        --LOG('Upgrade to '..tostring(upgradeID))
        if upgradeID then
            IssueUpgrade({unit}, upgradeID)
            -- Atomic lock: prevents the thread from picking this unit again 
            -- before the engine registers the 'Upgrading' state.
            self.UpgradingStructures[unit.EntityId] = unit
            return true
        end
        return false
    end,

    GetPrioritizedLayerZones = function(self, zoneTable, mainZoneID, threatKey)
        local sorted = {}
        for id, zone in zoneTable do
            local priority = 0
            -- Essential: Main base always gets first dibs on intel/shields
            if id == mainZoneID then
                priority = priority + 1000
            end
            -- Add threat weight (enemylandthreat or enemyantisurfacethreat)
            priority = priority + (zone[threatKey] or 0)
            
            table.insert(sorted, { id = id, data = zone, score = priority })
        end
        
        table.sort(sorted, function(a, b) return a.score > b.score end)
        
        -- Return just the data objects in order
        local result = {}
        for _, v in sorted do table.insert(result, v.data) end
        return result
    end,

    GetIntelUpgradingCount = function(self, aiBrain)
        local intelUnits = aiBrain:GetListOfUnits(categories.STRUCTURE * (categories.RADAR + categories.SONAR), true)
        local counts = { RadarT1 = 0, RadarT2 = 0, SonarT1 = 0, SonarT2 = 0, Total = 0 }
        
        for _, unit in intelUnits do
            if unit and not unit.Dead then
                if unit:IsUnitState('Upgrading') then
                    local unitCats = unit.Blueprint.CategoriesHash
                    if unitCats.RADAR then
                        if unitCats.TECH1 then
                            counts.RadarT1 = counts.RadarT1 + 1
                        elseif unitCats.TECH2 then
                            counts.RadarT2 = counts.RadarT2 + 1
                        end
                    elseif unitCats.SONAR then
                        if unitCats.TECH1 then
                            counts.SonarT1 = counts.SonarT1 + 1
                        elseif unitCats.TECH2 then
                            counts.SonarT2 = counts.SonarT2 + 1
                        end
                    end
                    counts.Total = counts.Total + 1
                end
            end
        end
        return counts
    end,
}

DummyManager = Class {
    Create = function(self)
        self.FactoryList = {}
    end,
    SetEnabled = function(self)
        return
    end,
    Destroy = function(self)
        return
    end,
}

function GetStructureManager(brain)
    return brain.StructureManager
end

function CreateStructureManager(brain)
    local sm 
    sm = StructureManager()
    sm:Create(brain)
    return sm
end

function CreateDummyManager(brain)
    local dm
    dm = DummyManager()
    dm:Create()
    return dm
end