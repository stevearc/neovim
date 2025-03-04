local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed = helpers.clear, helpers.feed
local eval = helpers.eval
local eq = helpers.eq
local neq = helpers.neq
local command = helpers.command
local set_method_error = helpers.set_method_error
local api = helpers.api
local async_meths = helpers.async_meths
local test_build_dir = helpers.paths.test_build_dir
local nvim_prog = helpers.nvim_prog
local exec = helpers.exec
local exec_capture = helpers.exec_capture
local exc_exec = helpers.exc_exec
local exec_lua = helpers.exec_lua
local poke_eventloop = helpers.poke_eventloop
local assert_alive = helpers.assert_alive
local retry = helpers.retry
local is_os = helpers.is_os
local is_ci = helpers.is_ci
local fn = helpers.fn
local skip = helpers.skip

describe('ui/ext_messages', function()
  local screen
  local fname = 'Xtest_functional_ui_messages_spec'

  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:attach({ rgb = true, ext_messages = true, ext_popupmenu = true })
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue1 },
      [2] = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
      [3] = { bold = true },
      [4] = { bold = true, foreground = Screen.colors.SeaGreen4 },
      [5] = { foreground = Screen.colors.Blue1 },
      [6] = { bold = true, reverse = true },
      [7] = { background = Screen.colors.Yellow },
      [8] = { foreground = Screen.colors.Red },
      [9] = { special = Screen.colors.Red, undercurl = true },
      [10] = { foreground = Screen.colors.Brown },
    })
  end)
  after_each(function()
    os.remove(fname)
  end)

  it('msg_clear follows msg_show kind of confirm', function()
    feed('iline 1<esc>')
    feed(':call confirm("test")<cr>')
    screen:expect {
      grid = [[
      line ^1                   |
      {1:~                        }|*4
    ]],
      messages = {
        {
          content = { { '\ntest\n[O]k: ', 4 } },
          kind = 'confirm',
        },
      },
    }

    feed('<cr>')
    screen:expect {
      grid = [[
      line ^1                   |
      {1:~                        }|*4
    ]],
    }
  end)

  it('msg_show kind=confirm,confirm_sub,emsg,wmsg,quickfix', function()
    feed('iline 1\nline 2<esc>')

    -- kind=confirm
    feed(':echo confirm("test")<cr>')
    screen:expect {
      grid = [[
      line 1                   |
      line ^2                   |
      {1:~                        }|*3
    ]],
      messages = {
        {
          content = { { '\ntest\n[O]k: ', 4 } },
          kind = 'confirm',
        },
      },
    }
    feed('<cr><cr>')
    screen:expect {
      grid = [[
      line 1                   |
      line ^2                   |
      {1:~                        }|*3
    ]],
      messages = {
        {
          content = { { '\ntest\n[O]k: ', 4 } },
          kind = 'confirm',
        },
        {
          content = { { '1' } },
          kind = 'echo',
        },
        {
          content = { { 'Press ENTER or type command to continue', 4 } },
          kind = 'return_prompt',
        },
      },
    }
    feed('<cr><cr>')

    -- kind=confirm_sub
    feed(':%s/i/X/gc<cr>')
    screen:expect {
      grid = [[
      l{7:i}ne 1                   |
      l{8:i}ne ^2                   |
      {1:~                        }|*3
    ]],
      attr_ids = {
        [1] = { bold = true, foreground = Screen.colors.Blue1 },
        [2] = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
        [3] = { bold = true },
        [4] = { bold = true, foreground = Screen.colors.SeaGreen4 },
        [5] = { foreground = Screen.colors.Blue1 },
        [6] = { bold = true, reverse = true },
        [7] = { reverse = true },
        [8] = { background = Screen.colors.Yellow },
      },
      messages = {
        {
          content = { { 'replace with X (y/n/a/q/l/^E/^Y)?', 4 } },
          kind = 'confirm_sub',
        },
      },
    }
    feed('nq')

    -- kind=wmsg (editing readonly file)
    command('write ' .. fname)
    command('set readonly nohls')
    feed('G$x')
    screen:expect {
      grid = [[
        line 1                   |
        {MATCH:.*}|
        {1:~                        }|*3
      ]],
      attr_ids = {
        [1] = { bold = true, foreground = Screen.colors.Blue1 },
        [7] = { foreground = Screen.colors.Red },
      },
      messages = {
        {
          content = { { 'W10: Warning: Changing a readonly file', 7 } },
          kind = 'wmsg',
        },
      },
    }

    -- kind=wmsg ('wrapscan' after search reaches EOF)
    feed('uG$/i<cr>')
    screen:expect {
      grid = [[
      l^ine 1                   |
      line 2                   |
      {1:~                        }|*3
    ]],
      attr_ids = {
        [1] = { bold = true, foreground = Screen.colors.Blue1 },
        [2] = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
        [3] = { bold = true },
        [4] = { bold = true, foreground = Screen.colors.SeaGreen4 },
        [5] = { foreground = Screen.colors.Blue1 },
        [6] = { bold = true, reverse = true },
        [7] = { foreground = Screen.colors.Red },
      },
      messages = {
        {
          content = { { 'search hit BOTTOM, continuing at TOP', 7 } },
          kind = 'wmsg',
        },
      },
    }

    -- kind=emsg after :throw
    feed(':throw "foo"<cr>')
    screen:expect {
      grid = [[
      l^ine 1                   |
      line 2                   |
      {1:~                        }|*3
    ]],
      messages = {
        {
          content = { { 'Error detected while processing :', 2 } },
          kind = 'emsg',
        },
        {
          content = { { 'E605: Exception not caught: foo', 2 } },
          kind = '',
        },
        {
          content = { { 'Press ENTER or type command to continue', 4 } },
          kind = 'return_prompt',
        },
      },
    }

    -- kind=quickfix after :cnext
    feed('<c-c>')
    command("caddexpr [expand('%').':1:line1',expand('%').':2:line2']")
    feed(':cnext<cr>')
    screen:expect {
      grid = [[
      line 1                   |
      ^line 2                   |
      {1:~                        }|*3
    ]],
      messages = {
        {
          content = { { '(2 of 2): line2' } },
          kind = 'quickfix',
        },
      },
    }
  end)

  it(':echoerr', function()
    feed(':echoerr "raa"<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      messages = { {
        content = { { 'raa', 2 } },
        kind = 'echoerr',
      } },
    }

    -- cmdline in a later input cycle clears error message
    feed(':')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      cmdline = { {
        firstc = ':',
        content = { { '' } },
        pos = 0,
      } },
    }

    feed('echoerr "bork" | echoerr "fail"<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      messages = {
        {
          content = { { 'bork', 2 } },
          kind = 'echoerr',
        },
        {
          content = { { 'fail', 2 } },
          kind = 'echoerr',
        },
        {
          content = { { 'Press ENTER or type command to continue', 4 } },
          kind = 'return_prompt',
        },
      },
    }

    feed(':echoerr "extrafail"<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      messages = {
        {
          content = { { 'bork', 2 } },
          kind = 'echoerr',
        },
        {
          content = { { 'fail', 2 } },
          kind = 'echoerr',
        },
        {
          content = { { 'extrafail', 2 } },
          kind = 'echoerr',
        },
        {
          content = { { 'Press ENTER or type command to continue', 4 } },
          kind = 'return_prompt',
        },
      },
    }

    feed('<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
    }

    -- cmdline without interleaving wait/display keeps the error message
    feed(':echoerr "problem" | let x = input("foo> ")<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      messages = { {
        content = { { 'problem', 2 } },
        kind = 'echoerr',
      } },
      cmdline = {
        {
          prompt = 'foo> ',
          content = { { '' } },
          pos = 0,
        },
      },
    }

    feed('solution<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
    }
    eq('solution', eval('x'))

    feed(':messages<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      msg_history = {
        { kind = 'echoerr', content = { { 'raa', 2 } } },
        { kind = 'echoerr', content = { { 'bork', 2 } } },
        { kind = 'echoerr', content = { { 'fail', 2 } } },
        { kind = 'echoerr', content = { { 'extrafail', 2 } } },
        { kind = 'echoerr', content = { { 'problem', 2 } } },
      },
      messages = {
        {
          content = { { 'Press ENTER or type command to continue', 4 } },
          kind = 'return_prompt',
        },
      },
    }

    feed '<cr>'
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
    }
  end)

  it(':echoerr multiline', function()
    exec_lua([[vim.g.multi = table.concat({ "bork", "fail" }, "\n")]])
    feed(':echoerr g:multi<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      messages = { {
        content = { { 'bork\nfail', 2 } },
        kind = 'echoerr',
      } },
    }

    feed(':messages<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      messages = {
        {
          content = { { 'Press ENTER or type command to continue', 4 } },
          kind = 'return_prompt',
        },
      },
      msg_history = {
        {
          content = { { 'bork\nfail', 2 } },
          kind = 'echoerr',
        },
      },
    }
  end)

  it('shortmess-=S', function()
    command('set shortmess-=S')
    feed('iline 1\nline 2<esc>')

    feed('/line<cr>')
    screen:expect {
      grid = [[
      {7:^line} 1                   |
      {7:line} 2                   |
      {1:~                        }|*3
    ]],
      messages = {
        { content = { { '/line      W [1/2]' } }, kind = 'search_count' },
      },
    }

    feed('n')
    screen:expect {
      grid = [[
      {7:line} 1                   |
      {7:^line} 2                   |
      {1:~                        }|*3
    ]],
      messages = {
        { content = { { '/line        [2/2]' } }, kind = 'search_count' },
      },
    }
  end)

  it(':hi Group output', function()
    feed(':hi ErrorMsg<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      messages = {
        {
          content = {
            { '\nErrorMsg      ' },
            { 'xxx', 2 },
            { ' ' },
            { 'ctermfg=', 5 },
            { '15 ' },
            { 'ctermbg=', 5 },
            { '1 ' },
            { 'guifg=', 5 },
            { 'White ' },
            { 'guibg=', 5 },
            { 'Red' },
          },
          kind = '',
        },
      },
    }
  end)

  it("doesn't crash with column adjustment #10069", function()
    feed(':let [x,y] = [1,2]<cr>')
    feed(':let x y<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      messages = {
        { content = { { 'x                     #1' } }, kind = '' },
        { content = { { 'y                     #2' } }, kind = '' },
        { content = { { 'Press ENTER or type command to continue', 4 } }, kind = 'return_prompt' },
      },
    }
  end)

  it('&showmode', function()
    command('imap <f2> <cmd>echomsg "stuff"<cr>')
    feed('i')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      showmode = { { '-- INSERT --', 3 } },
    }

    feed('alphpabet<cr>alphanum<cr>')
    screen:expect {
      grid = [[
      alphpabet                |
      alphanum                 |
      ^                         |
      {1:~                        }|*2
    ]],
      showmode = { { '-- INSERT --', 3 } },
    }

    feed('<c-x>')
    screen:expect {
      grid = [[
      alphpabet                |
      alphanum                 |
      ^                         |
      {1:~                        }|*2
    ]],
      showmode = { { '-- ^X mode (^]^D^E^F^I^K^L^N^O^Ps^U^V^Y)', 3 } },
    }

    feed('<c-p>')
    screen:expect {
      grid = [[
      alphpabet                |
      alphanum                 |
      alphanum^                 |
      {1:~                        }|*2
    ]],
      popupmenu = {
        anchor = { 1, 2, 0 },
        items = { { 'alphpabet', '', '', '' }, { 'alphanum', '', '', '' } },
        pos = 1,
      },
      showmode = { { '-- Keyword Local completion (^N^P) ', 3 }, { 'match 1 of 2', 4 } },
    }

    -- echomsg and showmode don't overwrite each other, this is the same
    -- as the TUI behavior with cmdheight=2 or larger.
    feed('<f2>')
    screen:expect {
      grid = [[
      alphpabet                |
      alphanum                 |
      alphanum^                 |
      {1:~                        }|*2
    ]],
      popupmenu = {
        anchor = { 1, 2, 0 },
        items = { { 'alphpabet', '', '', '' }, { 'alphanum', '', '', '' } },
        pos = 1,
      },
      messages = { {
        content = { { 'stuff' } },
        kind = 'echomsg',
      } },
      showmode = { { '-- Keyword Local completion (^N^P) ', 3 }, { 'match 1 of 2', 4 } },
    }

    feed('<c-p>')
    screen:expect {
      grid = [[
      alphpabet                |
      alphanum                 |
      alphpabet^                |
      {1:~                        }|*2
    ]],
      popupmenu = {
        anchor = { 1, 2, 0 },
        items = { { 'alphpabet', '', '', '' }, { 'alphanum', '', '', '' } },
        pos = 0,
      },
      messages = { {
        content = { { 'stuff' } },
        kind = 'echomsg',
      } },
      showmode = { { '-- Keyword Local completion (^N^P) ', 3 }, { 'match 2 of 2', 4 } },
    }

    feed('<esc>:messages<cr>')
    screen:expect {
      grid = [[
      alphpabet                |
      alphanum                 |
      alphpabe^t                |
      {1:~                        }|*2
    ]],
      msg_history = { {
        content = { { 'stuff' } },
        kind = 'echomsg',
      } },
      messages = {
        {
          content = { { 'Press ENTER or type command to continue', 4 } },
          kind = 'return_prompt',
        },
      },
    }
  end)

  it('&showmode with macro-recording message', function()
    feed('qq')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      showmode = { { 'recording @q', 3 } },
    }

    feed('i')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      showmode = { { '-- INSERT --recording @q', 3 } },
    }

    feed('<esc>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      showmode = { { 'recording @q', 3 } },
    }

    feed('q')
    screen:expect([[
      ^                         |
      {1:~                        }|*4
    ]])
  end)

  it('shows macro-recording message with &noshowmode', function()
    command('set noshowmode')
    feed('qq')
    -- also check mode to avoid immediate success
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      showmode = { { 'recording @q', 3 } },
      mode = 'normal',
    }

    feed('i')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      showmode = { { 'recording @q', 3 } },
      mode = 'insert',
    }

    feed('<esc>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      showmode = { { 'recording @q', 3 } },
      mode = 'normal',
    }

    feed('q')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      mode = 'normal',
    }
  end)

  it('supports &showcmd and &ruler', function()
    command('set showcmd ruler')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      ruler = { { '0,0-1   All' } },
    }
    feed('i')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      showmode = { { '-- INSERT --', 3 } },
      ruler = { { '0,1     All' } },
    }
    feed('abcde<cr>12345<esc>')
    screen:expect {
      grid = [[
      abcde                    |
      1234^5                    |
      {1:~                        }|*3
    ]],
      ruler = { { '2,5     All' } },
    }
    feed('d')
    screen:expect {
      grid = [[
      abcde                    |
      1234^5                    |
      {1:~                        }|*3
    ]],
      showcmd = { { 'd' } },
      ruler = { { '2,5     All' } },
    }
    feed('<esc>^')
    screen:expect {
      grid = [[
      abcde                    |
      ^12345                    |
      {1:~                        }|*3
    ]],
      ruler = { { '2,1     All' } },
    }
    feed('d')
    screen:expect {
      grid = [[
      abcde                    |
      ^12345                    |
      {1:~                        }|*3
    ]],
      showcmd = { { 'd' } },
      ruler = { { '2,1     All' } },
    }
    feed('i')
    screen:expect {
      grid = [[
      abcde                    |
      ^12345                    |
      {1:~                        }|*3
    ]],
      showcmd = { { 'di' } },
      ruler = { { '2,1     All' } },
    }
    feed('w')
    screen:expect {
      grid = [[
      abcde                    |
      ^                         |
      {1:~                        }|*3
    ]],
      ruler = { { '2,0-1   All' } },
    }

    -- when ruler is part of statusline it is not externalized.
    -- this will be added as part of future ext_statusline support
    command('set laststatus=2')
    screen:expect([[
      abcde                    |
      ^                         |
      {1:~                        }|*2
      {6:<o Name] [+] 2,0-1    All}|
    ]])
  end)

  it('keeps history of message of different kinds', function()
    feed(':echomsg "howdy"<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      messages = { {
        content = { { 'howdy' } },
        kind = 'echomsg',
      } },
    }

    -- always test a message without kind. If this one gets promoted to a
    -- category, add a new message without kind.
    feed('<c-c>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      messages = {
        {
          content = { { 'Type  :qa  and press <Enter> to exit Nvim' } },
          kind = '',
        },
      },
    }

    feed(':echoerr "bork"<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      messages = { {
        content = { { 'bork', 2 } },
        kind = 'echoerr',
      } },
    }

    feed(':echo "xyz"<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      messages = { {
        content = { { 'xyz' } },
        kind = 'echo',
      } },
    }

    feed(':call nosuchfunction()<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      messages = {
        {
          content = { { 'E117: Unknown function: nosuchfunction', 2 } },
          kind = 'emsg',
        },
      },
    }

    feed(':messages<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      msg_history = {
        { kind = 'echomsg', content = { { 'howdy' } } },
        { kind = '', content = { { 'Type  :qa  and press <Enter> to exit Nvim' } } },
        { kind = 'echoerr', content = { { 'bork', 2 } } },
        { kind = 'emsg', content = { { 'E117: Unknown function: nosuchfunction', 2 } } },
      },
      messages = {
        {
          content = { { 'Press ENTER or type command to continue', 4 } },
          kind = 'return_prompt',
        },
      },
    }
  end)

  it("implies ext_cmdline but allows changing 'cmdheight'", function()
    eq(0, eval('&cmdheight'))
    feed(':set cmdheight=1')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      cmdline = {
        {
          content = { { 'set cmdheight=1' } },
          firstc = ':',
          pos = 15,
        },
      },
    }

    feed('<cr>')
    screen:expect([[
      ^                         |
      {1:~                        }|*3
                               |
    ]])
    eq(1, eval('&cmdheight'))

    feed(':set cmdheight=0')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*3
                               |
    ]],
      cmdline = {
        {
          content = { { 'set cmdheight=0' } },
          firstc = ':',
          pos = 15,
        },
      },
    }
    feed('<cr>')
    screen:expect([[
      ^                         |
      {1:~                        }|*4
    ]])
    eq(0, eval('&cmdheight'))
  end)

  it('supports multiline messages from lua', function()
    feed(':lua error("such\\nmultiline\\nerror")<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      messages = {
        {
          content = {
            {
              [[E5108: Error executing lua [string ":lua"]:1: such
multiline
error
stack traceback:
	[C]: in function 'error'
	[string ":lua"]:1: in main chunk]],
              2,
            },
          },
          kind = 'lua_error',
        },
      },
    }
  end)

  it('supports multiline messages from rpc', function()
    feed(':call rpcrequest(1, "test_method")<cr>')

    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      messages = {
        {
          content = {
            { "Error invoking 'test_method' on channel 1:\ncomplete\nerror\n\nmessage", 2 },
          },
          kind = 'rpc_error',
        },
      },
      request_cb = function(name)
        if name == 'test_method' then
          set_method_error('complete\nerror\n\nmessage')
        end
      end,
    }
  end)

  it('supports multiline messages for :map', function()
    command('mapclear')
    command('nmap Y y$')
    command('nmap Q @@')
    command('nnoremap j k')
    feed(':map<cr>')

    screen:expect {
      messages = {
        {
          content = {
            { '\nn  Q             @@\nn  Y             y$\nn  j           ' },
            { '*', 5 },
            { ' k' },
          },
          kind = '',
        },
      },
    }
  end)

  it('wildmode=list', function()
    screen:try_resize(25, 7)
    screen:set_option('ext_popupmenu', false)

    command('set wildmenu wildmode=list')
    feed(':set wildm<tab>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*6
    ]],
      messages = { {
        content = { { 'wildmenu  wildmode' } },
        kind = '',
      } },
      cmdline = {
        {
          firstc = ':',
          content = { { 'set wildm' } },
          pos = 9,
        },
      },
    }
  end)

  it('hides prompt_for_number messages', function()
    command('set spell')
    feed('ihelllo<esc>')

    feed('z=')
    screen:expect {
      grid = [[
      {9:helllo}                   |
      {1:~                        }|*3
      {1:^~                        }|
    ]],
      messages = {
        {
          content = {
            {
              'Change "helllo" to:\n 1 "Hello"\n 2 "Hallo"\n 3 "Hullo"\nType number and <Enter> or click with the mouse (q or empty cancels): ',
            },
          },
          kind = '',
        },
      },
    }

    feed('1')
    screen:expect {
      grid = [[
      {9:helllo}                   |
      {1:~                        }|*3
      {1:^~                        }|
    ]],
      messages = {
        {
          content = {
            {
              'Change "helllo" to:\n 1 "Hello"\n 2 "Hallo"\n 3 "Hullo"\nType number and <Enter> or click with the mouse (q or empty cancels): ',
            },
          },
          kind = '',
        },
        { content = { { '1' } }, kind = '' },
      },
    }

    feed('<cr>')
    screen:expect {
      grid = [[
      ^Hello                    |
      {1:~                        }|*4
    ]],
    }
  end)

  it('supports nvim_echo messages with multiple attrs', function()
    async_meths.nvim_echo(
      { { 'wow, ', 'Search' }, { 'such\n\nvery ', 'ErrorMsg' }, { 'color', 'LineNr' } },
      true,
      {}
    )
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      messages = {
        { content = { { 'wow, ', 7 }, { 'such\n\nvery ', 2 }, { 'color', 10 } }, kind = 'echomsg' },
      },
    }

    feed ':ls<cr>'
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      messages = {
        { content = { { '\n  1 %a   "[No Name]"                    line 1' } }, kind = '' },
      },
    }

    feed ':messages<cr>'
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      messages = {
        { content = { { 'Press ENTER or type command to continue', 4 } }, kind = 'return_prompt' },
      },
      msg_history = {
        { content = { { 'wow, ', 7 }, { 'such\n\nvery ', 2 }, { 'color', 10 } }, kind = 'echomsg' },
      },
    }

    feed '<cr>'
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
    }
  end)

  it('does not truncate messages', function()
    command('write ' .. fname)
    screen:expect({
      messages = {
        { content = { { string.format('"%s" [New] 0L, 0B written', fname) } }, kind = '' },
      },
    })
  end)
