--!nonstrict
-- Floating panel built from the declarative ui.* vocabulary. Replaces
-- Panel.qml. There's no native file picker in the plugin API, so "Add Key"
-- is a path input instead of NFilePicker — paste or type the key path.
--
-- Everything here is a thin client: it reads noctalia.state("status")
-- (published by service.luau) and requests actions by writing to the
-- "command" channel. It never touches ssh-agent/ssh-add directly.

local status = noctalia.state.get("status") or {}

local editing = false
local selectedSessionName = ""
local editName, editHost, editUser, editPort, editKeyPath, editExtraArgs = "", "", "", "22", "", ""
local addKeyPath = ""

local function sendCommand(action, extra)
	local cmd = extra or {}
	cmd.action = action
	cmd.ts = noctalia.nowMs()
	noctalia.state.set("command", cmd)
end

local function clearForm()
	editing = false
	selectedSessionName = ""
	editName, editHost, editUser, editPort, editKeyPath, editExtraArgs = "", "", "", "22", "", ""
end

local function loadIntoForm(session)
	editing = true
	selectedSessionName = session.name or ""
	editName = session.name or ""
	editHost = session.host or ""
	editUser = session.user or ""
	editPort = tostring(session.port or "22")
	editKeyPath = session.key_path or ""
	editExtraArgs = session.extra_args or ""
end

