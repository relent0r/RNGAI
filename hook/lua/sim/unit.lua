local RNGUnitClass = Unit
Unit = Class(RNGUnitClass) {

    AddACUDetectionCallBack = function (self, fn)
        if not fn then
            error('*ERROR: Tried to add a callback type - AddACUDetectionCallBack with a nil function')
            return
        end
        table.insert( self.EventCallbacks.ACUDetected, fn )
        if not self.ACUDetect then
            self.ACUDetect = self:ForkThread(self.ACUDetectionThread)
        end
    end,

    ACUDetectionThread = function (self)
        local aiBrain = self:GetBrain()
        local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
        local ACUTable = aiBrain.EnemyIntel.ACU
        if ACUTable then 
            while not self.Dead do
                local currentGameTime = GetGameTimeSeconds()
                local acuUnits = aiBrain:GetUnitsAroundPoint(categories.COMMAND, self:GetPosition(), 40, Enemy)
                for _, v in ACUTable do
                    if not v.LastSpoted then
                        v.LastSpoted = 0
                    end
                    
                    if currentGameTime - 60 > v.LastSpoted and ACUTable[enemyIndex] == enemyIndex then
                        if acuUnits then
                            for _, v in acuUnits do
                                enemyIndex = v:GetArmyIndex()
                                acuPos = v.Position
                                ACUTable[enemyIndex] = { acuPos, LastSpoted = currentGameTime }
                            end
                        end
                    end
                    WaitSeconds(2)
                end
            end
        else
                WARN('No EnemyIntel ACU Table found')
        end
    end,
}