end)

describe('ui/builtin messages', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(60, 7)
    screen:attach({ rgb = true, ext_popupmenu = true })
    screen:set_default_attr_ids {
      [1] = { bold = true, foreground = Screen.colors.Blue1 },
      [2] = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
      [3] = { bold = true, reverse = true },
      [4] = { bold = true, foreground = Screen.colors.SeaGreen4 },
      [5] = { foreground = Screen.colors.Blue1 },
      [6] = { bold = true, foreground = Screen.colors.Magenta },
      [7] = { background = Screen.colors.Grey20 },
      [8] = { reverse = true },
      [9] = { background = Screen.colors.LightRed },
      [10] = { background = Screen.colors.Yellow },
      [11] = { foreground = Screen.colors.Brown },
    }
  end)

  it('supports multiline messages from rpc', function()
    feed(':call rpcrequest(1, "test_method")<cr>')

    screen:expect {
      grid = [[
      {3:                                                            }|
      {2:Error invoking 'test_method' on channel 1:}                  |
      {2:complete}                                                    |
      {2:error}                                                       |
                                                                  |
      {2:message}                                                     |
      {4:Press ENTER or type command to continue}^                     |
    ]],
      request_cb = function(name)
        if name == 'test_method' then
          set_method_error('complete\nerror\n\nmessage')
        end
      end,
    }
  end)

  it(':hi Group output', function()
    screen:try_resize(70, 7)
    feed(':hi ErrorMsg<cr>')
    screen:expect([[
                                                                            |
      {1:~                                                                     }|*2
      {3:                                                                      }|
      :hi ErrorMsg                                                          |
      ErrorMsg       {2:xxx} {5:ctermfg=}15 {5:ctermbg=}1 {5:guifg=}White {5:guibg=}Red         |
      {4:Press ENTER or type command to continue}^                               |
    ]])

    feed('<cr>')
    screen:try_resize(30, 7)
    feed(':hi ErrorMsg<cr>')
    screen:expect([[
      :hi ErrorMsg                  |
      ErrorMsg       {2:xxx} {5:ctermfg=}15 |
                         {5:ctermbg=}1  |
                         {5:guifg=}White|
                         {5:guibg=}Red  |
      {4:Press ENTER or type command to}|
      {4: continue}^                     |
    ]])
    feed('<cr>')

    -- screen size doesn't affect internal output #10285
    eq('ErrorMsg       xxx ctermfg=15 ctermbg=1 guifg=White guibg=Red', exec_capture('hi ErrorMsg'))
  end)

  it(':syntax list langGroup output', function()
    command('syntax on')
    command('set syntax=vim')
    screen:try_resize(110, 7)
    feed(':syntax list vimComment<cr>')
    screen:expect([[
      {6:--- Syntax items ---}                                                                                          |
      vimComment     {5:xxx} {5:match} /\s"[^\-:.%#=*].*$/ms=s+1,lc=1  {5:excludenl} {5:contains}=@vimCommentGroup,vimCommentString |
                                                                                                                    |
                         {5:match} /\<endif\s\+".*$/ms=s+5,lc=5  {5:contains}=@vimCommentGroup,vimCommentString             |
                         {5:match} /\<else\s\+".*$/ms=s+4,lc=4  {5:contains}=@vimCommentGroup,vimCommentString              |
                         {5:links to} Comment                                                                           |
      {4:Press ENTER or type command to continue}^                                                                       |
    ]])

    feed('<cr>')
    screen:try_resize(55, 7)
    feed(':syntax list vimComment<cr>')
    screen:expect([[
                                                             |
                         {5:match} /\<endif\s\+".*$/ms=s+5,lc=5  |
      {5:contains}=@vimCommentGroup,vimCommentString             |
                         {5:match} /\<else\s\+".*$/ms=s+4,lc=4  {5:c}|
      {5:ontains}=@vimCommentGroup,vimCommentString              |
                         {5:links to} Comment                    |
      {4:Press ENTER or type command to continue}^                |
    ]])
    feed('<cr>')

    -- ignore final whitespace inside string
    -- luacheck: push ignore
    eq(
      [[--- Syntax items ---
vimComment     xxx match /\s"[^\-:.%#=*].*$/ms=s+1,lc=1  excludenl contains=@vimCommentGroup,vimCommentString 
                   match /\<endif\s\+".*$/ms=s+5,lc=5  contains=@vimCommentGroup,vimCommentString 
                   match /\<else\s\+".*$/ms=s+4,lc=4  contains=@vimCommentGroup,vimCommentString 
                   links to Comment]],
      exec_capture('syntax list vimComment')
    )
    -- luacheck: pop
  end)

  it('no empty line after :silent #12099', function()
    exec([[
      func T1()
        silent !echo
        echo "message T1"
      endfunc
      func T2()
        silent lua print("lua message")
        echo "message T2"
      endfunc
      func T3()
        silent call nvim_out_write("api message\n")
        echo "message T3"
      endfunc
    ]])
    feed(':call T1()<CR>')
    screen:expect {
      grid = [[
      ^                                                            |
      {1:~                                                           }|*5
      message T1                                                  |
    ]],
    }
    feed(':call T2()<CR>')
    screen:expect {
      grid = [[
      ^                                                            |
      {1:~                                                           }|*5
      message T2                                                  |
    ]],
    }
    feed(':call T3()<CR>')
    screen:expect {
      grid = [[
      ^                                                            |
      {1:~                                                           }|*5
      message T3                                                  |
    ]],
    }
  end)

  it('supports ruler with laststatus=0', function()
    command('set ruler laststatus=0')
    screen:expect {
      grid = [[
      ^                                                            |
      {1:~                                                           }|*5
                                                0,0-1         All |
    ]],
    }

    command('hi MsgArea guibg=#333333')
    screen:expect {
      grid = [[
      ^                                                            |
      {1:~                                                           }|*5
      {7:                                          0,0-1         All }|
    ]],
    }

    command('set rulerformat=%15(%c%V\\ %p%%%)')
    screen:expect {
      grid = [[
      ^                                                            |
      {1:~                                                           }|*5
      {7:                                          0,0-1 100%        }|
    ]],
    }
  end)

  it('supports echo with CRLF line separators', function()
    feed(':echo "line 1\\r\\nline 2"<cr>')
    screen:expect {
      grid = [[
                                                                  |
      {1:~                                                           }|*2
      {3:                                                            }|
      line 1                                                      |
      line 2                                                      |
      {4:Press ENTER or type command to continue}^                     |
    ]],
    }

    feed('<cr>:echo "abc\\rz"<cr>')
    screen:expect {
      grid = [[
      ^                                                            |
      {1:~                                                           }|*5
      zbc                                                         |
    ]],
    }
  end)

  it('redraws UPD_NOT_VALID correctly after message', function()
    -- edge case: only one window was set UPD_NOT_VALID. Original report
    -- used :make, but fake it using one command to set the current
    -- window UPD_NOT_VALID and another to show a long message.
    command('set more')
    feed(':new<cr><c-w><c-w>')
    screen:expect {
      grid = [[
                                                                  |
      {1:~                                                           }|
      {8:[No Name]                                                   }|
      ^                                                            |
      {1:~                                                           }|
      {3:[No Name]                                                   }|
      :new                                                        |
    ]],
    }

    feed(':set colorcolumn=10 | digraphs<cr>')
    screen:expect {
      grid = [[
      :set colorcolumn=10 | digraphs                              |
      NU {5:^@}  10    SH {5:^A}   1    SX {5:^B}   2    EX {5:^C}   3            |
      ET {5:^D}   4    EQ {5:^E}   5    AK {5:^F}   6    BL {5:^G}   7            |
      BS {5:^H}   8    HT {5:^I}   9    LF {5:^@}  10    VT {5:^K}  11            |
      FF {5:^L}  12    CR {5:^M}  13    SO {5:^N}  14    SI {5:^O}  15            |
      DL {5:^P}  16    D1 {5:^Q}  17    D2 {5:^R}  18    D3 {5:^S}  19            |
      {4:-- More --}^                                                  |
    ]],
    }

    feed('q')
    screen:expect {
      grid = [[
                                                                  |
      {1:~                                                           }|
      {8:[No Name]                                                   }|
      ^         {9: }                                                  |
      {1:~                                                           }|
      {3:[No Name]                                                   }|
                                                                  |
    ]],
    }

    -- edge case: just covers statusline
    feed(':set colorcolumn=5 | lua error("x\\n\\nx")<cr>')
    screen:expect {
      grid = [[
      {2:E5108: Error executing lua [string ":lua"]:1: x}             |
                                                                  |
      {2:x}                                                           |
      {2:stack traceback:}                                            |
      {2:        [C]: in function 'error'}                            |
      {2:        [string ":lua"]:1: in main chunk}                    |
      {4:Press ENTER or type command to continue}^                     |
    ]],
    }

    feed('<cr>')
    screen:expect {
      grid = [[
                                                                  |
      {1:~                                                           }|
      {8:[No Name]                                                   }|
      ^    {9: }                                                       |
      {1:~                                                           }|
      {3:[No Name]                                                   }|
                                                                  |
    ]],
    }

    -- edge case: just covers lowest window line
    feed(':set colorcolumn=5 | lua error("x\\n\\n\\nx")<cr>')
    screen:expect {
      grid = [[
      {2:E5108: Error executing lua [string ":lua"]:1: x}             |
                                                                  |*2
      {2:x}                                                           |
      {2:stack traceback:}                                            |
      {2:        [C]: in function 'error'}                            |
      {4:-- More --}^                                                  |
    ]],
    }

    feed('<cr>')
    screen:expect {
      grid = [[
                                                                  |*2
      {2:x}                                                           |
      {2:stack traceback:}                                            |
      {2:        [C]: in function 'error'}                            |
      {2:        [string ":lua"]:1: in main chunk}                    |
      {4:Press ENTER or type command to continue}^                     |
    ]],
    }
  end)

  it('supports nvim_echo messages with multiple attrs', function()
    async_meths.nvim_echo(
      { { 'wow, ', 'Search' }, { 'such\n\nvery ', 'ErrorMsg' }, { 'color', 'LineNr' } },
      true,
      {}
    )
    screen:expect {
      grid = [[
                                                                  |
      {1:~                                                           }|
      {3:                                                            }|
      {10:wow, }{2:such}                                                   |
                                                                  |
      {2:very }{11:color}                                                  |
      {4:Press ENTER or type command to continue}^                     |
    ]],
    }

    feed '<cr>'
    screen:expect {
      grid = [[
      ^                                                            |
      {1:~                                                           }|*5
                                                                  |
    ]],
    }

    feed ':messages<cr>'
    screen:expect {
      grid = [[
                                                                  |
      {1:~                                                           }|
      {3:                                                            }|
      {10:wow, }{2:such}                                                   |
                                                                  |
      {2:very }{11:color}                                                  |
      {4:Press ENTER or type command to continue}^                     |
    ]],
    }
  end)

  it('prints lines in Ex mode correctly with a burst of carriage returns #19341', function()
    command('set number')
    api.nvim_buf_set_lines(0, 0, 0, true, { 'aaa', 'bbb', 'ccc' })
    feed('gggQ<CR><CR>1<CR><CR>vi')
    screen:expect([[
      Entering Ex mode.  Type "visual" to go to Normal mode.      |
      {11:  2 }bbb                                                     |
      {11:  3 }ccc                                                     |
      :1                                                          |
      {11:  1 }aaa                                                     |
      {11:  2 }bbb                                                     |
      :vi^                                                         |
    ]])
    feed('<CR>')
    screen:expect([[
      {11:  1 }aaa                                                     |
      {11:  2 }^bbb                                                     |
      {11:  3 }ccc                                                     |
      {11:  4 }                                                        |
      {1:~                                                           }|*2
                                                                  |
    ]])
  end)

  describe('echo messages are shown when immediately followed by', function()
    --- @param to_block  string           command to cause a blocking wait
    --- @param to_unblock  number|string  number: timeout for blocking screen
    ---                                   string: keys to stop the blocking wait
    local function test_flush_before_block(to_block, to_unblock)
      local timeout = type(to_unblock) == 'number' and to_unblock or nil
      exec(([[
        func PrintAndWait()
          echon "aaa\nbbb"
          %s
          echon "\nccc"
        endfunc
      ]]):format(to_block))
      feed(':call PrintAndWait()<CR>')
      screen:expect {
        grid = [[
                                                                    |
        {1:~                                                           }|*3
        {3:                                                            }|
        aaa                                                         |
        bbb^                                                         |
      ]],
        timeout = timeout,
      }
      if type(to_unblock) == 'string' then
        feed(to_unblock)
      end
      screen:expect {
        grid = [[
                                                                    |
        {1:~                                                           }|
        {3:                                                            }|
        aaa                                                         |
        bbb                                                         |
        ccc                                                         |
        {4:Press ENTER or type command to continue}^                     |
      ]],
      }
    end

    it('getchar()', function()
      test_flush_before_block([[call getchar()]], 'k')
    end)

    it('wait()', function()
      test_flush_before_block([[call wait(300, '0')]], 100)
    end)

    it('lua vim.wait()', function()
      test_flush_before_block([[lua vim.wait(300, function() end)]], 100)
    end)
  end)

  it('consecutive calls to win_move_statusline() work after multiline message #21014', function()
    async_meths.nvim_exec(
      [[
      echo "\n"
      call win_move_statusline(0, -4)
      call win_move_statusline(0, 4)
    ]],
      false
    )
    screen:expect([[
                                                                  |
      {1:~                                                           }|*3
      {3:                                                            }|
                                                                  |
      {4:Press ENTER or type command to continue}^                     |
    ]])
    feed('<CR>')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*5
                                                                  |
    ]])
    eq(1, api.nvim_get_option_value('cmdheight', {}))
  end)

  it('using nvim_echo in VimResized does not cause hit-enter prompt #26139', function()
    command([[au VimResized * lua vim.api.nvim_echo({ { '123456' } }, true, {})]])
    screen:try_resize(60, 5)
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*3
                                                                  |
    ]])
    eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
  end)

  it('bottom of screen is cleared after increasing &cmdheight #20360', function()
    command('set laststatus=2')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*4
      {3:[No Name]                                                   }|
                                                                  |
    ]])
    command('set cmdheight=4')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|
      {3:[No Name]                                                   }|
                                                                  |*4
    ]])
  end)
