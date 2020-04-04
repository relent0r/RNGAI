local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')

RNGAddToBuildQueue = AddToBuildQueue
function AddToBuildQueue(aiBrain, builder, whatToBuild, buildLocation, relative)
    if not aiBrain.RNG then
        return RNGAddToBuildQueue(aiBrain, builder, whatToBuild, buildLocation, relative)
    end
    if not builder.EngineerBuildQueue then
        builder.EngineerBuildQueue = {}
    end
    -- put in build queue.. but will be removed afterwards... just so that it can iteratively find new spots to build
    RUtils.EngineerTryReclaimCaptureArea(aiBrain, builder, BuildToNormalLocation(buildLocation)) 
    aiBrain:BuildStructure(builder, whatToBuild, buildLocation, false)
    local newEntry = {whatToBuild, buildLocation, relative}
    table.insert(builder.EngineerBuildQueue, newEntry)
end