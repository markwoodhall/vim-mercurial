if exists('g:loaded_mercurial') || &cp
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
  call system('hg commit -m "' . a:message .'"')
endfunction

function! mercurial#commit_from_buffer() abort
  let message = []
  for l in getline(0, '$')
    if l !~ '^HG:.*$'
      let message += [l]
    endif
  endfor

  if empty(message)
    return
  endif

  let message = join(message, '\n')

  echomsg 'using message ' .message
  call mercurial#commit(message)
endfunction

function! mercurial#prepare_commit() abort
  let info = getline(0, '$')
  execute ":q!"
  let command = (expand('%b') =~ 'vim-mercurial-commit' || buffer_exists('vim-mercurial-commit')) ? 'e' : 'split'
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
    hi hgBranch guifg=#8C7A37

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

    autocmd BufWrite * call mercurial#commit_from_buffer()
endfunction

function! mercurial#status() abort
  let command = (expand('%b') =~ 'vim-mercurial' || buffer_exists('vim-mercurial')) ? 'e' : 'split'
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
    hi hgBranch guifg=#8C7A37

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

autocmd BufEnter * command! -buffer Hgstatus :call mercurial#status()
autocmd BufEnter * command! -buffer -nargs=* -complete=file Hgadd :call mercurial#add(<f-args>)
autocmd BufEnter * command! -buffer -nargs=* -complete=file Hgforget :call mercurial#forget(<f-args>)
autocmd BufEnter * command! -buffer -nargs=* -complete=file Hgrevert :call mercurial#revert(<f-args>)
