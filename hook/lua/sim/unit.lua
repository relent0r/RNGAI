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

        while not self.Dead do

            local acuUnits = aiBrain:GetUnitsAroundPoint(categories.COMMAND, unit:GetPosition(), 40, Enemy)
            if acuUnits then
                
            end

        end
    end,
}