end)

it('calling screenstring() after redrawing between messages without UI #20999', function()
  clear()
  exec([[
    echo repeat('a', 100)
    redraw
    echo "\n"
    call screenstring(1, 1)
  ]])
  assert_alive()
end)

describe('ui/ext_messages', function()
  local screen

  before_each(function()
    clear { args_rm = { '--headless' }, args = { '--cmd', 'set shortmess-=I' } }
    screen = Screen.new(80, 24)
    screen:attach({ rgb = true, ext_messages = true, ext_popupmenu = true })
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue1 },
      [2] = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
      [3] = { bold = true },
      [4] = { bold = true, foreground = Screen.colors.SeaGreen4 },
      [5] = { foreground = Screen.colors.Blue1 },
      [6] = { reverse = true },
      [7] = { bold = true, reverse = true },
    })
  end)

  it('supports intro screen', function()
    -- intro message is not externalized. But check that it still works.
    -- Note parts of it depends on version or is indeterministic. We ignore those parts.
    screen:expect([[
      ^                                                                                |
      {1:~                                                                               }|*4
      {MATCH:.*}|
      {1:~                                                                               }|
      {1:~                 }Nvim is open source and freely distributable{1:                  }|
      {1:~                           }https://neovim.io/#chat{1:                             }|
      {1:~                                                                               }|
      {1:~                }type  :help nvim{5:<Enter>}       if you are new! {1:                 }|
      {1:~                }type  :checkhealth{5:<Enter>}     to optimize Nvim{1:                 }|
      {1:~                }type  :q{5:<Enter>}               to exit         {1:                 }|
      {1:~                }type  :help{5:<Enter>}            for help        {1:                 }|
      {1:~                                                                               }|
      {1:~{MATCH: +}}type  :help news{5:<Enter>} to see changes in v{MATCH:%d+%.%d+}{1:{MATCH: +}}|
      {1:~                                                                               }|
      {1:~                        }Help poor children in Uganda!{1:                          }|
      {1:~                }type  :help iccf{5:<Enter>}       for information {1:                 }|
      {1:~                                                                               }|*5
    ]])

    -- <c-l> (same as :mode) does _not_ clear intro message
    feed('<c-l>i')
    screen:expect {
      grid = [[
      ^                                                                                |
      {1:~                                                                               }|*4
      {MATCH:.*}|
      {1:~                                                                               }|
      {1:~                 }Nvim is open source and freely distributable{1:                  }|
      {1:~                           }https://neovim.io/#chat{1:                             }|
      {1:~                                                                               }|
      {1:~                }type  :help nvim{5:<Enter>}       if you are new! {1:                 }|
      {1:~                }type  :checkhealth{5:<Enter>}     to optimize Nvim{1:                 }|
      {1:~                }type  :q{5:<Enter>}               to exit         {1:                 }|
      {1:~                }type  :help{5:<Enter>}            for help        {1:                 }|
      {1:~                                                                               }|
      {1:~{MATCH: +}}type  :help news{5:<Enter>} to see changes in v{MATCH:%d+%.%d+}{1:{MATCH: +}}|
      {1:~                                                                               }|
      {1:~                        }Help poor children in Uganda!{1:                          }|
      {1:~                }type  :help iccf{5:<Enter>}       for information {1:                 }|
      {1:~                                                                               }|*5
    ]],
      showmode = { { '-- INSERT --', 3 } },
    }

    -- but editing text does..
    feed('x')
    screen:expect {
      grid = [[
      x^                                                                               |
      {1:~                                                                               }|*23
    ]],
      showmode = { { '-- INSERT --', 3 } },
    }

    feed('<esc>:intro<cr>')
    screen:expect {
      grid = [[
      ^                                                                                |
                                                                                      |*4
      {MATCH:.*}|
                                                                                      |
                        Nvim is open source and freely distributable                  |
                                  https://neovim.io/#chat                             |
                                                                                      |
                       type  :help nvim{5:<Enter>}       if you are new!                  |
                       type  :checkhealth{5:<Enter>}     to optimize Nvim                 |
                       type  :q{5:<Enter>}               to exit                          |
                       type  :help{5:<Enter>}            for help                         |
                                                                                      |
      {MATCH: +}type  :help news{5:<Enter>} to see changes in v{MATCH:%d+%.%d+ +}|
                                                                                      |
                               Help poor children in Uganda!                          |
                       type  :help iccf{5:<Enter>}       for information                  |
                                                                                      |*5
    ]],
      messages = {
        { content = { { 'Press ENTER or type command to continue', 4 } }, kind = 'return_prompt' },
      },
    }

    feed('<cr>')
    screen:expect {
      grid = [[
      ^x                                                                               |
      {1:~                                                                               }|*23
    ]],
    }
  end)

  it('supports global statusline', function()
    feed(':set laststatus=3<cr>')
    feed(':sp<cr>')
    feed(':set cmdheight<cr>')
    screen:expect({
      grid = [[
      ^                                                                                |
      {1:~                                                                               }|*10
      ────────────────────────────────────────────────────────────────────────────────|
                                                                                      |
      {1:~                                                                               }|*10
      {7:[No Name]                                                                       }|
    ]],
      messages = {
        { content = { { '  cmdheight=0' } }, kind = '' },
      },
    })

    feed('<c-w>+')
    feed(':set laststatus<cr>')
    screen:expect({
      grid = [[
      ^                                                                                |
      {1:~                                                                               }|*11
      ────────────────────────────────────────────────────────────────────────────────|
                                                                                      |
      {1:~                                                                               }|*9
      {7:[No Name]                                                                       }|
    ]],
      messages = {
        { content = { { '  laststatus=3' } }, kind = '' },
      },
    })

    feed(':set mouse=a<cr>')
    api.nvim_input_mouse('left', 'press', '', 0, 12, 10)
    poke_eventloop()
    api.nvim_input_mouse('left', 'drag', '', 0, 11, 10)
    feed('<c-l>')
    feed(':set cmdheight<cr>')
    screen:expect({
      grid = [[
      ^                                                                                |
      {1:~                                                                               }|*10
      ────────────────────────────────────────────────────────────────────────────────|
                                                                                      |
      {1:~                                                                               }|*10
      {7:[No Name]                                                                       }|
    ]],
      messages = {
        { content = { { '  cmdheight=0' } }, kind = '' },
      },
    })
  end)
