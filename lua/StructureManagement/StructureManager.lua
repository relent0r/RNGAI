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
            AIR = {
                {
                    Units = {},
                    UpgradingCount = 0
                },
                {
                    Units = {},
                    UpgradingCount = 0,
                    HQCount = 0
                },
                {
                    Units = {},
                    UpgradingCount = 0,
                    HQCount = 0
                }
            },
            LAND = {
                {
                    Units = {},
                    UpgradingCount = 0
                },
                {
                    Units = {},
                    UpgradingCount = 0,
                    HQCount = 0
                },
                {
                    Units = {},
                    UpgradingCount = 0,
                    HQCount = 0
                }
            },
            NAVAL = {
                {
                    Units = {},
                    UpgradingCount = 0
                },
                {
                    Units = {},
                    UpgradingCount = 0,
                    HQCount = 0
                },
                {
                    Units = {},
                    UpgradingCount = 0,
                    HQCount = 0
                }
            }
        }
    end,

    Run = function(self)
        LOG('RNGAI : StructureManager Starting')
        self:ForkThread(self.ValidateFactoryUpgradeRNG)
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

    ValidateFactoryUpgradeRNG = function(self)
        -- Lets try be smart about how we do this
            -- The current conditions, we'll just do like for like for now
            --'GreaterThanGameTimeRNG', { 450, true } },
            --'LessThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY } },
            --'GreaterThanEconIncomeCombinedRNG',  { 2.5, 20.0 }},
            --'GreaterThanEconStorageRatioRNG', { 0.03, 0.3}},
            --'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1 }},
            --'GreaterThanEconEfficiencyCombinedRNG', { 1.025, 1.025 }},

        coroutine.yield(Random(5,20))
        local ALLBPS = __blueprints
        while true do
            -- Create a table rather than a million locals
            local FactoryData = {
                T2LANDHQCount = 0,
                T3LANDHQCount = 0,
                T2AIRHQCount = 0,
                T3AIRHQCount = 0,
                T2NAVALHQCount = 0,
                T3NAVALHQCount = 0,
                T1LANDUpgrading = 0,
                T2LANDUpgrading = 0,
                T1AIRUpgrading = 0,
                T2AIRUpgrading = 0,
                T1NAVALUpgrading = 0,
                T2NAVALUpgrading = 0,
                T1LAND = {},
                T2LAND = {},
                T3LAND = {},
                T1AIR = {},
                T2AIR = {},
                T3AIR = {},
                T1NAVAL = {},
                T2NAVAL = {},
                T3NAVAL = {},
            }
            for k, manager in self.Brain.BuilderManagers do
                if RNGGETN(manager.FactoryManager.FactoryList) > 0 then
                    for c, unit in manager.FactoryManager.FactoryList do
                        if not unit.Dead and not unit:BeenDestroyed() then
                            if ALLBPS[unit.UnitId].CategoriesHash.LAND then
                                if ALLBPS[unit.UnitId].CategoriesHash.TECH1 then
                                    RNGINSERT(self.Factories.LAND[1].Units, unit)
                                    if unit:IsUnitState('Upgrading') then
                                        FactoryData.T1LANDUpgrading = FactoryData.T1LANDUpgrading + 1
                                    end
                                elseif ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                                    RNGINSERT(self.Factories.LAND[2].Units, unit)
                                    if not ALLBPS[unit.UnitId].CategoriesHash.SUPPORT then
                                        FactoryData.T2LANDHQCount = FactoryData.T2LANDHQCount + 1
                                    end
                                    if unit:IsUnitState('Upgrading') then
                                        FactoryData.T2LANDUpgrading = FactoryData.T2LANDUpgrading + 1
                                    end
                                elseif ALLBPS[unit.UnitId].CategoriesHash.TECH3 then
                                    RNGINSERT(self.Factories.LAND[3].Units, unit)
                                    if not ALLBPS[unit.UnitId].CategoriesHash.SUPPORT then
                                        FactoryData.T3LANDHQCount = FactoryData.T3LANDHQCount + 1
                                    end
                                end
                            elseif ALLBPS[unit.UnitId].CategoriesHash.AIR then
                                if ALLBPS[unit.UnitId].CategoriesHash.TECH1 then
                                    RNGINSERT(self.Factories.AIR[1].Units, unit)
                                    if unit:IsUnitState('Upgrading') then
                                        FactoryData.T1AIRUpgrading = FactoryData.T1AIRUpgrading + 1
                                    end
                                elseif ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                                    RNGINSERT(self.Factories.AIR[2].Units, unit)
                                    if not ALLBPS[unit.UnitId].CategoriesHash.SUPPORT then
                                        FactoryData.T2AIRHQCount = FactoryData.T2AIRHQCount + 1
                                    end
                                    if unit:IsUnitState('Upgrading') then
                                        FactoryData.T2AIRUpgrading = FactoryData.T2AIRUpgrading + 1
                                    end
                                elseif ALLBPS[unit.UnitId].CategoriesHash.TECH3 then
                                    RNGINSERT(self.Factories.AIR[3].Units, unit)
                                    if not ALLBPS[unit.UnitId].CategoriesHash.SUPPORT then
                                        FactoryData.T3AIRHQCount = FactoryData.T3AIRHQCount + 1
                                    end
                                end

                            elseif ALLBPS[unit.UnitId].CategoriesHash.NAVAL then
                                if ALLBPS[unit.UnitId].CategoriesHash.TECH1 then
                                    RNGINSERT(self.Factories.NAVAL[1].Units, 1, unit)
                                    if unit:IsUnitState('Upgrading') then
                                        FactoryData.T1NAVALUpgrading = FactoryData.T1NAVALUpgrading + 1
                                    end
                                elseif ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                                    RNGINSERT(self.Factories.NAVAL[2].Units, unit)
                                    if not ALLBPS[unit.UnitId].CategoriesHash.SUPPORT then
                                        FactoryData.T2NAVALHQCount = FactoryData.T2NAVALHQCount + 1
                                    end
                                    if unit:IsUnitState('Upgrading') then
                                        FactoryData.T2NAVALUpgrading = FactoryData.T2NAVALUpgrading + 1
                                    end
                                elseif ALLBPS[unit.UnitId].CategoriesHash.TECH3 then
                                    RNGINSERT(self.Factories.NAVAL[3].Units, unit)
                                    if not ALLBPS[unit.UnitId].CategoriesHash.SUPPORT then
                                        FactoryData.T3NAVALHQCount = FactoryData.T3NAVALHQCount + 1
                                    end
                                    FactoryData.T3NAVALUpgrading = FactoryData.T3NAVALUpgrading + 1
                                end
                            end
                        end
                    end
                end
            end
            self.Factories.LAND[1].UpgradingCount
            self.Factories.LAND[2].UpgradingCount
            self.Factories.LAND[2].HQCount
            LOG('Structure Manager')
            LOG('Number of upgrading T1 Land '..self.Factories.LAND[1].UpgradingCount)
            LOG('Number of upgrading T2 Land '..self.Factories.LAND[2].UpgradingCount)
            LOG('Number of HQs T2 Land '..self.Factories.LAND[2].HQCount)
            LOG('Number of HQs T3 Land '..self.Factories.LAND[3].HQCount)
            LOG('Number of upgrading T1 Air '..self.Factories.AIR[1].UpgradingCount)
            LOG('Number of upgrading T2 Air '..self.Factories.AIR[2].UpgradingCount)
            LOG('Number of HQs T2 Air '..self.Factories.AIR[2].HQCount)
            LOG('Number of HQs T3 Air '..self.Factories.AIR[3].HQCount)
            LOG('Number of upgrading T1 NAVAL '..self.Factories.NAVAL[1].UpgradingCount)
            LOG('Number of upgrading T2 NAVAL '..self.Factories.NAVAL[2].UpgradingCount)
            LOG('Number of HQs T2 Naval '..self.Factories.NAVAL[2].HQCount)
            LOG('Number of HQs T3 Naval '..self.Factories.NAVAL[3].HQCount)

            coroutine.yield(50)
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