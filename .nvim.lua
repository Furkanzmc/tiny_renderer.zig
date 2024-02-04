vim.cmd([[cabbrev just Just]])
vim.cmd([[nmap <leader>ab :silent Just<CR>]])
vim.cmd([[nmap <leader>ar :silent Just run<CR>]])
vim.cmd(
    [[nmap <leader>at :silent execute("Just test " . substitute(expand("%"), "\\", "/", "g"))<CR>]]
)

vim.g.vimrc_dap_lldb_vscode_path = "/usr/local/bin/lldb-vscode"
vim.api.nvim_create_autocmd({ "VimEnter" }, {
    group = vim.api.nvim_create_augroup("nvimrc_autocmd", { clear = true }),
    callback = function(_)
        local current_dir = vim.fn.getcwd()

        require("vimrc.dap").init({
            language = "zig",
            name = "tiny_renderer",
            program = current_dir .. "/zig-out/bin/tiny_renderer",
            symbolSearchPath = current_dir,
            cwd = current_dir,
            debuggerRoot = current_dir .. "/zig-out/bin",
            env = {},
            runInTerminal = true,
        })
    end,
})
