if exists('g:loaded_mercurial') || &cp
  finish
endif

if !filereadable('.hg/00changelog.i')
  finish
endif

let g:loaded_mercurial = 1
let g:mercurial#filename_offset = 6

function! s:goto_line(line)
  let counter=1
  for l in getline(0, '$')
    if l[g:mercurial#filename_offset:-1] == a:line[g:mercurial#filename_offset:-1]
      call setpos('.', [0, counter, g:mercurial#filename_offset-1, 0])
    endif
    let counter += 1
  endfor
endfunction

function! mercurial#open_in_split()
  let file = getline('.')[g:mercurial#filename_offset:-1]
  execute 'leftabove split ' . file
endfunction

function! mercurial#add(file) abort
  call system('hg add '. a:file)
endfunction

function! mercurial#forget(file) abort
  call system('hg forget '. a:file)
endfunction

function! mercurial#revert(file) abort
  call system('hg revert '. a:file)
endfunction

function! mercurial#forget_under_cursor() abort
  let line = getline('.')
  if line =~ '    A'
    call mercurial#forget(line[g:mercurial#filename_offset:-1])
    call mercurial#status()
    call s:goto_line(line)
  endif
endfunction

function! mercurial#add_under_cursor() abort
  let line = getline('.')
  if line =~ '    ?'
    call mercurial#add(line[g:mercurial#filename_offset:-1])
    call mercurial#status()
    call s:goto_line(line)
  endif
endfunction

function! mercurial#revert_under_cursor() abort
  let line = getline('.')
  if line =~ '    M' || line =~ '    !'  || line =~ '    R'
    call mercurial#revert(line[g:mercurial#filename_offset:-1])
    call mercurial#status()
    call s:goto_line(line)
  endif
endfunction

function! mercurial#branch()
  return system('hg branch')[0:-2]
endfunction

function! mercurial#user()
  let config = split(system('hg showconfig'), '\n')
  let user = ''
  for c in config
    if c =~ '^ui.username.*$'
      let user = substitute(c, 'ui.username=', '', '')
    endif
  endfor
  return user
endfunction

function! mercurial#commit(message, files, args) abort
  if empty(a:message)
    return
  endif
  let temp_commit_file = tempname()
  call system('echo "'.substitute(a:message, '"', '\\"', 'g').'" > '.temp_commit_file)
  let commit_output = system('hg commit -m "$(cat '.temp_commit_file.')" ' . join(a:files, ' ') . ' ' . a:args)
  if empty(commit_output)
    call mercurial#commit_stat()
  endif
endfunction

function! mercurial#commit_from_buffer() abort
  let message = []
  for l in getline(0, '$')
    if l !~ '^HG:.*$'
      let message += [l]
    else
      break
    endif
  endfor

  if !empty(message)
    let files = []
    let found_files = 0
    for f in getline(0, '$')
      if f == 'Changes ready for commit: '
        let found_files = 1
      elseif found_files
        if !empty(f)
          let file = f[g:mercurial#filename_offset:-1]
          if filereadable(file)
            let files += [file]
          endif
        endif
      endif
    endfor
    let message = join(message, '\n')
    call mercurial#commit(message, files, s:commit_args)
  endif
endfunction

function! mercurial#inline_diff() abort
  let output = split(system('hg diff '.getline('.')[g:mercurial#filename_offset:-1]), '\n')
  call append(line('.'), output)
endfunction

function! mercurial#prepare_commit(...) abort
  let s:commit_args = ''
  if a:0 >= 1
    let s:commit_args = join(a:000, ' ')
  endif
  let info = []
  if expand('%b') == 'vim-mercurial'
    let info = getline(0, '$')
  endif

  let command = expand('%b') == 'vim-mercurial' ? 'e' : 'split'
  execute command 'vim-mercurial-commit'

    execute "resize 20"
    silent execute "f ". tempname()

    setlocal syntax=diff
    setlocal colorcolumn=80

    syn region hgCommitMessage start="\%1l" end="\%2l" 
    syn match hgModified	"M .*$"
    syn match hgAdded	    "A .*$"
    syn match hgMissing	  "! .*$"
    syn match hgNew	      "? .*$"
    syn match hgBranch	  "(.*)$"

    hi hgCommitMessage guifg=#99C794
    hi hgModified guifg=#6699CC
    hi hgMissing guifg=#5FB3B3
    hi hgAdded guifg=#99C794
    hi hgNew guifg=#C595C5
    hi hgBranch guifg=#FAC863

    let lines =  ["",
                \ "HG: Enter commit message.  Lines beginning with 'HG:' are removed.",
                \ "HG: Leave message empty to abort commit.",
                \ "HG: --",
                \ "HG: user: " . mercurial#user(),
                \ "HG: branch " . mercurial#branch()]

    for i in info
      let lines += [i]
    endfor

    normal ggdG
    call append(0, lines)

    normal dd
    normal gg

    nnoremap <silent> <buffer> D :call mercurial#inline_diff()<CR>
    autocmd! * <buffer>
    autocmd BufLeave <buffer> call mercurial#commit_from_buffer()
endfunction

function! mercurial#status() abort
  let command = expand('%b') =~ 'vim-mercurial' ? 'e' : 'split'
  execute command 'vim-mercurial'

    execute "resize 20"

    setlocal buftype=nofile
    setlocal syntax=diff

    syn match hgModified	"M .*$"
    syn match hgAdded	    "A .*$"
    syn match hgRemoved   "R .*$"
    syn match hgMissing	  "! .*$"
    syn match hgNew	      "? .*$"
    syn match hgBranch	  "(.*)$"

    hi hgModified guifg=#6699CC
    hi hgMissing guifg=#5FB3B3
    hi hgAdded guifg=#99C794
    hi hgNew guifg=#C595C5
    hi hgRemoved guifg=#EC695D
    hi hgBranch guifg=#FAC863

    let hg_branch = mercurial#branch()
    let hg_status = system('hg status')
    let lines = ["On branch (".hg_branch.")",
                \ "",
                \ "No changes ready for commit"]

    if !empty(hg_status)
      let lines = ["On branch (".hg_branch.")",
                \ "",
                \ "Changes ready for commit: ",
                \ ""]

      let statuses = split(hg_status, '\n')
      for s in statuses
        let lines += ['    '.s]
      endfor
    endif

    normal ggdG
    call append(0, lines)
    normal dd
    normal gg

    nnoremap <silent> <buffer> - :call mercurial#forget_under_cursor()<CR>
    nnoremap <silent> <buffer> + :call mercurial#add_under_cursor()<CR>
    nnoremap <silent> <buffer> U :call mercurial#revert_under_cursor()<CR>
    nnoremap <silent> <buffer> R :call mercurial#status()<CR>
    nnoremap <silent> <buffer> C :call mercurial#prepare_commit()<CR>
    nnoremap <silent> <buffer> A :call mercurial#prepare_commit('--amend')<CR>
    nnoremap <silent> <buffer> D :call mercurial#inline_diff()<CR>
    nnoremap <silent> <buffer> E :call mercurial#open_in_split()<CR>

endfunction

function! mercurial#tag(...)
  let args = ''
  if len(a:0) >= 1
    let args = join(a:000, ' ')
  endif
  let output = split(system('hg tag '. args), '\n')
  if empty(output)
    call mercurial#tags()
  endif
endfunction

function! mercurial#tags(...)
  let args = ''
  if len(a:0) >= 1
    let args = join(a:000, ' ')
  endif
  let output = split(system('hg tags '. args), '\n')

  let command = expand('%b') =~ 'vim-mercurial' ? 'e' : 'split'
  execute command 'vim-mercurial'

    execute "resize 20"

    setlocal buftype=nofile
    setlocal syntax=diff

    syn match hgTag	"^.*\s"

    hi hgTag guifg=#FAC863

    normal ggdG
    call append(0, output)
    normal dd
    normal gg

    nnoremap <silent> <buffer> D :call mercurial#log('--rev', split(getline('.'),':')[-1], '-p')<CR>
endfunction

function! mercurial#change_list(cmd, args)
  let args = ''
  if len(a:args) >= 1
    let args = join(a:args, ' ')
  endif
  let output = split(system('hg '. a:cmd .' '. args), '\n')

  let command = expand('%b') =~ 'vim-mercurial' ? 'e' : 'botright split'
  execute command 'vim-mercurial'

    execute "resize 20"

    setlocal buftype=nofile
    setlocal syntax=diff

    syn match hgTitle	"^\w*"

    hi hgTitle guifg=#FAC863

    normal ggdG
    call append(0, output)
    normal dd
    normal gg
endfunction

function! mercurial#commit_stat()
  let output = split(system('hg log --limit 1 --stat'), '\n')

  let command = expand('%b') =~ 'vim-mercurial' ? 'e' : 'split'
  execute command 'vim-mercurial'

    execute "resize 20"

    setlocal buftype=nofile
    setlocal syntax=diff

    syn match hgDeletions   "-"
    syn match hgAdditions   "+"

    hi hgDeletions guifg=#EC5F67
    hi hgAdditions guifg=#99C794

    normal ggdG
    call append(0, output[6:-2])
    normal dd
    normal gg
endfunction

function! mercurial#log(...)
  call mercurial#change_list('log', a:000)
endfunction

function! mercurial#glog(...)
  call mercurial#change_list('glog', a:000)
endfunction

function! mercurial#inc(...)
  call mercurial#change_list('incoming', a:000)
endfunction

function! mercurial#out(...)
  call mercurial#change_list('outgoing', a:000)
endfunction

function! mercurial#heads(...)
  call mercurial#change_list('heads', a:000)
endfunction

function! mercurial#branches(...)
  let args = ''
  if len(a:0) >= 1
    let args = join(a:000, ' ')
  endif
  let output = split(system('hg branches '. args), '\n')

  let command = expand('%b') =~ 'vim-mercurial' ? 'e' : 'botright split'
  execute command 'vim-mercurial'

    execute "resize 20"

    setlocal buftype=nofile
    setlocal syntax=diff

    syn match hgTitle	"^\w*"
    syn match hgValue	"\w*:\w*"
    syn region hgBranch start="\%1l" end="\%2l" contains=hgValue

    hi hgValue guifg=#ffffff
    hi hgTitle guifg=#FAC863
    hi hgBranch guifg=#99C794

    normal ggdG
    call append(0, output)
    normal dd
    normal gg
endfunction

function! mercurial#blame(...)
  let args = ''
  if a:0 >= 1
    let args = join(a:000, ' ')
  endif
  let args = expand('%') . ' ' . args
  echomsg string(args)
  let output = split(system('hg blame ' . args . ' --changeset --number --user --date -q'), '\n')
  let current_line = line('.')

  setlocal scrollbind nowrap nofoldenable
  exe 'keepalt leftabove vsplit mercurial-blame'
  setlocal nomodified nonumber scrollbind nowrap foldcolumn=0 nofoldenable

    execute "vertical resize 30"
    setlocal buftype=nofile
    setlocal syntax=diff

    execute current_line
    syncbind

    syn match hgBlameBoundary  "^\^"
    syn match hgBlameBlank     "^\s\+\s\@="
    syn match hgBlameAuthor    "\w\+"
    syn match hgBlameNumber    "\d\+"
    syn match hgBlameChangeset "[a-f0-9]\{12\}"
    syn match hgBlameDate      "[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}"

    hi hgBlameChangeset guifg=#FAC863
    hi hgBlameAuthor guifg=#C595C5
    hi hgBlameDate guifg=#6699CC
    hi hgBlameNumber guifg=#FAC863

    normal ggdG
    let cleaned = []
    for o in output
      let cleaned += [split(o, ':')[0]]
    endfor
    call append(0, cleaned)
    normal dd
    normal gg

    nnoremap <silent> <buffer> D :call mercurial#log('--rev', split(getline('.'),' ')[2], '-p')<CR>
endfunction

function! mercurial#rename(from, to, ...) abort
  let args = ''
  if a:0 >= 1
    let args = join(a:000, ' ')
  endif
  let output = split(system('hg rename ' . a:from . ' ' . a:to . ' ' . args), '\n')
  if empty(output)
    if expand('%') == a:from
      execute 'e ' . a:to
    endif
  endif
endfunction

function! mercurial#config(...)
  let args = ''
  if a:0 >= 1
    let args = join(a:000, ' ')
  endif

  let output = split(system('hg showconfig ' . args), '\n')

  let command = expand('%b') =~ 'vim-mercurial' ? 'e' : 'split'
  execute command 'vim-mercurial'

    execute "resize 20"

    setlocal buftype=nofile
    setlocal syntax=ini

    normal ggdG
    call append(0, output)
    normal dd
    normal gg
endfunction

function! mercurial#hg(...)
  let args = ''
  if a:0 >= 1
    let args = join(a:000, ' ')
  endif
  let output = split(system('hg ' . args), '\n')

  let command = expand('%b') =~ 'vim-mercurial' ? 'e' : 'split'
  execute command 'vim-mercurial'

    execute "resize 20"

    setlocal buftype=nofile

    normal ggdG
    call append(0, output)
    normal dd
endfunction

function! mercurial#complete_command(A, L, P)
  let commands = []
  let output = split(system('hg --help'), '\n')[5:-1]

  for o in output
    if o == 'enabled extensions:'
      break
    endif
    let command = split(o, ' ')
    if len(command) > 0 && command[0] =~ a:A
      let commands += [command[0]]
    endif
  endfor

  return commands
endfunction

autocmd BufEnter * command! -buffer -nargs=* -complete=customlist,mercurial#complete_command Hg :call mercurial#hg(<f-args>)
autocmd BufEnter * command! -buffer -nargs=* Hgcommit :call mercurial#prepare_commit(<f-args>)
autocmd BufEnter * command! -buffer -nargs=* Hgtag :call mercurial#tag(<f-args>)
autocmd BufEnter * command! -buffer -nargs=* Hgtags :call mercurial#tags(<f-args>)
autocmd BufEnter * command! -buffer -nargs=* Hgheads :call mercurial#heads(<f-args>)
autocmd BufEnter * command! -buffer -nargs=* Hgbranch :call mercurial#hg('branch', <f-args>)
autocmd BufEnter * command! -buffer -nargs=* Hgbranches :call mercurial#branches(<f-args>)
autocmd BufEnter * command! -buffer -nargs=* Hglog :call mercurial#log(<f-args>)
autocmd BufEnter * command! -buffer -nargs=* Hgglog :call mercurial#glog(<f-args>)
autocmd BufEnter * command! -buffer -nargs=* Hginc :call mercurial#inc(<f-args>)
autocmd BufEnter * command! -buffer -nargs=* Hgout :call mercurial#out(<f-args>)
autocmd BufEnter * command! -buffer -nargs=* Hgcstat :call mercurial#commit_stat(<f-args>)
autocmd BufEnter * command! -buffer -nargs=* Hgblame :call mercurial#blame(<f-args>)
autocmd BufEnter * command! -buffer -nargs=* Hgconfig :call mercurial#config(<f-args>)

autocmd BufEnter * command! -buffer Hgstatus :call mercurial#status()

autocmd BufEnter * command! -buffer -nargs=* -complete=file Hgadd :call mercurial#add(<f-args>)
autocmd BufEnter * command! -buffer -nargs=* -complete=file Hgforget :call mercurial#forget(<f-args>)
autocmd BufEnter * command! -buffer -nargs=* -complete=file Hgrevert :call mercurial#revert(<f-args>)
autocmd BufEnter * command! -buffer -nargs=* -complete=file Hgrename :call mercurial#rename(<f-args>)

autocmd BufEnter * command! -buffer -nargs=* -complete=file HgaddB :call mercurial#add(expand('%'), <f-args>)
autocmd BufEnter * command! -buffer -nargs=* -complete=file HgforgetB :call mercurial#forget(expand('%'), <f-args>)
autocmd BufEnter * command! -buffer -nargs=* -complete=file HgrevertB :call mercurial#revert(expand('%'), <f-args>)
autocmd BufEnter * command! -buffer -nargs=* -complete=file HgrenameB :call mercurial#rename(expand('%'), <f-args>)
