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
                if acuUnits[1] then
                    LOG('ACU Detected')
                    for _, v in acuUnits do
                        enemyIndex = v:GetArmyIndex()
                        for _, c in ACUTable do
                            if currentGameTime - 60 > c.LastSpotted and ACUTable[enemyIndex] == enemyIndex then
                                ACUTable[enemyIndex].Position = v.Position
                                ACUTable[enemyIndex].LastSpotted = currentGameTime
                            end
                        end
                    end
                end
                WaitTicks(20)
            end
        else
                WARN('No EnemyIntel ACU Table found')
        end
    end,
}