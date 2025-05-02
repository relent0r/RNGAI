local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG
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
        self.ShieldCoverage = {}
        self.TMDRequired = false
        self.StructuresRequiringTMD = {}
        self.ExtractorUpgradeQueue = {}
    end,

    Run = function(self)
       --LOG('RNGAI : StructureManager Starting')
        self:ForkThread(self.FactoryDataCaptureRNG)
        self:ForkThread(self.EcoExtractorUpgradeCheckRNG, self.Brain)
        self:ForkThread(self.CheckDefensiveCoverage)
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

    FactoryDataCaptureRNG = function(self)
        -- Lets try be smart about how we do this
        -- This captures the current factory states, replaces all those builder conditions
        -- Note it uses the factory managers rather than getlistofunits
        -- This means we won't capture factories that are potentially given in fullshare
        -- So I might need to manage that somewhere else
        -- Or maybe we should just use getlistofunits instead but then we won't know which base they are in.. tbd
        coroutine.yield(Random(5,20))
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
            for baseName, manager in self.Brain.BuilderManagers do
                if baseName ~= 'FLOATING' then
                    if manager.FactoryManager.FactoryList and not table.empty(manager.FactoryManager.FactoryList) then
                        local massToFactoryValues = manager.BaseSettings.MassToFactoryValues
                        for c, unit in manager.FactoryManager.FactoryList do
                            local unitCat = unit.Blueprint.CategoriesHash
                            if not IsDestroyed(unit) then
                                if unitCat.LAND then
                                    if unitCat.TECH1 then
                                        RNGINSERT(FactoryData.T1LAND, unit)
                                        if unit:IsUnitState('Upgrading') then
                                            FactoryData.T1LANDUpgrading = FactoryData.T1LANDUpgrading + 1
                                        end
                                        FactoryData.TotalT1LAND = FactoryData.TotalT1LAND + 1
                                        FactoryData.T1LANDApproxConsumption = FactoryData.T1LANDApproxConsumption + massToFactoryValues.T1LandValue
                                    elseif unitCat.TECH2 then
                                        RNGINSERT(FactoryData.T2LAND, unit)
                                        if not unitCat.SUPPORTFACTORY then
                                            if not FactoryData.T2LANDHQCount[unit.UnitId] then
                                                FactoryData.T2LANDHQCount[unit.UnitId] = 0
                                            end
                                            FactoryData.T2LANDHQCount[unit.UnitId] = FactoryData.T2LANDHQCount[unit.UnitId] + 1
                                        end
                                        if unit:IsUnitState('Upgrading') then
                                            FactoryData.T2LANDUpgrading = FactoryData.T2LANDUpgrading + 1
                                        end
                                        FactoryData.TotalT2LAND = FactoryData.TotalT2LAND + 1
                                        FactoryData.T2LANDApproxConsumption = FactoryData.T2LANDApproxConsumption + massToFactoryValues.T2LandValue
                                    elseif unitCat.TECH3 then
                                        RNGINSERT(FactoryData.T3LAND, unit)
                                        if not unitCat.SUPPORTFACTORY then
                                            if not FactoryData.T3LANDHQCount[unit.UnitId] then
                                                FactoryData.T3LANDHQCount[unit.UnitId] = 0
                                            end
                                            FactoryData.T3LANDHQCount[unit.UnitId] = FactoryData.T3LANDHQCount[unit.UnitId] + 1
                                        end
                                        FactoryData.TotalT3LAND = FactoryData.TotalT3LAND + 1
                                        FactoryData.T3LANDApproxConsumption = FactoryData.T3LANDApproxConsumption + massToFactoryValues.T3LandValue
                                    end
                                elseif unitCat.AIR then
                                    if unitCat.TECH1 then
                                        RNGINSERT(FactoryData.T1AIR, unit)
                                        if unit:IsUnitState('Upgrading') then
                                            FactoryData.T1AIRUpgrading = FactoryData.T1AIRUpgrading + 1
                                        end
                                        FactoryData.TotalT1AIR = FactoryData.TotalT1AIR + 1
                                        FactoryData.T1AIRApproxConsumption = FactoryData.T1AIRApproxConsumption + massToFactoryValues.T1AirValue
                                    elseif unitCat.TECH2 then
                                        RNGINSERT(FactoryData.T2AIR, unit)
                                        if not unitCat.SUPPORTFACTORY then
                                            if not FactoryData.T2AIRHQCount[unit.UnitId] then
                                                FactoryData.T2AIRHQCount[unit.UnitId] = 0
                                            end
                                            FactoryData.T2AIRHQCount[unit.UnitId] = FactoryData.T2AIRHQCount[unit.UnitId] + 1
                                        end
                                        if unit:IsUnitState('Upgrading') then
                                            FactoryData.T2AIRUpgrading = FactoryData.T2AIRUpgrading + 1
                                        end
                                        FactoryData.TotalT2AIR = FactoryData.TotalT2AIR + 1
                                        FactoryData.T2AIRApproxConsumption = FactoryData.T2AIRApproxConsumption + massToFactoryValues.T2AirValue
                                    elseif unitCat.TECH3 then
                                        RNGINSERT(FactoryData.T3AIR, unit)
                                        if not unitCat.SUPPORTFACTORY then
                                            if not FactoryData.T3AIRHQCount[unit.UnitId] then
                                                FactoryData.T3AIRHQCount[unit.UnitId] = 0
                                            end
                                            FactoryData.T3AIRHQCount[unit.UnitId] = FactoryData.T3AIRHQCount[unit.UnitId] + 1
                                        end
                                        FactoryData.TotalT3AIR = FactoryData.TotalT3AIR + 1
                                        FactoryData.T3AIRApproxConsumption = FactoryData.T3AIRApproxConsumption + massToFactoryValues.T3AirValue
                                    end
                                elseif unitCat.NAVAL then
                                    if unitCat.TECH1 then
                                        RNGINSERT(FactoryData.T1NAVAL, 1, unit)
                                        if unit:IsUnitState('Upgrading') then
                                            FactoryData.T1NAVALUpgrading = FactoryData.T1NAVALUpgrading + 1
                                        end
                                        FactoryData.TotalT1NAVAL = FactoryData.TotalT1NAVAL + 1
                                        FactoryData.T1NAVALApproxConsumption = FactoryData.T1NAVALApproxConsumption + massToFactoryValues.T1NavalValue
                                    elseif unitCat.TECH2 then
                                        RNGINSERT(FactoryData.T2NAVAL, unit)
                                        if not unitCat.SUPPORTFACTORY then
                                            if not FactoryData.T2NAVALHQCount[unit.UnitId] then
                                                FactoryData.T2NAVALHQCount[unit.UnitId] = 0
                                            end
                                            FactoryData.T2NAVALHQCount[unit.UnitId] = FactoryData.T2NAVALHQCount[unit.UnitId] + 1
                                        end
                                        if unit:IsUnitState('Upgrading') then
                                            FactoryData.T2NAVALUpgrading = FactoryData.T2NAVALUpgrading + 1
                                        end
                                        FactoryData.TotalT2NAVAL = FactoryData.TotalT2NAVAL + 1
                                        FactoryData.T2NAVALApproxConsumption = FactoryData.T2NAVALApproxConsumption + massToFactoryValues.T2NavalValue
                                    elseif unitCat.TECH3 then
                                        RNGINSERT(FactoryData.T3NAVAL, unit)
                                        if not unitCat.SUPPORTFACTORY then
                                            if not FactoryData.T3NAVALHQCount[unit.UnitId] then
                                                FactoryData.T3NAVALHQCount[unit.UnitId] = 0
                                            end
                                            FactoryData.T3NAVALHQCount[unit.UnitId] = FactoryData.T3NAVALHQCount[unit.UnitId] + 1
                                        end
                                        FactoryData.TotalT3NAVAL = FactoryData.TotalT3NAVAL + 1
                                        FactoryData.T3NAVALApproxConsumption = FactoryData.T3NAVALApproxConsumption + massToFactoryValues.T3NavalValue
                                    end
                                end
                            end
                        end
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

        -- HQ Upgrades
        local mexSpend = aiBrain.EcoManager.TotalMexSpend or 0
        local actualMexIncome = aiBrain.cmanager.income.r.m - mexSpend
        local massEfficiencyOverTime = aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime
        local energyEfficiencyOverTime = aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime
        local disableForT3AirRushStrategy = aiBrain.BrainIntel.PlayerStrategy.T3AirRush
        --RNGLOG('Actual Mex Income '..actualMexIncome)

        local t2LandPass = false
        if totalLandT2HQCount < 1 and totalLandT3HQCount < 1 and self.Factories.LAND[1].UpgradingCount < 1 and self.Factories.LAND[1].Total > 0 and not disableForT3AirRushStrategy then
            if aiBrain:GetCurrentUnits(categories.ENGINEER * categories.TECH1) > 2 then
                local distanceByPass = (aiBrain.EnemyIntel.ClosestEnemyBase and aiBrain.EnemyIntel.ClosestEnemyBase > 422500 ) and actualMexIncome >= (15 * multiplier) and aiBrain.EconomyOverTimeCurrent.EnergyIncome > 26.0
                if (not aiBrain.RNGEXP and (actualMexIncome > (23 * multiplier) or aiBrain.EnemyIntel.EnemyCount > 1 and actualMexIncome > (15 * multiplier)))
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
        local airRush = (aiBrain.amanager.Demand.Air.T2.torpedo > 0 or aiBrain.RNGEXP or aiBrain.BrainIntel.PlayerRole.AirPlayer or (factionIndex == 2 and actualMexIncome > (25 * multiplier)))
        if airRush and totalAirT2HQCount < 1 and totalAirT3HQCount < 1 and self.Factories.AIR[1].UpgradingCount < 1 then
            --LOG('Air Player first factory upgrade checking if massEfficiencyOverTime '..tostring(massEfficiencyOverTime)..' energyEfficiencyOverTime '..tostring(energyEfficiencyOverTime))
            if aiBrain:GetCurrentUnits(categories.ENGINEER * categories.TECH1) > 2 then
                if aiBrain.EconomyOverTimeCurrent.EnergyIncome > 32.0 and massEfficiencyOverTime >= 0.8 and (airRush and energyEfficiencyOverTime >= 0.85 or energyEfficiencyOverTime >= 1.05) then
                    --LOG('Factory Upgrade efficiency over time check passed for air upgrade')
                    local EnergyEfficiency = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
                    local MassEfficiency = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
                    --LOG('Air Player first factory upgrade checking if massEfficiency '..tostring(MassEfficiency)..' energyEfficiency '..tostring(EnergyEfficiency))
                    if MassEfficiency >= 0.8 and (airRush and EnergyEfficiency >= 0.85 or EnergyEfficiency >= 1.05)  then
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
            if self.Factories.LAND[1].UpgradingCount < 2 then
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
        if not t3AirPass and (aiBrain.RNGEXP or aiBrain.BrainIntel.PlayerRole.AirPlayer) and totalAirT3HQCount < 1 and totalAirT2HQCount > 0 and self.Factories.AIR[2].UpgradingCount < 1 and self.Factories.AIR[2].Total > 0 then
            if aiBrain.EconomyOverTimeCurrent.MassIncome > (2.5 * multiplier) and aiBrain.EconomyOverTimeCurrent.EnergyIncome > 100.0 then
                --RNGLOG('Factory Upgrade Income Over time check passed')
                if GetEconomyIncome(aiBrain,'MASS') >= (2.5 * multiplier) and GetEconomyIncome(aiBrain,'ENERGY') >= 100.0 then
                    --RNGLOG('Factory Upgrade Income check passed')
                    if massEfficiencyOverTime >= 1.0 and energyEfficiencyOverTime >= 1.0 then
                        --RNGLOG('Factory Upgrade efficiency over time check passed')
                        local EnergyEfficiency = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
                        local MassEfficiency = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
                        if MassEfficiency >= 1.0 and EnergyEfficiency >= 1.00 then
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
                if (actualMexIncome > (30 * multiplier) or aiBrain.EnemyIntel.NavalPhase > 1 and actualMexIncome > (23 * multiplier)) and aiBrain.EconomyOverTimeCurrent.EnergyIncome > 50.0 then
                    if massEfficiencyOverTime >= 1.015 and energyEfficiencyOverTime >= 1.0 or aiBrain.EnemyIntel.NavalPhase > 1 and massEfficiencyOverTime >= 0.8 and energyEfficiencyOverTime >= 1.0 then
                        local EnergyEfficiency = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
                        local MassEfficiency = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
                        if MassEfficiency >= 1.015 and EnergyEfficiency >= 1.0 or aiBrain.EnemyIntel.NavalPhase > 1 and MassEfficiency >= 0.8 and EnergyEfficiency >= 1.0 then
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
                if aiBrain.EconomyOverTimeCurrent.MassIncome > (8.0 * multiplier) and aiBrain.EconomyOverTimeCurrent.EnergyIncome > 150.0 then
                    if GetEconomyIncome(aiBrain,'MASS') >= (8.0 * multiplier) and GetEconomyIncome(aiBrain,'ENERGY') >= 150.0 then
                        if massEfficiencyOverTime >= 1.025 and energyEfficiencyOverTime >= 1.05 then
                            local EnergyEfficiency = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
                            local MassEfficiency = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
                            if MassEfficiency >= 1.05 and EnergyEfficiency >= 1.05 then
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
                --RNGLOG('Active Expansion is '..activeExpansion)
                local activeExpansionPass = false
                if (totalLandT2HQCount > 0 or totalLandT3HQCount > 0) and self.Factories.LAND[1].Total > 0 and self.Factories.LAND[2].Total < 11 then
                    --RNGLOG('Factory T1 Upgrade Support Check passed')
                    --RNGLOG('Performing Upgrade Check '..activeExpansion)
                    --RNGLOG('T2 Factory count at active expansion '..self:LocationFactoryCountRNG(aiBrain, categories.LAND * categories.FACTORY * categories.TECH2, activeExpansion))
                    if self:LocationFactoryCountRNG(aiBrain, categories.LAND * categories.FACTORY * categories.TECH2, activeExpansion) < 2 then
                        if self.Factories.LAND[1].UpgradingCount < 3 then
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
                        if self.Factories.LAND[1].UpgradingCount < 3 then
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
                        if self.Factories.LAND[2].UpgradingCount < 3 then
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
                        if self.Factories.LAND[2].UpgradingCount < 3 then
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

                if not expansionPass then
                    if (totalLandT2HQCount > 0 or totalLandT3HQCount > 0) and self.Factories.LAND[1].Total > 0 and self.Factories.LAND[2].Total < 11 then
                        --RNGLOG('Factory T1 Upgrade Support Check passed')
                        --RNGLOG('Performing Upgrade Check '..activeExpansion)
                        --RNGLOG('T2 Factory count at active expansion '..self:LocationFactoryCountRNG(aiBrain, categories.LAND * categories.FACTORY * categories.TECH2, activeExpansion))
                        if self:LocationFactoryCountRNG(aiBrain, categories.LAND * categories.FACTORY * categories.TECH2, locationType) < 2 then
                            if self.Factories.LAND[1].UpgradingCount < 3 then
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
                            if self.Factories.LAND[1].UpgradingCount < 3 then
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
                            if self.Factories.LAND[2].UpgradingCount < 2 then
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
                            if self.Factories.LAND[2].UpgradingCount < 2 then
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
            coroutine.yield(10)
            if (not IsDestroyed(unit)) and (not IsDestroyed(unit.UnitBeingBuilt)) then
                local upgradedFactory = unit.UnitBeingBuilt
                local fractionComplete = upgradedFactory:GetFractionComplete()
                unit.Upgrading = true
                unit.Offline = true
                if hq == 'LAND' then
                    self.Brain.EngineerAssistManagerFocusLandUpgrade = true
                elseif hq =='AIR' then
                    self.Brain.EngineerAssistManagerFocusAirUpgrade = true
                    
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
                if hq == 'LAND' then
                    self.Brain.EngineerAssistManagerFocusLandUpgrade = false
                    if self.Brain.EngineerAssistManagerFocusCategory == categories.FACTORY * categories.AIR - categories.SUPPORTFACTORY then
                        self.Brain.EngineerAssistManagerFocusCategory = false
                    end
                elseif hq =='AIR' then
                    self.Brain.EngineerAssistManagerFocusAirUpgrade = false
                    if self.Brain.EngineerAssistManagerFocusCategory == categories.FACTORY * categories.LAND - categories.SUPPORTFACTORY then
                        self.Brain.EngineerAssistManagerFocusCategory = false
                    end
                    if self.Brain.BrainIntel.PlayerStrategy.T3AirRush and upgradedFactory.Blueprint.CategoriesHash.TECH3 then
                        self.Brain.BrainIntel.PlayerStrategy.T3AirRush = false
                    end
                end
                unit.Upgrading = false
                unit.Offline = false
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
            local multiplier = aiBrain.EcoManager.EcoMultiplier
            local upgradeTrigger = false
            local upgradeSpend = aiBrain.cmanager.income.r.m*aiBrain.EconomyUpgradeSpend
            if upgradeSpend > 4 or GetGameTimeSeconds() > (420 / multiplier) or aiBrain.BrainIntel.PlayerRole.AirPlayer or aiBrain.BrainIntel.PlayerRole.ExperimentalPlayer or self.BrainIntel.HighestPhase > 1 then
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
            --LOG('{ "GameTime" : '..tostring(currentTime)..', "Nickname": "'..tostring(aiBrain.Nickname)..'" }')
            --LOG('{ "GameTime" : '..tostring(currentTime)..', "CoreT3Extractors" : "'..tostring(aiBrain.EcoManager.CoreExtractorT3Count)..'" }')
            --LOG('{ "GameTime" : '..tostring(currentTime)..', "CoreExtractorsTotal" : "'..tostring(aiBrain.EcoManager.TotalCoreExtractors)..'" }')
            --LOG('TotalExtractorSpend : '..tostring(totalSpend))
            --LOG('{ "GameTime" : '..tostring(currentTime)..', "TotalAllowedExtractorSpend" : "'..tostring(upgradeSpend)..'" }')
            --LOG('AvailableExtractorUpgradeSpend'..tostring(upgradeSpend - totalSpend))
            --LOG('{ "GameTime" : '..tostring(currentTime)..', "CurrentT3ExtractorUpgradeSpend" : "'..tostring(tech2Consumption)..'" }')
            --LOG('T1ExtractorUpgradeCount '..tostring(extractorsDetail.TECH1Upgrading))
            --LOG('T2ExtractorUpgradeCount '..tostring(extractorsDetail.TECH2Upgrading))
            --LOG('Current T2 to T1 extractor ratio '..tostring(extractorsDetail.TECH2 / extractorsDetail.TECH1))
            


            if aiBrain.EcoManager.CoreExtractorT3Count < 3 and aiBrain.EcoManager.TotalCoreExtractors > 2 and aiBrain.cmanager.income.r.m > (140 * multiplier) and (aiBrain.smanager.Current.Structure.fact.Land.T3 > 0 or aiBrain.smanager.Current.Structure.fact.Air.T3 > 0) and aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= 1.0 and currentEnergyEfficiency >= 1.0 then
                aiBrain.EcoManager.CoreMassPush = true
                --RNGLOG('Assist Focus is Mass extraction')
                aiBrain.EngineerAssistManagerFocusCategory = categories.MASSEXTRACTION
            elseif aiBrain.EcoManager.CoreMassPush then
                aiBrain.EcoManager.CoreMassPush = false
                --RNGLOG('Assist Focus is set to false from Extractor upgrade manager')
                if aiBrain.EngineerAssistManagerFocusCategory == categories.MASSEXTRACTION then
                    aiBrain.EngineerAssistManagerFocusCategory = false
                end
            end

            local massEfficiencyOverTime = aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime
            local massStorage = GetEconomyStored( aiBrain, 'MASS')
            local energyEfficiencyOverTime = aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime
            local energyStorage = GetEconomyStored( aiBrain, 'ENERGY')
            local coreExtractorT2Count = aiBrain.EcoManager.CoreExtractorT2Count
            --LOG('Energy Efficiency over time '..tostring(energyEfficiencyOverTime))
            --LOG('Energy Efficiency '..tostring(currentEnergyEfficiency))

            if aiBrain.EcoManager.CoreMassPush and extractorsDetail.TECH2Upgrading < 1 and aiBrain.cmanager.income.r.m > (140 * multiplier) then
                --LOG('Trigger all tiers true')
                self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, true)
                coroutine.yield(60)
                continue
            end
            if massStorage > 1500 and aiBrain.EcoManager.CoreExtractorT3Count < aiBrain.EcoManager.CoreMassMarkerCount
            and coreExtractorT2Count > 0
            and aiBrain.BrainIntel.SelfThreat.ExtractorCount > aiBrain.BrainIntel.MassSharePerPlayer 
            and extractorsDetail.TECH2Upgrading < aiBrain.EcoManager.CoreMassMarkerCount 
            and energyEfficiencyOverTime > 1.1 and currentEnergyEfficiency >= 1.1 and energyStorage > 8000 then
                --LOG('We Could upgrade an extractor now with over time of 1.1 and energy storage of 8000')
                self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, true)
                coroutine.yield(80)
                continue
            elseif (coreExtractorT2Count + aiBrain.EcoManager.CoreExtractorT3Count >= aiBrain.EcoManager.TotalCoreExtractors and (upgradeSpend > tech2Consumption * 2.2) or 
            coreExtractorT2Count + aiBrain.EcoManager.CoreExtractorT3Count >= 4 and (upgradeSpend > tech2Consumption * 2.2)) 
            and extractorsDetail.TECH2Upgrading < 1 and aiBrain.BrainIntel.SelfThreat.ExtractorCount > aiBrain.BrainIntel.MassSharePerPlayer  
            and coreExtractorT2Count > 0
            and energyStorage > 8000 and energyEfficiencyOverTime > 1.1 and currentEnergyEfficiency >= 1.1 then
                --LOG('Extractor upgrade triggered due to massshareperplayer being higher than average')
                self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, true)
                coroutine.yield(80)
                continue
            elseif massStorage > 2500 and energyStorage > 8000 and energyEfficiencyOverTime > 1.1 and currentEnergyEfficiency >= 1.1 and extractorsDetail.TECH2Upgrading < 2 then
                --LOG('We Could upgrade an extractor now with over time')
                self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, true)
                coroutine.yield(80)
                continue
            end
            if extractorsDetail.TECH1Upgrading < 5 and extractorsDetail.TECH2Upgrading < 2 and upgradeTrigger and (totalSpend < upgradeSpend or massStorage > 800) and 
                   energyEfficiencyOverTime >= 1.0 and currentEnergyEfficiency >= 1.0 and not aiBrain.BrainIntel.PlayerRole.SpamPlayer and extractorsDetail.TECH2 > 0 and 
                   (upgradeSpend > (tech2Consumption / 2) or extractorsDetail.TECH1 == 0) and (upgradeSpend > tech2Consumption * 2.2) then
                        --LOG('We Could upgrade a t2 extractor now with over time and we are not already upgrading t2')
                        self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, true)
                        coroutine.yield(30)
            elseif extractorsDetail.TECH1Upgrading < 4 and extractorsDetail.TECH2Upgrading < 1 and upgradeTrigger and (totalSpend < upgradeSpend or massStorage > 600 or upgradeSpend - totalSpend > (tech2Consumption / 2) or upgradeSpend > tech2Consumption) and 
                    energyEfficiencyOverTime >= 1.0 and currentEnergyEfficiency >= 1.0 and not aiBrain.BrainIntel.PlayerRole.SpamPlayer and extractorsDetail.TECH2 > 0 and 
                    (extractorsDetail.TECH1 > 0 and (extractorsDetail.TECH2 / extractorsDetail.TECH1 >= 1.2) or extractorsDetail.TECH1 == 0) then
                        --LOG('We Could upgrade a t2 extractor now with over time ratio 1.2 and we are not already upgrading t2')
                        self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, true)
                        coroutine.yield(30)
            elseif extractorsDetail.TECH1Upgrading < 3 and extractorsDetail.TECH2Upgrading < 1 and upgradeTrigger and (totalSpend < upgradeSpend or massStorage > 600) and 
                   energyEfficiencyOverTime >= 1.0 and currentEnergyEfficiency >= 1.0 and not aiBrain.BrainIntel.PlayerRole.SpamPlayer and extractorsDetail.TECH1 > 0 and extractorsDetail.TECH2 > 0 and 
                   ((extractorsDetail.TECH1 / extractorsDetail.TECH2 >= 1.7) or upgradeSpend < 15) and (upgradeSpend < tech2Consumption) then
                        --LOG('We Could upgrade a t1 extractor now with over time ratio 1.7 and we are not already upgrading t2')
                        self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, false)
                        coroutine.yield(30)
            elseif extractorsDetail.TECH1 > 0 and extractorsDetail.TECH1Upgrading < 1 and extractorsDetail.TECH2Upgrading > 0 and upgradeTrigger and totalSpend < upgradeSpend 
                   and energyEfficiencyOverTime >= 1.0 and currentEnergyEfficiency >= 1.0 and not aiBrain.BrainIntel.PlayerRole.SpamPlayer then
                    --LOG('Upgrading the minimum number t1 ')
                    self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, false)
                    coroutine.yield(60)
            elseif extractorsDetail.TECH1 > 0 and extractorsDetail.TECH1Upgrading < 4 and upgradeTrigger and (totalSpend < upgradeSpend or massStorage > 450) 
                   and energyEfficiencyOverTime >= 1.0 and currentEnergyEfficiency >= 1.0 and not aiBrain.BrainIntel.PlayerRole.SpamPlayer and massStorage < 2500 then
                    --LOG('Upgrading if we have less than 5 t1 upgrading t1')
                    self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, false)
                    coroutine.yield(60)
            elseif massStorage > 500 and energyStorage > 3000 and extractorsDetail.TECH2Upgrading < 2 and coreExtractorT2Count + aiBrain.EcoManager.CoreExtractorT3Count >= aiBrain.EcoManager.TotalCoreExtractors 
                   and massEfficiencyOverTime >= 1.015 and energyEfficiencyOverTime >= 1.1 and currentEnergyEfficiency >= 1.1 and currentMassEfficiency >= 1.015 then
                    --LOG('We Could upgrade an extractor now with storage and efficiency t2')
                    self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, true)
                    coroutine.yield(30)
            elseif massStorage > 2500 and energyStorage > 8000 and massEfficiencyOverTime >= 0.8 and energyEfficiencyOverTime >= 0.9 and currentEnergyEfficiency >= 1.05 and currentMassEfficiency > 0.8 then
                    --LOG('We could update an extractor because we have alot of mass storage')
                    self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, true)
                    coroutine.yield(30)
            elseif extractorsDetail.TECH1 > 0 and extractorsDetail.TECH1Upgrading < 8 and extractorsDetail.TECH2Upgrading > 0 and upgradeTrigger and totalSpend < upgradeSpend 
                and energyEfficiencyOverTime >= 1.0 and currentEnergyEfficiency >= 1.0 and not aiBrain.BrainIntel.PlayerRole.SpamPlayer then
                --LOG('Upgrading the minimum number t1 ')
                 self:ValidateExtractorUpgradeRNG(aiBrain, extractorTable, false)
                 coroutine.yield(30)
            end
            coroutine.yield(30)
        end
    end,

    StructureTMLCheck = function(self, structure, optionalUnit)
        local defended = true
        local TMLInRange = 0
        local TMDCount = 0
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
                local structurePos = structure:GetPosition()
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
        local bestZone, bestExtractor, lowestDist
        local basePosition = aiBrain.BuilderManagers['MAIN'].Position
        
        local zoneExtractors = {
            Land = {},
            Naval = {},
        }

        for tier, extractors in extractorTable do
            if allTiers or tier == "TECH1" then
                for _, c in extractors do
                    if c and not c.Dead and c.InitialDelayCompleted then
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
                if zone then
                    local zoneDist = VDist2Sq(basePosition[1], basePosition[3], zone.pos[1], zone.pos[3])
                    for _, c in extractors do
                        if not bestExtractor or zoneDist < lowestDist then
                            bestExtractor = c
                            bestZone = zoneID
                            lowestDist = zoneDist
                        end
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
                --LOG('Starting Upgrade queue thread')
                aiBrain.ExtractorUpgradeThread = self:ForkThread(self.UpgradeManagementThread, aiBrain)
            end
            aiBrain.CentralBrainExtractorUnitUpgradeClosest = bestExtractor
            -- Trigger the upgrade process
            self:ForkThread(self.AddExtractorToUpgradeQueue, aiBrain, bestExtractor, distanceToBase)
            --LOG('Added Extractor')
        else
            --LOG('No valid extractor found for upgrade.')
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
                for i, extractorInfo in ipairs(upgradeManagementQueue) do
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
            local structures = self.Brain:GetListOfUnits((categories.MASSEXTRACTION + categories.FACTORY) - categories.TECH1  + categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3), true)
            local tmdRequired = {}
            local shieldRequired = {}
            for _, v in structures do
                local isTMDDefended = self:StructureTMLCheck(v)
                if not isTMDDefended then
                    RNGINSERT(tmdRequired, {Unit = v, Assigned = false, AssignedEngineer = nil})
                end
                local isShieldDefended = self:StructureShieldCheck(v)
                if not isShieldDefended then
                    RNGINSERT(shieldRequired, v)
                end
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

function GetStructureManager(brain)
    return brain.StructureManager
end