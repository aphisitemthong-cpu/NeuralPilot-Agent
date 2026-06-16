require "import"
import "com.androlua.Http"
import "android.widget.*"
import "android.view.*"
import "android.app.*"
import "java.util.*"
import "android.content.*"
import "android.speech.tts.TextToSpeech"
import "android.speech.SpeechRecognizer"
import "android.speech.RecognizerIntent"
import "com.loopj.android.http.*"
import "cjson"
import "android.Manifest"
import "android.content.pm.PackageManager"
import "android.os.Vibrator"
import "android.os.Build"
import "android.os.StrictMode"
import "android.content.ClipboardManager"
import "android.content.ClipData"
import "android.text.InputType"
import "java.io.File"
import "java.net.URL"
import "java.net.URLEncoder"
import "java.io.BufferedReader"
import "java.io.InputStreamReader"
import "android.net.Uri"
import "android.provider.Settings"

if table == nil then
    table = {}
end

if table.insert == nil then
    table.insert = function(t, v)
        t[#t + 1] = v
    end
end

if table.concat == nil then
    table.concat = function(t, sep)
        sep = sep or ""
        local s = ""
        for i = 1, #t do
            if i > 1 then
                s = s .. sep
            end
            s = s .. tostring(t[i])
        end
        return s
    end
end

local activity = activity
local APP_NAME = "NeuralPilot Agent"
local VERSION = "3.5.2"

local APP_FOLDER = "/storage/emulated/0/NeuralPilot/"
local CONVERSATIONS_FILE = APP_FOLDER .. "neuralpilot_conversations.txt"
local GENERATED_CODE_FOLDER = APP_FOLDER .. "generated_code/"
local SETTINGS_FILE = APP_FOLDER .. "neuralpilot_settings.json"

local AUTO_UPDATE_URL = "https://raw.githubusercontent.com/aphisitemthong-cpu/NeuralPilot-Agent/main/main.lua"
local AUTO_UPDATE_FILE = APP_FOLDER .. "neuralpilot_latest.lua"
local AUTO_UPDATE_LOG_FILE = APP_FOLDER .. "neuralpilot_auto_update_log.txt"
local AUTO_UPDATE_ENABLED_DEFAULT = true

local OPENROUTER_API_URL = "https://openrouter.ai/api/v1/chat/completions"
local OPENROUTER_MODELS_LIST_URL = "https://openrouter.ai/api/v1/models"
local GOOGLE_API_BASE = "https://generativelanguage.googleapis.com/v1beta/models/"
local GOOGLE_MODELS_LIST_URL = "https://generativelanguage.googleapis.com/v1beta/models"
local NVIDIA_API_URL = "https://integrate.api.nvidia.com/v1/chat/completions"
local NVIDIA_MODELS_LIST_URL = "https://integrate.api.nvidia.com/v1/models"

local tts
local speechRecognizer
local vibrator
local isListening = false

local mainLayout
local settingsLayout
local conversationTextView
local taskInput
local selectedModelText
local agentStatusText
local settingsProviderText
local settingsModelText
local settingsPermissionsText
local autoUpdateStatusText
local memoryButton
local runtimeModeButton
local responseStyleButton
local autoUpdateButton
local codeButton
local stopButton

local openRouterApiKey = ""
local openRouterModel = "openrouter/free"
local googleApiKey = ""
local googleModel = "gemini-2.0-flash"
local nvidiaApiKey = ""
local nvidiaModel = "meta/llama-3.1-8b-instruct"
local apiProvider = "openrouter"

local openRouterKeyIndex = 0
local googleKeyIndex = 0
local nvidiaKeyIndex = 0

local memoryEnabled = true
local autoUpdateEnabled = AUTO_UPDATE_ENABLED_DEFAULT
local runtimeMode = "safe"
local permissionIO = false
local permissionOS = false
local permissionImport = false
local permissionUnrestricted = false
local userPersonalInfo = ""

local responseStyle = "Balanced"
local responseStyles = {
    "Balanced",
    "Concise",
    "Detailed",
    "Friendly",
    "Professional",
    "Step-by-step",
    "Beginner-friendly",
    "Accessibility-focused",
    "Technical",
    "Creative"
}

local generatedCodeCount = 0
local generatedCodes = {}
local currentConversation = {user = {}, assistant = {}}

local agentActive = false
local agentStopRequested = false
local agentRunId = 0
local agentIteration = 0
local finalAnswerRepairCount = 0

local currentUserTask = ""
local currentHistoryText = ""
local lastGeneratedCode = ""
local lastRuntimeOutput = ""
local lastRuntimeError = ""
local currentAssistantPrefix = ""

function addItem(list, value)
    list[#list + 1] = value
end

function joinList(list, sep)
    sep = sep or ""
    local s = ""
    for i = 1, #list do
        if i > 1 then
            s = s .. sep
        end
        s = s .. tostring(list[i])
    end
    return s
end

function hasText(value)
    return value ~= nil and tostring(value):match("%S") ~= nil
end

function trimText(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function createFolder(path)
    local f = File(path)
    if not f.exists() then
        f.mkdirs()
    end
end

function ensureFiles()
    createFolder(APP_FOLDER)
    createFolder(GENERATED_CODE_FOLDER)
    local f = io.open(CONVERSATIONS_FILE, "a+")
    if f then
        f:close()
    end
end

function setupNetworkPolicy()
    pcall(function()
        local policy = StrictMode.ThreadPolicy.Builder().permitAll().build()
        StrictMode.setThreadPolicy(policy)
    end)
end

function fileExists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

function readTextFile(path)
    local f = io.open(path, "r")
    if not f then
        return nil, "Cannot open file for reading: " .. tostring(path)
    end
    local content = f:read("*a")
    f:close()
    return content, nil
end

function saveTextFile(path, text)
    local f = io.open(path, "w")
    if not f then
        return false, "Cannot open file for writing: " .. tostring(path)
    end
    f:write(tostring(text or ""))
    f:close()
    return true, ""
end

function countTextLines(text)
    local value = tostring(text or "")
    if value == "" then return 0 end

    local count = 1
    for _ in value:gmatch("\n") do
        count = count + 1
    end
    return count
end

function formatBytes(size)
    size = tonumber(size) or 0

    if size >= 1024 * 1024 then
        return string.format("%.2f MB", size / 1024 / 1024)
    elseif size >= 1024 then
        return string.format("%.2f KB", size / 1024)
    else
        return tostring(size) .. " bytes"
    end
end

function extractVersionFromCode(code)
    local version = tostring(code or ""):match('VERSION%s*=%s*"([^"]+)"')
    if version then return version end

    version = tostring(code or ""):match("VERSION%s*=%s*'([^']+)'")
    if version then return version end

    return "Unknown"
end

function autoUpdateToast(message, long)
    local text = tostring(message or "")
    if #text > 3000 then
        text = string.sub(text, 1, 3000) .. "\n...check update log for full message..."
    end
    Toast.makeText(activity, text, long and Toast.LENGTH_LONG or Toast.LENGTH_SHORT).show()
end

function writeAutoUpdateLog(title, message)
    pcall(function()
        createFolder(APP_FOLDER)
        local f = io.open(AUTO_UPDATE_LOG_FILE, "a+")
        if f then
            f:write("==== " .. tostring(title) .. " ====\n")
            f:write(tostring(message or "") .. "\n")
            f:write("Built-in app version: " .. tostring(VERSION) .. "\n")
            f:write("Auto update enabled: " .. tostring(autoUpdateEnabled) .. "\n")
            f:write("Update URL: " .. tostring(AUTO_UPDATE_URL) .. "\n")
            f:write("Update file: " .. tostring(AUTO_UPDATE_FILE) .. "\n")
            f:write("==============================\n\n")
            f:close()
        end
    end)
end

function getLocalUpdateInfo()
    local content = nil
    local err = nil

    if fileExists(AUTO_UPDATE_FILE) then
        content, err = readTextFile(AUTO_UPDATE_FILE)
    end

    if content then
        return {
            exists = true,
            version = extractVersionFromCode(content),
            size = #content,
            lines = countTextLines(content)
        }
    end

    return {
        exists = false,
        version = "None",
        size = 0,
        lines = 0
    }
end

function buildUpdateDetails(remoteContent)
    local localInfo = getLocalUpdateInfo()
    local remoteText = tostring(remoteContent or "")
    local remoteVersion = extractVersionFromCode(remoteText)
    local remoteSize = #remoteText
    local remoteLines = countTextLines(remoteText)

    local details = ""
    details = details .. "A remote NeuralPilot Agent script is available.\n\n"
    details = details .. "Current built-in version: " .. tostring(VERSION) .. "\n"
    details = details .. "Saved local update version: " .. tostring(localInfo.version) .. "\n"
    details = details .. "Remote version: " .. tostring(remoteVersion) .. "\n\n"
    details = details .. "Remote script size: " .. formatBytes(remoteSize) .. " (" .. tostring(remoteSize) .. " bytes)\n"
    details = details .. "Remote code lines: " .. tostring(remoteLines) .. " lines\n\n"

    if localInfo.exists then
        details = details .. "Saved local update size: " .. formatBytes(localInfo.size) .. " (" .. tostring(localInfo.size) .. " bytes)\n"
        details = details .. "Saved local update lines: " .. tostring(localInfo.lines) .. " lines\n\n"
    else
        details = details .. "Saved local update: none\n\n"
    end

    details = details .. "Update URL:\n" .. tostring(AUTO_UPDATE_URL) .. "\n\n"
    details = details .. "Update file:\n" .. tostring(AUTO_UPDATE_FILE) .. "\n\n"
    details = details .. "Press Update Now to save and start the downloaded version."

    return details
end

function startDownloadedLatestVersion(savedInstanceState)
    if not fileExists(AUTO_UPDATE_FILE) then
        return false, "Downloaded update file does not exist."
    end

    local func, loadErr = loadfile(AUTO_UPDATE_FILE)
    if not func then
        return false, "Load error: " .. tostring(loadErr)
    end

    local oldOnCreate = onCreate
    local oldOnPause = onPause
    local oldOnDestroy = onDestroy

    _G.NEURALPILOT_BOOTLOADED_LATEST = true

    local ok, runErr = xpcall(function()
        func()
    end, function(err)
        if debug and debug.traceback then
            return debug.traceback(tostring(err), 2)
        end
        return tostring(err)
    end)

    if not ok then
        onCreate = oldOnCreate
        onPause = oldOnPause
        onDestroy = oldOnDestroy
        return false, "Runtime error while loading saved update: " .. tostring(runErr)
    end

    if type(onCreate) == "function" and onCreate ~= oldOnCreate then
        local startOk, startErr = xpcall(function()
            onCreate(savedInstanceState)
        end, function(err)
            if debug and debug.traceback then
                return debug.traceback(tostring(err), 2)
            end
            return tostring(err)
        end)

        if startOk then
            return true, ""
        else
            onCreate = oldOnCreate
            onPause = oldOnPause
            onDestroy = oldOnDestroy
            return false, "Saved update onCreate error: " .. tostring(startErr)
        end
    end

    return false, "Saved update loaded, but no replacement onCreate function was found."
end

function startSavedUpdateOrBuiltIn(savedInstanceState, reason)
    writeAutoUpdateLog("Start saved update or built-in", tostring(reason or ""))

    if fileExists(AUTO_UPDATE_FILE) then
        autoUpdateToast("Starting saved NeuralPilot update.", false)

        local savedOk, savedErr = startDownloadedLatestVersion(savedInstanceState)
        if savedOk then
            writeAutoUpdateLog("Saved update started", "Saved update started successfully.")
            return
        end

        writeAutoUpdateLog("Saved update failed", savedErr)
        autoUpdateToast("Saved update could not start. Starting built-in version.", true)
        _G.NEURALPILOT_BOOTLOADED_LATEST = false
        startMainApp(savedInstanceState)
        return
    end

    writeAutoUpdateLog("No saved update", "No saved update file exists. Starting built-in version.")
    startMainApp(savedInstanceState)
end

function saveAndStartRemoteUpdate(remoteContent, savedInstanceState)
    local saveOk, saveErr = saveTextFile(AUTO_UPDATE_FILE, remoteContent)
    if not saveOk then
        writeAutoUpdateLog("Auto update save error", saveErr)
        autoUpdateToast("Update download succeeded, but saving failed. Starting saved update or built-in version.", true)
        startSavedUpdateOrBuiltIn(savedInstanceState, "Remote update save failed.")
        return
    end

    writeAutoUpdateLog("Auto update saved", "Latest script saved successfully. Size: " .. tostring(#tostring(remoteContent)) .. " bytes. Lines: " .. tostring(countTextLines(remoteContent)) .. ".")
    autoUpdateToast("Latest version saved. Starting update.", false)

    local latestOk, latestErr = startDownloadedLatestVersion(savedInstanceState)
    if latestOk then
        writeAutoUpdateLog("Auto update success", "Latest version started successfully.")
        return
    end

    writeAutoUpdateLog("Auto update runtime fallback", latestErr)
    autoUpdateToast("Latest version could not start. Starting built-in version instead.", true)
    _G.NEURALPILOT_BOOTLOADED_LATEST = false
    startMainApp(savedInstanceState)
end

function showUpdateAvailableDialog(remoteContent, savedInstanceState, manualCheck)
    local details = buildUpdateDetails(remoteContent)

    local builder = AlertDialog.Builder(activity)
    builder.setTitle("NeuralPilot Update Available")
    builder.setMessage(details)
    builder.setPositiveButton("Update Now", {
        onClick = function()
            saveAndStartRemoteUpdate(remoteContent, savedInstanceState)
        end
    })
    builder.setNegativeButton("Skip", {
        onClick = function()
            writeAutoUpdateLog("Auto update skipped", "User skipped update popup.")
            if manualCheck then
                autoUpdateToast("Update skipped.", false)
            else
                startSavedUpdateOrBuiltIn(savedInstanceState, "User skipped remote update popup.")
            end
        end
    })
    builder.setNeutralButton("Disable Auto Update", {
        onClick = function()
            autoUpdateEnabled = false
            saveSettings()
            updateAutoUpdateButtonText()
            updateAutoUpdateStatusText()
            writeAutoUpdateLog("Auto update disabled", "User disabled auto update from update popup.")
            autoUpdateToast("Auto update disabled.", true)
            if not manualCheck then
                startSavedUpdateOrBuiltIn(savedInstanceState, "Auto update disabled from update popup.")
            end
        end
    })
    builder.show()
end

function checkForLatestVersionThenStart(savedInstanceState, manualCheck)
    setupNetworkPolicy()
    createFolder(APP_FOLDER)

    if not autoUpdateEnabled and not manualCheck then
        writeAutoUpdateLog("Auto update disabled", "Starting saved update first because auto update is off.")
        startSavedUpdateOrBuiltIn(savedInstanceState, "Auto update is off.")
        return
    end

    if manualCheck then
        autoUpdateToast("Checking for latest NeuralPilot Agent update...", false)
    else
        autoUpdateToast("Checking for latest NeuralPilot Agent...", false)
    end

    writeAutoUpdateLog("Auto update started", "Checking remote script.")

    Http.get(AUTO_UPDATE_URL, function(code, content)
        local callbackOk, callbackErr = xpcall(function()
            if code == 200 and content and tostring(content):match("%S") then
                writeAutoUpdateLog("Remote update downloaded", "Remote size: " .. tostring(#tostring(content)) .. " bytes. Remote lines: " .. tostring(countTextLines(content)) .. ".")

                showUpdateAvailableDialog(content, savedInstanceState, manualCheck)
            else
                local msg = "Download failed. HTTP Code: " .. tostring(code)
                if content then
                    msg = msg .. "\nResponse preview: " .. tostring(string.sub(tostring(content), 1, 500))
                end

                writeAutoUpdateLog("Auto update download failed", msg)

                if manualCheck then
                    autoUpdateToast("Could not download latest version. HTTP Code: " .. tostring(code), true)
                else
                    autoUpdateToast("Could not download latest version. Starting saved update or built-in version.", true)
                    startSavedUpdateOrBuiltIn(savedInstanceState, "Remote download failed.")
                end
            end
        end, function(err)
            if debug and debug.traceback then
                return debug.traceback(tostring(err), 2)
            end
            return tostring(err)
        end)

        if not callbackOk then
            writeAutoUpdateLog("Auto update callback fatal error", callbackErr)

            if manualCheck then
                autoUpdateToast("Update system error. Check update log.", true)
            else
                autoUpdateToast("Update system error. Starting saved update or built-in version.", true)
                startSavedUpdateOrBuiltIn(savedInstanceState, "Auto update callback fatal error.")
            end
        end
    end)
end

function toggleAutoUpdate()
    autoUpdateEnabled = not autoUpdateEnabled
    saveSettings()
    updateAutoUpdateButtonText()
    updateAutoUpdateStatusText()

    if autoUpdateEnabled then
        speak("Automatic update is enabled.")
    else
        speak("Automatic update is disabled.")
    end
end

function updateAutoUpdateButtonText()
    if autoUpdateButton then
        autoUpdateButton.setText(autoUpdateEnabled and "Automatic Update: On" or "Automatic Update: Off")
    end
end

function updateAutoUpdateStatusText()
    if autoUpdateStatusText then
        local localInfo = getLocalUpdateInfo()
        local status = autoUpdateEnabled and "On" or "Off"

        autoUpdateStatusText.setText(
            "Automatic update: " .. status ..
            "\nUpdate URL: " .. tostring(AUTO_UPDATE_URL) ..
            "\nSaved update file: " .. tostring(AUTO_UPDATE_FILE) ..
            "\nSaved update version: " .. tostring(localInfo.version) ..
            "\nSaved update size: " .. formatBytes(localInfo.size) ..
            "\nSaved update lines: " .. tostring(localInfo.lines) ..
            "\nUpdate log: " .. tostring(AUTO_UPDATE_LOG_FILE)
        )
    end
end

function splitApiKeys(text)
    local keys = {}
    for line in tostring(text or ""):gmatch("[^\r\n]+") do
        local key = trimText(line)
        if key ~= "" then
            addItem(keys, key)
        end
    end
    return keys
end

function hasApiKeys(text)
    return #splitApiKeys(text) > 0
end

function getNextApiKey(provider)
    if provider == "google" then
        local keys = splitApiKeys(googleApiKey)
        if #keys == 0 then return "" end
        googleKeyIndex = googleKeyIndex + 1
        if googleKeyIndex > #keys then googleKeyIndex = 1 end
        return keys[googleKeyIndex]
    elseif provider == "nvidia" then
        local keys = splitApiKeys(nvidiaApiKey)
        if #keys == 0 then return "" end
        nvidiaKeyIndex = nvidiaKeyIndex + 1
        if nvidiaKeyIndex > #keys then nvidiaKeyIndex = 1 end
        return keys[nvidiaKeyIndex]
    else
        local keys = splitApiKeys(openRouterApiKey)
        if #keys == 0 then return "" end
        openRouterKeyIndex = openRouterKeyIndex + 1
        if openRouterKeyIndex > #keys then openRouterKeyIndex = 1 end
        return keys[openRouterKeyIndex]
    end
end

function saveSettings()
    createFolder(APP_FOLDER)

    local data = {
        apiKey = openRouterApiKey,
        model = openRouterModel,
        googleApiKey = googleApiKey,
        googleModel = googleModel,
        nvidiaApiKey = nvidiaApiKey,
        nvidiaModel = nvidiaModel,
        apiProvider = apiProvider,
        memoryEnabled = memoryEnabled,
        autoUpdateEnabled = autoUpdateEnabled,
        runtimeMode = runtimeMode,
        permissionIO = permissionIO,
        permissionOS = permissionOS,
        permissionImport = permissionImport,
        permissionUnrestricted = permissionUnrestricted,
        userPersonalInfo = userPersonalInfo,
        responseStyle = responseStyle
    }

    local f = io.open(SETTINGS_FILE, "w")
    if f then
        f:write(cjson.encode(data))
        f:close()
    else
        speak("Unable to save settings.")
    end
end

function loadSettings()
    local f = io.open(SETTINGS_FILE, "r")
    if not f then return end

    local content = f:read("*a")
    f:close()

    local ok, data = pcall(cjson.decode, content)
    if not ok or not data then return end

    if data.apiKey then openRouterApiKey = tostring(data.apiKey) end
    if data.model then openRouterModel = tostring(data.model) end
    if data.googleApiKey then googleApiKey = tostring(data.googleApiKey) end
    if data.googleModel then googleModel = tostring(data.googleModel) end
    if data.nvidiaApiKey then nvidiaApiKey = tostring(data.nvidiaApiKey) end
    if data.nvidiaModel then nvidiaModel = tostring(data.nvidiaModel) end
    if data.userPersonalInfo then userPersonalInfo = tostring(data.userPersonalInfo) end
    if data.responseStyle then responseStyle = tostring(data.responseStyle) end

    if data.apiProvider then
        apiProvider = tostring(data.apiProvider)
        if apiProvider ~= "openrouter" and apiProvider ~= "google" and apiProvider ~= "nvidia" then
            apiProvider = "openrouter"
        end
    end

    if data.memoryEnabled ~= nil then memoryEnabled = data.memoryEnabled end
    if data.autoUpdateEnabled ~= nil then autoUpdateEnabled = data.autoUpdateEnabled end
    if data.permissionIO ~= nil then permissionIO = data.permissionIO end
    if data.permissionOS ~= nil then permissionOS = data.permissionOS end
    if data.permissionImport ~= nil then permissionImport = data.permissionImport end
    if data.permissionUnrestricted ~= nil then permissionUnrestricted = data.permissionUnrestricted end

    if data.runtimeMode then
        runtimeMode = tostring(data.runtimeMode)
        if runtimeMode ~= "safe" and runtimeMode ~= "expanded" and runtimeMode ~= "android" and runtimeMode ~= "unrestricted" then
            runtimeMode = "safe"
        end
    end

    local validStyle = false
    for i = 1, #responseStyles do
        if responseStyle == responseStyles[i] then
            validStyle = true
        end
    end
    if not validStyle then
        responseStyle = "Balanced"
    end
end

function speak(text)
    text = tostring(text or "")
    if tts then
        tts.speak(text, TextToSpeech.QUEUE_FLUSH, nil)
    else
        Toast.makeText(activity, text, Toast.LENGTH_SHORT).show()
    end
end

function vibrate(ms)
    if vibrator then
        vibrator.vibrate(ms)
    end
end

function appendConversationDisplay(text)
    if not conversationTextView then return end
    text = tostring(text or "")
    local old = tostring(conversationTextView.getText())
    if old == "" then
        conversationTextView.setText(text)
    else
        conversationTextView.setText(old .. "\n\n" .. text)
    end
end

function getProviderDisplayName()
    if apiProvider == "google" then return "Google AI Studio" end
    if apiProvider == "nvidia" then return "NVIDIA NIM" end
    return "OpenRouter"
end

function getCurrentModelName()
    if apiProvider == "google" then return googleModel end
    if apiProvider == "nvidia" then return nvidiaModel end
    return openRouterModel
end

function getRuntimeModeDisplayName()
    if runtimeMode == "expanded" then return "Expanded Runtime" end
    if runtimeMode == "android" then return "Android Runtime" end
    if runtimeMode == "unrestricted" then return "Unrestricted Runtime" end
    return "Safe Runtime"
end

function getResponseStyleInstruction()
    if responseStyle == "Concise" then
        return "Response style: Concise. Answer briefly and directly."
    elseif responseStyle == "Detailed" then
        return "Response style: Detailed. Provide a complete and well-explained answer."
    elseif responseStyle == "Friendly" then
        return "Response style: Friendly. Use a warm, supportive, natural tone."
    elseif responseStyle == "Professional" then
        return "Response style: Professional. Use a polished, reliable, work-ready tone."
    elseif responseStyle == "Step-by-step" then
        return "Response style: Step-by-step. Explain actions and answers in clear ordered steps."
    elseif responseStyle == "Beginner-friendly" then
        return "Response style: Beginner-friendly. Avoid jargon and explain simply."
    elseif responseStyle == "Accessibility-focused" then
        return "Response style: Accessibility-focused. Be clear for screen reader users, describe states and next actions."
    elseif responseStyle == "Technical" then
        return "Response style: Technical. Be precise, structured, and implementation-aware."
    elseif responseStyle == "Creative" then
        return "Response style: Creative. Be engaging and expressive while staying useful."
    else
        return "Response style: Balanced. Be clear, useful, and not too short or too long."
    end
end

function setAgentActive(value)
    agentActive = value
    updateAgentStatusText()
end

function updateAgentStatusText()
    if agentStatusText then
        if agentStopRequested then
            agentStatusText.setText("Status: Stopped")
        elseif agentActive then
            agentStatusText.setText("Status: NeuralPilot is working...")
        else
            agentStatusText.setText("Status: Ready")
        end
    end

    if stopButton then
        stopButton.setEnabled(agentActive)
    end
end
function updateSelectedModelText()
    if selectedModelText then
        selectedModelText.setText("Provider: " .. getProviderDisplayName() .. " | Model: " .. getCurrentModelName() .. " | Runtime: " .. getRuntimeModeDisplayName() .. " | Style: " .. responseStyle)
    end
end

function updateSettingsProviderText()
    if settingsProviderText then
        settingsProviderText.setText("Current provider: " .. getProviderDisplayName())
    end
end

function updateSettingsModelText()
    if settingsModelText then
        settingsModelText.setText("Current model: " .. getCurrentModelName() .. "\nCurrent runtime: " .. getRuntimeModeDisplayName() .. "\nResponse style: " .. responseStyle)
    end
end

function updateMemoryButtonText()
    if memoryButton then
        memoryButton.setText(memoryEnabled and "Conversation Memory: On" or "Conversation Memory: Off")
    end
end

function updateRuntimeModeButtonText()
    if runtimeModeButton then
        runtimeModeButton.setText("Runtime Access Mode: " .. getRuntimeModeDisplayName())
    end
end

function updateResponseStyleButtonText()
    if responseStyleButton then
        responseStyleButton.setText("Response Style: " .. responseStyle)
    end
end

function updatePermissionsStatusText()
    if not settingsPermissionsText then return end

    local importState = permissionImport and "allowed" or "blocked"
    local ioState = permissionIO and "allowed" or "blocked"
    local osState = permissionOS and "allowed" or "blocked"

    settingsPermissionsText.setText("Runtime permissions: io " .. ioState .. ", os " .. osState .. ", import " .. importState .. ".")
end

function updateCodeButtonText()
    if codeButton then
        codeButton.setText("Generated Code (" .. generatedCodeCount .. ")")
    end
end

function requestPermissions()
    local permissions = {
        Manifest.permission.RECORD_AUDIO,
        Manifest.permission.WRITE_EXTERNAL_STORAGE,
        Manifest.permission.VIBRATE
    }
    activity.requestPermissions(permissions, 1)
end

function onRequestPermissionsResult(requestCode, permissions, grantResults)
    if requestCode == 1 then
        speak("Permission request completed.")
    end
end

function copyToClipboard(label, text)
    local clipboard = activity.getSystemService(Context.CLIPBOARD_SERVICE)
    clipboard.setPrimaryClip(ClipData.newPlainText(label, tostring(text or "")))
end

function initialGreeting()
    speak("Welcome to NeuralPilot Agent version " .. VERSION .. ". Type or speak naturally. I can chat, remember your personal instructions, use response styles, import libraries when allowed, call simple APIs, and run Lua code when useful.")
    vibrate(400)
end

function createRecognitionListener()
    return {
        onResults = function(results)
            local matches = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            if matches and matches.size() > 0 then
                local text = matches.get(0)
                if taskInput then taskInput.setText(text) end
                askChatGPT(text)
            else
                speak("I did not understand that. Please try again.")
            end
            isListening = false
        end,

        onError = function(error)
            speak("Speech recognition error. Please try again.")
            isListening = false
        end,

        onReadyForSpeech = function(params)
            speak("I'm listening.")
        end,

        onEndOfSpeech = function()
            isListening = false
        end
    }
end

function startListening()
    if isListening or not speechRecognizer then
        speak("I'm already listening.")
        return
    end

    local intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
    intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
    intent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
    speechRecognizer.startListening(intent)
    isListening = true
end

function stopListening()
    if isListening and speechRecognizer then
        speechRecognizer.stopListening()
        isListening = false
        speak("Stopped listening.")
    end
end

function extractBestCode(text)
    text = tostring(text or "")
    local luaCode = text:match("```[lL][uU][aA]%s*\n?(.-)```")
    if hasText(luaCode) then return luaCode end
    local anyCode = text:match("```[%w%-%_]*%s*\n?(.-)```")
    if hasText(anyCode) then return anyCode end
    return text
end

function appearsIncompleteCode(code)
    code = tostring(code or "")
    if not hasText(code) then return true end

    local lower = code:lower()
    if lower:match("continue here") or lower:match("same as before") or lower:match("to be continued") then
        return true
    end

    for line in code:gmatch("[^\r\n]+") do
        local l = trimText(line)
        if l == "..." or l == "-- ..." or l == "# ..." then
            return true
        end
    end

    if code:match("```") then return true end

    local function countWord(word)
        local count = 0
        for _ in code:gmatch("%f[%a]" .. word .. "%f[%A]") do
            count = count + 1
        end
        return count
    end

    local opens = countWord("function") + countWord("if") + countWord("for") + countWord("while") + countWord("repeat")
    local closes = countWord("end") + countWord("until")

    return opens > closes + 2
end

function parseJsonLike(text)
    text = tostring(text or "")
    local jsonText = text:match("```[jJ][sS][oO][nN]%s*\n?(.-)```")
    if not jsonText then jsonText = text:match("```%s*\n?(.-)```") end
    if not jsonText then jsonText = text end

    local ok, data = pcall(cjson.decode, jsonText)
    if ok and data then return data end

    local object = jsonText:match("({.*})")
    if object then
        local ok2, data2 = pcall(cjson.decode, object)
        if ok2 and data2 then return data2 end
    end

    return nil
end

function getAnyUserAnswer(data)
    if not data then return "" end
    if hasText(data.final_answer) then return tostring(data.final_answer) end
    if hasText(data.answer) then return tostring(data.answer) end
    if hasText(data.message) then return tostring(data.message) end
    if hasText(data.text) then return tostring(data.text) end
    if hasText(data.content) then return tostring(data.content) end
    if hasText(data.result) then return tostring(data.result) end
    return ""
end

function saveConversation(question, answer)
    createFolder(APP_FOLDER)
    local f = io.open(CONVERSATIONS_FILE, "a+")
    if f then
        f:write("Q: " .. tostring(question) .. "\nA: " .. tostring(answer) .. "\n\n")
        f:close()
    end
end

function saveCodeToFile(n, code)
    createFolder(GENERATED_CODE_FOLDER)
    generatedCodes[n] = code
    local f = io.open(GENERATED_CODE_FOLDER .. "generated_code_" .. n .. ".txt", "w")
    if f then
        f:write(tostring(code or ""))
        f:close()
    end
end

function resetConversation()
    stopGeneration(false)
    currentConversation = {user = {}, assistant = {}}
    generatedCodeCount = 0
    generatedCodes = {}
    currentUserTask = ""
    currentHistoryText = ""
    lastGeneratedCode = ""
    lastRuntimeOutput = ""
    lastRuntimeError = ""
    currentAssistantPrefix = ""
    finalAnswerRepairCount = 0
    updateCodeButtonText()
    if conversationTextView then conversationTextView.setText("") end
    speak("Conversation history has been reset.")
end

function stopGeneration(announce)
    agentStopRequested = true
    agentRunId = agentRunId + 1
    setAgentActive(false)

    if isListening and speechRecognizer then
        speechRecognizer.stopListening()
        isListening = false
    end

    if announce ~= false then
        speak("Generation stopped.")
    end
end

function shouldIgnoreCallback(runId)
    if agentStopRequested then return true end
    if runId ~= agentRunId then return true end
    return false
end

function showFullCode()
    local allCode = ""

    for i = 1, generatedCodeCount do
        local path = GENERATED_CODE_FOLDER .. "generated_code_" .. i .. ".txt"
        local f = io.open(path, "r")
        if f then
            allCode = allCode .. "Code #" .. i .. ":\n" .. f:read("*a") .. "\n\n"
            f:close()
        elseif generatedCodes[i] then
            allCode = allCode .. "Code #" .. i .. ":\n" .. tostring(generatedCodes[i]) .. "\n\n"
        end
    end

    if allCode == "" then allCode = "No code content is available." end

    local builder = AlertDialog.Builder(activity)
    builder.setTitle("All Generated Code")
    builder.setMessage(allCode)
    builder.setPositiveButton("Close", nil)
    builder.show()
end

function copyAllCode()
    local allCode = ""

    for i = 1, generatedCodeCount do
        local path = GENERATED_CODE_FOLDER .. "generated_code_" .. i .. ".txt"
        local f = io.open(path, "r")
        if f then
            allCode = allCode .. "Code #" .. i .. ":\n" .. f:read("*a") .. "\n\n"
            f:close()
        elseif generatedCodes[i] then
            allCode = allCode .. "Code #" .. i .. ":\n" .. tostring(generatedCodes[i]) .. "\n\n"
        end
    end

    copyToClipboard("Generated Code", allCode)
    speak("All code copied to clipboard.")
end

function showCodeNumberDialog()
    if generatedCodeCount == 0 then
        speak("No code has been generated yet.")
        return
    end

    local msg = "Total code snippets generated: " .. generatedCodeCount .. "\n\n"
    for i = 1, generatedCodeCount do
        msg = msg .. "Code #" .. i .. "\n"
    end

    local builder = AlertDialog.Builder(activity)
    builder.setTitle("Generated Code")
    builder.setMessage(msg)
    builder.setPositiveButton("Close", nil)
    builder.setNeutralButton("Copy", {onClick = function() copyAllCode() end})
    builder.setNegativeButton("Show", {onClick = function() showFullCode() end})
    builder.show()
end

function setMultiLineValue(title, message, currentValue, onSave)
    local input = EditText(activity)
    input.setSingleLine(false)
    input.setMinLines(5)
    input.setText(currentValue or "")
    input.setGravity(Gravity.TOP)
    input.setInputType(InputType.TYPE_CLASS_TEXT + InputType.TYPE_TEXT_FLAG_MULTI_LINE)

    local builder = AlertDialog.Builder(activity)
    builder.setTitle(title)
    builder.setMessage(message)
    builder.setView(input)
    builder.setPositiveButton("Save", {
        onClick = function()
            onSave(input.getText().toString())
        end
    })
    builder.setNegativeButton("Cancel", nil)
    builder.show()
end

function setOpenRouterApiKey()
    setMultiLineValue("Set OpenRouter API Keys", "Enter one or more OpenRouter API keys. Put each key on a new line.", openRouterApiKey, function(value)
        openRouterApiKey = value
        saveSettings()
        speak("OpenRouter API keys saved.")
    end)
end

function setGoogleApiKey()
    setMultiLineValue("Set Google AI Studio API Keys", "Enter one or more Google AI Studio API keys. Put each key on a new line.", googleApiKey, function(value)
        googleApiKey = value
        saveSettings()
        speak("Google AI Studio API keys saved.")
    end)
end

function setNvidiaApiKey()
    setMultiLineValue("Set NVIDIA NIM API Keys", "Enter one or more NVIDIA NIM API keys. Put each key on a new line.", nvidiaApiKey, function(value)
        nvidiaApiKey = value
        saveSettings()
        speak("NVIDIA NIM API keys saved.")
    end)
end

function setPersonalInfo()
    setMultiLineValue("Set Personal Info", "Type anything you want NeuralPilot to remember in every conversation.", userPersonalInfo, function(value)
        userPersonalInfo = value
        saveSettings()
        speak("Personal info saved.")
    end)
end

function toggleApiProvider()
    if apiProvider == "openrouter" then
        apiProvider = "google"
    elseif apiProvider == "google" then
        apiProvider = "nvidia"
    else
        apiProvider = "openrouter"
    end

    saveSettings()
    updateSelectedModelText()
    updateSettingsProviderText()
    updateSettingsModelText()
    speak("AI provider set to " .. getProviderDisplayName())
end

function toggleMemory()
    memoryEnabled = not memoryEnabled
    saveSettings()
    updateMemoryButtonText()
    speak(memoryEnabled and "Conversation memory is enabled." or "Conversation memory is disabled.")
end

function cycleResponseStyle()
    local index = 1
    for i = 1, #responseStyles do
        if responseStyle == responseStyles[i] then
            index = i
        end
    end

    index = index + 1
    if index > #responseStyles then
        index = 1
    end

    responseStyle = responseStyles[index]
    saveSettings()
    updateResponseStyleButtonText()
    updateSelectedModelText()
    updateSettingsModelText()
    speak("Response style set to " .. responseStyle)
end

function showUnrestrictedWarningThenEnable()
    local builder = AlertDialog.Builder(activity)
    builder.setTitle("Unrestricted Runtime Warning")
    builder.setMessage("Unrestricted Runtime gives AI-generated Lua access to the full app environment allowed by Android and app permissions. It may crash the app, access files allowed by permissions, import libraries, open Android APIs, or behave unexpectedly. Use it only when you trust the task and model.")
    builder.setPositiveButton("Enable", {
        onClick = function()
            runtimeMode = "unrestricted"
            permissionUnrestricted = true
            saveSettings()
            updateRuntimeModeButtonText()
            updatePermissionsStatusText()
            updateSettingsModelText()
            updateSelectedModelText()
            speak("Unrestricted Runtime enabled.")
        end
    })
    builder.setNegativeButton("Cancel", nil)
    builder.show()
end

function cycleRuntimeMode()
    if runtimeMode == "safe" then
        runtimeMode = "expanded"
        permissionUnrestricted = false
        speak("Expanded Runtime enabled.")
    elseif runtimeMode == "expanded" then
        runtimeMode = "android"
        permissionUnrestricted = false
        speak("Android Runtime enabled.")
    elseif runtimeMode == "android" then
        showUnrestrictedWarningThenEnable()
        return
    else
        runtimeMode = "safe"
        permissionUnrestricted = false
        speak("Safe Runtime enabled.")
    end

    saveSettings()
    updateRuntimeModeButtonText()
    updatePermissionsStatusText()
    updateSettingsModelText()
    updateSelectedModelText()
end

function showPermissionsDialog()
    local items = {
        "Allow io library in Safe/Expanded prompts",
        "Allow os library in Safe/Expanded prompts",
        "Allow import, require, and package in runtime"
    }

    local checked = {permissionIO, permissionOS, permissionImport}

    local builder = AlertDialog.Builder(activity)
    builder.setTitle("Additional Runtime Permissions")
    builder.setMultiChoiceItems(items, checked, {
        onClick = function(dialog, which, isChecked)
            if which == 0 then permissionIO = isChecked end
            if which == 1 then permissionOS = isChecked end
            if which == 2 then permissionImport = isChecked end
        end
    })
    builder.setPositiveButton("Save", {
        onClick = function()
            saveSettings()
            updatePermissionsStatusText()
            speak("Permission settings saved.")
        end
    })
    builder.setNegativeButton("Cancel", nil)
    builder.show()
end

function showApiSetupHelp()
    local builder = AlertDialog.Builder(activity)
    builder.setTitle("NeuralPilot Setup Help")
    builder.setMessage([[
NeuralPilot Agent is designed for everyday users. You can chat normally, ask questions, solve calculations, call simple APIs, handle complex tasks, check device details, and let the AI run Lua code when useful.

Personal Info:
Use Set Personal Info on the home screen to save anything you want NeuralPilot to remember in every conversation.

Response Style:
Use Response Style in Settings to choose how NeuralPilot answers. There are 10 styles: Balanced, Concise, Detailed, Friendly, Professional, Step-by-step, Beginner-friendly, Accessibility-focused, Technical, and Creative.

Library Import:
In Settings, enable "Allow import, require, and package in runtime" if you want generated Lua code to import libraries or Java classes. Use with care.

Auto Update:
Automatic update can be turned on or off in Settings. When it is on, NeuralPilot checks GitHub when the app opens. If the user skips the update popup or the internet fails, NeuralPilot now tries to start the latest saved update first. It only falls back to the built-in version if no saved update exists or the saved update cannot start.

Saved Update:
The saved update file is stored here:
/storage/emulated/0/NeuralPilot/neuralpilot_latest.lua

Settings Page:
The Settings page uses a ScrollView, so all settings can be reached on smaller mobile screens.

Example code for the model:
local topic = "AI"
local url = "https://th.wikipedia.org/w/api.php?action=query&format=json&prop=extracts&exintro=1&explaintext=1&titles=" .. urlEncode(topic)
local raw = httpGet(url)
local data = json.decode(raw)
for pageId, page in pairs(data.query.pages) do
    print(page.extract)
end

Credits:
Developer: Jieshuo Library
Join our channel: t.me/Jieshuolibrary
]])
    builder.setPositiveButton("OK", nil)
    builder.show()
end

function showModelSelectionDialog(names)
    if not names or #names == 0 then
        speak("No models were found.")
        return
    end

    local builder = AlertDialog.Builder(activity)
    builder.setTitle("Select Model")
    builder.setItems(names, {
        onClick = function(dialog, which)
            local selected = names[which + 1]
            if selected then
                if apiProvider == "google" then
                    googleModel = selected
                elseif apiProvider == "nvidia" then
                    nvidiaModel = selected
                else
                    openRouterModel = selected
                end
                saveSettings()
                updateSelectedModelText()
                updateSettingsModelText()
                speak("Model selected: " .. selected)
            end
        end
    })
    builder.show()
end

function showDefaultNvidiaModels()
    showModelSelectionDialog({
        "meta/llama-3.1-8b-instruct",
        "meta/llama-3.1-70b-instruct",
        "meta/llama-3.3-70b-instruct",
        "deepseek-ai/deepseek-v4-flash",
        "deepseek-ai/deepseek-v4-pro",
        "mistralai/mistral-nemotron",
        "microsoft/phi-4-mini-instruct"
    })
end

function fetchAndShowModelList()
    if apiProvider == "google" then
        if not hasApiKeys(googleApiKey) then
            speak("Please set your Google AI Studio API key first.")
            setGoogleApiKey()
            return
        end

        local url = GOOGLE_MODELS_LIST_URL .. "?key=" .. getNextApiKey("google")
        speak("Loading models from Google AI Studio.")

        Http.get(url, {}, function(code, content)
            if code == 200 then
                local ok, response = pcall(cjson.decode, content)
                if ok and response and response.models then
                    local names = {}
                    for i = 1, #response.models do
                        local m = response.models[i]
                        local supported = false
                        if m.supportedGenerationMethods then
                            for j = 1, #m.supportedGenerationMethods do
                                if m.supportedGenerationMethods[j] == "generateContent" then
                                    supported = true
                                end
                            end
                        end
                        if supported and m.name then
                            addItem(names, tostring(m.name):gsub("^models/", ""))
                        end
                    end
                    showModelSelectionDialog(names)
                else
                    speak("Unable to read the model list.")
                end
            else
                speak("Failed to load model list.")
            end
        end)

    elseif apiProvider == "nvidia" then
        if not hasApiKeys(nvidiaApiKey) then
            speak("Please set your NVIDIA NIM API key first.")
            setNvidiaApiKey()
            return
        end

        local headers = {["Authorization"] = "Bearer " .. getNextApiKey("nvidia")}
        speak("Loading models from NVIDIA NIM.")

        Http.get(NVIDIA_MODELS_LIST_URL, headers, function(code, content)
            if code == 200 then
                local ok, response = pcall(cjson.decode, content)
                if ok and response and response.data then
                    local names = {}
                    for i = 1, #response.data do
                        if response.data[i].id then
                            addItem(names, tostring(response.data[i].id))
                        end
                    end
                    showModelSelectionDialog(names)
                else
                    showDefaultNvidiaModels()
                end
            else
                showDefaultNvidiaModels()
            end
        end)

    else
        local headers = {}
        if hasApiKeys(openRouterApiKey) then
            headers["Authorization"] = "Bearer " .. getNextApiKey("openrouter")
        end

        speak("Loading models from OpenRouter.")

        Http.get(OPENROUTER_MODELS_LIST_URL, headers, function(code, content)
            if code == 200 then
                local ok, response = pcall(cjson.decode, content)
                if ok and response and response.data then
                    local names = {"openrouter/free"}
                    for i = 1, #response.data do
                        if response.data[i].id then
                            addItem(names, tostring(response.data[i].id))
                        end
                    end
                    showModelSelectionDialog(names)
                else
                    speak("Unable to read the model list.")
                end
            else
                speak("Failed to load model list.")
            end
        end)
    end
end

function buildOpenAICompatibleMessages(systemText, userText)
    return {
        {role = "system", content = systemText},
        {role = "user", content = userText}
    }
end

function readOpenAICompatibleAnswer(response)
    if response and response.choices and response.choices[1] and response.choices[1].message and response.choices[1].message.content then
        return response.choices[1].message.content
    end
    if response and response.choices and #response.choices == 0 then
        return nil, "The provider returned an empty choices list."
    end
    return nil, "The provider response did not contain message content."
end

function callOpenRouter(messages, temperature, onSuccess, onFailure, runId)
    if not hasApiKeys(openRouterApiKey) then
        speak("Please set your OpenRouter API key first.")
        setOpenRouterApiKey()
        if onFailure then onFailure("Missing OpenRouter API key") end
        return
    end

    local body = {
        model = openRouterModel,
        messages = messages,
        temperature = temperature or 0.2
    }

    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. getNextApiKey("openrouter"),
        ["HTTP-Referer"] = "https://neuralpilot.local",
        ["X-Title"] = "NeuralPilot Agent"
    }

    Http.post(OPENROUTER_API_URL, cjson.encode(body), headers, function(code, content)
        if shouldIgnoreCallback(runId) then return end
        if code == 200 then
            local ok, response = pcall(cjson.decode, content)
            if ok and response then
                local answer, err = readOpenAICompatibleAnswer(response)
                if answer then
                    onSuccess(answer)
                else
                    onFailure("OpenRouter response error: " .. tostring(err))
                end
            else
                onFailure("Unexpected OpenRouter response format.")
            end
        else
            onFailure("OpenRouter request failed. Code: " .. tostring(code))
        end
    end)
end

function callNvidia(messages, temperature, onSuccess, onFailure, runId)
    if not hasApiKeys(nvidiaApiKey) then
        speak("Please set your NVIDIA NIM API key first.")
        setNvidiaApiKey()
        if onFailure then onFailure("Missing NVIDIA NIM API key") end
        return
    end

    local body = {
        model = nvidiaModel,
        messages = messages,
        temperature = temperature or 0.2
    }

    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. getNextApiKey("nvidia")
    }

    Http.post(NVIDIA_API_URL, cjson.encode(body), headers, function(code, content)
        if shouldIgnoreCallback(runId) then return end
        if code == 200 then
            local ok, response = pcall(cjson.decode, content)
            if ok and response then
                local answer, err = readOpenAICompatibleAnswer(response)
                if answer then
                    onSuccess(answer)
                else
                    onFailure("NVIDIA NIM response error: " .. tostring(err))
                end
            else
                onFailure("Unexpected NVIDIA NIM response format.")
            end
        else
            onFailure("NVIDIA NIM request failed. Code: " .. tostring(code))
        end
    end)
end

function callGoogleAI(systemText, userText, temperature, onSuccess, onFailure, runId)
    if not hasApiKeys(googleApiKey) then
        speak("Please set your Google AI Studio API key first.")
        setGoogleApiKey()
        if onFailure then onFailure("Missing Google AI Studio API key") end
        return
    end

    local body = {
        contents = {
            {
                role = "user",
                parts = {{text = userText}}
            }
        },
        systemInstruction = {
            parts = {{text = systemText}}
        },
        generationConfig = {
            temperature = temperature or 0.2
        }
    }

    local url = GOOGLE_API_BASE .. googleModel .. ":generateContent?key=" .. getNextApiKey("google")

    Http.post(url, cjson.encode(body), {["Content-Type"] = "application/json"}, function(code, content)
        if shouldIgnoreCallback(runId) then return end
        if code == 200 then
            local ok, response = pcall(cjson.decode, content)
            if ok and response and response.candidates and response.candidates[1] and response.candidates[1].content and response.candidates[1].content.parts and response.candidates[1].content.parts[1] and response.candidates[1].content.parts[1].text then
                onSuccess(response.candidates[1].content.parts[1].text)
            else
                onFailure("Unexpected Google AI Studio response format.")
            end
        else
            onFailure("Google AI Studio request failed. Code: " .. tostring(code))
        end
    end)
end
function callAI(systemText, userText, temperature, onSuccess, onFailure, runId)
    if shouldIgnoreCallback(runId) then return end

    if apiProvider == "google" then
        callGoogleAI(systemText, userText, temperature, onSuccess, onFailure, runId)
    else
        local messages = buildOpenAICompatibleMessages(systemText, userText)
        if apiProvider == "nvidia" then
            callNvidia(messages, temperature, onSuccess, onFailure, runId)
        else
            callOpenRouter(messages, temperature, onSuccess, onFailure, runId)
        end
    end
end

function providerHasRequiredApiKey()
    if apiProvider == "google" then
        if not hasApiKeys(googleApiKey) then
            setGoogleApiKey()
            return false
        end
    elseif apiProvider == "nvidia" then
        if not hasApiKeys(nvidiaApiKey) then
            setNvidiaApiKey()
            return false
        end
    else
        if not hasApiKeys(openRouterApiKey) then
            setOpenRouterApiKey()
            return false
        end
    end
    return true
end

function buildConversationHistoryText()
    local count = #currentConversation.user
    if count <= 1 then return "" end

    local parts = {}
    for i = 1, count - 1 do
        addItem(parts, "Previous user message: " .. tostring(currentConversation.user[i]))
        if currentConversation.assistant[i] then
            addItem(parts, "Previous NeuralPilot answer: " .. tostring(currentConversation.assistant[i]))
        end
    end
    return joinList(parts, "\n")
end

function httpGetSync(url)
    local result = {}
    local u = URL(tostring(url))
    local conn = u.openConnection()
    conn.setConnectTimeout(15000)
    conn.setReadTimeout(20000)
    conn.setRequestProperty("User-Agent", "NeuralPilot-Agent/" .. tostring(VERSION))
    local reader = BufferedReader(InputStreamReader(conn.getInputStream(), "UTF-8"))
    while true do
        local line = reader.readLine()
        if line == nil then break end
        addItem(result, tostring(line))
    end
    reader.close()
    return joinList(result, "\n")
end

function urlEncodeSync(text)
    return tostring(URLEncoder.encode(tostring(text or ""), "UTF-8"))
end

function createBaseRuntimeEnvironment(outputLines)
    local env = {}

    env.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            addItem(parts, tostring(select(i, ...)))
        end
        addItem(outputLines, joinList(parts, "\t"))
    end

    env.tostring = tostring
    env.tonumber = tonumber
    env.type = type
    env.pairs = pairs
    env.ipairs = ipairs
    env.next = next
    env.select = select
    env.unpack = unpack
    env.pcall = pcall
    env.xpcall = xpcall
    env.error = error
    env.assert = assert
    env.math = math
    env.string = string
    env.table = table
    env.json = cjson
    env.cjson = cjson
    env.httpGet = httpGetSync
    env.urlEncode = urlEncodeSync

    if permissionImport then
        env.import = import
        env.require = require
        env.package = package
    end

    env.androidBuild = {
        release = tostring(Build.VERSION.RELEASE),
        sdk = tostring(Build.VERSION.SDK_INT),
        manufacturer = tostring(Build.MANUFACTURER),
        model = tostring(Build.MODEL)
    }

    env.appInfo = {
        name = APP_NAME,
        version = VERSION,
        folder = APP_FOLDER,
        conversationsFile = CONVERSATIONS_FILE,
        generatedCodeFolder = GENERATED_CODE_FOLDER,
        provider = getProviderDisplayName(),
        model = getCurrentModelName(),
        runtimeMode = getRuntimeModeDisplayName(),
        responseStyle = responseStyle
    }

    env.userProfile = tostring(userPersonalInfo or "")

    return env
end

function createSafeRuntimeEnvironment(outputLines)
    local env = createBaseRuntimeEnvironment(outputLines)
    if permissionIO then env.io = io end
    if permissionOS then env.os = os end
    return env
end

function createExpandedRuntimeEnvironment(outputLines)
    local env = createBaseRuntimeEnvironment(outputLines)
    env.io = io
    env.os = os
    env.File = File
    env.Build = Build
    env.Uri = Uri
    return env
end

function createAndroidRuntimeEnvironment(outputLines)
    local env = createExpandedRuntimeEnvironment(outputLines)
    env.activity = activity
    env.Context = Context
    env.Intent = Intent
    env.Settings = Settings
    env.Toast = Toast
    env.Vibrator = Vibrator
    env.ClipboardManager = ClipboardManager
    env.ClipData = ClipData
    env.vibrator = vibrator
    return env
end

function createRuntimeEnvironment(outputLines)
    if runtimeMode == "unrestricted" then return nil end
    if runtimeMode == "android" then return createAndroidRuntimeEnvironment(outputLines) end
    if runtimeMode == "expanded" then return createExpandedRuntimeEnvironment(outputLines) end
    return createSafeRuntimeEnvironment(outputLines)
end

function runLuaCodeSafely(code)
    if agentStopRequested then
        return false, "", "Generation was stopped by the user."
    end

    setupNetworkPolicy()

    local outputLines = {}
    local env = createRuntimeEnvironment(outputLines)
    local originalPrint = print

    if runtimeMode == "unrestricted" then
        _G.print = function(...)
            local parts = {}
            for i = 1, select("#", ...) do
                addItem(parts, tostring(select(i, ...)))
            end
            addItem(outputLines, joinList(parts, "\t"))
        end
        _G.json = cjson
        _G.cjson = cjson
        _G.httpGet = httpGetSync
        _G.urlEncode = urlEncodeSync
        _G.userProfile = tostring(userPersonalInfo or "")
        if permissionImport then
            _G.import = import
            _G.require = require
            _G.package = package
        end
    end

    local chunk
    local loadError

    if load then
        local ok, loadedOrError = pcall(function()
            if env then
                return load(code, "neuralpilot_generated_code", "t", env)
            end
            return load(code, "neuralpilot_generated_code", "t")
        end)
        if ok and loadedOrError then
            chunk = loadedOrError
        else
            loadError = tostring(loadedOrError)
        end
    end

    if not chunk and loadstring then
        chunk, loadError = loadstring(code, "neuralpilot_generated_code")
        if chunk and setfenv and env then
            setfenv(chunk, env)
        end
    end

    if not chunk then
        if runtimeMode == "unrestricted" then
            _G.print = originalPrint
        end
        return false, "", "Code load error: " .. tostring(loadError)
    end

    local ok, result = pcall(chunk)

    if runtimeMode == "unrestricted" then
        _G.print = originalPrint
    end

    if result ~= nil then
        addItem(outputLines, "Return: " .. tostring(result))
    end

    if env and env.result ~= nil then
        addItem(outputLines, "Result variable: " .. tostring(env.result))
    end

    local output = joinList(outputLines, "\n")
    if not ok then
        return false, output, tostring(result)
    end

    if output == "" then
        output = "NO_VISIBLE_OUTPUT"
    end

    return true, output, ""
end

function buildPermissionGuidelines()
    local profile = ""
    if hasText(userPersonalInfo) then
        profile = "\nPersistent user personal info:\n" .. tostring(userPersonalInfo) .. "\n"
    end

    local importText = permissionImport and "- import, require, and package are available when the runtime environment exposes them.\n" or "- import, require, and package are blocked unless the user enables library import in settings.\n"

    local example = [[
Example Lua code for a Wikipedia API task:
local topic = "AI"
local url = "https://th.wikipedia.org/w/api.php?action=query&format=json&prop=extracts&exintro=1&explaintext=1&titles=" .. urlEncode(topic)
local raw = httpGet(url)
local data = json.decode(raw)
for pageId, page in pairs(data.query.pages) do
    print(page.extract)
end
]]

    local base = [[
]] .. getResponseStyleInstruction() .. [[

Runtime helpers:
- json and cjson are available for JSON parsing.
- httpGet(url) is available for simple HTTP GET requests and returns text.
- urlEncode(text) is available for URL encoding.
- userProfile contains persistent user personal info.
- appInfo contains app metadata.
- androidBuild contains device metadata.
]] .. importText .. profile .. "\n" .. example .. "\n"

    if runtimeMode == "unrestricted" then
        return base .. [[
Runtime mode: Unrestricted Runtime.
- AI-generated Lua runs in the full app runtime allowed by Android and app permissions.
- Do not perform destructive actions unless the user explicitly asks.
- Do not access private data unless the user explicitly asks.
]]
    elseif runtimeMode == "android" then
        return base .. [[
Runtime mode: Android Runtime.
- Available: print, math, string, table, io, os, File, Build, Uri, activity, Context, Intent, Settings, Toast, Vibrator, ClipboardManager, ClipData, json, httpGet, urlEncode.
- If import is enabled, you may use import, require, and package carefully.
]]
    elseif runtimeMode == "expanded" then
        return base .. [[
Runtime mode: Expanded Runtime.
- Available: print, math, string, table, io, os, File, Build, Uri, json, httpGet, urlEncode.
- If import is enabled, you may use import, require, and package carefully.
]]
    else
        local extra = ""
        if permissionIO then extra = extra .. "- io is available.\n" end
        if permissionOS then extra = extra .. "- os is available.\n" end
        return base .. [[
Runtime mode: Safe Runtime.
- Available: print, math, string, table, json, cjson, httpGet, urlEncode, androidBuild, appInfo, userProfile.
]] .. extra .. [[
- Do not use activity, service, raw Java classes, io unless enabled, os unless enabled, or import unless enabled.
]]
    end
end

function makeFastDecisionPrompt(userTask, historyText)
    local history = ""
    if hasText(historyText) then
        history = "\n\nConversation memory for this session:\n" .. tostring(historyText)
    end

    local profile = ""
    if hasText(userPersonalInfo) then
        profile = "\n\nPersistent user personal info:\n" .. tostring(userPersonalInfo)
    end

    return [[
You are NeuralPilot Agent, an accessible AI assistant built for everyday Android users.

Your purpose:
- Help through natural conversation.
- Follow the selected response style.
- Handle easy and difficult tasks.
- Use local Lua execution when it improves accuracy or enables API/data work.
- For web/API tasks, you may generate Lua using httpGet(url), urlEncode(text), and json.decode(...).
- If library import is enabled, you may import libraries/classes when useful and safe.
- Never expose raw code or raw runtime output unless explicitly asked.
- Always provide a clear final answer.

Respond only with JSON. Do not use Markdown.

For normal conversation:
{
  "mode": "chat",
  "final_answer": "complete answer for the user"
}

For runtime work:
{
  "mode": "code_task",
  "code": "complete Lua code to run"
}

For difficult/hybrid work:
{
  "mode": "hybrid_task",
  "initial_answer": "short user-facing message",
  "code": "complete Lua code to run"
}

Mode compatibility:
If you accidentally use hard_task, complex_task, hybrid, code_and_chat, chat_and_code, or hard_work, NeuralPilot will treat it as hybrid_task if code is present.

For code:
]] .. buildPermissionGuidelines() .. [[

Code rules:
- Complete code from beginning to end.
- Must print or return a visible result.
- For API calls, use httpGet(url).
- For URL query terms, use urlEncode(text).
- For JSON, use json.decode(text).
- If imports are needed and available, use import carefully.
- Do not include Markdown fences in JSON.
- Do not truncate.
- Do not use placeholders.
]] .. profile .. history .. [[

User message:
]] .. tostring(userTask)
end

function normalizeDecisionMode(mode, data)
    local m = tostring(mode or ""):lower():gsub("%s+", "_"):gsub("%-", "_")
    local code = data and (data.code or data.lua_code or data.script or data.program) or nil
    local hasCode = hasText(code)

    if m == "chat" or m == "answer" or m == "conversation" then
        return hasCode and "hybrid_task" or "chat"
    end

    if m == "code_task" or m == "code" or m == "run_code" or m == "runtime" or m == "execute" or m == "tool" then
        return "code_task"
    end

    if m == "hybrid_task" or m == "hybrid" or m == "hard_task" or m == "hard_work" or m == "complex_task" or m == "difficult_task" or m == "code_and_chat" or m == "chat_and_code" or m == "both" or m == "multi_step" then
        return "hybrid_task"
    end

    return hasCode and "code_task" or "chat"
end

function getDecisionCode(data)
    if not data then return nil end
    if hasText(data.code) then return tostring(data.code) end
    if hasText(data.lua_code) then return tostring(data.lua_code) end
    if hasText(data.script) then return tostring(data.script) end
    if hasText(data.program) then return tostring(data.program) end
    return nil
end

function getInitialAnswer(data)
    if not data then return "" end
    if hasText(data.initial_answer) then return tostring(data.initial_answer) end
    if hasText(data.message) then return tostring(data.message) end
    if hasText(data.explanation) then return tostring(data.explanation) end
    if hasText(data.status_message) then return tostring(data.status_message) end
    return ""
end

function parseFastDecisionResponse(text)
    local data = parseJsonLike(text)

    if data and data.mode then
        data.mode = normalizeDecisionMode(data.mode, data)
        if not data.code then
            data.code = getDecisionCode(data)
        end
        return data
    end

    local code = extractBestCode(text)
    if hasText(code) and (tostring(text):match("```") or code:match("print") or code:match("return") or code:match("httpGet") or code:match("import")) then
        return {mode = "code_task", code = code}
    end

    return {mode = "chat", final_answer = tostring(text or "")}
end

function makeCompleteCodeRepairPrompt(userTask, incompleteCode)
    return [[
The previous Lua code appears incomplete, truncated, or not safe to run.

Return only JSON:
{
  "code": "complete corrected Lua code"
}

Rules:
- Complete code only.
- Must print or return visible result.
- Use httpGet(url) for API calls.
- Use urlEncode(text) for query text.
- Use json.decode(text) for JSON.
- Use import only if enabled.
- No placeholders.
- No Markdown.

Runtime rules:
]] .. buildPermissionGuidelines() .. [[

User task:
]] .. tostring(userTask) .. [[

Incomplete code:
]] .. tostring(incompleteCode)
end

function requestCompleteCodeRepair(incompleteCode, runId)
    if shouldIgnoreCallback(runId) then return end

    callAI(
        "You repair incomplete Lua code. Return JSON only.",
        makeCompleteCodeRepairPrompt(currentUserTask, incompleteCode),
        0.1,
        function(answer)
            if shouldIgnoreCallback(runId) then return end
            local data = parseJsonLike(answer)
            local code = data and data.code or extractBestCode(answer)

            if hasText(code) and not appearsIncompleteCode(code) then
                generatedCodeCount = generatedCodeCount + 1
                saveCodeToFile(generatedCodeCount, code)
                updateCodeButtonText()
                lastGeneratedCode = tostring(code)
                runAndValidate(tostring(code), runId)
            else
                finishWithAnswer("NeuralPilot received incomplete code and stopped before running it. Please try again or choose a stronger model.", runId, false)
            end
        end,
        function(errorMessage)
            finishWithAnswer("NeuralPilot could not repair incomplete code. Please try again or choose a stronger model.", runId, false)
        end,
        runId
    )
end

function makeValidationPrompt(userTask, code, output, err)
    return [[
You are NeuralPilot's execution controller.

Return only JSON.

If complete:
{
  "action": "stop",
  "final_answer": "clear final answer"
}

If more work is needed:
{
  "action": "run_code",
  "reason": "brief reason",
  "code": "complete corrected Lua code"
}

Rules:
- If runtime error exists, prefer run_code.
- If output is NO_VISIBLE_OUTPUT, prefer run_code to print useful output.
- Never return empty final_answer.
- Follow the selected response style.
- Do not expose raw code unless asked.
- For API tasks, summarize useful output.

Runtime rules:
]] .. buildPermissionGuidelines() .. [[

User task:
]] .. tostring(userTask) .. [[

Code:
]] .. tostring(code) .. [[

Runtime output:
]] .. tostring(output) .. [[

Runtime error:
]] .. tostring(err)
end

function parseValidatorResponse(text)
    local data = parseJsonLike(text)

    if data then
        if data.action then return data end
        if data.status == "done" then return {action = "stop", final_answer = getAnyUserAnswer(data)} end
        if data.status == "retry" then return {action = "run_code", reason = data.reason or "Retry requested.", code = data.code} end
    end

    local code = extractBestCode(text)
    if hasText(code) and (tostring(text):match("```") or code:match("print") or code:match("return") or code:match("httpGet") or code:match("import")) then
        return {action = "run_code", reason = "Validator returned code without valid JSON.", code = code}
    end

    return {action = "stop", final_answer = tostring(text or "")}
end

function makeFinalAnswerRepairPrompt(userTask, output, err, prefix)
    return [[
You are NeuralPilot's final answer writer.

Return only JSON:
{
  "final_answer": "clear final answer"
}

Rules:
- Follow this style:
]] .. getResponseStyleInstruction() .. [[

- Do not include raw code.
- Summarize useful runtime output.
- If output is API JSON, explain the human meaning.
- If output is NO_VISIBLE_OUTPUT, say the task ran but produced no visible result.
- If error exists, explain simply.
- Never return empty final_answer.
- Continue naturally after any initial message.

Initial message already shown:
]] .. tostring(prefix or "") .. [[

User task:
]] .. tostring(userTask) .. [[

Runtime output:
]] .. tostring(output) .. [[

Runtime error:
]] .. tostring(err)
end

function makeReliableFallbackAnswer()
    if hasText(lastRuntimeError) then
        return "The task could not be completed because the runtime reported an error. Try again, choose a different model, or use a higher runtime mode if the task needs more access."
    end

    if lastRuntimeOutput == "NO_VISIBLE_OUTPUT" then
        return "The internal task ran successfully, but it did not produce a visible result."
    end

    if hasText(lastRuntimeOutput) then
        return "The task completed successfully. NeuralPilot received an internal result, but the model did not format a final answer correctly."
    end

    if hasText(currentAssistantPrefix) then
        return "The task reached the final step, but the model did not provide an additional final answer."
    end

    return "NeuralPilot finished the request, but the model did not provide a readable final answer."
end

function finishWithAnswer(answer, runId, allowRepair)
    if shouldIgnoreCallback(runId) then return end
    if allowRepair == nil then allowRepair = true end

    answer = tostring(answer or "")

    if not hasText(answer) then
        if allowRepair then
            requestFinalAnswerRepair(runId)
            return
        else
            answer = makeReliableFallbackAnswer()
        end
    end

    setAgentActive(false)

    local saved = answer
    if hasText(currentAssistantPrefix) then
        saved = tostring(currentAssistantPrefix) .. "\n" .. answer
    end

    currentConversation.assistant[#currentConversation.user] = saved
    saveConversation(currentUserTask, saved)
    appendConversationDisplay("NeuralPilot: " .. answer)
    speak(answer)
    vibrate(250)
end

function requestFinalAnswerRepair(runId)
    if shouldIgnoreCallback(runId) then return end

    finalAnswerRepairCount = finalAnswerRepairCount + 1
    if finalAnswerRepairCount > 2 then
        finishWithAnswer(makeReliableFallbackAnswer(), runId, false)
        return
    end

    callAI(
        "You write final user-facing answers. Return JSON only.",
        makeFinalAnswerRepairPrompt(currentUserTask, lastRuntimeOutput, lastRuntimeError, currentAssistantPrefix),
        0.2,
        function(answer)
            if shouldIgnoreCallback(runId) then return end
            local data = parseJsonLike(answer)
            local final = data and getAnyUserAnswer(data) or ""

            if not hasText(final) then
                local raw = trimText(answer)
                if hasText(raw) and not raw:match("^%s*{%s*}") then final = raw end
            end

            if hasText(final) then
                finishWithAnswer(final, runId, false)
            else
                finishWithAnswer(makeReliableFallbackAnswer(), runId, false)
            end
        end,
        function(errorMessage)
            finishWithAnswer(makeReliableFallbackAnswer(), runId, false)
        end,
        runId
    )
end

function startAgent(userTask)
    userTask = tostring(userTask or "")
    if userTask:match("^%s*$") then speak("Please enter a message first."); return end
    if agentActive then speak("NeuralPilot is already working."); return end
    if not providerHasRequiredApiKey() then return end

    agentRunId = agentRunId + 1
    local runId = agentRunId

    agentStopRequested = false
    setAgentActive(true)

    agentIteration = 0
    finalAnswerRepairCount = 0
    currentUserTask = userTask
    lastGeneratedCode = ""
    lastRuntimeOutput = ""
    lastRuntimeError = ""
    currentAssistantPrefix = ""

    currentConversation.user[#currentConversation.user + 1] = userTask

    currentHistoryText = memoryEnabled and buildConversationHistoryText() or ""

    appendConversationDisplay("You: " .. userTask)
    speak("NeuralPilot is working.")

    requestFastDecision(userTask, currentHistoryText, runId)
end

function handleCodeFromDecision(code, runId)
    if shouldIgnoreCallback(runId) then return end

    code = tostring(code or "")

    if appearsIncompleteCode(code) then
        requestCompleteCodeRepair(code, runId)
        return
    end

    generatedCodeCount = generatedCodeCount + 1
    saveCodeToFile(generatedCodeCount, code)
    updateCodeButtonText()

    lastGeneratedCode = code
    runAndValidate(code, runId)
end

function requestFastDecision(userTask, historyText, runId)
    if shouldIgnoreCallback(runId) then return end

    callAI(
        "You are NeuralPilot Agent. Decide whether to answer directly, run Lua code, or do both. Return JSON only.",
        makeFastDecisionPrompt(userTask, historyText),
        0.2,
        function(answer)
            if shouldIgnoreCallback(runId) then return end

            local data = parseFastDecisionResponse(answer)
            local mode = normalizeDecisionMode(data.mode, data)
            local code = getDecisionCode(data)

            if hasText(code) then
                if mode == "hybrid_task" or data.initial_answer or data.message or data.explanation or data.status_message then
                    local initial = getInitialAnswer(data)
                    if hasText(initial) then
                        currentAssistantPrefix = initial
                        appendConversationDisplay("NeuralPilot: " .. initial)
                        speak(initial)
                    end
                end

                handleCodeFromDecision(code, runId)
                return
            end

            if mode == "code_task" or mode == "hybrid_task" then
                finishWithAnswer("NeuralPilot selected a runtime task, but the model did not return runnable code. Please try again or choose a different model.", runId, false)
                return
            end

            local final = getAnyUserAnswer(data)
            if not hasText(final) then final = tostring(answer or "") end
            finishWithAnswer(final, runId, true)
        end,
        function(errorMessage)
            finishWithAnswer("AI request failed. " .. tostring(errorMessage), runId, false)
        end,
        runId
    )
end

function runAndValidate(code, runId)
    if shouldIgnoreCallback(runId) then return end

    agentIteration = agentIteration + 1

    local ok, output, err = runLuaCodeSafely(code)

    if shouldIgnoreCallback(runId) then return end

    lastRuntimeOutput = output
    lastRuntimeError = err

    validateResultWithAI(runId)
end

function validateResultWithAI(runId)
    if shouldIgnoreCallback(runId) then return end

    callAI(
        "You are NeuralPilot's execution controller. Return JSON only.",
        makeValidationPrompt(currentUserTask, lastGeneratedCode, lastRuntimeOutput, lastRuntimeError),
        0.1,
        function(answer)
            if shouldIgnoreCallback(runId) then return end

            local data = parseValidatorResponse(answer)

            if data.action == "run_code" and hasText(data.code) then
                local code = tostring(data.code)

                if appearsIncompleteCode(code) then
                    requestCompleteCodeRepair(code, runId)
                    return
                end

                generatedCodeCount = generatedCodeCount + 1
                saveCodeToFile(generatedCodeCount, code)
                updateCodeButtonText()

                lastGeneratedCode = code
                runAndValidate(code, runId)
                return
            end

            if hasText(lastRuntimeError) then
                requestErrorCorrectionAgain(runId)
                return
            end

            if lastRuntimeOutput == "NO_VISIBLE_OUTPUT" then
                requestOutputImprovementAgain(runId)
                return
            end

            if data.action == "stop" then
                local final = getAnyUserAnswer(data)
                if hasText(final) then
                    finishWithAnswer(final, runId, false)
                else
                    requestFinalAnswerRepair(runId)
                end
                return
            end

            requestFinalAnswerRepair(runId)
        end,
        function(errorMessage)
            if hasText(lastRuntimeError) then
                requestErrorCorrectionAgain(runId)
            elseif lastRuntimeOutput == "NO_VISIBLE_OUTPUT" then
                requestOutputImprovementAgain(runId)
            else
                requestFinalAnswerRepair(runId)
            end
        end,
        runId
    )
end

function makeErrorCorrectionPrompt(userTask, code, output, err)
    return [[
The previous Lua code failed.

Return only JSON:
{
  "code": "complete corrected Lua code"
}

Rules:
- Fix the error.
- Complete Lua code only.
- Must print or return a visible result.
- Use httpGet(url) for API calls.
- Use urlEncode(text) for query text.
- Use json.decode(text) for JSON.
- Use import only if enabled.
- No Markdown.
- No placeholders.

Runtime rules:
]] .. buildPermissionGuidelines() .. [[

User task:
]] .. tostring(userTask) .. [[

Previous code:
]] .. tostring(code) .. [[

Runtime output:
]] .. tostring(output) .. [[

Runtime error:
]] .. tostring(err)
end

function requestErrorCorrectionAgain(runId)
    if shouldIgnoreCallback(runId) then return end

    callAI(
        "You fix failed Lua code. Return JSON only.",
        makeErrorCorrectionPrompt(currentUserTask, lastGeneratedCode, lastRuntimeOutput, lastRuntimeError),
        0.1,
        function(answer)
            if shouldIgnoreCallback(runId) then return end

            local data = parseJsonLike(answer)
            local code = data and data.code or extractBestCode(answer)

            if hasText(code) then
                if appearsIncompleteCode(code) then
                    requestCompleteCodeRepair(code, runId)
                    return
                end

                generatedCodeCount = generatedCodeCount + 1
                saveCodeToFile(generatedCodeCount, code)
                updateCodeButtonText()

                lastGeneratedCode = tostring(code)
                runAndValidate(tostring(code), runId)
            else
                requestFinalAnswerRepair(runId)
            end
        end,
        function(errorMessage)
            requestFinalAnswerRepair(runId)
        end,
        runId
    )
end

function makeOutputImprovementPrompt(userTask, code)
    return [[
The previous Lua code ran successfully but produced no visible output.

Return only JSON:
{
  "code": "complete corrected Lua code"
}

Rules:
- Keep the task goal.
- Add print or return statements so the user gets a visible result.
- For API responses, parse and print a human-readable result.
- Use httpGet(url) for API calls.
- Use urlEncode(text) for query text.
- Use json.decode(text) for JSON.
- Use import only if enabled.
- No Markdown.
- No placeholders.

Runtime rules:
]] .. buildPermissionGuidelines() .. [[

User task:
]] .. tostring(userTask) .. [[

Previous code:
]] .. tostring(code)
end

function requestOutputImprovementAgain(runId)
    if shouldIgnoreCallback(runId) then return end

    callAI(
        "You improve Lua code that produced no visible output. Return JSON only.",
        makeOutputImprovementPrompt(currentUserTask, lastGeneratedCode),
        0.1,
        function(answer)
            if shouldIgnoreCallback(runId) then return end

            local data = parseJsonLike(answer)
            local code = data and data.code or extractBestCode(answer)

            if hasText(code) then
                if appearsIncompleteCode(code) then
                    requestCompleteCodeRepair(code, runId)
                    return
                end

                generatedCodeCount = generatedCodeCount + 1
                saveCodeToFile(generatedCodeCount, code)
                updateCodeButtonText()

                lastGeneratedCode = tostring(code)
                runAndValidate(tostring(code), runId)
            else
                requestFinalAnswerRepair(runId)
            end
        end,
        function(errorMessage)
            requestFinalAnswerRepair(runId)
        end,
        runId
    )
end

function askChatGPT(question)
    startAgent(question)
end

function runTypedTask()
    if not taskInput then
        speak("Task input is not available.")
        return
    end
    startAgent(taskInput.getText().toString())
end

function showAgentHelp()
    local builder = AlertDialog.Builder(activity)
    builder.setTitle("NeuralPilot Agent Help")
    builder.setMessage([[
NeuralPilot Agent is an accessible AI assistant for everyday Android users.

Main features:
1. Chat naturally.
2. Remember your personal info across conversations.
3. Use 10 response styles.
4. Handle hard multi-step tasks.
5. Run Lua code internally when useful.
6. Talk and run code in the same turn.
7. Call simple web APIs using httpGet(url).
8. Parse JSON using json.decode(text).
9. Import libraries or Java classes when import access is enabled.
10. Repair failed or incomplete code automatically.
11. Improve code that produced no visible output.
12. Recover missing final answers.
13. Stop generation at any time.
14. Use multiple API keys per provider.
15. Use four runtime modes: Safe, Expanded, Android, and Unrestricted.
16. Automatic update can be turned on or off in Settings.
17. If an update is skipped or the internet fails, NeuralPilot starts the latest saved update first.
18. The built-in version is used only if no saved update exists or the saved update cannot start.

Response styles:
Balanced, Concise, Detailed, Friendly, Professional, Step-by-step, Beginner-friendly, Accessibility-focused, Technical, and Creative.

Auto Update:
When automatic update is enabled, NeuralPilot checks GitHub when the app opens. If a remote script is found, a popup shows version, file size, code line count, URL, and saved local update details. If you press Update Now, the remote code is saved and started. If you press Skip, NeuralPilot starts the latest saved update if available.

Saved Update:
The saved update file is stored here:
/storage/emulated/0/NeuralPilot/neuralpilot_latest.lua

Credits:
Developer: Jieshuo Library
Join our channel: t.me/Jieshuolibrary
]])
    builder.setPositiveButton("OK", nil)
    builder.show()
end

function buildSettingsLayout()
    local scrollView = ScrollView(activity)

    local layout = LinearLayout(activity)
    layout.setOrientation(LinearLayout.VERTICAL)
    layout.setPadding(16, 16, 16, 16)

    local titleText = TextView(activity)
    titleText.setText("NeuralPilot Settings")
    titleText.setTextSize(22)
    layout.addView(titleText)

    settingsProviderText = TextView(activity)
    layout.addView(settingsProviderText)

    local providerButton = Button(activity)
    providerButton.setText("Switch AI Provider")
    providerButton.setOnClickListener{onClick = function() toggleApiProvider() end}
    layout.addView(providerButton)

    local openRouterKeyButton = Button(activity)
    openRouterKeyButton.setText("Set OpenRouter API Keys")
    openRouterKeyButton.setOnClickListener{onClick = function() setOpenRouterApiKey() end}
    layout.addView(openRouterKeyButton)

    local googleKeyButton = Button(activity)
    googleKeyButton.setText("Set Google AI Studio API Keys")
    googleKeyButton.setOnClickListener{onClick = function() setGoogleApiKey() end}
    layout.addView(googleKeyButton)

    local nvidiaKeyButton = Button(activity)
    nvidiaKeyButton.setText("Set NVIDIA NIM API Keys")
    nvidiaKeyButton.setOnClickListener{onClick = function() setNvidiaApiKey() end}
    layout.addView(nvidiaKeyButton)

    local apiSetupHelpButton = Button(activity)
    apiSetupHelpButton.setText("Setup Help and Credits")
    apiSetupHelpButton.setOnClickListener{onClick = function() showApiSetupHelp() end}
    layout.addView(apiSetupHelpButton)

    settingsModelText = TextView(activity)
    layout.addView(settingsModelText)

    local selectModelButton = Button(activity)
    selectModelButton.setText("Select Model")
    selectModelButton.setOnClickListener{onClick = function() fetchAndShowModelList() end}
    layout.addView(selectModelButton)

    responseStyleButton = Button(activity)
    updateResponseStyleButtonText()
    responseStyleButton.setOnClickListener{onClick = function() cycleResponseStyle() end}
    layout.addView(responseStyleButton)

    local runtimeLabel = TextView(activity)
    runtimeLabel.setText("Runtime Access")
    layout.addView(runtimeLabel)

    runtimeModeButton = Button(activity)
    updateRuntimeModeButtonText()
    runtimeModeButton.setOnClickListener{onClick = function() cycleRuntimeMode() end}
    layout.addView(runtimeModeButton)

    local memoryLabel = TextView(activity)
    memoryLabel.setText("Memory")
    layout.addView(memoryLabel)

    memoryButton = Button(activity)
    memoryButton.setOnClickListener{onClick = function() toggleMemory() end}
    layout.addView(memoryButton)

    local permissionsLabel = TextView(activity)
    permissionsLabel.setText("Additional Runtime Permissions")
    layout.addView(permissionsLabel)

    settingsPermissionsText = TextView(activity)
    layout.addView(settingsPermissionsText)

    local permissionsButton = Button(activity)
    permissionsButton.setText("Configure Additional Permissions")
    permissionsButton.setOnClickListener{onClick = function() showPermissionsDialog() end}
    layout.addView(permissionsButton)

    local updateLabel = TextView(activity)
    updateLabel.setText("Auto Update")
    layout.addView(updateLabel)

    autoUpdateStatusText = TextView(activity)
    layout.addView(autoUpdateStatusText)

    autoUpdateButton = Button(activity)
    updateAutoUpdateButtonText()
    autoUpdateButton.setOnClickListener{onClick = function() toggleAutoUpdate() end}
    layout.addView(autoUpdateButton)

    local checkUpdateButton = Button(activity)
    checkUpdateButton.setText("Check Latest Version Now")
    checkUpdateButton.setOnClickListener{
        onClick = function()
            checkForLatestVersionThenStart(nil, true)
        end
    }
    layout.addView(checkUpdateButton)

    local backButton = Button(activity)
    backButton.setText("Back")
    backButton.setOnClickListener{onClick = function() showMainPage() end}
    layout.addView(backButton)

    scrollView.addView(layout)

    return scrollView
end

function showSettingsPage()
    if not settingsLayout then
        settingsLayout = buildSettingsLayout()
    end

    updateSettingsProviderText()
    updateSettingsModelText()
    updateMemoryButtonText()
    updateRuntimeModeButtonText()
    updateResponseStyleButtonText()
    updatePermissionsStatusText()
    updateAutoUpdateButtonText()
    updateAutoUpdateStatusText()

    activity.setContentView(settingsLayout)
end

function showMainPage()
    activity.setContentView(mainLayout)
end

function startMainApp(savedInstanceState)
    activity.setTitle(APP_NAME .. " v" .. VERSION)

    setupNetworkPolicy()
    ensureFiles()
    loadSettings()

    mainLayout = LinearLayout(activity)
    mainLayout.setOrientation(LinearLayout.VERTICAL)
    mainLayout.setPadding(16, 16, 16, 16)

    local titleText = TextView(activity)
    titleText.setText(APP_NAME .. " v" .. VERSION)
    titleText.setTextSize(22)
    mainLayout.addView(titleText)

    agentStatusText = TextView(activity)
    mainLayout.addView(agentStatusText)

    local localInfo = getLocalUpdateInfo()
    local updateState = autoUpdateEnabled and "On" or "Off"

    local storageInfo = TextView(activity)
    storageInfo.setText(
        "Storage: " .. APP_FOLDER ..
        "\nGenerated code: " .. GENERATED_CODE_FOLDER ..
        "\nAutomatic update: " .. updateState ..
        "\nSaved update file: " .. AUTO_UPDATE_FILE ..
        "\nSaved update version: " .. tostring(localInfo.version) ..
        "\nSaved update size: " .. formatBytes(localInfo.size) ..
        "\nSaved update lines: " .. tostring(localInfo.lines)
    )
    mainLayout.addView(storageInfo)

    selectedModelText = TextView(activity)
    mainLayout.addView(selectedModelText)

    taskInput = EditText(activity)
    taskInput.setHint("Type your message here. NeuralPilot can chat, import libraries when allowed, call APIs, run code, or do both for hard tasks.")
    taskInput.setMinLines(4)
    taskInput.setGravity(Gravity.TOP)
    mainLayout.addView(taskInput)

    local runButton = Button(activity)
    runButton.setText("Send to NeuralPilot")
    runButton.setOnClickListener{onClick = function() runTypedTask() end}
    mainLayout.addView(runButton)

    stopButton = Button(activity)
    stopButton.setText("Stop Generating")
    stopButton.setEnabled(false)
    stopButton.setOnClickListener{onClick = function() stopGeneration(true) end}
    mainLayout.addView(stopButton)

    local personalInfoButton = Button(activity)
    personalInfoButton.setText("Set Personal Info")
    personalInfoButton.setOnClickListener{onClick = function() setPersonalInfo() end}
    mainLayout.addView(personalInfoButton)

    local talkButton = Button(activity)
    talkButton.setText("Talk to NeuralPilot")
    talkButton.setOnClickListener{
        onClick = function()
            if isListening then stopListening() else startListening() end
        end
    }
    mainLayout.addView(talkButton)

    local settingsButton = Button(activity)
    settingsButton.setText("Settings")
    settingsButton.setOnClickListener{onClick = function() showSettingsPage() end}
    mainLayout.addView(settingsButton)

    codeButton = Button(activity)
    codeButton.setOnClickListener{onClick = function() showCodeNumberDialog() end}
    mainLayout.addView(codeButton)

    local resetButton = Button(activity)
    resetButton.setText("Reset Conversation")
    resetButton.setOnClickListener{onClick = function() resetConversation() end}
    mainLayout.addView(resetButton)

    local helpButton = Button(activity)
    helpButton.setText("Help")
    helpButton.setOnClickListener{onClick = function() showAgentHelp() end}
    mainLayout.addView(helpButton)

    local scrollView = ScrollView(activity)
    conversationTextView = TextView(activity)
    conversationTextView.setText("")
    conversationTextView.setTextSize(16)
    scrollView.addView(conversationTextView)
    mainLayout.addView(scrollView, LinearLayout.LayoutParams(-1, 0, 1))

    activity.setContentView(mainLayout)

    updateAgentStatusText()
    updateSelectedModelText()
    updateCodeButtonText()

    tts = TextToSpeech(activity, TextToSpeech.OnInitListener({
        onInit = function(status)
            if status == TextToSpeech.SUCCESS then
                tts.setLanguage(Locale.getDefault())
                initialGreeting()
            else
                Toast.makeText(activity, "Text-to-speech initialization failed.", Toast.LENGTH_SHORT).show()
            end
        end
    }))

    if SpeechRecognizer.isRecognitionAvailable(activity) then
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(activity)
        speechRecognizer.setRecognitionListener(createRecognitionListener())
    else
        speak("Speech recognition is not available on this device.")
    end

    vibrator = activity.getSystemService(Context.VIBRATOR_SERVICE)

    requestPermissions()
end

function onCreate(savedInstanceState)
    ensureFiles()
    loadSettings()

    if _G.NEURALPILOT_BOOTLOADED_LATEST then
        startMainApp(savedInstanceState)
        return
    end

    if autoUpdateEnabled then
        checkForLatestVersionThenStart(savedInstanceState, false)
    else
        startSavedUpdateOrBuiltIn(savedInstanceState, "Auto update is off at app launch.")
    end
end

function onPause()
    if isListening and speechRecognizer then
        speechRecognizer.stopListening()
        isListening = false
    end
end

function onDestroy()
    stopGeneration(false)

    if speechRecognizer then
        speechRecognizer.destroy()
        speechRecognizer = nil
    end

    if tts then
        tts.stop()
        tts.shutdown()
        tts = nil
    end
end