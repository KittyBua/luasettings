--[[ The Tuxbox Copyright
 Copyright 2019 Markus Volk, Horsti58
 Redistribution and use in source and binary forms, with or without modification, 
 are permitted provided that the following conditions are met:
 Redistributions of source code must retain the above copyright notice, this list
 of conditions and the following disclaimer. Redistributions in binary form must
 reproduce the above copyright notice, this list of conditions and the following
 disclaimer in the documentation and/or other materials provided with the distribution.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS`` AND ANY EXPRESS OR IMPLIED
 WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 The views and conclusions contained in the software and documentation are those of the
 authors and should not be interpreted as representing official policies, either expressed
 or implied, of the Tuxbox Project.]]

caption = "Settings Updater"

local on = "ein"
local off = "aus"

locale = {}
locale["deutsch"] = {
fetch_source = "Die aktuellen Senderlisten werden geladen",
fetch_failed = "Download fehlgeschlagen",
write_settings = "Die ausgewählten Senderlisten werden geschrieben",
cleanup = "Temporäre Dateien werden gelöscht",
cleanup_failed = "Temporäre Dateien konnten nicht entfernt werden",
menu_options = "Einstellungen",
menu_update = "Update starten",
cfg_install_a = "Senderliste ",
cfg_install_b = " installieren",
cfg_ubouquets = "uBouquets installieren",
last_update = "Letztes Update: ",
update_available = "Aktualisierung verfügbar"
}
locale["english"] = {
fetch_source = "The latest settings are getting downloaded",
fetch_failed = "Download failed",
write_settings = "Writing the selected settings  to its destination",
cleanup = "Cleanup temporary files",
cleanup_failed = "Cleanup data failed",
menu_options = "Options",
menu_update = "Start update",
cfg_install_a = "Install ",
cfg_install_b = " settings",
cfg_ubouquets = "Install ubouqets",
last_update = "Last update: ",
update_available = "Update available"
}

n = neutrino()
tmp = "/tmp/settingupdate"
neutrino_conf_base = "/var/tuxbox/config"
icondir = "/share/tuxbox/neutrino/icons"
neutrino_conf = neutrino_conf_base .. "/neutrino.conf"
zapitdir = neutrino_conf_base .. "/zapit"
setting_intro = tmp .. "/lua"
settingupdater_cfg = neutrino_conf_base .. "/settingupdater.cfg"

function exists(file)
	local ok, err, exitcode = os.rename(file, file)
	if not ok then
		if exitcode == 13 then
		-- Permission denied, but it exists
		return true
		end
	end
	return ok, err
end

function isdir(path)
	return exists(path .. "/")
end

function create_settingupdater_cfg()
	file = io.open(settingupdater_cfg, "w")
	file:write("19.2E=1", "\n")
	file:close()
end

if (exists(settingupdater_cfg) ~= true) then
	create_settingupdater_cfg()
end

function last_updated()
	if exists(zapitdir .. "/services.xml") then
		for line in io.lines(zapitdir .. "/services.xml") do
			if line:match(",") and line:match(":") then
				local _,mark_begin = string.find(line, ",")
				local _,mark_end = string.find(line, ":")
				date = string.sub(line,mark_begin+6, mark_end-3)
				found = true
			end
		end
	end
	if not found then date = "" end
	return date
end

function check_for_update()
	if not isdir(tmp) then os.execute("mkdir -p " .. tmp) end
	os.execute("curl -k https://raw.githubusercontent.com/KittyBua/luasettings/main/services.xml -o " .. tmp .. "/version_online")
	for line in io.lines(tmp .. "/version_online") do
		if line:match(",") and line:match(":") then
			local _,mark_begin = string.find(line, ",")
			local _,mark_end = string.find(line, ":")
			online_date = string.sub(line,mark_begin+6, mark_end-3)
 		end
	end
	if last_updated() ~= online_date then
		os.execute("rm -rf " .. tmp)
		return true
	end
	os.execute("rm -rf " .. tmp)
end

