vim.cmd([[cabbrev just Just]])
vim.cmd([[nmap <leader>ab :Just<CR>]])
vim.cmd([[nmap <leader>ar :Just run<CR>]])
vim.cmd([[nmap <leader>at :Just test %<CR>]])

vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
    group = vim.api.nvim_create_augroup("nvimrc_autocmd", { clear = true }),
    callback = function(_)
        if vim.fn.expand("$AW_AUTO_SESSION") == "1" then
            cmd([[mksession! session.vim]])
        end
    end,
})