local function render()
	local keyRows = {}
	for _, key in ipairs(status.loaded_keys or {}) do
		table.insert(
			keyRows,
			ui.row({ gap = 8, align = "center" }, {
				ui.label({ text = key.name or "(unknown)", flexGrow = 1 }),
				ui.label({ text = key.type or "", color = "on_surface_variant", fontSize = 11 }),
				ui.button({
					glyph = "trash",
					onClick = function()
						sendCommand("remove-key", { name = key.name })
					end,
				}),
			})
		)
	end
	if #keyRows == 0 then
		table.insert(keyRows, ui.label({ text = "No keys loaded", color = "on_surface_variant" }))
	end

	local sessionRows = {}
	for _, s in ipairs(status.sessions or {}) do
		table.insert(
			sessionRows,
			ui.row({ gap = 8, align = "center" }, {
				ui.label({ text = s.name or "", fontWeight = "medium", flexGrow = 1 }),
				ui.label({ text = s.host or "", color = "on_surface_variant" }),
				ui.button({
					glyph = "terminal",
					onClick = function()
						sendCommand("launch-session", { session = s })
					end,
				}),
				ui.button({
					glyph = "edit",
					onClick = function()
						loadIntoForm(s)
						render()
					end,
				}),
				ui.button({
					glyph = "trash",
					onClick = function()
						sendCommand("delete-session", { name = s.name })
					end,
				}),
			})
		)
	end
	if #sessionRows == 0 then
		table.insert(sessionRows, ui.label({ text = "No saved sessions", color = "on_surface_variant" }))
	end

	local children = {
		ui.row({ align = "center", justify = "space_between", gap = 8 }, {
			ui.label({ text = "SSH Agent", fontSize = 16, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
			ui.label({
				text = status.agent_running and "Running" or "Stopped",
				color = status.agent_running and "primary" or "error",
			}),
			ui.button({ glyph = "close", onClick = "onCloseClicked" }),
		}),

		ui.column({ gap = 8 }, {
			ui.row({ align = "center", justify = "space_between", gap = 8 }, {
				ui.label({ text = "Loaded Keys", fontWeight = "medium", color = "on_surface_variant", flexGrow = 1 }),
				ui.button({ glyph = "refresh", onClick = "onRefreshClicked" }),
			}),
			ui.column({ gap = 4 }, keyRows),
			ui.row({ gap = 8, align = "center" }, {
				ui.input({
					key = "add_key_path",
					placeholder = "Path to private key…",
					value = addKeyPath,
					onChange = "onAddKeyPathChange",
					onSubmit = "onAddKeySubmit",
				}),
				ui.button({
					text = (not addKeyPath or addKeyPath == "") and "Browse…" or "Add Key",
					onClick = "onAddKeyClicked",
				}),

			}),
		}),

		ui.column({ gap = 8 }, {
			ui.row({ align = "center", justify = "space_between", gap = 8 }, {
				ui.label({ text = "Saved Sessions", fontWeight = "medium", color = "on_surface_variant", flexGrow = 1 }),
				ui.button({ text = "New Session", glyph = "plus", onClick = "onNewSessionClicked" }),
			}),
			ui.column({ gap = 4 }, sessionRows),
		}),
	}

	if editing then
		table.insert(
			children,
			ui.column({ gap = 8 }, {
				ui.label({ text = selectedSessionName ~= "" and "Edit Session" or "New Session", fontWeight = "medium" }),
				ui.input({ key = "name", placeholder = "Session name", value = editName, onChange = "onNameChange" }),
				ui.input({ key = "host", placeholder = "Host", value = editHost, onChange = "onHostChange" }),
				ui.input({ key = "user", placeholder = "User", value = editUser, onChange = "onUserChange" }),
				ui.input({ key = "port", placeholder = "Port", value = editPort, onChange = "onPortChange" }),
				ui.input({ key = "key_path", placeholder = "Key path", value = editKeyPath, onChange = "onKeyPathChange" }),
				ui.input({
					key = "extra_args",
					placeholder = "Extra SSH args",
					value = editExtraArgs,
					onChange = "onExtraArgsChange",
				}),
				ui.row({ gap = 8 }, {
					ui.button({
						text = (selectedSessionName ~= "" and "Update Session" or "Save Session"),
						glyph = "device-floppy",
						onClick = "onSaveSession",
					}),
					ui.button({ text = "Cancel", glyph = "x", onClick = "onCancelEdit" }),
				}),
			})
		)
	end

	panel.render(ui.scroll({ flexGrow = 1, gap = 16, align = "stretch" }, children))
end

function onOpen(_context)
	status = noctalia.state.get("status") or {}
	render()
end

noctalia.state.watch("status", function(value)
	status = value or {}
	render()
end)

function onNameChange(value)
	editName = value
end
function onHostChange(value)
	editHost = value
end
function onUserChange(value)
	editUser = value
end
function onPortChange(value)
	editPort = value
end
function onKeyPathChange(value)
	editKeyPath = value
end
function onExtraArgsChange(value)
	editExtraArgs = value
end
function onAddKeyPathChange(value)
	addKeyPath = value
end

function onNewSessionClicked()
	clearForm()
	editing = true
	render()
end

function onCancelEdit()
	clearForm()
	render()
end

function onSaveSession()
	sendCommand("upsert-session", {
		session = {
			name = editName,
			host = editHost,
			user = editUser,
			port = editPort,
			key_path = editKeyPath,
			extra_args = editExtraArgs,
		},
	})
	clearForm()
	render()
end

-- function onAddKeyClicked()
-- 	if addKeyPath ~= "" then
-- 		sendCommand("add-key", { path = addKeyPath })
-- 		addKeyPath = ""
-- 		render()
-- 	end
-- end

function onAddKeySubmit(value)
	addKeyPath = value
	if addKeyPath ~= "" then
		sendCommand("add-key", { path = addKeyPath })
		addKeyPath = ""
	end
	render()
end

function onRefreshClicked()
	sendCommand("refresh")
end

function onCloseClicked()
	panel.close()
end

local function openFileBrowser(callback)
	noctalia.runAsync("zenity --file-selection --title='Select SSH Private Key' 2>/dev/null", function(res)
		local output = (res and res.stdout) or ""
		if res and res.exitCode == 0 and output ~= "" then
			callback((output:gsub("%s+$", "")))
		else
			callback(nil)
		end
	end, 60000)
end

function onAddKeyClicked()
	if not addKeyPath or addKeyPath:match("^%s*$") then
		openFileBrowser(function(selectedPath)
			if selectedPath then
				addKeyPath = selectedPath
				onAddKeySubmit(selectedPath)
			end
		end)
	else
		onAddKeySubmit(addKeyPath)
	end
end

