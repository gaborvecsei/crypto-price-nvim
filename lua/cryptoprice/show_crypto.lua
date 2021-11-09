local popup = require("plenary.popup")
local reqs = require("cryptoprice.reqs")
-- Just to suppress editor errors
local vim = vim

local M = {}

-- Popup window
Crypto_buf = nil
Crypto_win_id = nil


local function get_crypto_prices(base_currency, coin_names)
    -- Returns the price of the defined cryptos in the base currency

    coin_names = table.concat(coin_names, "%2C")
    local resp = reqs.get_prices(coin_names, base_currency)

    if not resp.success then
       error("Could not make request for " .. coin_names)
    end

    -- Simplify the response to a table where the key is the coin name and the value is the price
    local prices_table = {}
    for k, v in pairs(resp.json_table) do
        prices_table[k] = v[base_currency]
    end

    -- returns a table, e.g. {bitcoin=69, ethereum=420}
    return prices_table
end

local function create_window(width, height)
    -- Creates a popup window where we will show the prices

    width = width or 60
    height = height or 10
    local borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }
    local bufnr = vim.api.nvim_create_buf(false, false)

    local win_id, win = popup.create(bufnr, {
        title = "Crypto Prices",
        highlight = "CryptoPriceWindow",
        line = math.floor(((vim.o.lines - height) / 2) - 1),
        col = math.floor((vim.o.columns - width) / 2),
        minwidth = width,
        minheight = height,
        borderchars = borderchars,
    })

    vim.api.nvim_win_set_option(
        win.border.win_id,
        "winhl",
        "Normal:CryptoPriceBorder"
    )

    return {
        bufnr = bufnr,
        win_id = win_id,
    }
end

local function close_window()
    -- Close the popup window

    vim.api.nvim_win_close(Crypto_win_id, true)
    Crypto_win_id = nil
    Crypto_buf = nil
end

local function set_buffer_contents(buf, contents)
    -- Helper function to set the contents of the window buffer

    vim.api.nvim_buf_set_name(buf, "cryptoprice-menu")

    -- TODO: offsetting the help message from the last "real" line - I am sure there is a better way to do this
    -- Another call to vim.api.nvim_buf_set_lines did not work, there was no offset
    if #contents < 9 then
        -- While we don't fill the whole window, show the help at the bottom (last line)
        for i=1,10-#contents-1 do contents[#contents+1] = "" end
    end
    contents[#contents+1] = "(Press 'q' to close this window, 'r' to refresh prices)"
    vim.api.nvim_buf_set_lines(buf, 0, #contents, false, contents)

    vim.api.nvim_buf_set_option(buf, "filetype", "cryptoprice")
    vim.api.nvim_buf_set_option(buf, "buftype", "acwrite")
    vim.api.nvim_buf_set_option(buf, "bufhidden", "delete")
end

local function create_price_data()
    -- Gather prices of the defined coins and create the messages which we will show on the created popup window

    local contents = {}
    local req_status, prices = pcall(get_crypto_prices, vim.g.cryptoprice_base_currency, vim.g.cryptoprice_crypto_list)

    if req_status then
        -- Create the message line by line in the defined crypto order
        for k, v in ipairs(vim.g.cryptoprice_crypto_list) do
            contents[#contents+1] = "- 1 " .. string.upper(v) .. " is " .. tostring(prices[v]) .. " " .. string.upper(vim.g.cryptoprice_base_currency)
        end
    else
        contents[1] = "[ERROR] No prices found"
    end
    return contents
end

function M.refresh_prices()
    -- Gather prices and then create the messages which will be displayed

    if Crypto_win_id ~= nil and vim.api.nvim_win_is_valid(Crypto_win_id) then
        local contents = create_price_data()
        set_buffer_contents(Crypto_buf, contents)
    else
        print("Window does not exists, no price data will be shown")
    end
end

function M.toggle_price_window()
    -- Creates the popup window, then draws the crypto price content in the buffer

    if Crypto_win_id ~= nil and vim.api.nvim_win_is_valid(Crypto_win_id) then
        -- If the window already exists, then close it
        close_window()
        return
    end

    -- Create the window, and assign the global variables, so we can use later
    local win_info = create_window(vim.g.cryptoprice_window_width, vim.g.cryptoprice_window_height)
    Crypto_win_id = win_info.win_id
    Crypto_buf = win_info.bufnr

    -- Check if the API is reachable
    if not reqs.ping_api() then
        set_buffer_contents(Crypto_buf, {"[ERROR] the API is not reachable", "Check your internet connection"})
        return
    end

    -- Show the current prices
    M.refresh_prices()

    -- Keymappings for the opened window
    vim.api.nvim_buf_set_keymap(
        Crypto_buf,
        "n",
        "q",
        ":lua require('cryptoprice.show_crypto').toggle_price_window()<CR>",
        { silent = true }
    )
    vim.api.nvim_buf_set_keymap(
        Crypto_buf,
        "n",
        "r",
        ":lua require('cryptoprice.show_crypto').refresh_prices()<CR>",
        { silent = true }
    )
end

return M

