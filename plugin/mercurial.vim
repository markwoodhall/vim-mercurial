if exists('g:loaded_mercurial') || &cp
  finish
endif

if !filereadable('.hg/hgrc')
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
  if line =~ '    M' || line =~ '    !'
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

function! mercurial#commit(message) abort
  if empty(a:message)
    return
  endif
  let temp_commit_file = tempname()
  call system('echo "'.substitute(a:message, '"', '\\"', 'g').'" > '.temp_commit_file)
  call system('hg commit -m "$(cat '.temp_commit_file.')"')
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

  if empty(message)
    return
  endif

  let message = join(message, '\n')

  call mercurial#commit(message)
endfunction

function! mercurial#prepare_commit() abort
  let info = getline(0, '$')
  execute ":q!"
  let command = expand('%b') =~ 'vim-mercurial-commit' ? 'e' : 'split'
  execute command 'vim-mercurial-commit'

    execute "resize 20"
    silent execute "f ". tempname()

    setlocal syntax=diff

    syn match hgModified	"M .*$"
    syn match hgAdded	    "A .*$"
    syn match hgMissing	  "! .*$"
    syn match hgNew	      "? .*$"
    syn match hgBranch	  "(.*)$"

    hi hgModified guifg=#6699CC
    hi hgMissing guifg=#5FB3B3
    hi hgAdded guifg=#99C794
    hi hgNew guifg=#C595C5
    hi hgBranch guifg=#FAC863

    let lines =  ["HG: Enter commit message.  Lines beginning with 'HG:' are removed.",
                \ "HG: Leave message empty to abort commit.",
                \ "HG: --",
                \ "HG: user: " . mercurial#user(),
                \ "HG: branch " . mercurial#branch()]

    for i in info
      let lines += ['HG: ' . i]
    endfor

    normal ggdG
    call append(0, lines)

    normal dd
    normal gg

    nnoremap <silent> <buffer> D :call append(line('.'), split(system('hg diff '.getline('.')[g:mercurial#filename_offset+3:-1]), '\n'))<CR>
    autocmd BufWrite * call mercurial#commit_from_buffer()
endfunction

function! mercurial#status() abort
  let command = expand('%b') =~ 'vim-mercurial' ? 'e' : 'split'
  execute command 'vim-mercurial'

    execute "resize 20"

    setlocal buftype=nofile
    setlocal syntax=diff

    syn match hgModified	"M .*$"
    syn match hgAdded	    "A .*$"
    syn match hgMissing	  "! .*$"
    syn match hgNew	      "? .*$"
    syn match hgBranch	  "(.*)$"

    hi hgModified guifg=#6699CC
    hi hgMissing guifg=#5FB3B3
    hi hgAdded guifg=#99C794
    hi hgNew guifg=#C595C5
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

    nnoremap <silent> <buffer> - :call mercurial#forget_under_cursor()<CR>
    nnoremap <silent> <buffer> + :call mercurial#add_under_cursor()<CR>
    nnoremap <silent> <buffer> U :call mercurial#revert_under_cursor()<CR>
    nnoremap <silent> <buffer> R :call mercurial#status()<CR>
    nnoremap <silent> <buffer> C :call mercurial#prepare_commit()<CR>
    nnoremap <silent> <buffer> D :call append(line('.'), split(system('hg diff '.getline('.')[g:mercurial#filename_offset:-1]), '\n'))<CR>

endfunction

function! mercurial#change_list(cmd, args)
  let args = ''
  if len(a:args) >= 1
    let args = join(a:args, ' ')
  endif
  let output = split(system('hg '. a:cmd .' '. args), '\n')

  let command = expand('%b') =~ 'vim-mercurial' ? 'e' : 'split'
  execute command 'vim-mercurial'

    execute "resize 20"

    setlocal buftype=nofile
    setlocal syntax=diff

    syn match hgChangeset	"changeset:"
    syn match hgTag	      "tag:"
    syn match hgUser      "user:"
    syn match hgDate      "date:"
    syn match hgSummary   "summary:"

    hi hgChangeset guifg=#FAC863
    hi hgTag       guifg=#FAC863
    hi hgUser      guifg=#FAC863
    hi hgDate      guifg=#FAC863
    hi hgSummary   guifg=#FAC863

    normal ggdG
    call append(0, output)
    normal dd
    normal gg
endfunction

function! mercurial#hglog(...)
  call mercurial#change_list('log', a:000)
endfunction

function! mercurial#hginc(...)
  call mercurial#change_list('incoming', a:000)
endfunction

function! mercurial#hgout(...)
  call mercurial#change_list('outgoing', a:000)
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

autocmd BufEnter * command! -buffer -nargs=* Hg :call mercurial#hg(<f-args>)
autocmd BufEnter * command! -buffer -nargs=* Hglog :call mercurial#hglog(<f-args>)
autocmd BufEnter * command! -buffer -nargs=* Hginc :call mercurial#hginc(<f-args>)
autocmd BufEnter * command! -buffer -nargs=* Hgout :call mercurial#hgout(<f-args>)
autocmd BufEnter * command! -buffer Hgstatus :call mercurial#status()
autocmd BufEnter * command! -buffer -nargs=* -complete=file Hgadd :call mercurial#add(<f-args>)
autocmd BufEnter * command! -buffer -nargs=* -complete=file Hgforget :call mercurial#forget(<f-args>)
autocmd BufEnter * command! -buffer -nargs=* -complete=file Hgrevert :call mercurial#revert(<f-args>)
