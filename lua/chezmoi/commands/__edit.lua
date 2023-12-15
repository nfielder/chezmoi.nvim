local Path = require("plenary.path")
local config = require("chezmoi.config").values
local notify = require("chezmoi.notify")
local util = require("chezmoi.util")
local base = require("chezmoi.commands.__base")

local edit_cmd = {}

---@return table { watch: boolean }
---@param args { watch: boolean }
function edit_cmd.__resolve_args(args)
  local ret = { watch = false }

  for _, v in ipairs(args) do
    if v == "--watch" then
      ret.watch = true
    end
  end

  return ret
end

local function watch(bufnr, source_file_path)
  -- Use autocmd to make it work as if 'watch' option is given
  local augroup = vim.api.nvim_create_augroup("chezmoi", { clear = false })
  vim.api.nvim_create_autocmd({ 'BufWritePost' }, {
    group = augroup,
    buffer = bufnr,
    callback = function()
      base.execute({
        cmd = "apply",
        args = {
          "--source-path",
          source_file_path,
        },
        on_exit = function(_, _)
          if config.notification.on_save then
            notify.info("Successfully applied")
          end
        end
      })
    end
  })
end

---@ param pos_args string|string[]
---@ param args string[]
function edit_cmd.execute(pos_args, args)
  args = edit_cmd.__resolve_args(args or {})

  local resolved_pos_args = util.__resolve_pos_args(pos_args)
  if resolved_pos_args == nil then
    notify.panic("failed to validate positional arguments")
    return
  end

  local path = Path:new(resolved_pos_args[1])

  if not path:exists() then
    local message = "The file " .. tostring(path) .. "does not exists.\n"
    message = message .. "Check the values of the list below\n"
    message = message .. " - 'config.chezmoi.destination_path'\n"
    message = message .. " - 'config.chezmoi.source_path'"
    notify.panic(message)
    return
  end

  local source_file_path = base.execute({
    cmd = "source-path",
    pos_args = { tostring(path) },
  })
  if not source_file_path then
    return
  end
  -- print(source_file_path)
  -- print(vim.inspect(source_file_path))

  local ok, _ = pcall(vim.cmd.edit, source_file_path[1])
  if ok then
    if config.notification.on_open then
      notify.info("This is a chezmoi managed file")
    end
  else
    notify.error("Failed to open file " .. source_file_path[1])
    return
  end

  if args.watch then
    local bufnr = vim.api.nvim_get_current_buf()
    watch(bufnr, source_file_path[1])
  end
end

return edit_cmd
