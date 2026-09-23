-- In-buffer markdown rendering: headings, tables, code blocks, checkboxes and
-- callouts drawn as virtual text while the file on disk stays plain markdown.
-- https://github.com/MeanderingProgrammer/render-markdown.nvim

vim.pack.add { 'https://github.com/MeanderingProgrammer/render-markdown.nvim' }

require('render-markdown').setup {
  -- Render in every mode; anti_conceal still shows the raw source on the cursor line.
  render_modes = true,
  completions = { blink = { enabled = true } },
}

vim.keymap.set('n', '<leader>tm', '<Cmd>RenderMarkdown toggle<CR>', { desc = '[T]oggle [M]arkdown rendering' })