function get_cfg_value(str)
	for line in io.lines(settingupdater_cfg) do
		if line:match(str .. "=") then
			local i,j = string.find(line, str .. "=")
			r = tonumber(string.sub(line, j+1, #line))
		end
	end
	return r
end

function nconf_value(str)
	for line in io.lines(neutrino_conf) do
		if line:match(str .. "=") then
			local i,j = string.find(line, str .. "=")
			value = string.sub(line, j+1, #line)
		end
	end
	return value
end

lang = nconf_value("language")
if locale[lang] == nil then
	lang = "english"
end

timing_menu = nconf_value("timing.menu")

function sleep(n)
	os.execute("sleep " .. tonumber(n))
end

function show_msg(msg)
	ret = hintbox.new { title = caption, icon = "settings", text = msg };
	ret:paint();
	sleep(1);
	ret:hide();
end

function start_update()
	chooser:hide()
	if (isdir(tmp) == true) then os.execute("rm -rf " .. tmp) end
	local ret = hintbox.new { title = caption, icon = "settings", text = locale[lang].fetch_source };
	ret:paint();
	if (get_cfg_value("use_git") == 1) then
		setting_url = "https://github.com/KittyBua/luasettings"
		ok ,err, exitcode = os.execute("git clone " .. setting_url .. " " .. tmp)
	else
		setting_url = "https://codeload.github.com/KittyBua/luasettings/zip/main"
		ok ,err, exitcode = os.execute("curl -k " .. setting_url .. " -o " .. tmp .. ".zip")
		if (exists(tmp) ~= true) then
			os.execute("mkdir " .. tmp)
		end
		os.execute("unzip -x " .. tmp .. ".zip -d " .. tmp)
		local glob = require "posix".glob
		for _, j in pairs(glob(tmp .. "/*", 0)) do
			os.execute("mv -f " .. j .. "/* " .. tmp)
		end
		os.execute("rm -rf " .. tmp .. ".zip")
	end

	if (exitcode ~= 0) then
		ret:hide()
		show_msg(locale[lang].fetch_failed)
		return
	else
		ret:hide();
	end
	local ok,err,exitcode = os.execute("rsync -rlpgoD --size-only " .. setting_intro .. "/settingupdater_" .. nconf_value("osd_resolution") .. ".png " .. icondir .. "/settingupdater.png")
	if (exitcode ~= 0) then
		ret:hide()
		print("rsync missing?")
		local ok,err,exitcode = os.execute("cp -f " .. setting_intro .. "/settingupdater_" .. nconf_value("osd_resolution") .. ".png " .. icondir .. "/settingupdater.png")
	else
		ret:hide();
	end
    local ok,err,exitcode = os.execute("cp -f " .. neutrino_conf_base .. "/satellites.xml " .. neutrino_conf_base .. "/satellites-kopie.xml")
	local ret = hintbox.new { title = caption, icon = "settings", text = locale[lang].write_settings};
	ret:paint();
	local positions ={}
	table.insert (positions, "start")
	if (get_cfg_value("19.2E") == 1) then table.insert (positions, "19.2E"); have_sat = 1 end
	table.insert (positions, "end")

	bouquets = io.open(zapitdir .. "/bouquets.xml", 'w')
	services = io.open(zapitdir .. "/services.xml", 'w')
 	if have_sat == 1 then satellites = io.open(neutrino_conf_base .. "/satellites.xml", 'w') end

	for i, v in ipairs(positions) do
		for line in io.lines(tmp .. "/" .. v .. "/bouquets.xml") do
			bouquets:write(line, "\n")
		end
		for line in io.lines(tmp .. "/" .. v .. "/services.xml") do
			services:write(line, "\n")
		end
		if exists(tmp .. "/" .. v .. "/satellites.xml") and have_sat == 1 then
			for line in io.lines(tmp .. "/" .. v .. "/satellites.xml") do
				satellites:write(line, "\n")
			end
		end
	end

	bouquets:close()
	services:close()
	if have_sat == 1 then satellites:close() end
	os.execute("pzapit -c ")
	sleep(1)
	ret:hide()
	local ret = hintbox.new { title = caption, icon = "settings", text = locale[lang].cleanup };
	ret:paint()
	local ok,err,exitcode = os.execute("rm -r " .. tmp)
	sleep(1);
	if (exitcode ~= 0) then
		ret:hide()
		show_msg(locale[lang].cleanup_failed)
		return
	else
		ret:hide()
	end
end

function write_cfg(k, v, str)
	if (v == on) then a = 1 else a = 0 end
	local cfg_content = {}
	for line in io.lines(settingupdater_cfg) do
		if line:match(str .. "=") then
			nline = string.reverse(string.gsub(string.reverse(line), string.sub(string.reverse(line), 1, 1), a, 1))
			table.insert (cfg_content, nline)
		else
			table.insert (cfg_content, line)
		end
	end
	file = io.open(settingupdater_cfg, 'w')
	for i, v in ipairs(cfg_content) do
		file:write(v, "\n")
	end
	io.close(file)
end

function astra_cfg(k, v, str)
	write_cfg(k, v, "19.2E")
end

function options ()
	chooser:hide()
	menu = menu.new{name=locale[lang].menu_options}
	menu:addItem{type="back"}
	menu:addItem{type="separatorline"}
	if (get_cfg_value("19.2E") == 1) then
		menu:addItem{type="chooser", action="astra_cfg", options={on, off}, icon=4, directkey=RC["4"], name=locale[lang].cfg_install_a .. " 19.2E " .. locale[lang].cfg_install_b}
	elseif (get_cfg_value("19.2E") == 0) then
		menu:addItem{type="chooser", action="astra_cfg", options={off, on}, icon=4, directkey=RC["4"], name=locale[lang].cfg_install_a .. " 19.2E " .. locale[lang].cfg_install_b}
	end
	menu:exec()
	main()
end

if check_for_update() then show_msg(locale[lang].update_available) end

function main()
	chooser_dx = n:scale2Res(560)
	chooser_dy = n:scale2Res(400)
	chooser_x = SCREEN.OFF_X + (((SCREEN.END_X - SCREEN.OFF_X) - chooser_dx) / 2)
	chooser_y = SCREEN.OFF_Y + (((SCREEN.END_Y - SCREEN.OFF_Y) - chooser_dy) / 2)

	chooser = cwindow.new {
	caption = locale[lang].last_update .. last_updated(),
	x = chooser_x,
	y = chooser_y,
	dx = chooser_dx,
	dy = chooser_dy,
	icon = "settings",
	has_shadow = true,
	btnGreen = locale[lang].menu_update,
	btnRed = locale[lang].menu_options
	}
	picture = cpicture.new {
	parent = chooser,
	image="settingupdater",
	}
	chooser:paint()
	i = 0
	d = 500 -- ms
	t = (timing_menu * 1000) / d
	if t == 0 then
		t = -1 -- no timeout
	end
	colorkey = nil
	repeat
		i = i + 1
		msg, data = n:GetInput(d)
		if (msg == RC['red']) then
			options()
			colorkey = true
		elseif (msg == RC['green']) then
			start_update()
			colorkey = true
		end
	until msg == RC['home'] or colorkey or i == t
	chooser:hide()
end

main()
