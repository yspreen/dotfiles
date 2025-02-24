do_cut = false

currentBundle = function()
    result = hs.window.focusedWindow()
    if result == nil then
        return ""
    end
    result = result:application()
    if result == nil then
        return ""
    end
    result = result:bundleID()
    if result == nil then
        return ""
    end
    return result
end

fc = function()
    hkc:disable()
    if currentBundle() == "com.apple.finder" then
        hs.eventtap.keyStroke({"cmd"}, "C")
        do_cut = false
    else
        hs.eventtap.keyStroke({"cmd"}, "C")
    end
    hkc:enable()
end
fc = function()
    hkc:disable()
    if currentBundle() == "com.apple.finder" then
        hs.eventtap.keyStroke({"cmd"}, "C")
        do_cut = false
    else
        hs.eventtap.keyStroke({"cmd"}, "C")
    end
    hkc:enable()
end

fx = function()
    hkc:disable()
    hkx:disable()
    if currentBundle() == "com.apple.finder" then
        hs.eventtap.keyStroke({"cmd"}, "C")
        do_cut = true
    else
        hs.eventtap.keyStroke({"cmd"}, "X")
    end
    hkc:enable()
    hkx:enable()
end

fv = function()
    hkv:disable()
    if currentBundle() == "com.apple.finder" then
        if do_cut then
            hs.eventtap.keyStroke({"cmd", "alt"}, "V")
        else
            hs.eventtap.keyStroke({"cmd"}, "V")
        end
        do_cut = false
    else
        hs.eventtap.keyStroke({"cmd"}, "V")
    end
    hkv:enable()
end
fm = function()
    hkm:disable()
    if hs.application.get("com.hnc.Discord") == nil then
        hs.eventtap.keyStroke({"cmd"}, "N")
    else
        hs.eventtap.event.newKeyEvent({"cmd", "shift"}, "m", true):post(hs.application.get("com.hnc.Discord"))
        hs.eventtap.event.newKeyEvent({"cmd", "shift"}, "m", false):post(hs.application.get("com.hnc.Discord"))
    end
    hkm:enable()
end

hkc = hs.hotkey.new({"cmd"}, "C", fc)
hkc:enable()
hkx = hs.hotkey.new({"cmd"}, "X", fx)
hkx:enable()
hkv = hs.hotkey.new({"cmd"}, "V", fv)
hkv:enable()
hkm = hs.hotkey.new({"cmd"}, "N", fm)
hkm:enable()

-- hs.hotkey.bind({}, "P", function()
--     hs.eventtap.keyStroke({}, "F8")
--     hs.timer.doAfter(0.05, function() hs.eventtap.keyStroke({}, "Right") end)
--     hs.timer.doAfter(0.10, function() hs.eventtap.keyStroke({"cmd"}, ".") end)
--     hs.timer.doAfter(0.15, function() hs.eventtap.keyStroke({}, "return") end)
-- end)

-- AClock = hs.loadSpoon('AClock')
-- AClock:init()
-- AClock:show()