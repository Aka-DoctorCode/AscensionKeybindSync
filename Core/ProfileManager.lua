-------------------------------------------------------------------------------
-- Project: AscensionKeybindSync
-- Author: Aka-DoctorCode
-- File: ProfileManager.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

local addonName, addonTable = ...
local Util = addonTable.Util

local ProfileManager = {}
ProfileManager.__index = ProfileManager

function ProfileManager:new(addonInstance)
    local instance = setmetatable({
        addon = addonInstance,
    }, self)
    return instance
end

function ProfileManager:getCurrentBindings()
    local bindings = {}
    for i = 1, 180 do
        local actionType, id, subType = GetActionInfo(i)
        local bindingPrefix, buttonIndex = Util.getBindingPrefixForSlot(i)
        local key1, key2 = GetBindingKey(bindingPrefix .. buttonIndex)
        
        local name, icon, macroData
        if actionType == "spell" then
            local targetSpellID = id
            local isAssistedCombat = (subType == "assistedcombat")
            if not isAssistedCombat and C_ActionBar and C_ActionBar.IsAssistedCombatAction then
                isAssistedCombat = C_ActionBar.IsAssistedCombatAction(i)
            end
            if isAssistedCombat then
                subType = "assistedcombat"
                local combatTable = _G["C_AssistedCombat"]
                if combatTable then
                    local getActionSpell = combatTable["Get" .. "ActionSpell"]
                    if getActionSpell then
                        targetSpellID = getActionSpell(i) or id
                    end
                end
                id = 1229376
            else
                local findBaseSpell = _G["FindBase" .. "SpellByID"]
                if findBaseSpell then
                    targetSpellID = findBaseSpell(id) or id
                end
            end
            local spellInfo = C_Spell.GetSpellInfo(targetSpellID)
            if spellInfo then
                name = spellInfo.name
            end
            icon = C_Spell.GetSpellTexture(targetSpellID)
        elseif actionType == "macro" then
            name = GetActionText(i)
            icon = GetActionTexture(i)
            if name then
                local _, _, macroBody = GetMacroInfo(name)
                if macroBody then
                    macroData = {
                        macroName = Util.encodeBase64(name),
                        macroBody = Util.encodeBase64(macroBody),
                        macroScope = "c",
                    }
                    local macroIndex = GetMacroIndexByName(name)
                    if macroIndex and macroIndex > 0 and macroIndex <= 120 then
                        macroData.macroScope = "a"
                    end
                end
            end
        elseif actionType == "item" then
            name = C_Item.GetItemInfo(id)
            icon = C_Item.GetItemIconByID(id)
            if subType then
                id = id .. ":" .. subType
            end
        elseif actionType == "summonmount" then
            local mountID = tonumber(id) or 0
            name = C_MountJournal.GetMountInfoByID(mountID)
            if name then
                icon = select(3, C_MountJournal.GetMountInfoByID(mountID))
                id = select(2, C_MountJournal.GetMountInfoByID(mountID))
            end
        elseif actionType == "summonpet" then
            local petID = tostring(id)
            name = select(8, C_PetJournal.GetPetInfoByPetID(petID))
            icon = select(9, C_PetJournal.GetPetInfoByPetID(petID))
        elseif actionType == "equipmentset" then
            local setID = tonumber(id) or 0
            name = C_EquipmentSet.GetEquipmentSetInfo(setID)
            icon = select(2, C_EquipmentSet.GetEquipmentSetInfo(setID))
        elseif actionType == "flyout" then
            local flyoutID = tonumber(id) or 0
            name = GetFlyoutInfo(flyoutID)
            icon = select(2, GetFlyoutInfo(flyoutID))
        end
        bindings[i] = {
            actionType = actionType,
            id = id,
            subType = subType,
            key1 = key1,
            key2 = key2,
            name = name,
            icon = icon,
            macroName = macroData and macroData.macroName or nil,
            macroBody = macroData and macroData.macroBody or nil,
            macroScope = macroData and macroData.macroScope or nil,
        }
    end
    return bindings
end

function ProfileManager:clearActionBars()
    for i = 1, 180 do
        PickupAction(i)
        ClearCursor()
    end
end

function ProfileManager:clearKeybindings()
    if GetCurrentBindingSet() == 2 then
        LoadBindings(1)
    end
    for i = 1, 180 do
        local bindingPrefix, buttonIndex = Util.getBindingPrefixForSlot(i)
        local bindingName = bindingPrefix .. buttonIndex
        local key1, key2 = GetBindingKey(bindingName)
        if key1 then SetBinding(key1, nil) end
        if key2 then SetBinding(key2, nil) end
    end
    SaveBindings(1)
end

