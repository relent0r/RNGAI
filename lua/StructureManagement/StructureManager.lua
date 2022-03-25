local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local GetEconomyIncome = moho.aibrain_methods.GetEconomyIncome
local GetEconomyRequested = moho.aibrain_methods.GetEconomyRequested
local GetEconomyStored = moho.aibrain_methods.GetEconomyStored

local RNGGETN = table.getn
local RNGINSERT = table.insert
local RNGREMOVE = table.remove
local RNGSORT = table.sort

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
    end,

    Run = function(self)
        LOG('RNGAI : StructureManager Starting')
        self:ForkThread(self.FactoryDataCaptureRNG)
        if self.Debug then
            self:ForkThread(self.StructureDebugThread)
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

    FactoryDataCaptureRNG = function(self)
        -- Lets try be smart about how we do this
        -- This captures the current factory states, replaces all those builder conditions
        -- Note it uses the factory managers rather than getlistofunits
        -- This means we won't capture factories that are potentially given in fullshare
        -- So I might need to manage that somewhere else
        -- Or maybe we should just use getlistofunits instead but then we won't know which base they are in.. tbd
        coroutine.yield(Random(5,20))
        local ALLBPS = __blueprints
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
            for k, manager in self.Brain.BuilderManagers do
                if RNGGETN(manager.FactoryManager.FactoryList) > 0 then
                    for c, unit in manager.FactoryManager.FactoryList do
                        if not unit.Dead and not unit:BeenDestroyed() then
                            if ALLBPS[unit.UnitId].CategoriesHash.LAND then
                                if ALLBPS[unit.UnitId].CategoriesHash.TECH1 then
                                    RNGINSERT(FactoryData.T1LAND, unit)
                                    if unit:IsUnitState('Upgrading') then
                                        FactoryData.T1LANDUpgrading = FactoryData.T1LANDUpgrading + 1
                                    end
                                    FactoryData.TotalT1LAND = FactoryData.TotalT1LAND + 1
                                elseif ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                                    RNGINSERT(FactoryData.T2LAND, unit)
                                    if not ALLBPS[unit.UnitId].CategoriesHash.SUPPORTFACTORY then
                                        FactoryData.T2LANDHQCount[unit.UnitId] = FactoryData.T2LANDHQCount[unit.UnitId] + 1
                                    end
                                    if unit:IsUnitState('Upgrading') then
                                        FactoryData.T2LANDUpgrading = FactoryData.T2LANDUpgrading + 1
                                    end
                                    FactoryData.TotalT2LAND = FactoryData.TotalT2LAND + 1
                                elseif ALLBPS[unit.UnitId].CategoriesHash.TECH3 then
                                    RNGINSERT(FactoryData.T3LAND, unit)
                                    if not ALLBPS[unit.UnitId].CategoriesHash.SUPPORTFACTORY then
                                        FactoryData.T3LANDHQCount[unit.UnitId] = FactoryData.T3LANDHQCount[unit.UnitId] + 1
                                    end
                                    FactoryData.TotalT3LAND = FactoryData.TotalT3LAND + 1
                                end
                            elseif ALLBPS[unit.UnitId].CategoriesHash.AIR then
                                if ALLBPS[unit.UnitId].CategoriesHash.TECH1 then
                                    RNGINSERT(FactoryData.T1AIR, unit)
                                    if unit:IsUnitState('Upgrading') then
                                        FactoryData.T1AIRUpgrading = FactoryData.T1AIRUpgrading + 1
                                    end
                                    FactoryData.TotalT1AIR = FactoryData.TotalT1AIR + 1
                                elseif ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                                    RNGINSERT(FactoryData.T2AIR, unit)
                                    if not ALLBPS[unit.UnitId].CategoriesHash.SUPPORTFACTORY then
                                        FactoryData.T2AIRHQCount[unit.UnitId] = FactoryData.T2AIRHQCount[unit.UnitId] + 1
                                    end
                                    if unit:IsUnitState('Upgrading') then
                                        FactoryData.T2AIRUpgrading = FactoryData.T2AIRUpgrading + 1
                                    end
                                    FactoryData.TotalT2AIR = FactoryData.TotalT2AIR + 1
                                elseif ALLBPS[unit.UnitId].CategoriesHash.TECH3 then
                                    RNGINSERT(FactoryData.T3AIR, unit)
                                    if not ALLBPS[unit.UnitId].CategoriesHash.SUPPORTFACTORY then
                                        FactoryData.T3AIRHQCount[unit.UnitId] = FactoryData.T3AIRHQCount[unit.UnitId] + 1
                                    end
                                    FactoryData.TotalT3AIR = FactoryData.TotalT3AIR + 1
                                end

                            elseif ALLBPS[unit.UnitId].CategoriesHash.NAVAL then
                                if ALLBPS[unit.UnitId].CategoriesHash.TECH1 then
                                    RNGINSERT(FactoryData.T1NAVAL, 1, unit)
                                    if unit:IsUnitState('Upgrading') then
                                        FactoryData.T1NAVALUpgrading = FactoryData.T1NAVALUpgrading + 1
                                    end
                                    FactoryData.TotalT1NAVAL = FactoryData.TotalT1NAVAL + 1
                                elseif ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                                    RNGINSERT(FactoryData.T2NAVAL, unit)
                                    if not ALLBPS[unit.UnitId].CategoriesHash.SUPPORTFACTORY then
                                        FactoryData.T2NAVALHQCount[unit.UnitId] = FactoryData.T2NAVALHQCount[unit.UnitId] + 1
                                    end
                                    if unit:IsUnitState('Upgrading') then
                                        FactoryData.T2NAVALUpgrading = FactoryData.T2NAVALUpgrading + 1
                                    end
                                    FactoryData.TotalT1NAVAL = FactoryData.TotalT1NAVAL + 1
                                elseif ALLBPS[unit.UnitId].CategoriesHash.TECH3 then
                                    RNGINSERT(FactoryData.T3NAVAL, unit)
                                    if not ALLBPS[unit.UnitId].CategoriesHash.SUPPORTFACTORY then
                                        FactoryData.T3NAVALHQCount[unit.UnitId] = FactoryData.T3NAVALHQCount[unit.UnitId] + 1
                                    end
                                    FactoryData.TotalT1NAVAL = FactoryData.TotalT1NAVAL + 1
                                end
                            end
                        end
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
            self.Factories.AIR[2].Total = FactoryData.TotalT2AIR
            self.Factories.NAVAL[1].UpgradingCount = FactoryData.T1NAVALUpgrading
            self.Factories.NAVAL[1].Total = FactoryData.TotalT1NAVAL
            self.Factories.NAVAL[2].UpgradingCount = FactoryData.T2NAVALUpgrading
            self.Factories.NAVAL[2].Total = FactoryData.TotalT2NAVAL
            self.Factories.NAVAL[2].HQCount = FactoryData.T2NAVALHQCount
            self.Factories.NAVAL[3].HQCount = FactoryData.T3NAVALHQCount
            self.Factories.NAVAL[3].Total = FactoryData.TotalT3NAVAL
            LOG('Structure Manager')
            LOG('Number of upgrading T1 Land '..self.Factories.LAND[1].UpgradingCount)
            LOG('Number of upgrading T2 Land '..self.Factories.LAND[2].UpgradingCount)
            LOG('Number of HQs T2 Land '..repr(self.Factories.LAND[2].HQCount))
            LOG('Number of HQs T3 Land '..repr(self.Factories.LAND[3].HQCount))
            LOG('Number of upgrading T1 Air '..self.Factories.AIR[1].UpgradingCount)
            LOG('Number of upgrading T2 Air '..self.Factories.AIR[2].UpgradingCount)
            LOG('Number of HQs T2 Air '..repr(self.Factories.AIR[2].HQCount))
            LOG('Number of HQs T3 Air '..repr(self.Factories.AIR[3].HQCount))
            LOG('Number of upgrading T1 NAVAL '..self.Factories.NAVAL[1].UpgradingCount)
            LOG('Number of upgrading T2 NAVAL '..self.Factories.NAVAL[2].UpgradingCount)
            LOG('Number of HQs T2 Naval '..repr(self.Factories.NAVAL[2].HQCount))
            LOG('Number of HQs T3 Naval '..repr(self.Factories.NAVAL[3].HQCount))
            self:ValidateFactoryUpgradeRNG()
            coroutine.yield(30)
        end
    end,

    GetClosestFactory = function(self, base, type, tech, hqFlag)
        local ALLBPS = __blueprints
        local basePosition = self.Brain.BuilderManagers[base].Position
        LOG('GetClosestFactory Base position is '..repr(basePosition))
        local factoryList = self.Brain.BuilderManagers[base].FactoryManager.FactoryList
        local unitPos
        local DistanceToBase
        local LowestDistanceToBase
        local lowestUnit
        for _, fact in factoryList do
            if fact and not fact.Dead and ALLBPS[fact.UnitId].CategoriesHash[type] and ALLBPS[fact.UnitId].CategoriesHash[tech]then
                if hqFlag then
                    if not ALLBPS[fact.UnitId].CategoriesHash.SUPPORTFACTORY then
                        if not fact:IsUnitState('Upgrading') then
                            unitPos = fact:GetPosition()
                            DistanceToBase = VDist2Sq(basePosition[1] or 0, basePosition[3] or 0, unitPos[1] or 0, unitPos[3] or 0)
                            if not LowestDistanceToBase or DistanceToBase < LowestDistanceToBase then
                                LowestDistanceToBase = DistanceToBase
                                lowestUnit = fact
                                LOG('Lowest Distance Factory added')
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
                            LOG('Lowest Distance Factory added')
                        end
                    end
                end
            end
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
        local factoryToUpgrade
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
        LOG('Total T2 HQ Count is '..totalLandT2HQCount)
        local t2LandPass = false
        if totalLandT2HQCount < 1 and totalLandT3HQCount < 1 and self.Factories.LAND[1].UpgradingCount < 1 and self.Factories.LAND[1].Total > 0 then
            LOG('Factory T1 Upgrade HQ Check passed')
            if GetGameTimeSeconds() > (450 / tonumber(ScenarioInfo.Options.BuildMult)) then
                LOG('Factory Upgrade Time Check passed')
                if self.Brain.EconomyOverTimeCurrent.MassIncome > 2.5 and self.Brain.EconomyOverTimeCurrent.EnergyIncome > 20.0 then
                    LOG('Factory Upgrade Income Over time check passed')
                    if GetEconomyIncome(self.Brain,'MASS') >= 2.5 and GetEconomyIncome(self.Brain,'ENERGY') >= 20.0 then
                        LOG('Factory Upgrade Income check passed')
                        if self.Brain.EconomyOverTimeCurrent.MassEfficiencyOverTime >= 1.025 and self.Brain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= 1.025 then
                            LOG('Factory Upgrade efficiency over time check passed')
                            local EnergyEfficiency = math.min(GetEconomyIncome(self.Brain,'ENERGY') / GetEconomyRequested(self.Brain,'ENERGY'), 2)
                            local MassEfficiency = math.min(GetEconomyIncome(self.Brain,'MASS') / GetEconomyRequested(self.Brain,'MASS'), 2)
                            if MassEfficiency >= 1.025 and EnergyEfficiency >= 1.025 then
                                LOG('Factory Upgrade efficiency check passed, get closest factory')
                                local factoryToUpgrade = self:GetClosestFactory('MAIN', 'LAND', 'TECH1')
                                if factoryToUpgrade and not factoryToUpgrade.Dead then
                                    LOG('Structure Manager Triggering T2 HQ Upgrade')
                                    self:UpgradeFactoryRNG(factoryToUpgrade)
                                    t2LandPass = true
                                    coroutine.yield(30)
                                end
                            end
                        end
                    end
                end
            end
        end
        if not t2LandPass and totalLandT2HQCount < 1 and totalLandT3HQCount < 1 and self.Factories.LAND[1].UpgradingCount < 1 and self.Factories.LAND[1].Total > 0 then
            if GetEconomyStored(self.Brain, 'MASS') >= 1300 and GetEconomyStored(self.Brain, 'ENERGY') >= 3990 then
                LOG('Factory T2 Upgrade HQ Excess Check passed')
                local factoryToUpgrade = self:GetClosestFactory('MAIN', 'LAND', 'TECH1')
                if factoryToUpgrade and not factoryToUpgrade.Dead then
                    LOG('Structure Manager Triggering T2 HQ Upgrade')
                    self:UpgradeFactoryRNG(factoryToUpgrade)
                    t2LandPass = true
                    coroutine.yield(30)
                end
            end
        end
        if not t2LandPass and (totalLandT2HQCount > 0 or totalLandT3HQCount > 0) and self.Factories.LAND[1].Total > 0 and self.Factories.LAND[2].Total < 11 then
            LOG('Factory T1 Upgrade Support Check passed')
            if self.Factories.LAND[1].UpgradingCount < 1 then
                LOG('Factory T1 Upgrade Less than 1 Factory Upgrading')
                if self.Brain.EconomyOverTimeCurrent.MassTrendOverTime >= 0.0 and self.Brain.EconomyOverTimeCurrent.EnergyTrendOverTime >= 0.0 then
                    if self.Brain.EconomyOverTimeCurrent.MassEfficiencyOverTime >= 1.025 and self.Brain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= 1.025 then
                        LOG('Factory Upgrade efficiency over time check passed')
                        local EnergyEfficiency = math.min(GetEconomyIncome(self.Brain,'ENERGY') / GetEconomyRequested(self.Brain,'ENERGY'), 2)
                        local MassEfficiency = math.min(GetEconomyIncome(self.Brain,'MASS') / GetEconomyRequested(self.Brain,'MASS'), 2)
                        if MassEfficiency >= 1.025 and EnergyEfficiency >= 1.025 then
                            LOG('Factory Upgrade efficiency check passed, get closest factory')
                            local factoryToUpgrade = self:GetClosestFactory('MAIN', 'LAND', 'TECH1')
                            if factoryToUpgrade and not factoryToUpgrade.Dead then
                                LOG('Structure Manager Triggering T2 Support Upgrade')
                                self:UpgradeFactoryRNG(factoryToUpgrade)
                                t2LandPass = true
                                coroutine.yield(30)
                            end
                        end
                    end
                end
            elseif self.Factories.LAND[1].UpgradingCount < 2 then
                LOG('Factory T1 Upgrade Less than 2 Factory Upgrading')
                if GetEconomyStored(self.Brain, 'MASS') >= 1300 and GetEconomyStored(self.Brain, 'ENERGY') >= 3990 then
                    local factoryToUpgrade = self:GetClosestFactory('MAIN', 'LAND', 'TECH1')
                    if factoryToUpgrade and not factoryToUpgrade.Dead then
                        LOG('Structure Manager Triggering T2 HQ Upgrade')
                        self:UpgradeFactoryRNG(factoryToUpgrade)
                        t2LandPass = true
                        coroutine.yield(30)
                    end
                end
            end
        end
        local t3LandPass = false
        if totalLandT3HQCount < 1 and totalLandT2HQCount > 0 and self.Factories.LAND[2].UpgradingCount < 1 and self.Factories.LAND[2].Total > 0 then
            LOG('Factory T1 Upgrade HQ Check passed')
            if GetGameTimeSeconds() > (960 / tonumber(ScenarioInfo.Options.BuildMult)) then
                LOG('Factory Upgrade Time Check passed')
                if self.Brain.EconomyOverTimeCurrent.MassIncome > 5.0 and self.Brain.EconomyOverTimeCurrent.EnergyIncome > 100.0 then
                    LOG('Factory Upgrade Income Over time check passed')
                    if GetEconomyIncome(self.Brain,'MASS') >= 5.0 and GetEconomyIncome(self.Brain,'ENERGY') >= 100.0 then
                        LOG('Factory Upgrade Income check passed')
                        if self.Brain.EconomyOverTimeCurrent.MassEfficiencyOverTime >= 1.0 and self.Brain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= 1.0 then
                            LOG('Factory Upgrade efficiency over time check passed')
                            local EnergyEfficiency = math.min(GetEconomyIncome(self.Brain,'ENERGY') / GetEconomyRequested(self.Brain,'ENERGY'), 2)
                            local MassEfficiency = math.min(GetEconomyIncome(self.Brain,'MASS') / GetEconomyRequested(self.Brain,'MASS'), 2)
                            if MassEfficiency >= 1.0 and EnergyEfficiency >= 1.0 then
                                LOG('Factory Upgrade efficiency check passed, get closest factory')
                                local factoryToUpgrade = self:GetClosestFactory('MAIN', 'LAND', 'TECH2', true)
                                if factoryToUpgrade and not factoryToUpgrade.Dead then
                                    LOG('Structure Manager Triggering T3 HQ Upgrade')
                                    self:UpgradeFactoryRNG(factoryToUpgrade)
                                    t3LandPass = true
                                    coroutine.yield(30)
                                end
                            end
                        end
                    end
                end
            end
        end
        if not t3LandPass and totalLandT3HQCount < 1 and totalLandT2HQCount > 0 and self.Factories.LAND[2].UpgradingCount < 1 and self.Factories.LAND[2].Total > 0 then
            LOG('Factory T2 Upgrade HQ Check passed')
            if GetGameTimeSeconds() > (600 / tonumber(ScenarioInfo.Options.BuildMult)) then
                if GetEconomyStored(self.Brain, 'MASS') >= 1800 and GetEconomyStored(self.Brain, 'ENERGY') >= 9000 then
                    LOG('Factory T2 HQ Upgrade Excess Storage Check Passed')
                    local factoryToUpgrade = self:GetClosestFactory('MAIN', 'LAND', 'TECH2', true)
                    if factoryToUpgrade and not factoryToUpgrade.Dead then
                        LOG('Structure Manager Triggering T3 HQ Upgrade')
                        self:UpgradeFactoryRNG(factoryToUpgrade)
                        t3LandPass = true
                        coroutine.yield(30)
                    end
                end
            end
        end
        if not t3LandPass and totalLandT3HQCount > 0 and self.Factories.LAND[2].Total > 0 and self.Factories.LAND[3].Total < 11 then
            LOG('Factory T2 Upgrade Support Check passed')
            if self.Factories.LAND[2].UpgradingCount < 1 then
                LOG('Factory T2 Upgrade Less than 1 Factory Upgrading')
                if self.Brain.EconomyOverTimeCurrent.MassTrendOverTime >= 0.0 and self.Brain.EconomyOverTimeCurrent.EnergyTrendOverTime >= 0.0 then
                    if self.Brain.EconomyOverTimeCurrent.MassEfficiencyOverTime >= 1.020 and self.Brain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= 1.020 then
                        LOG('Factory Upgrade efficiency over time check passed')
                        local EnergyEfficiency = math.min(GetEconomyIncome(self.Brain,'ENERGY') / GetEconomyRequested(self.Brain,'ENERGY'), 2)
                        local MassEfficiency = math.min(GetEconomyIncome(self.Brain,'MASS') / GetEconomyRequested(self.Brain,'MASS'), 2)
                        if MassEfficiency >= 1.020 and EnergyEfficiency >= 1.020 then
                            LOG('Factory Upgrade efficiency check passed, get closest factory')
                            local factoryToUpgrade = self:GetClosestFactory('MAIN', 'LAND', 'TECH2')
                            if factoryToUpgrade and not factoryToUpgrade.Dead then
                                LOG('Structure Manager Triggering T3 HQ Upgrade')
                                self:UpgradeFactoryRNG(factoryToUpgrade)
                                t3LandPass = true
                                coroutine.yield(30)
                            end
                        end
                    end
                end
            elseif self.Factories.LAND[2].UpgradingCount < 2 then
                if GetGameTimeSeconds() > (600 / tonumber(ScenarioInfo.Options.BuildMult)) then
                    LOG('Factory T1 Upgrade Less than 2 Factory Upgrading')
                    if GetEconomyStored(self.Brain, 'MASS') >= 1800 and GetEconomyStored(self.Brain, 'ENERGY') >= 9000 then
                        local factoryToUpgrade = self:GetClosestFactory('MAIN', 'LAND', 'TECH2')
                        if factoryToUpgrade and not factoryToUpgrade.Dead then
                            LOG('Structure Manager Triggering T3 HQ Upgrade')
                            self:UpgradeFactoryRNG(factoryToUpgrade)
                            t3LandPass = true
                            coroutine.yield(30)
                        end
                    end
                end
            end
        end
        local t2AirPass = false
        if totalAirT2HQCount < 1 and totalAirT3HQCount < 1 and self.Factories.AIR[1].UpgradingCount < 1 and self.Factories.AIR[1].Total > 0 then
            LOG('Factory T1 Air Upgrade HQ Check passed')
            if self.Factories.LAND[2].Total > 0 then
                LOG('Factory Air Upgrade Time Check passed')
                if self.Brain.EconomyOverTimeCurrent.MassEfficiencyOverTime >= 1.025 and self.Brain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= 1.025 then
                    LOG('Factory Upgrade efficiency over time check passed')
                    local EnergyEfficiency = math.min(GetEconomyIncome(self.Brain,'ENERGY') / GetEconomyRequested(self.Brain,'ENERGY'), 2)
                    local MassEfficiency = math.min(GetEconomyIncome(self.Brain,'MASS') / GetEconomyRequested(self.Brain,'MASS'), 2)
                    if MassEfficiency >= 1.025 and EnergyEfficiency >= 1.025 then
                        LOG('Factory Upgrade efficiency check passed, get closest factory')
                        local factoryToUpgrade = self:GetClosestFactory('MAIN', 'AIR', 'TECH1')
                        if factoryToUpgrade and not factoryToUpgrade.Dead then
                            LOG('Structure Manager Triggering T2 HQ Upgrade')
                            self:UpgradeFactoryRNG(factoryToUpgrade)
                            t2AirPass = true
                            coroutine.yield(30)
                        end
                    end
                end
            end
        end
        if not t2AirPass and (totalAirT2HQCount > 0 or totalAirT3HQCount > 0) and self.Factories.AIR[1].Total > 0 and self.Factories.AIR[2].Total < 8 then
            LOG('Factory Air T2 Upgrade Support Check passed')
            if self.Factories.AIR[2].UpgradingCount < 1 then
                LOG('Factory Air T2 Upgrade Less than 1 Factory Upgrading')
                if self.Brain.EconomyOverTimeCurrent.MassEfficiencyOverTime >= 1.025 and self.Brain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= 1.025 then
                    LOG('Factory Upgrade efficiency over time check passed')
                    local EnergyEfficiency = math.min(GetEconomyIncome(self.Brain,'ENERGY') / GetEconomyRequested(self.Brain,'ENERGY'), 2)
                    local MassEfficiency = math.min(GetEconomyIncome(self.Brain,'MASS') / GetEconomyRequested(self.Brain,'MASS'), 2)
                    if MassEfficiency >= 1.025 and EnergyEfficiency >= 1.025 then
                        LOG('Factory Upgrade efficiency check passed, get closest factory')
                        local factoryToUpgrade = self:GetClosestFactory('MAIN', 'AIR', 'TECH1')
                        if factoryToUpgrade and not factoryToUpgrade.Dead then
                            LOG('Structure Manager Triggering T3 HQ Upgrade')
                            self:UpgradeFactoryRNG(factoryToUpgrade)
                            t3LandPass = true
                            coroutine.yield(30)
                        end
                    end
                end
            end
        end
        local t3AirPass = false
        if totalAirT3HQCount < 1 and totalAirT2HQCount > 0 and self.Factories.AIR[2].UpgradingCount < 1 and self.Factories.AIR[2].Total > 0 then
            LOG('Factory T2 Air Upgrade HQ Check passed')
            if GetGameTimeSeconds() > (990 / tonumber(ScenarioInfo.Options.BuildMult)) then
                LOG('Factory Upgrade Time Check passed')
                if self.Brain.EconomyOverTimeCurrent.MassEfficiencyOverTime >= 1.015 and self.Brain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= 1.015 then
                    LOG('Factory Upgrade efficiency over time check passed')
                    local EnergyEfficiency = math.min(GetEconomyIncome(self.Brain,'ENERGY') / GetEconomyRequested(self.Brain,'ENERGY'), 2)
                    local MassEfficiency = math.min(GetEconomyIncome(self.Brain,'MASS') / GetEconomyRequested(self.Brain,'MASS'), 2)
                    if MassEfficiency >= 1.015 and EnergyEfficiency >= 1.015 then
                        LOG('Factory Upgrade efficiency check passed, get closest factory')
                        local factoryToUpgrade = self:GetClosestFactory('MAIN', 'AIR', 'TECH2', true)
                        if factoryToUpgrade and not factoryToUpgrade.Dead then
                            LOG('Structure Manager Triggering T3 HQ Upgrade')
                            self:UpgradeFactoryRNG(factoryToUpgrade)
                            t3AirPass = true
                            coroutine.yield(30)
                        end
                    end
                end
            end
        end
        if not t3AirPass and totalAirT3HQCount < 1 and totalAirT2HQCount > 0 and self.Factories.AIR[2].UpgradingCount < 1 and self.Factories.AIR[2].Total > 0 then
            LOG('Factory T2 Upgrade HQ Check passed')
            if GetGameTimeSeconds() > (600 / tonumber(ScenarioInfo.Options.BuildMult)) then
                if GetEconomyStored(self.Brain, 'MASS') >= 1800 and GetEconomyStored(self.Brain, 'ENERGY') >= 14000 then
                    LOG('Factory T2 HQ Upgrade Excess Storage Check Passed')
                    local factoryToUpgrade = self:GetClosestFactory('MAIN', 'AIR', 'TECH2', true)
                    if factoryToUpgrade and not factoryToUpgrade.Dead then
                        LOG('Structure Manager Triggering T3 HQ Upgrade')
                        self:UpgradeFactoryRNG(factoryToUpgrade)
                        t3AirPass = true
                        coroutine.yield(30)
                    end
                end
            end
        end
        if not t3AirPass and totalAirT3HQCount > 0 and self.Factories.AIR[2].Total > 0 and self.Factories.AIR[3].Total < 11 then
            LOG('Factory T2 Upgrade Support Check passed')
            if self.Factories.AIR[2].UpgradingCount < 1 then
                LOG('Factory T2 Upgrade Less than 1 Factory Upgrading')
                if self.Brain.EconomyOverTimeCurrent.MassTrendOverTime >= 0.0 and self.Brain.EconomyOverTimeCurrent.EnergyTrendOverTime >= 0.0 then
                    if self.Brain.EconomyOverTimeCurrent.MassEfficiencyOverTime >= 1.05 and self.Brain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= 1.1 then
                        LOG('Factory Upgrade efficiency over time check passed')
                        local EnergyEfficiency = math.min(GetEconomyIncome(self.Brain,'ENERGY') / GetEconomyRequested(self.Brain,'ENERGY'), 2)
                        local MassEfficiency = math.min(GetEconomyIncome(self.Brain,'MASS') / GetEconomyRequested(self.Brain,'MASS'), 2)
                        if MassEfficiency >= 1.05 and EnergyEfficiency >= 1.1 then
                            LOG('Factory Upgrade efficiency check passed, get closest factory')
                            local factoryToUpgrade = self:GetClosestFactory('MAIN', 'LAND', 'TECH2')
                            if factoryToUpgrade and not factoryToUpgrade.Dead then
                                LOG('Structure Manager Triggering T3 HQ Upgrade')
                                self:UpgradeFactoryRNG(factoryToUpgrade)
                                t3LandPass = true
                                coroutine.yield(30)
                            end
                        end
                    end
                end
            elseif self.Factories.AIR[2].UpgradingCount < 2 then
                if GetGameTimeSeconds() > (600 / tonumber(ScenarioInfo.Options.BuildMult)) then
                    LOG('Factory T1 Upgrade Less than 2 Factory Upgrading')
                    if GetEconomyStored(self.Brain, 'MASS') >= 1800 and GetEconomyStored(self.Brain, 'ENERGY') >= 14000 then
                        local factoryToUpgrade = self:GetClosestFactory('MAIN', 'AIR', 'TECH2')
                        if factoryToUpgrade and not factoryToUpgrade.Dead then
                            LOG('Structure Manager Triggering T3 HQ Upgrade')
                            self:UpgradeFactoryRNG(factoryToUpgrade)
                            t3AirPass = true
                            coroutine.yield(30)
                        end
                    end
                end
            end
        end
        return false
    end,

    UpgradeFactoryRNG = function(self, unit)
        local ALLBPS = __blueprints
        local supportUpgradeID
        local followupUpgradeID = false
        local upgradeID = ALLBPS[unit.UnitId].General.UpgradesTo
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
        LOG('Upgrade Factory has triggered ')
        LOG('Default upgrade bp is '..upgradeID..' checking for support upgrade replacement')
        if upgradeID then
            if ALLBPS[unit.UnitId].CategoriesHash.LAND then
                if ALLBPS[unit.UnitId].CategoriesHash.TECH1 then
                    if self.Factories.LAND[2].HQCount[upgradeID] > 0 then
                        supportUpgradeID = self.SupportUpgradeTable.LAND.T2[unit.UnitId]
                    elseif followupUpgradeID and self.Factories.LAND[3].HQCount[followupUpgradeID] > 0 then
                        supportUpgradeID = self.SupportUpgradeTable.LAND.T2[unit.UnitId]
                    end
                elseif ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                    if self.Factories.LAND[3].HQCount[upgradeID] > 0 then
                        supportUpgradeID = self.SupportUpgradeTable.LAND.T3[unit.UnitId]
                    end
                end
            elseif ALLBPS[unit.UnitId].CategoriesHash.AIR then
                if ALLBPS[unit.UnitId].CategoriesHash.TECH1 then
                    if self.Factories.AIR[2].HQCount[upgradeID] > 0 then
                        supportUpgradeID = self.SupportUpgradeTable.AIR.T2[unit.UnitId]
                    elseif followupUpgradeID and self.Factories.AIR[3].HQCount[followupUpgradeID] > 0 then
                        supportUpgradeID = self.SupportUpgradeTable.AIR.T2[unit.UnitId]
                    end
                elseif ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                    if self.Factories.AIR[3].HQCount[upgradeID] > 0 then
                        supportUpgradeID = self.SupportUpgradeTable.AIR.T3[unit.UnitId]
                    end
                end
            elseif ALLBPS[unit.UnitId].CategoriesHash.NAVAL then
                if ALLBPS[unit.UnitId].CategoriesHash.TECH1 then
                    if self.Factories.NAVAL[2].HQCount[upgradeID] > 0 then
                        supportUpgradeID = self.SupportUpgradeTable.NAVAL.T2[unit.UnitId]
                    elseif followupUpgradeID and self.Factories.NAVAL[3].HQCount[followupUpgradeID] > 0 then
                        supportUpgradeID = self.SupportUpgradeTable.NAVAL.T2[unit.UnitId]
                    end
                elseif ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                    if self.Factories.NAVAL[3].HQCount[upgradeID] > 0 then
                        supportUpgradeID = self.SupportUpgradeTable.NAVAL.T3[unit.UnitId]
                    end
                end
            end
            if supportUpgradeID then
                LOG('Support Upgrade ID found '..supportUpgradeID)
                upgradeID = supportUpgradeID
            end
        end
        if upgradeID then
            LOG('Issuing Upgrade Command for factory')
            IssueClearCommands({unit})
            coroutine.yield(2)
            IssueUpgrade({unit}, upgradeID)
        end
    end,
}

local sm 

function CreateStructureManager(brain)
    sm = StructureManager()
    sm:Create(brain)
    return sm
end


function GetStructureManager()
    return sm
end