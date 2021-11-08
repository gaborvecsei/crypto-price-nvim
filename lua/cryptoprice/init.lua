local cryptoprice = require("cryptoprice.show_crypto")

local M = {}

-- Just a dummy function, so it's cleaner to call
function M.toggle()
    cryptoprice.toggle_price_window()
end

function M.setup(opts)
    local function set_default(opt, default)
		if vim.g["cryptoprice_" .. opt] ~= nil then
			return
		elseif opts[opt] ~= nil then
			vim.g["cryptoprice_" .. opt] = opts[opt]
		else
			vim.g["cryptoprice_" .. opt] = default
		end
	end

    set_default("crypto_list", {"bitcoin", "ethereum", "tezos"})
    set_default("base_currency", "usd")
end

-- Default config setup
M.setup({})

return M
