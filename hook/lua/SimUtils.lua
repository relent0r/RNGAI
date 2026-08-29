local RNGOldTransferUnitsOwnership = TransferUnitsOwnership
TransferUnitsOwnership = function(units, toArmy, captured)
    --LOG('TransferUnitsOwnership is running')
    local originBrain
    for _, v in units do
        local owner = v.Army
        if IsAlly(owner, toArmy) then
            originBrain = v:GetAIBrain()
        end
        break
    end
    local transferedUnits = RNGOldTransferUnitsOwnership(units, toArmy, captured)
    ForkThread(import('/mods/RNGAI/lua/AI/RNGEventCallbacks.lua').OnTransfered, transferedUnits, toArmy, captured, originBrain)
    return transferedUnits
end

local RNGOldDisableAI = DisableAI
function DisableAI(self)
    if self.RNG then
        -- print AI "ilost" text to chat
        SorianUtils.AISendChat('enemies', self.Nickname, 'ilost')
        -- remove PlatoonHandle from all AI units before we kill / transfer the army
        local units = self:GetListOfUnits(categories.ALLUNITS - categories.WALL, false)
        if not table.empty(units) then
            for _, unit in units do
                if not unit.Dead then
                    local handle = unit.PlatoonHandle
                    if handle and self:PlatoonExists(handle) then
                        if handle.Stop then
                            handle:Stop()
                        end
                        if handle.PlatoonDisbandNoAssign then
                            handle:PlatoonDisbandNoAssign()
                        end
                    end
                    IssueStop({ unit })
                    IssueToUnitClearCommands(unit)
                end
            end
        end

        -- Stop the AI from executing AI plans
        self.RepeatExecution = false
        -- removing AI BrainConditionsMonitor
        if self.ConditionsMonitor then
            self.ConditionsMonitor:Destroy()
        end
        -- removing AI BuilderManagers
        if self.BuilderManagers then
            for _, manager in self.BuilderManagers do
                if manager.EngineerManager then
                    manager.EngineerManager:SetEnabled(false)
                end

                if manager.FactoryManager then
                    manager.FactoryManager:SetEnabled(false)
                end

                if manager.PlatoonFormManager then
                    manager.PlatoonFormManager:SetEnabled(false)
                end

                if manager.EngineerManager then
                    manager.EngineerManager:Destroy()
                    manager.EngineerManager = nil
                end

                if manager.FactoryManager then
                    manager.FactoryManager:Destroy()
                    manager.FactoryManager = nil
                end

                if manager.PlatoonFormManager then
                    manager.PlatoonFormManager:Destroy()
                    manager.PlatoonFormManager = nil
                end
                if manager.StrategyManager then
                    manager.StrategyManager:SetEnabled(false)
                    manager.StrategyManager:Destroy()
                end
                manager.BaseSettings = nil
                manager.BuilderHandles = nil
                manager.Position = nil
            end
        end
        -- delete the AI pathcache
        self.PathCache = nil
    else
        RNGOldDisableAI(self)
    end
end