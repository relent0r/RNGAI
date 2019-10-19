oldPlatoon = Platoon
Platoon = Class(oldPlatoon) {

    AirHuntAI = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target
        local blip
        while aiBrain:PlatoonExists(self) do
            if self:IsOpponentAIRunning() then
                target = self:FindClosestUnit('Attack', 'Enemy', true, categories.AIR - categories.WALL)
                if target then
                    blip = target:GetBlip(armyIndex)
                    self:Stop()
                    self:AggressiveMoveToLocation( table.copy(target:GetPosition()) )
                end
            end
            WaitSeconds(17)
        end
    end,

    GuardMarker = function(self)
        local aiBrain = self:GetBrain()
        
        local platLoc = self:GetPlatoonPosition()        
        
        if not aiBrain:PlatoonExists(self) or not platLoc then
            return
        end
        
        ---------------------------------------------------------------------
        -- Platoon Data
        ---------------------------------------------------------------------
        -- type of marker to guard
        -- Start location = 'Start Location'... see MarkerTemplates.lua for other types
        local markerType = self.PlatoonData.MarkerType or 'Expansion Area'

        -- what should we look for for the first marker?  This can be 'Random',
        -- 'Threat' or 'Closest'
        local moveFirst = self.PlatoonData.MoveFirst or 'Threat'
        
        -- should our next move be no move be (same options as before) as well as 'None'
        -- which will cause the platoon to guard the first location they get to
        local moveNext = self.PlatoonData.MoveNext or 'None'         

        -- Minimum distance when looking for closest
        local avoidClosestRadius = self.PlatoonData.AvoidClosestRadius or 0        
        
        -- set time to wait when guarding a location with moveNext = 'None'
        local guardTimer = self.PlatoonData.GuardTimer or 0
        
        -- threat type to look at      
        local threatType = self.PlatoonData.ThreatType or 'AntiSurface'
        
        -- should we look at our own threat or the enemy's
        local bSelfThreat = self.PlatoonData.SelfThreat or false
        
        -- if true, look to guard highest threat, otherwise, 
        -- guard the lowest threat specified                 
        local bFindHighestThreat = self.PlatoonData.FindHighestThreat or false 
        
        -- minimum threat to look for
        local minThreatThreshold = self.PlatoonData.MinThreatThreshold or -1
        -- maximum threat to look for
        local maxThreatThreshold = self.PlatoonData.MaxThreatThreshold  or 99999999
  
        -- Avoid bases (true or false)
        local bAvoidBases = self.PlatoonData.AvoidBases or false
             
        -- Radius around which to avoid the main base
        local avoidBasesRadius = self.PlatoonData.AvoidBasesRadius or 0
        
        -- Use Aggresive Moves Only
        local bAggroMove = self.PlatoonData.AggressiveMove or false
        
        local PlatoonFormation = self.PlatoonData.UseFormation or 'NoFormation'

        local maxPathDistance = self.PlatoonData.MaxPathDistance or 200
        -----------------------------------------------------------------------
         
           
        AIAttackUtils.GetMostRestrictiveLayer(self)
        self:SetPlatoonFormationOverride(PlatoonFormation)
        local markerLocations = AIUtils.AIGetMarkerLocations(aiBrain, markerType)
        
        local bestMarker = false
        
        if not self.LastMarker then
            self.LastMarker = {nil,nil}
        end
            
        -- look for a random marker
        if moveFirst == 'Random' then
            if table.getn(markerLocations) <= 2 then
                self.LastMarker[1] = nil
                self.LastMarker[2] = nil
            end        	
            for _,marker in RandomIter(markerLocations) do
	            if table.getn(markerLocations) <= 2 then
	                self.LastMarker[1] = nil
	                self.LastMarker[2] = nil
	            end            	
                if self:AvoidsBases(marker.Position, bAvoidBases, avoidBasesRadius) then
            		if self.LastMarker[1] and marker.Position[1] == self.LastMarker[1][1] and marker.Position[3] == self.LastMarker[1][3] then
            		    continue                
            		end                        
            		if self.LastMarker[2] and marker.Position[1] == self.LastMarker[2][1] and marker.Position[3] == self.LastMarker[2][3] then
            		    continue                
            		end                    	
                    bestMarker = marker
                    break
                end
            end
        elseif moveFirst == 'Threat' then
            --Guard the closest least-defended marker
            local bestMarkerThreat = 0
            if not bFindHighestThreat then
                bestMarkerThreat = 99999999
            end
            
            local bestDistSq = 99999999
                      
             
            -- find best threat at the closest distance
            for _,marker in markerLocations do
                local markerThreat
                if bSelfThreat then
                    markerThreat = aiBrain:GetThreatAtPosition( marker.Position, 0, true, threatType, aiBrain:GetArmyIndex())
                else
                    markerThreat = aiBrain:GetThreatAtPosition( marker.Position, 0, true, threatType)
                end
                local distSq = VDist2Sq(marker.Position[1], marker.Position[3], platLoc[1], platLoc[3])

                if markerThreat >= minThreatThreshold and markerThreat <= maxThreatThreshold then
                    if self:AvoidsBases(marker.Position, bAvoidBases, avoidBasesRadius) then
                        if self.IsBetterThreat(bFindHighestThreat, markerThreat, bestMarkerThreat) then
                            bestDistSq = distSq
                            bestMarker = marker
                            bestMarkerThreat = markerThreat
                        elseif markerThreat == bestMarkerThreat then
                            if distSq < bestDistSq then
                                bestDistSq = distSq
                                bestMarker = marker  
                                bestMarkerThreat = markerThreat  
                            end
                        end
                     end
                 end
            end
            
        else 
            -- if we didn't want random or threat, assume closest (but avoid ping-ponging)
            local bestDistSq = 99999999
            if table.getn(markerLocations) <= 2 then
                self.LastMarker[1] = nil
                self.LastMarker[2] = nil
            end
            for _,marker in markerLocations do
                local distSq = VDist2Sq(marker.Position[1], marker.Position[3], platLoc[1], platLoc[3])
                if self:AvoidsBases(marker.Position, bAvoidBases, avoidBasesRadius) and distSq > (avoidClosestRadius * avoidClosestRadius) then
                    if distSq < bestDistSq then
                		if self.LastMarker[1] and marker.Position[1] == self.LastMarker[1][1] and marker.Position[3] == self.LastMarker[1][3] then
                		    continue                
                		end                        
                		if self.LastMarker[2] and marker.Position[1] == self.LastMarker[2][1] and marker.Position[3] == self.LastMarker[2][3] then
                		    continue                
                		end                      		
                        bestDistSq = distSq
                        bestMarker = marker 
                    end
                end
            end            
        end
        
        
        -- did we find a threat?
        if bestMarker then
        	self.LastMarker[2] = self.LastMarker[1]
            self.LastMarker[1] = bestMarker.Position
            --LOG("GuardMarker: Attacking " .. bestMarker.Name)
            local path, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, self.MovementLayer, self:GetPlatoonPosition(), bestMarker.Position, maxPathDistance)
            IssueClearCommands(self:GetPlatoonUnits())
            if path then
                local pathLength = table.getn(path)
                for i=1, pathLength-1 do
                	if bAggroMove then
                		self:AggressiveMoveToLocation(path[i])
            		else
                        self:MoveToLocation(path[i], false)
                    end
                end 
            elseif (not path and reason == 'NoPath') then
                AIAttackUtils.SendPlatoonWithTransports(aiBrain, self, bestMarker.Position, true)
            else
                self:PlatoonDisband()
                return
            end
            
            if moveNext == 'None' then
                -- guard
                IssueGuard( self:GetPlatoonUnits(), bestMarker.Position )
                -- guard forever
                if guardTimer <= 0 then return end
            else
                -- otherwise, we're moving to the location
                self:AggressiveMoveToLocation(bestMarker.Position)
            end
            
            -- wait till we get there
            repeat
                WaitSeconds(5)    
                platLoc = self:GetPlatoonPosition() 
            until VDist2Sq(platLoc[1], platLoc[3], bestMarker.Position[1], bestMarker.Position[3]) < 64 or not aiBrain:PlatoonExists(self)
            
            -- if we're supposed to guard for some time
            if moveNext == 'None' then
                -- this won't be 0... see above
                WaitSeconds(guardTimer)
                self:PlatoonDisband()
                return
            end
            
            if moveNext == 'Guard Base' then
                return self:GuardBase()
            end
            
            -- we're there... wait here until we're done
            local numGround = aiBrain:GetNumUnitsAroundPoint( ( categories.LAND + categories.NAVAL + categories.STRUCTURE ), bestMarker.Position, 15, 'Enemy' )
            while numGround > 0 and aiBrain:PlatoonExists(self) do
                WaitSeconds(Random(5,10))
                numGround = aiBrain:GetNumUnitsAroundPoint( ( categories.LAND + categories.NAVAL + categories.STRUCTURE ), bestMarker.Position, 15, 'Enemy' )    
            end
            
            if not aiBrain:PlatoonExists(self) then
                return
            end
            
            -- set our MoveFirst to our MoveNext
            self.PlatoonData.MoveFirst = moveNext
            return self:GuardMarker()
        else
            -- no marker found, disband!
            self:PlatoonDisband()
        end               
    end,
}