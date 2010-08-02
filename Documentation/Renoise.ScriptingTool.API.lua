--[[============================================================================
Renoise ScriptingTool API Reference
============================================================================]]--

--[[

This reference lists all available Lua functions and classes that are available
to Renoise xrnx scripting tools only. The scripting tool interface allows
your tool to interact with Renoise by injecting, creating menu entries or 
keybindings into Renoise; or by attaching to some common tool related notifiers.

Please read the INTRODUCTION.txt first to get an overview about the complete
API, and scripting in Renoise in general...

Have a look at the com.renoise.ExampleTool.xrnx for more info about XRNX tools.

Do not try to execute this file. It uses a .lua extension for markups only.

]]


--------------------------------------------------------------------------------
-- renoise
--------------------------------------------------------------------------------

-------- functions

-- access to your tools interface to Renoise. only valid for xrnx tools
renoise.tool() 
  -> [renoise.ScriptingTool object]


--------------------------------------------------------------------------------
-- renoise.ScriptingTool
--------------------------------------------------------------------------------

-------- functions

-- add_menu_entry: insert a new menu entry somewhere in Renoises existing 
-- context menues or the global app menu. insertion can be done while 
-- the script is initializing, but also dynamically later on.
--
-- The table passed as argument to 'add_menu_entry' is defined as:
--
-- * required fields
--   ["name"] = name and 'path' of the entry as shown in the global menus or 
--     context menus to the user
--   ["invoke"] = a function that is called as soon as the entry was clicked
--
-- * optional fields:
--   ["active"] = a function that should return true or false. when returning 
--     false, the action will not be invoked and "grayed out" in menus. This 
--     function is called every time before "invoke" is called and every time 
--     before a menu gets visible.
--   ["selected"] = a function that should return true or false. when returning
--     true, the entry will be marked as "this is a selected option"
--
-- Placing entries:
--
-- You can place your entries in any context menu or any window menu in Renoise.
-- To do so, use one of the specified categories in its name:
--
-- "Window Menu"
-- "Main Menu" (:File", ":Edit", ":View", ":Tools" or ":Help")
-- "Disk Browser Directories"
-- "Disk Browser Files"
-- "Instrument Box" 
-- "Instrument Box Samples" 
-- "Pattern Sequencer"
-- "Pattern Editor"
-- "Pattern Matrix"
-- "Pattern Matrix Header"
-- "Pattern Matrix",
-- "Sample Editor"
-- "Sample Editor Ruler"
-- "Mixer"
-- "Track DSPs Chain"
-- "Track DSPs Chain List"
-- "Track Automation" 
-- "Track Automation List"
-- "DSP Device"
-- "DSP Device Header"
-- "DSP Device Automation" 
--
-- Separating entries:
-- 
-- To divide entries into groups (separate entries with a line), prepend one or 
-- more dashes to the name, like "--- Main Menu:Tools:My Tool Group Starts Here"
renoise.tool():add_menu_entry(menu_entry_definition_table)

-- remove a previously added menu entry by specifying its full name
renoise.tool():remove_menu_entry(menu_entry_name)


-- add_keybinding: register key bindings somewhere in Renoises existing 
-- set of bindings.
--
-- The table passed as argument to add_keybinding is defined as:
--
-- * required fields
--   ["name"] = the scope, name and category of the key binding
--   ["invoke"] = a function that is called as soon as the mapped key was pressed
--
-- The key binding's 'name' must have 3 parts, separated with :'s
-- <scope:topic_name:binding_name>
-- * 'scope' is where the shortcut will be applied, just like you see them 
--   in the categories list in the keyboard assigment preferences pane
-- * 'topic_name' is useful to group entries in the key assignment pane.
--   use "tool" if you can not come up with something useful.
-- * 'binding_name' is the name of the binding
--
-- currently available scopes are:
-- "Global", "Automation", "Disk Browser", "Instrument Box", "Mixer", 
-- "Pattern Editor", "Pattern Matrix", "Pattern Sequencer", "Sample Editor"
-- "Track DSPs Chain"
--
-- Using a non avilable scope will not fire an error but only drive the binding
-- useless. It will be listed and can be mapped, but will never be invoked.
--
-- Theres no way to define default keyboard shortcuts for your entries. Users 
-- manually have to bind them in the keyboard prefs pane. As soon as they did,
-- they get saved just like any other key binding in Renoise.
renoise.tool():add_keybinding(keybinding_definition_table)

-- remove a previously added key binding by specifying its name and path 
renoise.tool():remove_keybinding(keybinding_name)


-------- properties

-- full abs path and name of your tools bundle directory
renoise.tool().bundle_path
  -> [read-only, string]

-- invoked, as soon as the application became the foreground window,
-- for example when you alt-tab'ed to it, or switched with the mouse
-- from another app to Renoise
renoise.tool().app_became_active_observable
  -> [renoise.Document.Observable object]
  
-- invoked, as soon as the application looses focus, another app
-- became the foreground window 
renoise.tool().app_resigned_active_observable
  -> [renoise.Document.Observable object]

-- invoked periodically in the background, more often when the work load
-- is low, less often when Renoises work load is high.
-- The exact interval is not defined and can not be relied on, but will be
-- around 10 times per sec.
-- You can do stuff in the background without blocking the application here.
-- Be gentle and don't do CPU heavy stuff here please!
renoise.tool().app_idle_observable
  -> [renoise.Document.Observable object]

-- invoked each time a new document (song) was created or loaded, aka each time
-- the result of renoise.song() has changed.
renoise.tool().app_new_document_observable
  -> [renoise.Document.Observable object]

-- get or set an optional renoise.Document.DocumentNode object, which will be
-- used as set of persistant "options" or preferences for your tool. 
-- by default nil. when set, the assigned document object will be automatically 
-- loaded and saved by Renoise, in order to retain the tools state.
-- the preference xml file is saved/loaded within the tool bundle as 
-- "com.example.your_tool.xrnx/preferences.xml".
--
-- a simple example:
-- -- create a document first
-- my_options = renoise.Document.create { 
--  some_option = true, 
--  some_value = "string_value"
-- }
--
-- -- register the document as the tools preferences
-- renoise.tool().preferences = my_options
--
-- -- values can be accessed (read, written) via 
-- my_options.some_option.value, my_options.some_value.value
--
-- -- also notifiers can be added to listen to changes to the values
-- -- done by you, or after new values got loaded or a view changed the value:
-- my_options.some_option:add_notifier(function() end)
--
-- please see Renoise.Document.API.txt for more info about renoise.DocumentNode
-- and documents in the Renoise API in general.
renoise.tool().preferences
  -> [renoise.Document.DocumentNode object or nil]
    