local ValidateAITaskTemplate = import("/lua/aibrains/tasks/task.lua").ValidateAITaskTemplate
local EngineerManagerConditions = import("/mods/rngai/lua/ai/management-framework/conditions/EngineerManagerConditions.lua")

MobileEngineerTech1 = ValidateAITaskTemplate({
    BaseConditions = { 
        { EngineerManagerConditions.LessEngineersThan, { 5 } },
     },
    BrainConditions = {},
    BuildCategory = categories.ENGINEER * categories.TECH1,
    Identifier = "(Tech 1) Mobile Engineer",
    DefaultDistance = 25,
    DefaultPriority = 100,
    PreferredChunk = "todo",
})

MobileEngineerTech2 = ValidateAITaskTemplate({
    BaseConditions = {},
    BrainConditions = {},
    BuildCategory = categories.ENGINEER * categories.TECH2,
    Identifier = "(Tech 2) Mobile Engineer",
    DefaultDistance = 25,
    DefaultPriority = 100,
    PreferredChunk = "todo",
})

MobileEngineerTech3 = ValidateAITaskTemplate({
    BaseConditions = {},
    BrainConditions = {},
    BuildCategory = categories.ENGINEER * categories.TECH3,
    Identifier = "(Tech 3) Mobile Engineer",
    DefaultDistance = 25,
    DefaultPriority = 100,
    PreferredChunk = "todo",
})