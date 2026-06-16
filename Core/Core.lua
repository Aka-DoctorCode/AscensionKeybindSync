-------------------------------------------------------------------------------
-- Project: AscensionKeybindSync
-- Author: Aka-DoctorCode
-- File: Core.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

local addonName, addonTable = ...
local AceAddon = LibStub("AceAddon-3.0")
local AceDB = LibStub("AceDB-3.0")

local addon = AceAddon:NewAddon(addonName, "AceEvent-3.0")
addon.profileManager = nil
addon.ui = nil
addon.configFrame = nil
addon.isApplyingProfile = false
addon.isInitialized = false
addon.macroImportContext = nil

local isSavePending = false

function addon:OnInitialize()
    local defaults = {
        global = {
            profiles = {},
            activeProfiles = {},
            enableAutoSync = true,
        }
    }
    self.db = AceDB:New("AscensionKeybindSyncDB", defaults)
    
    local suitUI = LibStub:GetLibrary("AscensionSuit-UI", true)
    if not suitUI then
        error("AscensionSuit-UI not found! This addon requires AscensionSuit to run.")
    end
    self.uiContext = suitUI:CreateContext()

    self.profileManager = addonTable.ProfileManager:new(self)
    self.ui = addonTable.UI:new(self)
    
    self:migrateDatabase()
    
    self.ui:registerOptionsUI()
end

function addon:OnEnable()
    self:RegisterEvent("ACTIONBAR_SLOT_CHANGED", "onActionBarSlotChanged")
    self:RegisterEvent("UPDATE_BINDINGS", "onUpdateBindings")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "onPlayerEnteringWorld")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "onPlayerSpecializationChanged")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "onPlayerRegenEnabled")
end

function addon:onPlayerRegenEnabled()
    if self.isDirtyInCombat then
        self.isDirtyInCombat = false
        self:scheduleAutoSave()
    end
    if self.combatQueue then
        local q = self.combatQueue
        self.combatQueue = nil
        if q.type == "load" then
            self:applyProfile(q.bindings, q.profileID)
        elseif q.type == "save" then
            self:saveProfileManually()
        end
    end
end

function addon:onActionBarSlotChanged()
    self:scheduleAutoSave()
end

function addon:onUpdateBindings()
    self:scheduleAutoSave()
end

function addon:onPlayerEnteringWorld(event, isInitialLogin, isReload)
    self.isInitialized = false
    C_Timer.After(1, function()
        self:checkAndPromptLoad()
    end)
end

function addon:onPlayerSpecializationChanged()
    self.isInitialized = false
    C_Timer.After(1, function()
        self:checkAndPromptLoad()
    end)
end

function addon:migrateDatabase()
    if not self.db.global.classProfiles then return end
    
    if not self.db.global.profiles then
        self.db.global.profiles = {}
    end
    if not self.db.global.activeProfiles then
        self.db.global.activeProfiles = {}
    end
    
    local counter = 1
    for classToken, specs in pairs(self.db.global.classProfiles) do
        for specID, bindings in pairs(specs) do
            local _, specName = GetSpecializationInfoByID(specID)
            specName = specName or "Unknown Spec"
            
            local profileID = string.format("%s-%d-%d", classToken, specID, counter)
            counter = counter + 1
            
            self.db.global.profiles[profileID] = {
                name = "Imported - " .. specName,
                classToken = classToken,
                specID = specID,
                bindings = bindings,
            }
            
            if not self.db.global.activeProfiles[classToken] then
                self.db.global.activeProfiles[classToken] = {}
            end
            self.db.global.activeProfiles[classToken][specID] = profileID
        end
    end
    
    self.db.global.classProfiles = nil
    self:printMessage("Database migrated to multi-profile schema.")
end

function addon:scheduleAutoSave()
    if not self.isInitialized then return end
    if self.isApplyingProfile then return end
    if not self.db.global.enableAutoSync then return end
    
    if InCombatLockdown() then
        self.isDirtyInCombat = true
        return
    end
    
    if isSavePending then return end
    isSavePending = true
    
    C_Timer.After(0.1, function()
        isSavePending = false
        if self.isApplyingProfile then return end
        if InCombatLockdown() then
            self.isDirtyInCombat = true
            return
        end
        
        local classToken, specID = self:getCurrentClassAndSpec()
        local activeProfileID = self.db.global.activeProfiles[classToken] and self.db.global.activeProfiles[classToken][specID]
        if activeProfileID and self.db.global.profiles[activeProfileID] then
            local currentBindings = self.profileManager:getCurrentBindings()
            local activeProfile = self.db.global.profiles[activeProfileID]
            
            if self.profileManager:areBindingsDifferent(currentBindings, activeProfile.bindings) then
                activeProfile.bindings = currentBindings
                self.ui:showToast("Profile Auto-Saved", "success")
                self.ui:updateSaveButtonState()
                self.ui:updatePreviewGrid(activeProfile.bindings)
            end
        end
    end)
end

