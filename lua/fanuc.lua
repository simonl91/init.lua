local job_id = 0
local ftp_job_id = 0

local function SplitPath(path)
  -- Returns the Path, Filename, and Extension as 3 values
  return string.match(path, '^(.-)([^\\/]-)(%.[^\\/%.]-)%.?$')
end

local on_build_finished = function(karelfile, ip, del)
  local pcfile = string.gsub(karelfile, '.kl', '.pc')

  local running = vim.fn.jobwait({ ftp_job_id }, 0)[1] == -1
  if running then
    vim.fn.jobstop(ftp_job_id)
  end

  if 1 == vim.fn.filereadable(pcfile) then
    local p, f, e = SplitPath(karelfile)
    local filename = f .. e
    local pc_filename = string.gsub(filename, '.kl', '.pc')
    local vr_filename = string.gsub(filename, '.kl', '.vr')
    local ftp_commands = {}
    table.insert(ftp_commands, 'prompt')
    table.insert(ftp_commands, 'delete ' .. pc_filename)
    if del == 'del' then
      table.insert(ftp_commands, 'delete ' .. vr_filename)
    end
    table.insert(ftp_commands, 'put ' .. pc_filename)
    table.insert(ftp_commands, 'done')

    local tempfile = vim.fn.tempname()
    if -1 == vim.fn.writefile(ftp_commands, tempfile) then
      print 'Error writing to tempfile'
      return
    end
    ftp_job_id = vim.fn.jobstart('ftp -s:"' .. tempfile .. '" ' .. ip, {
      stdout_buffered = true,
      on_stdout = function(_, d)
        for _, v in ipairs(d) do
          print(v)
        end
      end,
      on_exit = function()
        os.remove(tempfile)
        os.remove(pcfile)
      end,
    })
  end
end

-- Build karel file with ktrans and transfer to robot with ftp
-- Example: :FanucBuildTransfer "192.168.1.10"
vim.api.nvim_create_user_command('FanucBuildTransfer', function(d)
  local ip = d.fargs[1]
  local del = d.fargs[2]
  local running = vim.fn.jobwait({ job_id }, 0)[1] == -1
  if running then
    vim.fn.jobstop(job_id)
  end

  local karelfile = vim.api.nvim_buf_get_name(0)
  local cmd = 'ktrans "' .. karelfile
  job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, d)
      on_build_finished(karelfile, ip, del)
    end,
  })
end, {})