end)

it('ui/ext_multigrid supports intro screen', function()
  clear { args_rm = { '--headless' }, args = { '--cmd', 'set shortmess-=I' } }
  local screen = Screen.new(80, 24)
  screen:attach({ rgb = true, ext_multigrid = true })
  screen:set_default_attr_ids {
    [1] = { bold = true, foreground = Screen.colors.Blue1 },
    [2] = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
    [3] = { bold = true },
    [4] = { bold = true, foreground = Screen.colors.SeaGreen4 },
    [5] = { foreground = Screen.colors.Blue1 },
  }

  screen:expect {
    grid = [[
    ## grid 1
      [2:--------------------------------------------------------------------------------]|*23
      [3:--------------------------------------------------------------------------------]|
    ## grid 2
      ^                                                                                |
      {1:~                                                                               }|*4
      {MATCH:.*}|
      {1:~                                                                               }|
      {1:~                 }Nvim is open source and freely distributable{1:                  }|
      {1:~                           }https://neovim.io/#chat{1:                             }|
      {1:~                                                                               }|
      {1:~                }type  :help nvim{5:<Enter>}       if you are new! {1:                 }|
      {1:~                }type  :checkhealth{5:<Enter>}     to optimize Nvim{1:                 }|
      {1:~                }type  :q{5:<Enter>}               to exit         {1:                 }|
      {1:~                }type  :help{5:<Enter>}            for help        {1:                 }|
      {1:~                                                                               }|
      {1:~{MATCH: +}}type  :help news{5:<Enter>} to see changes in v{MATCH:%d+%.%d+}{1:{MATCH: +}}|
      {1:~                                                                               }|
      {1:~                        }Help poor children in Uganda!{1:                          }|
      {1:~                }type  :help iccf{5:<Enter>}       for information {1:                 }|
      {1:~                                                                               }|*4
    ## grid 3
                                                                                      |
    ]],
    win_viewport = {
      [2] = {
        win = 1000,
        topline = 0,
        botline = 2,
        curline = 0,
        curcol = 0,
        linecount = 1,
        sum_scroll_delta = 0,
      },
    },
  }

  feed 'ix'
  screen:expect {
    grid = [[
    ## grid 1
      [2:--------------------------------------------------------------------------------]|*23
      [3:--------------------------------------------------------------------------------]|
    ## grid 2
      x^                                                                               |
      {1:~                                                                               }|*22
    ## grid 3
      {3:-- INSERT --}                                                                    |
    ]],
    win_viewport = {
      [2] = {
        win = 1000,
        topline = 0,
        botline = 2,
        curline = 0,
        curcol = 1,
        linecount = 1,
        sum_scroll_delta = 0,
      },
    },
  }
end)