function addon:checkAndPromptLoad()
    if not self.db.global.enableAutoSync then
        self.isInitialized = true
        return
    end
    if InCombatLockdown() then return end
    
    local classToken, specID = self:getCurrentClassAndSpec()
    
    local activeProfileID = self.db.global.activeProfiles[classToken] and self.db.global.activeProfiles[classToken][specID]
    local savedProfile = activeProfileID and self.db.global.profiles[activeProfileID]
    
    if not savedProfile then
        if next(self.db.global.profiles) == nil then
            self:showCustomDialog("Welcome", "Welcome to AscensionKeybindSync! Please create your first profile to start saving and syncing your keybinds/bars.", {
                {
                    text = "Create First Profile",
                    onClick = function()
                        self.ui:showCreateProfileDialog(function()
                            self.isInitialized = true
                        end)
                    end
                },
                {
                    text = "Ignore",
                    onClick = function()
                        self.isInitialized = true
                    end
                }
            })
        else
            self:showCustomDialog("No Active Profile", "No active profile linked to current spec. Would you like to create a new profile from current action bars, or link an existing profile?", {
                {
                    text = "Create New",
                    onClick = function()
                        self.ui:showCreateProfileDialog(function()
                            self.isInitialized = true
                        end)
                    end
                },
                {
                    text = "Link Existing",
                    onClick = function()
                        self.ui:openConfigMenu()
                        if not self.ui.profileListFrame then
                            self.ui:createProfileListPanel(self.ui.configFrame)
                        end
                        self.ui:updateProfileList()
                        self.ui.profileListFrame:Show()
                        self.isInitialized = true
                    end
                },
                {
                    text = "Ignore",
                    onClick = function()
                        self.isInitialized = true
                    end
                }
            })
        end
        return
    end
    
    local current = self.profileManager:getCurrentBindings()
    if not self.profileManager:areBindingsDifferent(current, savedProfile.bindings) then
        self.isInitialized = true
        return
    end
    
    local _, specName = GetSpecializationInfoByID(specID)
    specName = specName or "Unknown"
    
    local text = string.format("A saved profile exists for specialization '%s'. Do you want to apply it?", specName)
    self.ui:showCustomDialog("Confirm Load", text, {
        {
            text = "Yes",
            onClick = function()
                self:applyProfile(savedProfile.bindings)
            end
        },
        {
            text = "No",
            onClick = function()
                self.isInitialized = true
            end
        }
    })
end

function addon:applyProfile(bindings, profileID)
    if InCombatLockdown() then
        self.combatQueue = { type = "load", bindings = bindings, profileID = profileID }
        self.ui:showToast("In combat. Load queued.", "error")
        return
    end
    self.isApplyingProfile = true
    self.profileManager:createOrUpdateMacros(bindings, function(updatedBindings)
        self.profileManager:clearActionBars()
        self.profileManager:clearKeybindings()
        self.profileManager:setActionBars(updatedBindings)
        self.profileManager:setKeybindings(updatedBindings)
        self.isApplyingProfile = false
        self.isInitialized = true
        if profileID then
            local classToken, specID = self:getCurrentClassAndSpec()
            if not self.db.global.activeProfiles[classToken] then
                self.db.global.activeProfiles[classToken] = {}
            end
            self.db.global.activeProfiles[classToken][specID] = profileID
        end
        self.ui:updateSaveButtonState()
        self.ui:showToast("Profile Applied", "success")
    end)
end

function addon:saveProfileManually()
    if InCombatLockdown() then
        self.combatQueue = { type = "save" }
        self.ui:showToast("In combat. Save queued.", "error")
        return
    end
    local classToken, specID = self:getCurrentClassAndSpec()
    self.isInitialized = true
    
    local activeProfileID = self.db.global.activeProfiles[classToken] and self.db.global.activeProfiles[classToken][specID]
    if not activeProfileID then
        self:printMessage("No active profile linked to current specialization.")
        return
    end
    
    local currentBindings = self.profileManager:getCurrentBindings()
    self.db.global.profiles[activeProfileID].bindings = currentBindings
    self.ui:showToast("Profile Saved", "success")
    self.ui:updateSaveButtonState()
end

function addon:loadProfileManually()
    local classToken, specID = self:getCurrentClassAndSpec()
    self.isInitialized = true
    local activeProfileID = self.db.global.activeProfiles[classToken] and self.db.global.activeProfiles[classToken][specID]
    local savedProfile = activeProfileID and self.db.global.profiles[activeProfileID]
    if not savedProfile then
        self:printMessage("No profile saved for this specialization.")
        return
    end
    self:applyProfile(savedProfile.bindings)
end

function addon:showCustomDialog(title, text, buttons)
    self.ui:showCustomDialog(title, text, buttons)
end

function addon:getCurrentClassAndSpec()
    local _, classToken = UnitClass("player")
    classToken = string.lower(classToken)
    local currentSpec = GetSpecialization()
    local specID = currentSpec and GetSpecializationInfo(currentSpec) or 0
    return classToken, specID
end

function addon:printMessage(msg)
    print("|cFF80CCFF[" .. addonName .. "]|r " .. msg)
end

_G.AscensionKeybindSync = addon
addonTable.addon = addon
