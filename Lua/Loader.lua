local websockets = require "gamesense/websockets"
local base64 = require "gamesense/base64"
local http = require "gamesense/http"

local DEFAULT_URL = "ws://sensical.club:3000"
local websocket_connection = nil
local connected = false
local logged_in = false
local luas = {}
local label1 = ui.new_label("LUA", "B", "Username")
local user_textbox = ui.new_textbox("LUA", "B", "Username")
local label2 = ui.new_label("LUA", "B", "Password")
local pass_textbox = ui.new_textbox("LUA", "B", "Password")
local lua_listbox = ui.new_listbox("LUA", "B", "Lua List", {})
ui.set_visible(lua_listbox, false)
local checkboxes = {}


local function update_checkboxes_visibility()
    for i, lua in ipairs(luas) do
        local checkbox = checkboxes[i]
        if ui.get(lua_listbox) == i - 1 then
            ui.set_visible(checkbox, true)
        else
            ui.set_visible(checkbox, false)
        end
    end
end

local function create_checkboxes()
    for i = 1, #luas do
        local checkbox = ui.new_checkbox("LUA", "B", "Load on Startup")
        ui.set_visible(checkbox, false)
        table.insert(checkboxes, checkbox)

        local startup_lua = database.read("startup_luas")
        if startup_lua and startup_lua[luas[i]] then
            ui.set(checkbox, true)
        end

        ui.set_callback(checkbox, function(self)
            local startup_lua = database.read("startup_luas") or {}
            startup_lua[luas[i]] = ui.get(self)
            database.write("startup_luas", startup_lua)
        end)
    end
end

local load_button = ui.new_button("LUA", "B", "Load Lua", function()
    local selected_lua = luas[ui.get(lua_listbox) + 1]
    if selected_lua then
        local load_message = string.format([[{"type": "load_lua", "lua": "%s"}]], selected_lua)
        websocket_connection:send(load_message)
        print("[wannacry] -> ", selected_lua)
    else
        print("[wannacry] -")
    end
end)



local login_button = ui.new_button("LUA", "B", "Login", function()
    if websocket_connection then
        local username = ui.get(user_textbox)
        local password = ui.get(pass_textbox)

        if username == "" or password == "" then
            print("[wannacry] Please enter valid credentials.")
            return
        end

        local login_message = string.format([[
            {
                "type": "login",
                "login": "%s",
                "senha": "%s"
            }
        ]], username, password)

        websocket_connection:send(login_message)

        database.write("login_datas", { username = username, password = password })
        for i, lua in ipairs(luas) do
            local checkbox_value = ui.get(checkboxes[i])
            database.write(lua .. "_load_on_startup", checkbox_value)
        end

        local startup_lua = {}
        for i, checkbox in ipairs(checkboxes) do
            if ui.get(checkbox) then
                startup_lua[luas[i]] = true
            end
        end
        database.write("startup_luas", startup_lua)

    else
        print("[wannacry] Connection not established.")
    end
end)

local register_button = ui.new_button("LUA", "B", "Register", function()
    if websocket_connection then
        local username = ui.get(user_textbox)
        local password = ui.get(pass_textbox)

        if username == "" or password == "" then
            print("[wannacry] Please enter valid credentials.")
            return
        end

        local register_message = string.format([[
            {
                "type": "register",
                "login": "%s",
                "senha": "%s"
            }
        ]], username, password)

        websocket_connection:send(register_message)

        database.write("login_datas", { username = username, password = password })
        for i, lua in ipairs(luas) do
            local checkbox_value = ui.get(checkboxes[i])
            database.write(lua .. "_load_on_startup", checkbox_value)
        end

        local startup_lua = {}
        for i, checkbox in ipairs(checkboxes) do
            if ui.get(checkbox) then
                startup_lua[luas[i]] = true
            end
        end
        database.write("startup_luas", startup_lua)

    else
        print("[wannacry] Connection not established.")
    end
end)

local label = ui.new_label("LUA", "B", "Log in to access your purchased luas")
ui.set_visible(login_button, false)
ui.set_visible(register_button, false)
ui.set_visible(load_button, false)
ui.set_visible(user_textbox, false)
ui.set_visible(pass_textbox, false)
ui.set_visible(label, false)
ui.set_visible(label1, false)
ui.set_visible(label2, false)

