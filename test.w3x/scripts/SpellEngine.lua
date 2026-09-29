-- Immediate print on loading screen processing
print("|cff00ff00====================================|r")
print("|cffffcc00[Lua Test]|r Hello World! Engine is active!")
print("|cff00ff00====================================|r")

-- Delayed in-game message test (runs 1 second after map start)
local function TestHelloWorld()
    local trg = CreateTrigger()
    TriggerRegisterTimerEvent(trg, 1.0, false)
    TriggerAddAction(trg, function()
        DisplayTextToPlayer(GetLocalPlayer(), 0, 0, "|cff00ffff[In-Game Test]|r Hello World from Lua!")
    end)
end

-- Hook into map start
local oldInit = InitGlobals
function InitGlobals()
    if oldInit then oldInit() end
    TestHelloWorld()
end