function ProfileManager:setActionBars(bindings)
    for i = 1, 180 do
        if bindings[i] then
            if bindings[i].actionType and bindings[i].id then
                if bindings[i].actionType == "spell" then
                    C_Spell.PickupSpell(bindings[i].id)
                elseif bindings[i].actionType == "macro" then
                    PickupMacro(bindings[i].id)
                elseif bindings[i].actionType == "item" then
                    if type(bindings[i].id) == "string" and string.find(bindings[i].id, ":") then
                        local itemID, _ = string.split(":", bindings[i].id)
                        C_Item.PickupItem(tonumber(itemID) or 0)
                    else
                        C_Item.PickupItem(bindings[i].id)
                    end
                elseif bindings[i].actionType == "summonmount" then
                    C_Spell.PickupSpell(bindings[i].id)
                elseif bindings[i].actionType == "summonpet" then
                    C_PetJournal.PickupPet(bindings[i].id)
                elseif bindings[i].actionType == "equipmentset" then
                    C_EquipmentSet.PickupEquipmentSet(bindings[i].id)
                elseif bindings[i].actionType == "flyout" then
                    C_SpellBook.PickupSpellBookItem(bindings[i].id, 1)
                end
                PlaceAction(i)
                ClearCursor()
            end
        end
    end
end

function ProfileManager:setKeybindings(bindings)
    if GetCurrentBindingSet() == 2 then
        LoadBindings(1)
    end
    for i = 1, 180 do
        if bindings[i] then
            local bindingPrefix, buttonIndex = Util.getBindingPrefixForSlot(i)
            local bindingName = bindingPrefix .. buttonIndex
            if bindings[i].key1 then
                SetBinding(bindings[i].key1, bindingName)
            end
            if bindings[i].key2 then
                SetBinding(bindings[i].key2, bindingName)
            end
        end
    end
    SaveBindings(1)
end

local function processBatch(list, index, batchSize, processFunc, onFinished)
    if not list or index > #list then
        if onFinished then onFinished() end
        return
    end
    
    local limit = math.min(index + batchSize - 1, #list)
    for i = index, limit do
        processFunc(list[i])
    end
    
    C_Timer.After(0.01, function()
        processBatch(list, limit + 1, batchSize, processFunc, onFinished)
    end)
end

function ProfileManager:createOrUpdateMacros(bindings, onComplete)
    local newMacros = {}
    local conflicts = {}
    local hasMacroData = false

    for i = 1, 180 do
        local b = bindings[i]
        if b and b.actionType == "macro" and b.macroName and b.macroBody then
            hasMacroData = true
            local decodedName = Util.decodeBase64(b.macroName)
            local decodedBody = Util.decodeBase64(b.macroBody)
            local existingIndex = GetMacroIndexByName(decodedName)
            if existingIndex and existingIndex > 0 then
                local _, _, existingBody = GetMacroInfo(existingIndex)
                if existingBody ~= decodedBody then
                    table.insert(conflicts, {
                        slot = i,
                        name = decodedName,
                        body = decodedBody,
                        scope = b.macroScope,
                        existingIndex = existingIndex
                    })
                else
                    bindings[i].id = existingIndex
                end
            else
                table.insert(newMacros, {
                    slot = i,
                    name = decodedName,
                    body = decodedBody,
                    scope = b.macroScope
                })
            end
        end
    end

    if not hasMacroData then
        onComplete(bindings)
        return
    end

    local function processNewMacro(m)
        local perCharacter = (m.scope == "c")
        local newIndex = CreateMacro(m.name, "INV_MISC_QUESTIONMARK", m.body, perCharacter)
        if newIndex then
            bindings[m.slot].id = newIndex
        end
    end

    local function executeFinalSteps(selectedOverwrites)
        local overwriteLookup = {}
        for _, c in ipairs(selectedOverwrites) do
            overwriteLookup[c.slot] = true
        end

        local function processOverwrite(c)
            EditMacro(c.existingIndex, c.name, nil, c.body)
            bindings[c.slot].id = c.existingIndex
        end

        for _, c in ipairs(conflicts) do
            if not overwriteLookup[c.slot] then
                bindings[c.slot].id = c.existingIndex
            end
        end

        processBatch(selectedOverwrites, 1, 3, processOverwrite, function()
            processBatch(newMacros, 1, 3, processNewMacro, function()
                onComplete(bindings)
            end)
        end)
    end

    if #conflicts == 0 then
        processBatch(newMacros, 1, 3, processNewMacro, function()
            onComplete(bindings)
        end)
        return
    end

    self.addon.ui:showMacroConflictDialog(newMacros, conflicts, function(selectedOverwrites)
        executeFinalSteps(selectedOverwrites)
    end, function()
        self.addon:printMessage("Macro import cancelled.")
        self.addon.isApplyingProfile = false
        self.addon.isInitialized = true
    end)
end

function ProfileManager:areBindingsDifferent(current, saved)
    if not current or not saved then return true end
    for i = 1, 180 do
        local c = current[i] or {}
        local s = saved[i] or {}
        if c.actionType ~= s.actionType or c.key1 ~= s.key1 or c.key2 ~= s.key2 then
            return true
        end
        if c.actionType == "macro" then
            if c.macroName ~= s.macroName then
                return true
            end
        else
            if tostring(c.id) ~= tostring(s.id) then
                return true
            end
        end
    end
    return false
end

addonTable.ProfileManager = ProfileManager
