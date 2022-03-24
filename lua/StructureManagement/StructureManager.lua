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
                    HQCount = {
                        ['ueb0202'] = 0,
                        ['uab0202'] = 0,
                        ['urb0202'] = 0,
                        ['xsb0202'] = 0
                    }
                },
                {
                    Units = {},
                    UpgradingCount = 0,
                    HQCount = {
                        ['ueb0302'] = 0,
                        ['uab0302'] = 0,
                        ['urb0302'] = 0,
                        ['xsb0302'] = 0
                    }
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
                    HQCount = {
                        ['ueb0201'] = 0,
                        ['uab0201'] = 0,
                        ['urb0201'] = 0,
                        ['xsb0201'] = 0
                    }
                },
                {
                    Units = {},
                    UpgradingCount = 0,
                    HQCount = HQCount = {
                        ['ueb0301'] = 0,
                        ['uab0301'] = 0,
                        ['urb0301'] = 0,
                        ['xsb0301'] = 0
                    }
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
                    HQCount = {
                        ['ueb0103'] = 0,
                        ['uab0103'] = 0,
                        ['urb0103'] = 0,
                        ['xsb0103'] = 0
                    }
                },
                {
                    Units = {},
                    UpgradingCount = 0,
                    HQCount = {
                        ['ueb0103'] = 0},
                        ['uab0103'] = 0},
                        ['urb0103'] = 0},
                        ['xsb0103'] = 0}
                    }
                }
            }
        }
        self.SupportUpgradeTable = {
            LAND = {
                T2 = {
                    {['ueb0101'] = 'zeb9501'},
                    {['uab0101'] = 'zab9501'},
                    {['urb0101'] = 'zrb9501'},
                    {['xsb0101'] = 'zsb9501'}
                },
                T3 = {
                    {['ueb0201'] = 'zeb9601'},
                    {['uab0201'] = 'zab9601'},
                    {['urb0201'] = 'zrb9601'},
                    {['xsb0201'] = 'zsb9601'}
                }
            },
            AIR = {
                T2 = {
                    {['ueb0102'] = 'zeb9502'},
                    {['uab0102'] = 'zab9502'},
                    {['urb0102'] = 'zrb9502'},
                    {['xsb0102'] = 'zsb9502'}
                },
                T3 = {
                    {['ueb0202'] = 'zeb9602'},
                    {['uab0202'] = 'zab9602'},
                    {['urb0202'] = 'zrb9602'},
                    {['xsb0202'] = 'zsb9602'}
                }
            },
            NAVAL = {
                T2 = {
                    {['ueb0103'] = 'zeb9503'},
                    {['uab0103'] = 'zab9503'},
                    {['urb0103'] = 'zrb9503'},
                    {['xsb0103'] = 'zsb9503'}
                },
                T3 = {
                    {['ueb0203'] = 'zeb9603'},
                    {['uab0203'] = 'zab9603'},
                    {['urb0203'] = 'zrb9603'},
                    {['xsb0203'] = 'zsb9603'}
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
                                    RNGINSERT(FactoryData.T1LAND, unit)
                                    if unit:IsUnitState('Upgrading') then
                                        FactoryData.T1LANDUpgrading = FactoryData.T1LANDUpgrading + 1
                                    end
                                elseif ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                                    RNGINSERT(FactoryData.T2LAND, unit)
                                    if not ALLBPS[unit.UnitId].CategoriesHash.SUPPORTFACTORY then
                                        FactoryData.T2LANDHQCount = FactoryData.T2LANDHQCount + 1
                                    end
                                    if unit:IsUnitState('Upgrading') then
                                        FactoryData.T2LANDUpgrading = FactoryData.T2LANDUpgrading + 1
                                    end
                                elseif ALLBPS[unit.UnitId].CategoriesHash.TECH3 then
                                    RNGINSERT(FactoryData.T3LAND, unit)
                                    if not ALLBPS[unit.UnitId].CategoriesHash.SUPPORTFACTORY then
                                        FactoryData.T3LANDHQCount = FactoryData.T3LANDHQCount + 1
                                    end
                                end
                            elseif ALLBPS[unit.UnitId].CategoriesHash.AIR then
                                if ALLBPS[unit.UnitId].CategoriesHash.TECH1 then
                                    RNGINSERT(FactoryData.T1AIR, unit)
                                    if unit:IsUnitState('Upgrading') then
                                        FactoryData.T1AIRUpgrading = FactoryData.T1AIRUpgrading + 1
                                    end
                                elseif ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                                    RNGINSERT(FactoryData.T2AIR, unit)
                                    if not ALLBPS[unit.UnitId].CategoriesHash.SUPPORTFACTORY then
                                        FactoryData.T2AIRHQCount = FactoryData.T2AIRHQCount + 1
                                    end
                                    if unit:IsUnitState('Upgrading') then
                                        FactoryData.T2AIRUpgrading = FactoryData.T2AIRUpgrading + 1
                                    end
                                elseif ALLBPS[unit.UnitId].CategoriesHash.TECH3 then
                                    RNGINSERT(FactoryData.T3AIR, unit)
                                    if not ALLBPS[unit.UnitId].CategoriesHash.SUPPORTFACTORY then
                                        FactoryData.T3AIRHQCount = FactoryData.T3AIRHQCount + 1
                                    end
                                end

                            elseif ALLBPS[unit.UnitId].CategoriesHash.NAVAL then
                                if ALLBPS[unit.UnitId].CategoriesHash.TECH1 then
                                    RNGINSERT(FactoryData.T1NAVAL, 1, unit)
                                    if unit:IsUnitState('Upgrading') then
                                        FactoryData.T1NAVALUpgrading = FactoryData.T1NAVALUpgrading + 1
                                    end
                                elseif ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                                    RNGINSERT(FactoryData.T2NAVAL, unit)
                                    if not ALLBPS[unit.UnitId].CategoriesHash.SUPPORTFACTORY then
                                        FactoryData.T2NAVALHQCount = FactoryData.T2NAVALHQCount + 1
                                    end
                                    if unit:IsUnitState('Upgrading') then
                                        FactoryData.T2NAVALUpgrading = FactoryData.T2NAVALUpgrading + 1
                                    end
                                elseif ALLBPS[unit.UnitId].CategoriesHash.TECH3 then
                                    RNGINSERT(FactoryData.T3NAVAL, unit)
                                    if not ALLBPS[unit.UnitId].CategoriesHash.SUPPORTFACTORY then
                                        FactoryData.T3NAVALHQCount = FactoryData.T3NAVALHQCount + 1
                                    end
                                end
                            end
                        end
                    end
                end
            end
            self.Factories.LAND[1].UpgradingCount = FactoryData.T1LANDUpgrading
            self.Factories.LAND[2].UpgradingCount = FactoryData.T2LANDUpgrading
            self.Factories.LAND[2].HQCount = FactoryData.T2LANDHQCount
            self.Factories.LAND[3].HQCount = FactoryData.T3LANDHQCount
            self.Factories.AIR[1].UpgradingCount = FactoryData.T1AIRUpgrading
            self.Factories.AIR[2].UpgradingCount = FactoryData.T2AIRUpgrading
            self.Factories.AIR[2].HQCount = FactoryData.T2AIRHQCount
            self.Factories.AIR[3].HQCount = FactoryData.T3AIRHQCount
            self.Factories.NAVAL[1].UpgradingCount = FactoryData.T1NAVALUpgrading
            self.Factories.NAVAL[2].UpgradingCount = FactoryData.T2NAVALUpgrading
            self.Factories.NAVAL[2].HQCount = FactoryData.T2NAVALHQCount
            self.Factories.NAVAL[3].HQCount = FactoryData.T3NAVALHQCount
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
            coroutine.yield(30)
        end
    end,

    UpgradeFactoryRNG = function(self, unit, type, tier)
        local ALLBPS = __blueprints
        upgradeID = ALLBPS[unit.UnitId].General.UpgradesTo
        if not upgradeID then
            WARN('No upgrade ID in blueprint for factory upgrade, aborting upgrade')
            coroutine.yield(20)
            return
        end
        if upgradeID then
            if ALLBPS[unit.UnitId].CategoriesHash.LAND then
                if ALLBPS[unit.UnitId].CategoriesHash.TECH1 then
                    if self.Factories.LAND[2].HQCount > 0 then
                        upgradeID = self.SupportUpgradeTable.LAND.T2[unit.UnitId]
                    end
                elseif ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                    if self.Factories.LAND[3].HQCount > 0 then
                        upgradeID = self.SupportUpgradeTable.LAND.T3[unit.UnitId]
                    end
                end
            elseif ALLBPS[unit.UnitId].CategoriesHash.AIR then
                if ALLBPS[unit.UnitId].CategoriesHash.TECH1 then
                    if self.Factories.AIR[2].HQCount > 0 then
                        upgradeID = self.SupportUpgradeTable.AIR.T2[unit.UnitId]
                    end
                elseif ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                    if self.Factories.AIR[3].HQCount > 0 then
                        upgradeID = self.SupportUpgradeTable.AIR.T3[unit.UnitId]
                    end
                end
            elseif ALLBPS[unit.UnitId].CategoriesHash.AIR then
                if ALLBPS[unit.UnitId].CategoriesHash.TECH1 then
                    if self.Factories.NAVAL[2].HQCount > 0 then
                        upgradeID = self.SupportUpgradeTable.AIR.T2[unit.UnitId]
                    end
                elseif ALLBPS[unit.UnitId].CategoriesHash.TECH2 then
                    if self.Factories.NAVAL[3].HQCount > 0 then
                        upgradeID = self.SupportUpgradeTable.AIR.T3[unit.UnitId]
                    end
                end
            end
            if not upgradeID then
                upgradeID = ALLBPS[unit.UnitId].General.UpgradesTo
            end
        end
        if upgradeID then
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