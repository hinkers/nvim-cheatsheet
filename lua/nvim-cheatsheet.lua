local api = vim.api
local loop = vim.loop
local M = {}

-- Function to read file content
local function read_file_content(file_path)
    local lines = {}
    for line in io.lines(file_path) do
        table.insert(lines, line)
    end
    return lines
end

-- Function to check if the line contains the query
local function line_contains_query(line, query)
    if query == '' then return true end  -- Return true for all lines if query is empty
    return string.find(line:lower(), query:lower()) ~= nil
end

-- Function to filter lines based on the query
local function filter_lines(lines, query)
    local filtered_lines = {}
    for _, line in ipairs(lines) do
        if line_contains_query(line, query) then
            table.insert(filtered_lines, line)
        end
    end
    
    return filtered_lines
end

-- Function to update the floating window content based on the query
local function update_floating_window(buf, file_lines, query)
    local filtered_lines = filter_lines(file_lines, query)
    
    -- Temporarily make the buffer modifiable to update the lines
    api.nvim_buf_set_option(buf, 'modifiable', true)
    api.nvim_buf_set_option(buf, 'readonly', false)

    -- Clear the buffer and set the lines
    api.nvim_buf_set_lines(buf, 0, -1, false, filtered_lines)

    -- Set the buffer back to read-only
    api.nvim_buf_set_option(buf, 'modifiable', false)
    api.nvim_buf_set_option(buf, 'readonly', true)

    return #filtered_lines
end

-- Function to set up syntax highlighting
local function setup_buffer_syntax(buf)
    -- Define the syntax patterns and link them to highlight groups
    local syntax_commands = {
        "syntax clear",  -- Clear existing syntax items
        "syntax match Normal /\\<normal\\>/",
        "syntax match Visual /\\<visual\\>/",
        "syntax match Insert /\\<insert\\>/",
        "syntax match Select /\\<select\\>/",
        "syntax match Command /\\<command\\>/",
        "syntax match Operator /\\<operator\\>/",
        "syntax match Brackets /\\[.*\\]/",
        -- Add more syntax matches as needed
    }

    -- Highlight groups (customize according to your colorscheme or preferences)
    local highlight_commands = {
        "highlight link Normal Keyword",
        "highlight link Visual Type",
        "highlight link Insert Identifier",
        "highlight link Select Special",
        "highlight link Command PreProc",
        "highlight link Operator Statement",
        "highlight link Brackets Constant",
        -- Add more highlight links as needed
    }

    -- Set buffer-specific syntax
    api.nvim_buf_call(buf, function()
        for _, cmd in ipairs(syntax_commands) do
            vim.cmd(cmd)
        end
        for _, cmd in ipairs(highlight_commands) do
            vim.cmd(cmd)
        end
    end)
end

-- Function to get the directory of the current script
local function get_script_directory()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end

-- Main function to create the floating window with fuzzy search
function M.create_floating_window_with_search()
    -- Define the file path for the user's cheatsheet and the default cheatsheet
    local file_path = vim.fn.expand('~/.config/nvim/cheatsheet.txt')

    -- Check if the file exists, if not, copy the default cheatsheet to the path
    if not loop.fs_stat(file_path) then
        -- Get the directory of the current script (plugin directory)
        local plugin_directory = get_script_directory()
        local default_file_path = plugin_directory .. 'data/cheatsheet.txt'
        loop.fs_copyfile(default_file_path, file_path)
    end

    -- Read file content
    local file_lines = read_file_content(file_path)
    -- Define the floating window's width and height
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)

    -- Calculate the starting position
    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)

    -- Buffer settings
    local buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    api.nvim_buf_set_option(buf, 'modifiable', false)
    api.nvim_buf_set_option(buf, 'readonly', true)

    -- Window settings
    local win = api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        col = col,
        row = row,
        style = 'minimal',
        border = 'rounded',
    })

    -- Initially display all lines
    local total_lines = update_floating_window(buf, file_lines, "")

    -- Syntax highlighting
    setup_buffer_syntax(buf) 

    -- Create a mapping for "/" to trigger the filter prompt
    api.nvim_buf_set_keymap(buf, 'n', '/', ':lua FilterLines()<CR>', {silent = true, noremap = true})
    api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':lua vim.api.nvim_win_close(' .. win .. ', true)<CR>', {silent = true, noremap = true})
    api.nvim_buf_set_keymap(buf, 'n', 'q', ':lua vim.api.nvim_win_close(' .. win .. ', true)<CR>', {silent = true, noremap = true})

    -- Function to trigger the filter prompt
    _G.FilterLines = function()
        local query = vim.fn.input('Filter ' .. total_lines .. ': ')
        if query and query ~= "" then
            total_lines = update_floating_window(buf, file_lines, query)
        end
    end
end

-- Command to trigger the floating window with search
vim.api.nvim_create_user_command('Cheatsheet', M.create_floating_window_with_search, {})

return M
