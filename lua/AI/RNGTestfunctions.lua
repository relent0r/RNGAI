-- Function to calculate the average position of a group of players
function calculateAveragePosition(players)
    local totalX, totalY = 0, 0
    for _, player in ipairs(players) do
        totalX = totalX + player.x
        totalY = totalY + player.y
    end
    local averageX = totalX / #players
    local averageY = totalY / #players
    return {x = averageX, y = averageY}
end

-- Function to find the midpoint between two points
function findMidpoint(point1, point2)
    local midX = (point1.x + point2.x) / 2
    local midY = (point1.y + point2.y) / 2
    return {x = midX, y = midY}
end

-- Function to generate a line of positions between two points
function generateLineOfPositions(point1, point2, numPositions)
    local line = {}
    local dx = (point2.x - point1.x) / numPositions
    local dy = (point2.y - point1.y) / numPositions
    for i = 1, numPositions do
        local newX = point1.x + dx * i
        local newY = point1.y + dy * i
        table.insert(line, {x = newX, y = newY})
    end
    return line
end

-- Example usage
-- Define player positions (replace these with your actual player positions)
local team1Players = {{x = 10, y = 20}, {x = 15, y = 25}, {x = 20, y = 30}}
local team2Players = {{x = 30, y = 40}, {x = 35, y = 45}, {x = 40, y = 50}}

-- Calculate average positions of each team
local averagePositionTeam1 = calculateAveragePosition(team1Players)
local averagePositionTeam2 = calculateAveragePosition(team2Players)

-- Find the midpoint between the two teams
local midpoint = findMidpoint(averagePositionTeam1, averagePositionTeam2)

-- Generate a line of positions between the two midpoints
local lineOfPositions = generateLineOfPositions(averagePositionTeam1, averagePositionTeam2, 5)

-- Print the results
print("Midpoint:", midpoint.x, midpoint.y)
print("Line of positions:")
for i, position in ipairs(lineOfPositions) do
    print("Position", i, ":", position.x, position.y)
end

-- Function to determine which side of the line a point lies on
function determineSideOfLine(point, lineStart, lineEnd)
    local crossProduct = (point.x - lineStart.x) * (lineEnd.y - lineStart.y) - (point.y - lineStart.y) * (lineEnd.x - lineStart.x)
    if crossProduct > 0 then
        return "green" -- Point is on the green side of the line
    elseif crossProduct < 0 then
        return "red" -- Point is on the red side of the line
    else
        return "on the line" -- Point is exactly on the line
    end
end

-- Example usage
-- Define the line between the two midpoints
local lineStart = averagePositionTeam1
local lineEnd = averagePositionTeam2

-- Determine which side of the line a point is on
local testPoint = {x = 25, y = 35} -- Example test point, replace with your actual point
local side = determineSideOfLine(testPoint, lineStart, lineEnd)

-- Print the result
print("Test point is on the:", side, "side of the line")

-- This required reintegration
local distressLocation = aiBrain:BaseMonitorDistressLocationRNG(position, distressRange, aiBrain.BaseMonitor.PoolDistressThreshold, 'Land')

function Testrallypointpositions(pos)
    LOG('Land Factory')
    local rallyPointOptions = NavUtils.DirectionsFrom('Land', factoryPos, 30)
    local fx = factoryPos[1] - opponentStart[1]
    local fz = factoryPos[3] - opponentStart[3]
    local factoryDistance = fx * fx + fz * fz
    for _, v in rallyPointOptions do
        local rx = v[1] - opponentStart[1]
        local rz = v[3] - opponentStart[3]
        local rallyDistance = rx * rx + rz * rz
        local frx = v[1] - factoryPos[1]
        local frz = v[3] - factoryPos[3]
        local rallyFactoryPosDistance = frx * frx + frz * frz
        if rallyFactoryPosDistance > 64 and rallyFactoryPosDistance < 60 * 60 and rallyDistance < factoryDistance and self.Brain:GetNumUnitsAroundPoint(categories.STRUCTURE, v, 8, 'Ally') < 1 then
            LOG('Found point at distance of '..math.sqrt(rallyFactoryPosDistance))
            position = v
            break
        end
    end
    --RNGLOG('Air Rally Position is :'..repr(position))
end