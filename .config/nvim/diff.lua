-- 基本设置
vim.opt.loadplugins = true
vim.opt.swapfile = false
vim.opt.diffopt:append({
  "internal",
  "filler",
  "closeoff",
  "hiddenoff",
  "algorithm:minimal"
})