local callbacks = {
    open = function(ws)
        print("[wannacry] Connected.")
        websocket_connection = ws
        connected = true
        logged_in = false

        local login_datas = database.read("login_datas")
        if login_datas and login_datas.username and login_datas.password then
            local username = login_datas.username
            local password = login_datas.password

            local login_message = string.format([[
                {
                    "type": "login",
                    "login": "%s",
                    "senha": "%s"
                }
            ]], username, password)

            websocket_connection:send(login_message)
            print("[wannacry] Logging in...")
        end
    end,
    message = function(ws, data)
        local message_data = json.parse(data)
        if not message_data then
            print("[wannacry] Invalid message received.")
            return
        end

        if message_data.type == "login" then
            if message_data.success then
                ui.set_visible(login_button, false)
                ui.set_visible(register_button, false)
                ui.set_visible(load_button, true)
                ui.set_visible(user_textbox, false)
                ui.set_visible(pass_textbox, false)
                ui.set_visible(label, false)
                ui.set_visible(label1, false)
                ui.set_visible(label2, false)
                print("[wannacry] Online: ", message_data.login)
                logged_in = true

                local startup_lua = database.read("startup_luas") or {}
                for lua, should_load in pairs(startup_lua) do
                    if should_load then
                        local load_message = string.format([[{"type": "load_lua", "lua": "%s"}]], lua)
                        websocket_connection:send(load_message)
                        print("[wannacry] Loading Lua: ", lua)
                    end
                end
            else
                print("[wannacry] Error: ", message_data.message)
                logged_in = false

                ui.set_visible(login_button, true)
                ui.set_visible(register_button, true)
                ui.set_visible(load_button, false)
                ui.set_visible(user_textbox, true)
                ui.set_visible(pass_textbox, true)
                ui.set_visible(label, true)
                ui.set_visible(label1, true)
                ui.set_visible(label2, true)
            end
        elseif message_data.type == "luas" then
            luas = message_data.luas or {}
            ui.set_visible(load_button, true)
            ui.update(lua_listbox, luas)
            ui.set_visible(lua_listbox, true)

            for _, checkbox in ipairs(checkboxes) do
                ui.delete(checkbox)
            end
            checkboxes = {}
            create_checkboxes()
            update_checkboxes_visibility()

        elseif message_data.type == "lua_link" then
            local lua_link = message_data.link
            local lua_name = message_data.luaName

            if not lua_link then
                return
            end

            http.get(lua_link, function(success, response)
                if success then
                    local lua_content = response.body

                    if not lua_content or lua_content == "" then
                        print("[wannacry] Error: Empty Lua content received from server.")
                        return
                    end

                    local loaded_func, load_err = load(lua_content)

                    if not loaded_func then
                        print("[wannacry] Error loading Lua script:", load_err)
                    else
                        local success, run_err = pcall(loaded_func)
                        if not success then
                            print("[wannacry] Error running Lua script:", run_err)
                        end
                    end
                else
                    print("[wannacry] Error: failed while loading Lua script.")
                end
            end)
   
        elseif message_data.type == "register" then
            if message_data.success then
                print("[wannacry] Registration successful.")
            else
                print("[wannacry] Registration error: ", message_data.message)
            end
        end
    end,
    close = function(ws, code, reason, was_clean)
        print("[wannacry] Connection closed.")
        websocket_connection = nil
        connected = false
        logged_in = false

        ui.set_visible(login_button, false)
        ui.set_visible(register_button, false)
        ui.set_visible(load_button, false)
        ui.set_visible(user_textbox, false)
        ui.set_visible(pass_textbox, false)
        ui.set_visible(label, false)
        ui.set_visible(label1, false)
        ui.set_visible(label2, false)

        for _, checkbox in ipairs(checkboxes) do
            ui.set_visible(checkbox, false)
        end
    end,
    error = function(ws, err)
        print("[wannacry] Connection error.")
        websocket_connection = nil
        connected = false
        logged_in = false

        ui.set_visible(user_textbox, true)
        ui.set_visible(pass_textbox, true)
        ui.set_visible(login_button, true)
        ui.set_visible(register_button, true)
        ui.set_visible(label, true)
        ui.set_visible(label1, true)
        ui.set_visible(label2, true)

        for _, checkbox in ipairs(checkboxes) do
            ui.set_visible(checkbox, false)
        end
    end
}

local function connect(url)
    websockets.connect(url, callbacks)
end

local login_datas = database.read("login_datas")
if login_datas and login_datas.username and login_datas.password then
    ui.set(user_textbox, login_datas.username)
    ui.set(pass_textbox, login_datas.password)
else
    ui.set_visible(user_textbox, true)
    ui.set_visible(pass_textbox, true)
    ui.set_visible(login_button, true)
    ui.set_visible(register_button, true)
    ui.set_visible(label, true)
    ui.set_visible(label1, true)
    ui.set_visible(label2, true)
end

websockets.connect(DEFAULT_URL, callbacks)

client.set_event_callback("paint_ui", function()
    update_checkboxes_visibility()
end)