describe('ui/msg_puts_printf', function()
  it('output multibyte characters correctly', function()
    local screen
    local cmd = ''
    local locale_dir = test_build_dir .. '/share/locale/ja/LC_MESSAGES'

    clear({ env = { LANG = 'ja_JP.UTF-8' } })
    screen = Screen.new(25, 5)
    screen:attach()

    if is_os('win') then
      if os.execute('chcp 932 > NUL 2>&1') ~= 0 then
        pending('missing japanese language features', function() end)
        return
      else
        cmd = 'chcp 932 > NULL & '
      end
    else
      if exc_exec('lang ja_JP.UTF-8') ~= 0 then
        pending('Locale ja_JP.UTF-8 not supported', function() end)
        return
      elseif is_ci() then
        -- Fails non--Windows CI. Message catalog directory issue?
        pending('fails on unix CI', function() end)
        return
      end
    end

    os.execute('cmake -E make_directory ' .. locale_dir)
    os.execute(
      'cmake -E copy ' .. test_build_dir .. '/src/nvim/po/ja.mo ' .. locale_dir .. '/nvim.mo'
    )

    cmd = cmd .. '"' .. nvim_prog .. '" -u NONE -i NONE -Es -V1'
    command([[call termopen(']] .. cmd .. [[')]])
    screen:expect([[
    ^Exモードに入ります。ノー |
    マルモードに戻るには "vis|
    ual" と入力してください。|
    :                        |
                             |
    ]])

    os.execute('cmake -E remove_directory ' .. test_build_dir .. '/share')
  end)
end)

describe('pager', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(35, 8)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue1 },
      [2] = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
      [3] = {
        foreground = Screen.colors.Grey100,
        background = Screen.colors.Red,
        special = Screen.colors.Yellow,
      },
      [4] = { bold = true, foreground = Screen.colors.SeaGreen4 },
      [5] = { special = Screen.colors.Yellow },
      [6] = { special = Screen.colors.Yellow, bold = true, foreground = Screen.colors.SeaGreen4 },
      [7] = { foreground = Screen.colors.Grey0, background = Screen.colors.Grey100 },
      [8] = { foreground = Screen.colors.Gray90, background = Screen.colors.Grey100 },
      [9] = { foreground = tonumber('0x00000c'), background = Screen.colors.Grey100 },
      [10] = { background = Screen.colors.Grey100, bold = true, foreground = tonumber('0xe5e5ff') },
      [11] = { background = Screen.colors.Grey100, bold = true, foreground = tonumber('0x2b8452') },
      [12] = { bold = true, reverse = true },
    })
    command('set more')

    exec_lua(
      '_G.x = ...',
      [[
Lorem ipsum dolor sit amet, consectetur
adipisicing elit, sed do eiusmod tempor
incididunt ut labore et dolore magna aliqua.
Ut enim ad minim veniam, quis nostrud xercitation
ullamco laboris nisi ut
aliquip ex ea commodo consequat.]]
    )
  end)

  it('can be quit with echon', function()
    screen:try_resize(25, 5)
    feed(':echon join(map(range(0, &lines*10), "v:val"), "\\n")<cr>')
    screen:expect {
      grid = [[
      0                        |
      1                        |
      2                        |
      3                        |
      {4:-- More --}^               |
    ]],
    }
    feed('q')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*3
                               |
    ]],
    }
  end)

  it('can be quit with Lua #11224 #16537', function()
    -- NOTE: adds "4" to message history, although not displayed initially
    --       (triggered the more prompt).
    screen:try_resize(40, 5)
    feed(':lua for i=0,10 do print(i) end<cr>')
    screen:expect {
      grid = [[
      0                                       |
      1                                       |
      2                                       |
      3                                       |
      {4:-- More --}^                              |
    ]],
    }
    feed('q')
    screen:expect {
      grid = [[
      ^                                        |
      {1:~                                       }|*3
                                              |
    ]],
    }
    feed(':mess<cr>')
    screen:expect {
      grid = [[
      0                                       |
      1                                       |
      2                                       |
      3                                       |
      {4:-- More --}^                              |
    ]],
    }
    feed('j')
    screen:expect {
      grid = [[
      1                                       |
      2                                       |
      3                                       |
      4                                       |
      {4:Press ENTER or type command to continue}^ |
    ]],
    }
    feed('<cr>')
  end)

  it('handles wrapped lines with line scroll', function()
    feed(':lua error(_G.x)<cr>')
    screen:expect {
      grid = [[
      {2:E5108: Error executing lua [string }|
      {2:":lua"]:1: Lorem ipsum dolor sit am}|
      {2:et, consectetur}                    |
      {2:adipisicing elit, sed do eiusmod te}|
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {4:-- More --}^                         |
    ]],
    }

    feed('j')
    screen:expect {
      grid = [[
      {2:":lua"]:1: Lorem ipsum dolor sit am}|
      {2:et, consectetur}                    |
      {2:adipisicing elit, sed do eiusmod te}|
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {2:Ut enim ad minim veniam, quis nostr}|
      {4:-- More --}^                         |
    ]],
    }

    feed('k')
    screen:expect {
      grid = [[
      {2:E5108: Error executing lua [string }|
      {2:":lua"]:1: Lorem ipsum dolor sit am}|
      {2:et, consectetur}                    |
      {2:adipisicing elit, sed do eiusmod te}|
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {4:-- More --}^                         |
    ]],
    }

    feed('j')
    screen:expect {
      grid = [[
      {2:":lua"]:1: Lorem ipsum dolor sit am}|
      {2:et, consectetur}                    |
      {2:adipisicing elit, sed do eiusmod te}|
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {2:Ut enim ad minim veniam, quis nostr}|
      {4:-- More --}^                         |
    ]],
    }
  end)

  it('handles wrapped lines with page scroll', function()
    feed(':lua error(_G.x)<cr>')
    screen:expect {
      grid = [[
      {2:E5108: Error executing lua [string }|
      {2:":lua"]:1: Lorem ipsum dolor sit am}|
      {2:et, consectetur}                    |
      {2:adipisicing elit, sed do eiusmod te}|
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {4:-- More --}^                         |
    ]],
    }
    feed('d')
    screen:expect {
      grid = [[
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {2:Ut enim ad minim veniam, quis nostr}|
      {2:ud xercitation}                     |
      {2:ullamco laboris nisi ut}            |
      {2:aliquip ex ea commodo consequat.}   |
      {4:-- More --}^                         |
    ]],
    }
    feed('u')
    screen:expect {
      grid = [[
      {2:E5108: Error executing lua [string }|
      {2:":lua"]:1: Lorem ipsum dolor sit am}|
      {2:et, consectetur}                    |
      {2:adipisicing elit, sed do eiusmod te}|
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {4:-- More --}^                         |
    ]],
    }
    feed('d')
    screen:expect {
      grid = [[
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {2:Ut enim ad minim veniam, quis nostr}|
      {2:ud xercitation}                     |
      {2:ullamco laboris nisi ut}            |
      {2:aliquip ex ea commodo consequat.}   |
      {4:-- More --}^                         |
    ]],
    }
  end)

  it('handles wrapped lines with line scroll and MsgArea highlight', function()
    command('hi MsgArea guisp=Yellow')

    feed(':lua error(_G.x)<cr>')
    screen:expect {
      grid = [[
      {3:E5108: Error executing lua [string }|
      {3:":lua"]:1: Lorem ipsum dolor sit am}|
      {3:et, consectetur}{5:                    }|
      {3:adipisicing elit, sed do eiusmod te}|
      {3:mpor}{5:                               }|
      {3:incididunt ut labore et dolore magn}|
      {3:a aliqua.}{5:                          }|
      {6:-- More --}{5:^                         }|
    ]],
    }

    feed('j')
    screen:expect {
      grid = [[
      {3:":lua"]:1: Lorem ipsum dolor sit am}|
      {3:et, consectetur}{5:                    }|
      {3:adipisicing elit, sed do eiusmod te}|
      {3:mpor}{5:                               }|
      {3:incididunt ut labore et dolore magn}|
      {3:a aliqua.}{5:                          }|
      {3:Ut enim ad minim veniam, quis nostr}|
      {6:-- More --}{5:^                         }|
    ]],
    }

    feed('k')
    screen:expect {
      grid = [[
      {3:E5108: Error executing lua [string }|
      {3:":lua"]:1: Lorem ipsum dolor sit am}|
      {3:et, consectetur}{5:                    }|
      {3:adipisicing elit, sed do eiusmod te}|
      {3:mpor}{5:                               }|
      {3:incididunt ut labore et dolore magn}|
      {3:a aliqua.}{5:                          }|
      {6:-- More --}{5:^                         }|
    ]],
    }

    feed('j')
    screen:expect {
      grid = [[
      {3:":lua"]:1: Lorem ipsum dolor sit am}|
      {3:et, consectetur}{5:                    }|
      {3:adipisicing elit, sed do eiusmod te}|
      {3:mpor}{5:                               }|
      {3:incididunt ut labore et dolore magn}|
      {3:a aliqua.}{5:                          }|
      {3:Ut enim ad minim veniam, quis nostr}|
      {6:-- More --}{5:^                         }|
    ]],
    }
  end)

  it('handles wrapped lines with page scroll and MsgArea highlight', function()
    command('hi MsgArea guisp=Yellow')
    feed(':lua error(_G.x)<cr>')
    screen:expect {
      grid = [[
      {3:E5108: Error executing lua [string }|
      {3:":lua"]:1: Lorem ipsum dolor sit am}|
      {3:et, consectetur}{5:                    }|
      {3:adipisicing elit, sed do eiusmod te}|
      {3:mpor}{5:                               }|
      {3:incididunt ut labore et dolore magn}|
      {3:a aliqua.}{5:                          }|
      {6:-- More --}{5:^                         }|
    ]],
    }
    feed('d')
    screen:expect {
      grid = [[
      {3:mpor}{5:                               }|
      {3:incididunt ut labore et dolore magn}|
      {3:a aliqua.}{5:                          }|
      {3:Ut enim ad minim veniam, quis nostr}|
      {3:ud xercitation}{5:                     }|
      {3:ullamco laboris nisi ut}{5:            }|
      {3:aliquip ex ea commodo consequat.}{5:   }|
      {6:-- More --}{5:^                         }|
    ]],
    }
    feed('u')
    screen:expect {
      grid = [[
      {3:E5108: Error executing lua [string }|
      {3:":lua"]:1: Lorem ipsum dolor sit am}|
      {3:et, consectetur}{5:                    }|
      {3:adipisicing elit, sed do eiusmod te}|
      {3:mpor}{5:                               }|
      {3:incididunt ut labore et dolore magn}|
      {3:a aliqua.}{5:                          }|
      {6:-- More --}{5:^                         }|
    ]],
    }
    feed('d')
    screen:expect {
      grid = [[
      {3:mpor}{5:                               }|
      {3:incididunt ut labore et dolore magn}|
      {3:a aliqua.}{5:                          }|
      {3:Ut enim ad minim veniam, quis nostr}|
      {3:ud xercitation}{5:                     }|
      {3:ullamco laboris nisi ut}{5:            }|
      {3:aliquip ex ea commodo consequat.}{5:   }|
      {6:-- More --}{5:^                         }|
    ]],
    }
  end)

  it('preserves MsgArea highlighting after more prompt', function()
    screen:try_resize(70, 6)
    command('hi MsgArea guisp=Yellow')
    command('map x Lorem ipsum labore et dolore magna aliqua')
    command('map y adipisicing elit')
    command('map z incididunt ut')
    command('map a labore et dolore')
    command('map b ex ea commodo')
    command('map xx yy')
    command('map xy yz')
    feed(':map<cr>')
    screen:expect {
      grid = [[
      {5:   a             labore et dolore                                     }|
      {5:   b             ex ea commodo                                        }|
      {5:   xy            yz                                                   }|
      {5:   xx            yy                                                   }|
      {5:   x             Lorem ipsum labore et dolore magna aliqua            }|
      {6:-- More --}{5:^                                                            }|
    ]],
    }
    feed('j')
    screen:expect {
      grid = [[
      {5:   b             ex ea commodo                                        }|
      {5:   xy            yz                                                   }|
      {5:   xx            yy                                                   }|
      {5:   x             Lorem ipsum labore et dolore magna aliqua            }|
      {5:   y             adipisicing elit                                     }|
      {6:-- More --}{5:^                                                            }|
    ]],
    }
    feed('j')
    screen:expect {
      grid = [[
      {5:   xy            yz                                                   }|
      {5:   xx            yy                                                   }|
      {5:   x             Lorem ipsum labore et dolore magna aliqua            }|
      {5:   y             adipisicing elit                                     }|
      {5:   z             incididunt ut                                        }|
      {6:Press ENTER or type command to continue}{5:^                               }|
    ]],
    }
  end)

  it('clears "-- more --" message', function()
    command('hi MsgArea guisp=Yellow blend=10')
    feed(':echon join(range(20), "\\n")<cr>')
    screen:expect {
      grid = [[
      {7:0}{8:                                  }|
      {9:1}{10:                                  }|
      {9:2}{10:                                  }|
      {9:3}{10:                                  }|
      {9:4}{10:                                  }|
      {9:5}{10:                                  }|
      {9:6}{10:                                  }|
      {11:--}{8: }{11:More}{8: }{11:--}{8:^                         }|
    ]],
    }

    feed('j')
    screen:expect {
      grid = [[
      {7:1}{8:                                  }|
      {9:2}{10:                                  }|
      {9:3}{10:                                  }|
      {9:4}{10:                                  }|
      {9:5}{10:                                  }|
      {9:6}{10:                                  }|
      {9:7}{10:                                  }|
      {11:--}{8: }{11:More}{8: }{11:--}{8:^                         }|
    ]],
    }

    feed('k')
    screen:expect {
      grid = [[
      {7:0}{8:                                  }|
      {9:1}{10:                                  }|
      {9:2}{10:                                  }|
      {9:3}{10:                                  }|
      {9:4}{10:                                  }|
      {9:5}{10:                                  }|
      {9:6}{10:                                  }|
      {11:--}{8: }{11:More}{8: }{11:--}{8:^                         }|
    ]],
    }

    feed('j')
    screen:expect {
      grid = [[
      {7:1}{8:                                  }|
      {9:2}{10:                                  }|
      {9:3}{10:                                  }|
      {9:4}{10:                                  }|
      {9:5}{10:                                  }|
      {9:6}{10:                                  }|
      {9:7}{10:                                  }|
      {11:--}{8: }{11:More}{8: }{11:--}{8:^                         }|
    ]],
    }
  end)

  it('with :!cmd does not crash on resize', function()
    skip(fn.executable('sleep') == 0, 'missing "sleep" command')
    feed(':!sleep 1<cr>')
    screen:expect {
      grid = [[
                                         |
      {1:~                                  }|*4
      {12:                                   }|
      :!sleep 1                          |
                                         |
    ]],
    }

    -- not processed while command is executing
    async_meths.nvim_ui_try_resize(35, 5)

    -- TODO(bfredl): ideally it should be processed just
    -- before the "press ENTER" prompt though
    screen:expect {
      grid = [[
                                         |
      {1:~                                  }|*2
      {12:                                   }|
      :!sleep 1                          |
                                         |
      {4:Press ENTER or type command to cont}|
      {4:inue}^                               |
    ]],
    }

    feed('<cr>')
    screen:expect {
      grid = [[
      ^                                   |
      {1:~                                  }|*3
                                         |
    ]],
    }
  end)

  it('can be resized', function()
    feed(':lua error(_G.x)<cr>')
    screen:expect {
      grid = [[
      {2:E5108: Error executing lua [string }|
      {2:":lua"]:1: Lorem ipsum dolor sit am}|
      {2:et, consectetur}                    |
      {2:adipisicing elit, sed do eiusmod te}|
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {4:-- More --}^                         |
    ]],
    }

    -- responds to resize, but text is not reflown
    screen:try_resize(45, 5)
    screen:expect {
      grid = [[
      {2:adipisicing elit, sed do eiusmod te}          |
      {2:mpor}                                         |
      {2:incididunt ut labore et dolore magn}          |
      {2:a aliqua.}                                    |
      {4:-- More --}^                                   |
    ]],
    }

    -- can create empty space, as the command hasn't output the text below yet.
    -- text is not reflown; existing lines get cut
    screen:try_resize(30, 12)
    screen:expect {
      grid = [[
      :lua error(_G.x)              |
      {2:E5108: Error executing lua [st}|
      {2:":lua"]:1: Lorem ipsum dolor s}|
      {2:et, consectetur}               |
      {2:adipisicing elit, sed do eiusm}|
      {2:mpore}                         |
      {2:incididunt ut labore et dolore}|
      {2:a aliqua.}                     |
                                    |*3
      {4:-- More --}^                    |
    ]],
    }

    -- continues in a mostly consistent state, but only new lines are
    -- wrapped at the new screen size.
    feed('<cr>')
    screen:expect {
      grid = [[
      {2:E5108: Error executing lua [st}|
      {2:":lua"]:1: Lorem ipsum dolor s}|
      {2:et, consectetur}               |
      {2:adipisicing elit, sed do eiusm}|
      {2:mpore}                         |
      {2:incididunt ut labore et dolore}|
      {2:a aliqua.}                     |
      {2:Ut enim ad minim veniam, quis }|
      {2:nostrud xercitation}           |
      {2:ullamco laboris nisi ut}       |
      {2:aliquip ex ea commodo consequa}|
      {4:-- More --}^                    |
    ]],
    }

    feed('<cr>')
    screen:expect {
      grid = [[
      {2:":lua"]:1: Lorem ipsum dolor s}|
      {2:et, consectetur}               |
      {2:adipisicing elit, sed do eiusm}|
      {2:mpore}                         |
      {2:incididunt ut labore et dolore}|
      {2:a aliqua.}                     |
      {2:Ut enim ad minim veniam, quis }|
      {2:nostrud xercitation}           |
      {2:ullamco laboris nisi ut}       |
      {2:aliquip ex ea commodo consequa}|
      {2:t.}                            |
      {4:-- More --}^                    |
    ]],
    }

    feed('q')
    screen:expect {
      grid = [[
      ^                              |
      {1:~                             }|*10
                                    |
    ]],
    }
  end)

  it('with cmdheight=0 does not crash with g<', function()
    command('set cmdheight=0')
    feed(':ls<cr>')
    screen:expect {
      grid = [[
                                         |
      {1:~                                  }|
      {12:                                   }|
      :ls                                |
        1 %a   "[No Name]"               |
           line 1                        |
      {4:Press ENTER or type command to cont}|
      {4:inue}^                               |
    ]],
    }

    feed('<cr>')
    screen:expect {
      grid = [[
      ^                                   |
      {1:~                                  }|*7
    ]],
    }

    feed('g<lt>')
    screen:expect {
      grid = [[
                                         |
      {1:~                                  }|
      {12:                                   }|
      :ls                                |
        1 %a   "[No Name]"               |
           line 1                        |
      {4:Press ENTER or type command to cont}|
      {4:inue}^                               |
    ]],
    }

    feed('<cr>')
    screen:expect {
      grid = [[
      ^                                   |
      {1:~                                  }|*7
    ]],
    }
  end)
end)

it('pager works in headless mode with UI attached', function()
  skip(is_os('win'))
  clear()
  local child_server = assert(helpers.new_pipename())
  fn.jobstart({ nvim_prog, '--clean', '--headless', '--listen', child_server })
  retry(nil, nil, function()
    neq(nil, vim.uv.fs_stat(child_server))
  end)

  local child_session = helpers.connect(child_server)
  local child_screen = Screen.new(40, 6)
  child_screen:attach(nil, child_session)

  child_session:notify('nvim_command', [[echo range(100)->join("\n")]])
  child_screen:expect([[
    0                                       |
    1                                       |
    2                                       |
    3                                       |
    4                                       |
    -- More --^                              |
  ]])

  child_session:request('nvim_input', 'G')
  child_screen:expect([[
    95                                      |
    96                                      |
    97                                      |
    98                                      |
    99                                      |
    Press ENTER or type command to continue^ |
  ]])

  child_session:request('nvim_input', 'g')
  child_screen:expect([[
    0                                       |
    1                                       |
    2                                       |
    3                                       |
    4                                       |
    -- More --^                              |
  ]])
end)
